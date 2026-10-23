#!/usr/bin/env bash
# tests/test_review_dispatch.sh
# The review dispatch is one mechanism: the pair arrives from the caller, the
# preconditions are refusals in code, and each seat's result is checked three
# ways.
#
# Tests:
#   - the usage guard takes a brief file, a scratch directory, a pair and a level
#   - a malformed pair and an empty thinking level are refused
#   - a missing brief, an empty brief, an absent scratch directory and an
#     unwritable scratch directory are each refused by name
#   - a dirty working tree is refused, with the offending paths printed
#   - the pair runs, both logs land under the scratch directory, and the
#     requested model is reported for both seats
#   - a seat that logs nothing fails the run
#   - a seat that binds another model fails the run and prints both ids
#   - the runner carries no model, provider or pinned pair
#
# Run:   bash tests/test_review_dispatch.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"

DISPATCH="$REPO_ROOT/src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh"
PAIR="deepseek/deepseek-flash"
LEVEL="high"

# write_stub_pi DIR MODE
#   MODE: ok | empty-log | wrong-model
#   Writes a `pi` that records the requested model into the session file the
#   script passes, and then behaves according to MODE.
write_stub_pi() {
  local dir="$1" mode="$2"
  mkdir -p "$dir"
  cat > "$dir/pi" <<STUB
#!/usr/bin/env bash
session=""; model=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --session) session="\$2"; shift 2 ;;
    --model) model="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '{"model":"%s"}\n' "\$model" > "\$session"
STUB
  case "$mode" in
    ok)          printf 'printf "report line\\n"\n' >> "$dir/pi" ;;
    empty-log)   printf ':\n' >> "$dir/pi" ;;
    wrong-model)
      printf 'printf "{%%s}" "not the requested model"\n' >> "$dir/pi"
      printf 'printf "{\\"model\\":\\"some-other-model\\"}\\n" > "$session"\n' >> "$dir/pi" ;;
  esac
  chmod +x "$dir/pi"
}

# make_workspace SANDBOX  --  a clean repo, a scratch dir and a brief, none of
#   the latter two inside the repo.
make_workspace() {
  local sandbox="$1"
  make_committed_repo "$sandbox/repo"
  mkdir -p "$sandbox/scratch"
  printf 'the brief\n' > "$sandbox/brief.md"
}

# run_dispatch SANDBOX [ARGS...]  --  run the dispatcher from inside the repo.
run_dispatch() {
  local sandbox="$1"; shift
  (cd "$sandbox/repo" && bash "$DISPATCH" "$@") 2>&1
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_usage_takes_the_brief_the_scratch_the_pair_and_the_level() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(run_dispatch "$sandbox")"; rc=$?
  assert_rc 1 "$rc" "no arguments is refused"
  assert_contains "$out" "usage: bash review-dispatch.sh <brief-file> <scratch-dir> <pair> <level>" "the usage names all four arguments"

  out="$(run_dispatch "$sandbox" "$sandbox/brief.md" "$sandbox/scratch" "$PAIR")"; rc=$?
  assert_rc 1 "$rc" "three arguments is refused"
}

test_refuses_a_malformed_pair_and_an_empty_level() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(run_dispatch "$sandbox" "$sandbox/brief.md" "$sandbox/scratch" "deepseek-flash" "$LEVEL")"; rc=$?
  assert_rc 1 "$rc" "a pair with no provider prefix is refused"
  assert_contains "$out" "pair is not provider/model" "the refusal names the shape"

  out="$(run_dispatch "$sandbox" "$sandbox/brief.md" "$sandbox/scratch" "$PAIR" "")"; rc=$?
  assert_rc 1 "$rc" "an empty thinking level is refused"
  assert_contains "$out" "thinking level is empty" "the refusal names the level"
}

test_refuses_a_bad_brief() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(run_dispatch "$sandbox" "$sandbox/absent.md" "$sandbox/scratch" "$PAIR" "$LEVEL")"; rc=$?
  assert_rc 1 "$rc" "a missing brief is refused"
  assert_contains "$out" "brief not found" "the refusal names the brief"

  : > "$sandbox/empty.md"
  out="$(run_dispatch "$sandbox" "$sandbox/empty.md" "$sandbox/scratch" "$PAIR" "$LEVEL")"; rc=$?
  assert_rc 1 "$rc" "an empty brief is refused"
  assert_contains "$out" "brief is empty" "the refusal says empty"
}

test_refuses_a_bad_scratch_directory() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(run_dispatch "$sandbox" "$sandbox/brief.md" "$sandbox/absent-dir" "$PAIR" "$LEVEL")"; rc=$?
  assert_rc 1 "$rc" "an absent scratch directory is refused"
  assert_contains "$out" "scratch directory not found" "the refusal names the scratch directory"

  mkdir -p "$sandbox/readonly"
  chmod 500 "$sandbox/readonly"
  out="$(run_dispatch "$sandbox" "$sandbox/brief.md" "$sandbox/readonly" "$PAIR" "$LEVEL")"; rc=$?
  chmod 700 "$sandbox/readonly"
  if [[ "$(id -u)" -eq 0 ]]; then
    pass "unwritable scratch directory is refused (skipped: running as root)"
  else
    assert_rc 1 "$rc" "an unwritable scratch directory is refused"
    assert_contains "$out" "not writable" "the refusal says why"
  fi
}

test_refuses_a_dirty_tree() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf 'uncommitted\n' >> "$sandbox/repo/file.txt"

  out="$(run_dispatch "$sandbox" "$sandbox/brief.md" "$sandbox/scratch" "$PAIR" "$LEVEL")"; rc=$?
  assert_rc 1 "$rc" "a dirty tree is refused"
  assert_contains "$out" "the working tree is dirty" "the refusal names the tree"
  assert_contains "$out" "file.txt" "the refusal prints the offending path"
}

test_dispatches_the_pair_and_reports_both_seats() {
  local sandbox out rc run_dir
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub_pi "$sandbox/bin" ok

  out="$(cd "$sandbox/repo" && PATH="$sandbox/bin:$PATH" bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/scratch" "$PAIR" "$LEVEL" 2>&1)"; rc=$?
  assert_rc 0 "$rc" "the pair runs and the run succeeds"
  assert_contains "$out" "pair: $PAIR" "the run names the pair it was given"
  assert_contains "$out" "model=deepseek-flash" "the requested model is read back"

  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  assert_dir_exists "$run_dir" "the run directory is created"
  assert_contains "$run_dir" "$sandbox/scratch/review-dispatch." "the run directory is created under the directed scratch directory"
  assert_file_exists "$run_dir/a.log" "the first seat's log exists"
  assert_file_exists "$run_dir/b.log" "the second seat's log exists"
  assert_not_empty "$(cat "$run_dir/a.log")" "the first seat's log holds the report"
  assert_not_empty "$(cat "$run_dir/b.log")" "the second seat's log holds the report"
}

test_a_silent_seat_fails_the_run() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub_pi "$sandbox/bin" empty-log

  out="$(cd "$sandbox/repo" && PATH="$sandbox/bin:$PATH" bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/scratch" "$PAIR" "$LEVEL" 2>&1)"; rc=$?
  assert_rc 1 "$rc" "a seat that logs nothing fails the run"
  assert_contains "$out" "NO OUTPUT" "the report names the silent seat"
  assert_contains "$out" "no usable work" "the refusal says the run produced nothing"
}

test_a_misbound_model_fails_the_run() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub_pi "$sandbox/bin" wrong-model

  out="$(cd "$sandbox/repo" && PATH="$sandbox/bin:$PATH" bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/scratch" "$PAIR" "$LEVEL" 2>&1)"; rc=$?
  assert_rc 1 "$rc" "a seat that bound another model fails the run"
  assert_contains "$out" "BOUND" "the report marks the misbind"
  assert_contains "$out" "some-other-model" "the report prints the model that was bound"
}

test_the_runner_carries_no_pair() {
  local hits
  hits="$(grep -En 'deepseek|openrouter|opencode-go|z-ai|step-5' "$DISPATCH")" || true
  assert_eq "" "$hits" "the runner names no model, provider or pinned pair"
}

run_test test_usage_takes_the_brief_the_scratch_the_pair_and_the_level
run_test test_refuses_a_malformed_pair_and_an_empty_level
run_test test_refuses_a_bad_brief
run_test test_refuses_a_bad_scratch_directory
run_test test_refuses_a_dirty_tree
run_test test_dispatches_the_pair_and_reports_both_seats
run_test test_a_silent_seat_fails_the_run
run_test test_a_misbound_model_fails_the_run
run_test test_the_runner_carries_no_pair

test_done
