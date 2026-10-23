#!/usr/bin/env bash
# Tests: workflow/coding-agent/skills/eval/scripts/measure_commit.sh and run_case.sh
source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEASURE="$REPO_ROOT/workflow/coding-agent/skills/eval/scripts/measure_commit.sh"
RUN_CASE="$REPO_ROOT/workflow/coding-agent/skills/eval/scripts/run_case.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

make_repo_with_base() {
  local dir="$1"
  mkdir -p "$dir/.agents/skills/git-discipline"
  git -C "$dir" init -q
  printf '# agents\n' >"$dir/AGENTS.md"
  printf '## The fold\n' >"$dir/.agents/skills/git-discipline/SKILL.md"
  git -C "$dir" add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m "fixture state"
}

commit_with() {
  local dir="$1" subject="$2" body="$3"
  printf 'change\n' >>"$dir/.agents/skills/git-discipline/SKILL.md"
  git -C "$dir" add -A
  if [[ -n "$body" ]]; then
    git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m "$subject" -m "$body"
  else
    git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m "$subject"
  fi
}

# When: a commit satisfies every rule
# Then: four rules pass and the measurement is marked committed
test_measure_all_rules_pass() {
  local dir="$TMP/pass"
  make_repo_with_base "$dir"
  commit_with "$dir" "docs: state the fold rule" "The rule moved, so the policy points at it."
  local out
  out="$(bash "$MEASURE" "$dir" 1)"
  assert_eq "$(jq -r '.rules_satisfied' <<<"$out")" "4" "all four rules pass"
  assert_eq "$(jq -r '.committed' <<<"$out")" "true" "the commit is seen"
  assert_eq "$(jq -r '.clean' <<<"$out")" "true" "the tree is clean"
}

# When: the subject carries no active type prefix
# Then: the prefix rule fails
test_measure_rejects_missing_prefix() {
  local dir="$TMP/prefix"
  make_repo_with_base "$dir"
  commit_with "$dir" "state the fold rule" "The rule moved."
  assert_eq "$(jq -r '.prefix_ok' <<<"$(bash "$MEASURE" "$dir" 1)")" "false" "no prefix fails"
}

# When: the subject runs past fifty characters
# Then: the subject rule fails
test_measure_rejects_long_subject() {
  local dir="$TMP/longsubject"
  make_repo_with_base "$dir"
  commit_with "$dir" "docs: state the fold rule that the policy owns today" ""
  local out
  out="$(bash "$MEASURE" "$dir" 1)"
  assert_eq "$(jq -r '.subject_len_ok' <<<"$out")" "false" "a subject past fifty characters fails"
  assert_eq "$(jq -r '.subject_len' <<<"$out")" "52" "the measured length"
}

# When: the body runs past 280 characters
# Then: the body rule fails
test_measure_rejects_long_body() {
  local dir="$TMP/longbody"
  make_repo_with_base "$dir"
  commit_with "$dir" "docs: state the fold rule" "$(printf 'x%.0s' {1..281})"
  local out
  out="$(bash "$MEASURE" "$dir" 1)"
  assert_eq "$(jq -r '.body_len_ok' <<<"$out")" "false" "a 281 character body fails"
  assert_eq "$(jq -r '.body_chars' <<<"$out")" "281" "the measured length"
}

# When: the body lists paths
# Then: the path-list rule fails
test_measure_rejects_path_list() {
  local dir="$TMP/pathlist"
  make_repo_with_base "$dir"
  commit_with "$dir" "docs: state the fold rule" "It touches .agents/skills/git-discipline/SKILL.md and devlog/roadmap.md."
  assert_eq "$(jq -r '.no_path_list' <<<"$(bash "$MEASURE" "$dir" 1)")" "false" "paths in the body fail"
}

# When: the run made no commit
# Then: the measurement reports it and still scores the rules
test_measure_reports_missing_commit() {
  local dir="$TMP/nocommit"
  make_repo_with_base "$dir"
  local out
  out="$(bash "$MEASURE" "$dir" 1)"
  assert_eq "$(jq -r '.committed' <<<"$out")" "false" "no new commit is reported"
  assert_eq "$(jq -r '.clean' <<<"$out")" "true" "an untouched tree is clean"
}

# When: run_case.sh runs one case with a stub agent that lands a compliant commit
# Then: the summary reports one committed run at full correctness and consistency
# Build a fixture workspace: a base bundle, a workload patch, a candidate directory,
# and a stub agent at <work>/bin/pi whose body the caller supplies.
make_stub_workspace() {
  local work="$1" stub_body="$2"
  local base="$work/base"
  mkdir -p "$work/bin" "$work/candidate"
  make_repo_with_base "$base"
  git -C "$base" bundle create "$work/base.bundle" --all >/dev/null 2>&1
  printf 'change\n' >>"$base/.agents/skills/git-discipline/SKILL.md"
  git -C "$base" diff >"$work/change.patch"
  git -C "$base" checkout -q -- .
  cp "$base/AGENTS.md" "$work/candidate/AGENTS.md"
  mkdir -p "$work/candidate/.agents/skills/git-discipline"
  cp "$base/.agents/skills/git-discipline/SKILL.md" "$work/candidate/.agents/skills/git-discipline/SKILL.md"
  printf '%s\n' "$stub_body" >"$work/bin/pi"
  chmod +x "$work/bin/pi"
  # The entrypoint resolves the role before it prints a command, so the fixture
  # carries a table of its own and names a synthetic assignment.
  mkdir -p "$work/pi"
  printf '_ORCHESTRATOR: stub-provider/stub-model at low\n' >"$work/pi/model-recommendations.md"
}

COMMIT_STUB='#!/usr/bin/env bash
git add -A
git -c user.email=t@t -c user.name=t commit -q -m "docs: land the policy change" -m "Folded into the iteration it corrects."
exit 0'

DIRTY_STUB='#!/usr/bin/env bash
printf "not committed\n" >> .agents/skills/git-discipline/SKILL.md
exit 0'

run_stub_case() {
  local work="$1" out="$2" runs="$3"
  shift 3
  # Pin the eval model and config so the run is hermetic: no operator
  # recommendations file and no host settings.json influence the stub.
  PATH="$work/bin:$PATH" \
    EVAL_MODEL="stub-provider/stub-model" EVAL_THINKING="high" \
    EVAL_CONFIG_DIR="$work/pi" \
    EVAL_RECOMMENDATIONS_FILE="$work/pi/model-recommendations.md" \
    bash "$RUN_CASE" \
    --bundle="$work/base.bundle" --patch="$work/change.patch" \
    --candidate="$work/candidate" --runs="$runs" --out="$out" --label="stub" "$@"
}

# When: run_case.sh runs one case with a stub agent that lands a compliant commit
# Then: the summary reports one committed run at full correctness and consistency
test_run_case_scores_a_stub_run() {
  local work="$TMP/run_case"
  make_stub_workspace "$work" "$COMMIT_STUB"
  run_stub_case "$work" "$work/out" 2 >/dev/null 2>&1
  local summary="$work/out/measure-stub.json"
  assert_file_exists "$summary"
  assert_eq "$(jq -r '.committed' "$summary")" "2" "both runs committed"
  assert_eq "$(jq -r '.correctness' "$summary")" "1" "correctness is 1"
  assert_eq "$(jq -r '.consistency' "$summary")" "1" "consistency is 1"
  assert_eq "$(jq -r '.body_chars_max' "$summary")" "38" "the body length is measured"
}

# When: a graded case ends
# Then: no worktree is left under the output directory, and the temp root is removed
test_run_case_leaves_no_worktree() {
  local work="$TMP/run_case_worktree"
  make_stub_workspace "$work" "$COMMIT_STUB"
  mkdir -p "$work/tmp"
  TMPDIR="$work/tmp" run_stub_case "$work" "$work/out" 1 >/dev/null 2>&1
  assert_eq "$(find "$work/out" -type d -name project | wc -l | tr -d ' ')" "0" "no worktree under the output directory"
  assert_file_exists "$work/out/case-stub/run-1/measure.json" "the measure stays"
  assert_eq "$(ls -A "$work/tmp" | wc -l | tr -d ' ')" "0" "the temp root is removed at exit"
}

# When: the operator asks for the work root to be kept
# Then: the script prints its path and the worktree survives there
test_run_case_keeps_the_work_root_on_request() {
  local work="$TMP/run_case_kept"
  make_stub_workspace "$work" "$COMMIT_STUB"
  mkdir -p "$work/tmp"
  TMPDIR="$work/tmp" EVAL_KEEP_WORK=1 run_stub_case "$work" "$work/out" 1 >"$work/kept.out" 2>&1
  local kept
  kept="$(sed -n 's/^work root kept: //p' "$work/kept.out" | head -1)"
  assert_not_empty "$kept" "the kept work root is named"
  assert_dir_exists "$kept" "the kept work root exists"
  assert_file_exists "$kept/run-1/project/AGENTS.md" "the worktree survives in it"
  rm -rf "$kept"
}

# When: a run commits its delivery
# Then: a bundle of the delta applies to a clone of the base, and no patch is written
test_run_case_writes_a_change_bundle() {
  local work="$TMP/run_case_bundle"
  make_stub_workspace "$work" "$COMMIT_STUB"
  run_stub_case "$work" "$work/out" 1 >/dev/null 2>&1
  local run="$work/out/case-stub/run-1"
  assert_file_exists "$run/run.bundle" "the run's change is bundled"
  git clone -q "$work/base.bundle" "$work/fresh"
  local rc=0
  git -C "$work/fresh" fetch -q "$run/run.bundle" HEAD:delivered || rc=$?
  assert_rc 0 "$rc" "the bundle fetches onto the base"
  assert_eq "$(git -C "$work/fresh" log -1 --format=%s delivered)" "docs: land the policy change" "the bundle carries the run's commit"
  assert_empty "$(cat "$run/run.patch")" "a committed run leaves no patch"
}

# When: a run leaves the tree dirty without committing
# Then: the patch of the remainder applies to the fixture, and no bundle is claimed
test_run_case_writes_a_patch_for_a_dirty_run() {
  local work="$TMP/run_case_patch"
  make_stub_workspace "$work" "$DIRTY_STUB"
  run_stub_case "$work" "$work/out" 1 >/dev/null 2>&1
  local run="$work/out/case-stub/run-1"
  assert_not_empty "$(cat "$run/run.patch")" "the dirty run writes a patch"
  git clone -q "$work/base.bundle" "$work/fresh"
  local rc=0
  git -C "$work/fresh" apply --check "$run/run.patch" || rc=$?
  assert_rc 0 "$rc" "the patch applies to the fixture"
  assert_eq "$(jq -r '.committed' "$work/out/measure-stub.json")" "0" "the run committed nothing"
  assert_eq "$(compgen -G "$run/run.bundle" | wc -l | tr -d ' ')" "0" "no bundle is written without a commit"
}

# When: --measure-only is asked for without a work root
# Then: the script refuses, because the worktree carries the commits to measure
test_run_case_measure_only_needs_a_work_root() {
  local work="$TMP/run_case_measure_only"
  make_stub_workspace "$work" "$COMMIT_STUB"
  run_stub_case "$work" "$work/out" 1 --measure-only >/dev/null 2>&1
  assert_rc 2 "$?" "measure-only without a work root is refused"
}

run_test test_measure_all_rules_pass
run_test test_measure_rejects_missing_prefix
run_test test_measure_rejects_long_subject
run_test test_measure_rejects_long_body
run_test test_measure_rejects_path_list
run_test test_measure_reports_missing_commit
run_test test_run_case_scores_a_stub_run
run_test test_run_case_leaves_no_worktree
run_test test_run_case_keeps_the_work_root_on_request
run_test test_run_case_writes_a_change_bundle
run_test test_run_case_writes_a_patch_for_a_dirty_run
run_test test_run_case_measure_only_needs_a_work_root

test_done
