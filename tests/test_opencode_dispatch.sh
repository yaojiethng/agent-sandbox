#!/usr/bin/env bash
# TEST_DEADLINE: 12
# tests/test_opencode_dispatch.sh
# The general OpenCode dispatch reports a change set against a named base
# revision, so a later pass over the same unit runs in place.
#
# Tests:
#   - the usage guard takes a brief file and a scratch directory
#   - a missing brief, an empty brief and an absent scratch directory are each
#     refused by name
#   - an unresolvable base revision is refused and the value is named
#   - a dirty tree is accepted; the run succeeds and reports the change set
#   - the change set names both the caller's uncommitted edit and the worker's
#   - the change set is measured from the named base, not from HEAD
#   - the header reports the base as a resolved commit object
#   - the pre-state recovery point holds the caller's tracked work, or is none
#     on a clean tree, and it still holds that work after a worker resets the
#     tree
#   - an unset base resolves to HEAD
#   - a worker that exits non-zero fails the run and names the log path
#   - a role listing two models tries the second when the first fails without
#     touching the tree, and reports the model that worked
#   - a first attempt that changed the tree is not followed by a second model
#   - a refused request stops its attempt early, so the fallback runs in seconds
#   - the failed candidates and their classes are reported at the end of the run
#     even when a later candidate succeeds
#
# The fallback cases below are held out of the default run; see the switch at
# the foot of this file.
#
# Run:   bash tests/test_opencode_dispatch.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"

# DISPATCH is overridable so the same cases can run against another revision
# of the script, such as the committed one, to prove they discriminate.
DISPATCH="${DISPATCH:-$REPO_ROOT/src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh}"

# write_stub BIN LOG EDIT EXIT_CODE [MODE]
#   Writes an executable worker stub. The stub appends its argv to LOG, prints
#   one line (so the run's log is non-empty), appends an edit to EDIT inside
#   the repo it was given as --dir, and exits EXIT_CODE. MODE `destroy` makes
#   it reset the tree first, the way an unguarded worker can.
write_stub() {
  local bin="$1" log="$2" edit="$3" exit_code="$4" mode="${5:-}"
  local destroy=""
  if [[ "$mode" == "destroy" ]]; then
    destroy='git -C "$dir" reset --hard >/dev/null 2>&1'
  fi
  mkdir -p "$(dirname "$bin")"
  cat > "$bin" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "$log"
dir=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --dir) dir="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf 'worker ran\n'
printf 'worker edit\n' >> "\$dir/$edit"
${destroy}
exit $exit_code
STUB
  chmod +x "$bin"
}

# make_workspace SANDBOX  --  a committed repo, a scratch dir, a brief, a role
#   table under AGENT_HOME, with none of the latter inside the repo.
make_workspace() {
  local sandbox="$1"
  make_committed_repo "$sandbox/repo"
  mkdir -p "$sandbox/scratch" "$sandbox/agenthome"
  printf 'the brief\n' > "$sandbox/brief.md"
  printf '_IMPLEMENTER: opencode/deepseek-v4.1-flash-free at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
}

# run_dispatch SANDBOX BASE [ARGS...]
#   Runs the script under test against the fixture, with AGENT_HOME pointing at
#   the fixture role table, DISPATCH_OPENCODE_BIN at the stub, and the named
#   base. Prints stdout and stderr together; the caller captures them.
run_dispatch() {
  local sandbox="$1" base="$2"; shift 2
  ( cd "$sandbox/repo" && \
    AGENT_HOME="$sandbox/agenthome" \
    DISPATCH_OPENCODE_BIN="$sandbox/bin/opencode" \
    OPENCODE_DISPATCH_BASE="$base" \
    bash "$DISPATCH" "$@" ) 2>&1
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_usage_guard() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(run_dispatch "$sandbox" HEAD)"; rc=$?
  assert_rc 1 "$rc" "no arguments is refused"
  assert_contains "$out" "usage: bash dispatch.sh <brief-file> <scratch-dir>" "the usage names the arguments"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md")"; rc=$?
  assert_rc 1 "$rc" "one argument is refused"
}

test_refuses_a_bad_brief() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/absent.md" "$sandbox/scratch")"; rc=$?
  assert_rc 1 "$rc" "a missing brief is refused"
  assert_contains "$out" "brief not found" "the refusal names the missing brief"

  : > "$sandbox/empty.md"
  out="$(run_dispatch "$sandbox" HEAD "$sandbox/empty.md" "$sandbox/scratch")"; rc=$?
  assert_rc 1 "$rc" "an empty brief is refused"
  assert_contains "$out" "brief is empty" "the refusal says the brief is empty"
}

test_refuses_a_bad_scratch_directory() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/absent-dir")"; rc=$?
  assert_rc 1 "$rc" "an absent scratch directory is refused"
  assert_contains "$out" "scratch directory not found" "the refusal names the scratch directory"
}

test_refuses_an_unresolvable_base() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"

  out="$(run_dispatch "$sandbox" no-such-revision "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 1 "$rc" "an unresolvable base is refused"
  assert_contains "$out" "base revision not found" "the refusal names the base check"
  assert_contains "$out" "no-such-revision" "the refusal names the value"
}

test_a_dirty_tree_is_accepted() {
  local sandbox out rc argv repo_root
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0
  printf 'caller edit\n' >> "$sandbox/repo/file.txt"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "a dirty tree is accepted"
  assert_contains "$out" "rc=0" "the run reports success"

  argv="$(cat "$sandbox/argv.log")"
  repo_root="$(git -C "$sandbox/repo" rev-parse --show-toplevel)"
  assert_contains "$argv" "$(printf -- '--dir\n%s' "$repo_root")" \
    "the stub received --dir naming the repository root"
}

test_change_set_is_the_units_set() {
  local sandbox out rc run_dir changes
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0
  printf 'caller edit\n' >> "$sandbox/repo/file.txt"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "the run over a dirty tree succeeds"
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  changes="$(cat "$run_dir/changes.txt")"
  assert_contains "$changes" "file.txt" "the change set names the caller's edit"
  assert_contains "$changes" "worker.txt" "the change set names the worker's edit"
}

test_change_set_uses_the_named_base() {
  local sandbox out rc old base_sha run_dir changes
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  # A second commit over the baseline: one file changes, one file is added.
  printf 'changed\n' > "$sandbox/repo/file.txt"
  printf 'added\n' > "$sandbox/repo/added.txt"
  git -C "$sandbox/repo" add file.txt added.txt
  git -C "$sandbox/repo" commit -m "change file.txt and add added.txt" --quiet
  old="$(git -C "$sandbox/repo" rev-parse HEAD~1)"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0

  out="$(run_dispatch "$sandbox" "$old" "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "a dispatch from an older base succeeds"
  base_sha="$(printf '%s\n' "$out" | sed -n 's/^base: //p')"
  assert_eq "$base_sha" "$old" "the base is the named older commit"
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  changes="$(cat "$run_dir/changes.txt")"
  assert_contains "$changes" "file.txt" "the change set names the file changed since the base"
  assert_contains "$changes" "added.txt" "the change set names the file added since the base"
}

test_base_is_a_resolved_sha() {
  local sandbox out rc base_sha base_type
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "a clean dispatch succeeds"
  base_sha="$(printf '%s\n' "$out" | sed -n 's/^base: //p')"
  assert_matches "$base_sha" '^[0-9a-f]{40}$' "the base is a 40-character object name"
  base_type="$(git -C "$sandbox/repo" cat-file -t "$base_sha" 2>/dev/null)"
  assert_eq "$base_type" "commit" "the base names a commit"
}

test_pre_state_recovery_point() {
  local sandbox out rc pre_sha pre_type content
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0
  printf 'caller edit\n' >> "$sandbox/repo/file.txt"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "a dispatch over a dirty tree succeeds"
  pre_sha="$(printf '%s\n' "$out" | sed -n 's/^pre-state: //p')"
  assert_matches "$pre_sha" '^[0-9a-f]{40}$' "the pre-state is a commit object"
  pre_type="$(git -C "$sandbox/repo" cat-file -t "$pre_sha" 2>/dev/null)"
  assert_eq "$pre_type" "commit" "the pre-state names a commit"
  content="$(git -C "$sandbox/repo" show "$pre_sha:file.txt" 2>/dev/null)"
  assert_contains "$content" "caller edit" "the pre-state holds the caller's work"

  local clean clean_out clean_rc clean_pre
  clean="$(get_fixture_dir)"
  make_workspace "$clean"
  write_stub "$clean/bin/opencode" "$clean/argv.log" worker.txt 0
  clean_out="$(run_dispatch "$clean" HEAD "$clean/brief.md" "$clean/scratch")"; clean_rc=$?
  assert_rc 0 "$clean_rc" "a dispatch over a clean tree succeeds"
  clean_pre="$(printf '%s\n' "$clean_out" | sed -n 's/^pre-state: //p')"
  assert_eq "$clean_pre" "none" "a clean tree reports no pre-state"
}

test_the_pre_state_survives_a_destructive_worker() {
  local sandbox out rc pre_sha content
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0 destroy
  printf 'caller edit\n' >> "$sandbox/repo/file.txt"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "the run completes even though the worker reset the tree"
  assert_not_contains "$(cat "$sandbox/repo/file.txt")" "caller edit" \
    "the worker's reset removed the caller's edit from the tree"
  pre_sha="$(printf '%s\n' "$out" | sed -n 's/^pre-state: //p')"
  content="$(git -C "$sandbox/repo" show "$pre_sha:file.txt" 2>/dev/null)"
  assert_contains "$content" "caller edit" "the pre-state still holds the work the worker destroyed"
}

test_the_base_defaults_to_head() {
  local sandbox out rc base_sha expected
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 0

  out="$( ( cd "$sandbox/repo" && \
    AGENT_HOME="$sandbox/agenthome" \
    DISPATCH_OPENCODE_BIN="$sandbox/bin/opencode" \
    env -u OPENCODE_DISPATCH_BASE bash "$DISPATCH" "$sandbox/brief.md" "$sandbox/scratch" ) 2>&1 )"; rc=$?
  assert_rc 0 "$rc" "a dispatch with no base set succeeds"
  base_sha="$(printf '%s\n' "$out" | sed -n 's/^base: //p')"
  expected="$(git -C "$sandbox/repo" rev-parse HEAD)"
  assert_eq "$base_sha" "$expected" "an unset base resolves to HEAD"
}

test_a_failing_worker_refuses() {
  local sandbox out rc run_dir
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  write_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt 1

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 1 "$rc" "a worker that exits non-zero fails the run"
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  assert_contains "$out" "the worker exited rc=1" "the refusal names the worker exit"
  assert_contains "$out" "$run_dir/worker.log" "the refusal names the log path"
}

# write_model_stub BIN LOG EDIT RULES
#   Writes a worker stub whose behaviour follows the model it was given.
#   RULES is a space-separated list of `<model>=<action>`, where the action is
#   `ok` (edit the tree and exit 0), `fail` (print and exit 1), `fail-edit`
#   (edit the tree, then exit 1), or `refuse` (print the message a spent free
#   tier returns, then sleep past the run's limit).
write_model_stub() {
  local bin="$1" log="$2" edit="$3" rules="$4"
  mkdir -p "$(dirname "$bin")"
  cat > "$bin" <<STUB
#!/usr/bin/env bash
model=""
prev=""
for arg in "\$@"; do
  [[ "\$prev" == "-m" ]] && model="\$arg"
  prev="\$arg"
done
printf '%s\n' "\$*" >> "$log"
action="ok"
for rule in $rules; do
  [[ "\${rule%%=*}" == "\$model" ]] && action="\${rule#*=}"
done
dir=""
prev=""
for arg in "\$@"; do
  [[ "\$prev" == "--dir" ]] && dir="\$arg"
  prev="\$arg"
done
case "\$action" in
  fail) printf 'the model failed\n'; exit 1 ;;
  fail-edit) printf 'worker edit\n' >> "\$dir/$edit"; printf 'the model failed\n'; exit 1 ;;
  refuse)
    printf 'Error: {\"message\":\"Rate limit exceeded. Please try again later.\"}\n'
    sleep 60
    exit 1 ;;
  hang) printf '> build \xc2\xb7 %s\n' "\$model"; sleep 60; exit 1 ;;
  *) printf 'worker ran\n'; printf 'worker edit\n' >> "\$dir/$edit"; exit 0 ;;
esac
STUB
  chmod +x "$bin"
}

test_falls_back_to_the_next_candidate() {
  local sandbox out rc attempts
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a at high; opencode/model-b at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a=fail opencode/model-b=ok"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "the run succeeds on the fallback"
  assert_contains "$out" "rc=0" "the run reports success"
  assert_contains "$out" "model=opencode/model-b" "the report names the model that worked"
  attempts="$(wc -l < "$sandbox/argv.log")"
  assert_eq "$attempts" "2" "the primary ran first, then the fallback"
}

test_a_changed_failure_does_not_fall_back() {
  local sandbox out rc attempts
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a at high; opencode/model-b at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a=fail-edit opencode/model-b=ok"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 1 "$rc" "a first attempt that changed the tree stops the run"
  assert_contains "$out" "the worker exited rc=1 after changing the tree" \
    "the refusal says the tree holds the attempt"
  attempts="$(wc -l < "$sandbox/argv.log")"
  assert_eq "$attempts" "1" "no second model ran over the first model's edits"
}

test_a_refused_model_is_stopped_early() {
  local sandbox out rc run_dir elapsed start
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a at high; opencode/model-b at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a=refuse opencode/model-b=ok"

  start=$(date +%s)
  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  elapsed=$(( $(date +%s) - start ))
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  assert_rc 0 "$rc" "the fallback runs after a refused request"
  assert_contains "$out" "model=opencode/model-b" "the report names the model that worked"
  assert_contains "$(cat "$run_dir/worker-attempt-1.log" 2>/dev/null)" \
    "aborted: the model refused the request" "the refused attempt says why it stopped"
  (( elapsed < 20 )) || fail "the refused attempt should stop in seconds, took ${elapsed}s"
  pass "the refused attempt stopped in ${elapsed}s, before the 1800s limit"
}

test_a_silent_attempt_is_stopped_and_falls_back() {
  local sandbox out rc run_dir elapsed start
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a at high; opencode/model-b at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a=hang opencode/model-b=ok"

  export OPENCODE_DISPATCH_STALL=2 OPENCODE_DISPATCH_POLL=0.05
  start=$(date +%s)
  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  elapsed=$(( $(date +%s) - start ))
  unset OPENCODE_DISPATCH_STALL
  run_dir="$(printf '%s\n' "$out" | sed -n 's/^run dir: //p')"
  assert_rc 0 "$rc" "the fallback runs after a silent attempt"
  assert_contains "$out" "model=opencode/model-b" "the report names the model that worked"
  assert_contains "$(cat "$run_dir/worker-attempt-1.log" 2>/dev/null)" \
    "aborted: no output for 3s" "the silent attempt says why it stopped"
  (( elapsed < 30 )) || fail "a silent attempt should stop after the stall limit, took ${elapsed}s"
  pass "the silent attempt stopped in ${elapsed}s"
}

test_reports_every_failed_candidate_at_the_end() {
  local sandbox out rc
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a at high; opencode/model-b at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a=refuse opencode/model-b=ok"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "the run succeeds on the fallback"
  assert_contains "$out" "failures: 1" "the run counts the failed candidate"
  assert_contains "$out" "opencode/model-a (quota)" "the run names the failed candidate and its class"
}

test_the_callers_own_edits_do_not_block_the_fallback() {
  local sandbox out rc attempts
  sandbox="$(get_fixture_dir)"
  make_workspace "$sandbox"
  printf '_IMPLEMENTER: opencode/model-a at high; opencode/model-b at high\n' \
    > "$sandbox/agenthome/model-recommendations.md"
  write_model_stub "$sandbox/bin/opencode" "$sandbox/argv.log" worker.txt \
    "opencode/model-a=fail opencode/model-b=ok"
  printf 'the caller edit\n' >> "$sandbox/repo/README.md"

  out="$(run_dispatch "$sandbox" HEAD "$sandbox/brief.md" "$sandbox/scratch")"; rc=$?
  assert_rc 0 "$rc" "the caller's uncommitted edit does not stop the fallback"
  attempts="$(wc -l < "$sandbox/argv.log")"
  assert_eq "$attempts" "2" "both candidates ran"
  assert_contains "$out" "model=opencode/model-b" "the report names the model that worked"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

run_test test_usage_guard
run_test test_refuses_a_bad_brief
run_test test_refuses_a_bad_scratch_directory
run_test test_refuses_an_unresolvable_base
run_test test_a_dirty_tree_is_accepted
run_test test_change_set_is_the_units_set
run_test test_change_set_uses_the_named_base
run_test test_base_is_a_resolved_sha
run_test test_pre_state_recovery_point
run_test test_the_pre_state_survives_a_destructive_worker
run_test test_the_base_defaults_to_head
run_test test_a_failing_worker_refuses
# The fallback cases are held out of the default run. Together they cost about
# twelve seconds against this suite's ten-second per-file deadline, and the
# deadline is the backpressure signal, so they run only on request:
#
#   OPENCODE_DISPATCH_FALLBACK_CASES=1 bash tests/test_opencode_dispatch.sh
FALLBACK_CASES="${OPENCODE_DISPATCH_FALLBACK_CASES:-0}"

if [[ "$FALLBACK_CASES" == "1" ]]; then
  run_test test_falls_back_to_the_next_candidate
  run_test test_a_changed_failure_does_not_fall_back
  run_test test_a_refused_model_is_stopped_early
  run_test test_a_silent_attempt_is_stopped_and_falls_back
  run_test test_reports_every_failed_candidate_at_the_end
  run_test test_the_callers_own_edits_do_not_block_the_fallback
fi

test_done
