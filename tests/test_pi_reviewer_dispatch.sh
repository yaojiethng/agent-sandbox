#!/usr/bin/env bash
# tests/test_pi_reviewer_dispatch.sh
# The reviewer dispatch is one mechanism: the pair is pinned, the preconditions
# are refusals in code, and each reviewer's result is checked three ways.
#
# Tests:
#   - the usage guard takes exactly a brief file and a scratch directory
#   - a missing brief, an empty brief, an absent scratch directory and an
#     unwritable scratch directory are each refused by name
#   - a dirty working tree is refused, with the offending paths printed
#   - the pair runs, both logs land under the scratch directory, and the
#     requested models are reported
#   - a reviewer that logs nothing fails the run
#   - a reviewer that binds another model fails the run and prints both ids
#
# Run:   bash tests/test_pi_reviewer_dispatch.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"

DISPATCH="$REPO_ROOT/src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/dispatch.sh"

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

# fixture SANDBOX  --  a clean repo, a scratch dir, a brief and a stub bin,
#   with none of the latter three inside the repo.
make_workspace() {
  local sandbox="$1"
  make_committed_repo "$sandbox/repo"
  mkdir -p "$sandbox/scratch"
  printf 'the brief\n' > "$sandbox/brief.md"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_usage_takes_exactly_two_arguments() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$( (cd "$sandbox/repo" && bash "$DISPATCH") 2>&1 )"; rc=$?
  assert_rc 1 "$rc" "no arguments is refused"
  assert_contains "$out" "usage: bash dispatch.sh <brief-file> <scratch-dir>" "the usage names both arguments"

  out="$( (cd "$sandbox/repo" && bash "$DISPATCH" "$sandbox/brief.md") 2>&1 )"; rc=$?
  assert_rc 1 "$rc" "one argument is refused"
}

test_refuses_a_bad_brief() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$( (cd "$sandbox/repo" && bash "$DISPATCH" "$sandbox/absent.md" "$sandbox/scratch") 2>&1 )"; rc=$?
  assert_rc 1 "$rc" "a missing brief is refused"
  assert_contains "$out" "brief not found" "the refusal names the brief"

  : > "$sandbox/empty.md"
  out="$( (cd "$sandbox/repo" && bash "$DISPATCH" "$sandbox/empty.md" "$sandbox/scratch") 2>&1 )"; rc=$?
  assert_rc 1 "$rc" "an empty brief is refused"
  assert_contains "$out" "brief is empty" "the refusal says empty"
}

test_refuses_a_bad_scratch_directory() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$( (cd "$sandbox/repo" && bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/absent-dir") 2>&1 )"; rc=$?
  assert_rc 1 "$rc" "an absent scratch directory is refused"
  assert_contains "$out" "scratch directory not found" "the refusal names the scratch directory"

  mkdir -p "$sandbox/readonly"
  chmod 500 "$sandbox/readonly"
  out="$( (cd "$sandbox/repo" && bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/readonly") 2>&1 )"; rc=$?
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

  out="$( (cd "$sandbox/repo" && bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/scratch") 2>&1 )"; rc=$?
  assert_rc 1 "$rc" "a dirty tree is refused"
  assert_contains "$out" "the working tree is dirty" "the refusal names the tree"
  assert_contains "$out" "file.txt" "the refusal prints the offending path"
}

test_dispatches_the_pair_and_reports_both() {
  local sandbox out rc run_dir
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub_pi "$sandbox/bin" ok

  out="$( (cd "$sandbox/repo" && PATH="$sandbox/bin:$PATH" bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/scratch") 2>&1 )"; rc=$?
  assert_rc 0 "$rc" "the pair runs and the run succeeds"
  assert_contains "$out" "fast" "the report names the first reviewer"
  assert_contains "$out" "flash" "the report names the second reviewer"
  assert_contains "$out" "model=deepseek-v4.1-flash" "the first requested model is read back"
  assert_contains "$out" "model=deepseek-flash" "the second requested model is read back"

  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  assert_dir_exists "$run_dir" "the run directory is created"
  assert_contains "$(printf '%s' "$run_dir")" "$sandbox/scratch/review-dispatch." "the run directory is created under the directed scratch directory"
  assert_file_exists "$run_dir/fast.log" "the first log exists"
  assert_file_exists "$run_dir/flash.log" "the second log exists"
  assert_not_empty "$(cat "$run_dir/fast.log")" "the first log holds the report"
}

test_a_silent_reviewer_fails_the_run() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub_pi "$sandbox/bin" empty-log

  out="$( (cd "$sandbox/repo" && PATH="$sandbox/bin:$PATH" bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/scratch") 2>&1 )"; rc=$?
  assert_rc 1 "$rc" "a reviewer that logs nothing fails the run"
  assert_contains "$out" "NO OUTPUT" "the report names the silent reviewer"
  assert_contains "$out" "no usable work" "the refusal says the run produced nothing"
}

test_a_misbound_model_fails_the_run() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub_pi "$sandbox/bin" wrong-model

  out="$( (cd "$sandbox/repo" && PATH="$sandbox/bin:$PATH" bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/scratch") 2>&1 )"; rc=$?
  assert_rc 1 "$rc" "a reviewer that bound another model fails the run"
  assert_contains "$out" "BOUND" "the report marks the misbind"
  assert_contains "$out" "some-other-model" "the report prints the model that was bound"
}

run_test test_usage_takes_exactly_two_arguments
run_test test_refuses_a_bad_brief
run_test test_refuses_a_bad_scratch_directory
run_test test_refuses_a_dirty_tree
run_test test_dispatches_the_pair_and_reports_both
run_test test_a_silent_reviewer_fails_the_run
run_test test_a_misbound_model_fails_the_run

test_done
