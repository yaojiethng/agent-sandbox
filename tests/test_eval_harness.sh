#!/usr/bin/env bash
# TEST_DEADLINE: 90
# Tests: .agents/skills/evals/scripts/measure_commit.sh, measure_report.sh and run_case.sh
source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEASURE="$REPO_ROOT/.agents/skills/evals/scripts/measure_commit.sh"
RUN_CASE="$REPO_ROOT/.agents/skills/evals/scripts/run_case.sh"
COMPILE="$REPO_ROOT/.agents/skills/evals/scripts/compile_declaration.sh"

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
  assert_eq "$(jq -r '.assertions | length' <<<"$out")" "4" "each rule is recorded as an assertion"
  assert_eq "$(jq -r '[.assertions[] | select(.pass)] | length' <<<"$out")" "4" "every assertion carries its pass flag"
  assert_eq "$(jq -r '.assertions[0].evidence' <<<"$out")" "prefix: docs" "the assertion carries its evidence"
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
# When: a session transcript holds assistant turns with usage and tool calls
# Then: each turn's input, tool calls and opened paths with their byte sizes are
# attributed, a path outside the clone still marks the session invalid, and an
# absent path carries no size
test_measure_reports_missing_commit() {
  local dir="$TMP/nocommit"
  make_repo_with_base "$dir"
  local out
  out="$(bash "$MEASURE" "$dir" 1)"
  assert_eq "$(jq -r '.committed' <<<"$out")" "false" "no new commit is reported"
  assert_eq "$(jq -r '.clean' <<<"$out")" "true" "an untouched tree is clean"
}

test_measure_session_attributes_cost_per_turn() {
  local work="$TMP/measure_session"
  mkdir -p "$work/project/devlog"
  printf 'roadmap body\n' >"$work/project/devlog/roadmap.md"
  cat >"$work/session.jsonl" <<EOF
{"type":"message","timestamp":"2026-11-09T10:00:00Z","message":{"role":"assistant","usage":{"input":100,"output":10,"totalTokens":110},"stopReason":"toolUse","content":[{"type":"toolCall","name":"read","arguments":{"path":"devlog/roadmap.md"}}]}}
{"type":"message","timestamp":"2026-11-09T10:00:01Z","message":{"role":"assistant","usage":{"input":200,"output":20,"totalTokens":220},"stopReason":"toolUse","content":[{"type":"toolCall","name":"read","arguments":{"path":"devlog/missing.md"}}]}}
{"type":"message","timestamp":"2026-11-09T10:00:02Z","message":{"role":"assistant","usage":{"input":300,"output":30,"totalTokens":330},"stopReason":"stop","content":[{"type":"toolCall","name":"read","arguments":{"path":"$REPO_ROOT/AGENTS.md"}}]}}
EOF
  local out
  out="$(node "$REPO_ROOT/.agents/skills/evals/scripts/measure_session.mjs" \
    --root "$work/project" --repo-root "$REPO_ROOT" --sessions-dir "$work/no-sessions" \
    --session "$work/session.jsonl")"
  assert_eq "$(jq -r '.turns_detail | length' <<<"$out")" "3" "every turn is attributed"
  assert_eq "$(jq -r '.turns_detail[0].input_tokens' <<<"$out")" "100" "the first turn's input is attributed"
  assert_eq "$(jq -r '.turns_detail[0].tool_calls.read' <<<"$out")" "1" "the first turn's tool call is counted"
  assert_eq "$(jq -r '.turns_detail[0].paths[0].path' <<<"$out")" "devlog/roadmap.md" "the opened path is relative to the clone"
  assert_eq "$(jq -r '.turns_detail[0].paths[0].bytes' <<<"$out")" "13" "the opened path carries its byte size"
  assert_eq "$(jq -r '.turns_detail[1].paths[0].bytes' <<<"$out")" "null" "an absent path carries no size"
  assert_eq "$(jq -r '.turns_detail[2].paths[0].path' <<<"$out")" "$REPO_ROOT/AGENTS.md" "a path outside the clone stays absolute"
  assert_eq "$(jq -r '.invalid' <<<"$out")" "true" "a path outside the clone marks the session invalid"
}

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
  mkdir -p "$work/candidate/custom"
  printf 'overlaid\n' >"$work/candidate/custom/policy.txt"
  printf '%s\n' "$stub_body" >"$work/bin/pi"
  chmod +x "$work/bin/pi"
  # The entrypoint resolves the role before it prints a command, so the fixture
  # carries a table of its own and names a synthetic assignment. Every caller
  # inherits both values, so no stub run reads the operator's own table.
  mkdir -p "$work/pi"
  printf '{}\n' >"$work/pi/settings.json"
  printf '_ORCHESTRATOR: stub-provider/stub-model at low\n' >"$work/pi/model-recommendations.md"
  export EVAL_CONFIG_DIR="$work/pi"
  export EVAL_RECOMMENDATIONS_FILE="$work/pi/model-recommendations.md"
}

# Write a case file that declares the stub workspace's fixture, its measure and one
# named configuration per overlay the caller lists: write_case <case.json> <work> <config:overlay>...
# The case is an observation: a valid declaration whose intent is the run loop.
write_case() {
  local case_file="$1" work="$2"; shift 2
  local configs="" first=1 name overlay bundle_sha patch_sha
  for spec in "$@"; do
    name="${spec%%:*}"; overlay="${spec#*:}"
    [[ $first -eq 1 ]] || configs+=","
    first=0
    configs+="\"$name\": {\"overlay\": \"$overlay\"}"
  done
  bundle_sha="$(sha256sum "$work/base.bundle" | awk '{print $1}')"
  patch_sha="$(sha256sum "$work/change.patch" | awk '{print $1}')"
  jq -n --arg root "$work" --arg measure "$MEASURE" --argjson configs "{$configs}" \
    --arg bsha "$bundle_sha" --arg psha "$patch_sha" '
    {subject: "the stub case",
     harness: {fixture_root: $root, bundle: "base.bundle", patch: "change.patch",
               measure: $measure, prompt: "Land the pending work.",
               configurations: $configs,
               fixture_sha256: {bundle: $bsha, patch: $psha},
               observation: "the stub exercises the run loop, not a hypothesis",
               decision: {runs: 2}}}' >"$case_file"
}

# Write a case file complete for --check: two configurations, a prompt, the
# fixture's real sha256 values and a decision block. It is an observation, so the
# graded fields stay out until a test adds them. write_checked_case <case.json>
# <work> <control-name> <repeat-name>.
write_checked_case() {
  local case_file="$1" work="$2" control="$3" repeat="$4"
  local bundle_sha patch_sha
  bundle_sha="$(sha256sum "$work/base.bundle" | awk '{print $1}')"
  patch_sha="$(sha256sum "$work/change.patch" | awk '{print $1}')"
  jq -n --arg root "$work" --arg measure "$MEASURE" \
    --arg bsha "$bundle_sha" --arg psha "$patch_sha" \
    --arg control "$control" --arg repeat "$repeat" '
    {subject: "the stub case",
     harness: {fixture_root: $root, bundle: "base.bundle", patch: "change.patch",
               measure: $measure, prompt: "Land the pending work.",
               configurations: {($control): {overlay: "candidate"}, ($repeat): {overlay: "candidate"}},
               fixture_sha256: {bundle: $bsha, patch: $psha},
               observation: "the stub exercises the validation rules, not a hypothesis",
               decision: {runs: 3}}}' >"$case_file"
}

# A stub that records its concurrent window to $POOL_LOG, so the pool's concurrency is
# observable, lands the commit and exits.
POOL_STUB='#!/usr/bin/env bash
printf "S %s\n" "$(date +%s%N)" >>"$POOL_LOG"
sleep 1
printf "E %s\n" "$(date +%s%N)" >>"$POOL_LOG"
git add -A
git -c user.email=t@t -c user.name=t commit -q -m "docs: land the policy change" -m "Folded into the iteration it corrects."
exit 0'

COMMIT_STUB='#!/usr/bin/env bash
git add -A
git -c user.email=t@t -c user.name=t commit -q -m "docs: land the policy change" -m "Folded into the iteration it corrects."
exit 0'

MIXED_STUB='#!/usr/bin/env bash
if [[ "$PWD" == */1/project ]]; then
  git add -A
  git -c user.email=t@t -c user.name=t commit -q -m "docs: land the policy change" -m "Folded into the iteration it corrects."
  exit 0
fi
exit 1'

FAIL_STUB='#!/usr/bin/env bash
exit 1'

DIRTY_STUB='#!/usr/bin/env bash
printf "not committed\n" >> .agents/skills/git-discipline/SKILL.md
exit 0'

# Commits with no identity flags, so the clone has to supply one.
IDENTITY_STUB='#!/usr/bin/env bash
git add -A
git commit -q -m "docs: land the policy change" -m "Folded into the iteration it corrects."
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
    --bundle="$work/base.bundle" --patch="$work/change.patch" --measure="$MEASURE" \
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
  assert_eq "$(jq -r '.runs_detail[0].measure.body_chars' "$summary")" "38" "the run carries its measure object"
  assert_eq "$(jq -r '.runs_detail[0].model' "$summary")" "unknown" "the run carries its model"
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
  assert_file_exists "$kept/1/project/AGENTS.md" "the worktree survives in it"
  rm -rf "$kept"
}

# When: a run is prepared for the model
# Then: the prompt path names no experiment, and the clone carries no origin that
# points at the fixture's eval path
test_run_case_neutralises_the_run_root() {
  local work="$TMP/run_case_neutral"
  make_stub_workspace "$work" "$COMMIT_STUB"
  mkdir -p "$work/tmp"
  TMPDIR="$work/tmp" EVAL_KEEP_WORK=1 run_stub_case "$work" "$work/out" 1 >"$work/kept.out" 2>&1
  local first
  first="$(head -1 "$work/out/case-stub/run-1/prompt.txt")"
  assert_not_contains "$first" "eval" "the prompt path names no experiment"
  local kept
  kept="$(sed -n 's/^work root kept: //p' "$work/kept.out" | head -1)"
  assert_eq "$(git -C "$kept/1/project" remote)" "" "the clone carries no origin"
  assert_not_contains "$(git -C "$kept/1/project" remote -v)" "evals" "the clone names no eval path"
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

# When: a case file declares the fixture, the measure and one configuration's overlay
# Then: the harness runs the case from the declaration, and the overlay reaches the
# project's own tree, so any relative path works and no fixed contract is assumed
test_run_case_runs_a_case_file_declaration() {
  local work="$TMP/run_case_casefile"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_case "$work/case.json" "$work" "with_overlay:candidate"
  PATH="$work/bin:$PATH" bash "$RUN_CASE" --case="$work/case.json" --config=with_overlay \
    --runs=1 --out="$work/out" >/dev/null 2>&1
  local summary="$work/out/measure-with_overlay.json"
  assert_file_exists "$summary"
  assert_eq "$(jq -r '.committed' "$summary")" "1" "the declared run committed"
  assert_eq "$(jq -r '.candidate' "$summary")" "with_overlay" "the measure file carries the configuration name"
  local run="$work/out/case-with_overlay/run-1"
  assert_file_exists "$run/run.bundle" "the change is bundled"
  git clone -q "$work/base.bundle" "$work/fresh"
  git -C "$work/fresh" fetch -q "$run/run.bundle" HEAD:delivered
  assert_contains "$(git -C "$work/fresh" ls-tree -r --name-only delivered)" "custom/policy.txt" "the overlay reached the project's own tree"
}

# When: a configuration declares a package root
# Then: the run gets its own config copy under the output slug, the package root's
# skill is seeded onto it, the copy keeps the rest of the config, and sessions are
# left out of the copy
test_run_case_seeds_a_package_root_onto_the_config_copy() {
  local work="$TMP/run_case_package"
  make_stub_workspace "$work" "$COMMIT_STUB"
  mkdir -p "$work/pkg/skills/stub-skill"
  printf 'stub skill body\n' >"$work/pkg/skills/stub-skill/SKILL.md"
  PATH="$work/bin:$PATH" bash "$RUN_CASE" --bundle="$work/base.bundle" --patch="$work/change.patch" --measure="$MEASURE" \
    --candidate="$work/candidate" --package-root="$work/pkg" --runs=1 --out="$work/out" >/dev/null 2>&1
  local cfg="$work/out/case-candidate/config"
  assert_file_exists "$cfg/skills/stub-skill/SKILL.md" "the package root's skill is seeded"
  assert_eq "$(cat "$cfg/skills/stub-skill/SKILL.md")" "stub skill body" "the seed carries the package root's content"
  assert_file_exists "$cfg/settings.json" "the copy keeps the rest of the config"
  assert_empty "$(compgen -G "$cfg/sessions" | head -1)" "the copy leaves sessions out"
  assert_empty "$(compgen -G "$HOME/.pi/agent/skills/stub-skill" | head -1)" "the operator's config is not touched"
}

# When: a case run names no --out
# Then: the output lands under the declared output root, named for the case's
# directory, so the layout declaration is the only statement of that root
test_run_case_defaults_the_output_root() {
  local work="$TMP/run_case_default_out" home="$TMP/run_case_default_home"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_case "$work/case.json" "$work" "stub:candidate"
  mkdir -p "$home"
  PATH="$work/bin:$PATH" HOME="$home" bash "$RUN_CASE" \
    --case="$work/case.json" --config=stub --runs=1 >/dev/null 2>&1
  assert_file_exists "$home/workspace/output/evals/$(basename "$work")/measure-stub.json" \
    "the run lands under the declared output root"
}

# When: the arguments misname the case, the configuration, the candidate or a flag
# Then: the script refuses with exit 2 before it runs anything
test_run_case_refuses_misset_arguments() {
  local work="$TMP/run_case_refuse"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_case "$work/case.json" "$work" "only:candidate"
  bash "$RUN_CASE" --case="$work/case.json" --out="$work/out" >/dev/null 2>&1
  assert_rc 2 "$?" "a case with no config or cells is refused"
  bash "$RUN_CASE" --case="$work/case.json" --config=absent --out="$work/out" >/dev/null 2>&1
  assert_rc 2 "$?" "an unknown configuration is refused"
  bash "$RUN_CASE" --case="$work/case.json" --config=only --cells=only --out="$work/out" >/dev/null 2>&1
  assert_rc 2 "$?" "cells and config together are refused"
  mkdir -p "$work/empty"
  bash "$RUN_CASE" --bundle="$work/base.bundle" --patch="$work/change.patch" --measure="$MEASURE" --candidate="$work/empty" \
    --out="$work/out" >/dev/null 2>&1
  assert_rc 2 "$?" "a candidate with no files is refused"
  bash "$RUN_CASE" --bundle="$work/base.bundle" --patch="$work/change.patch" --measure="$MEASURE" --candidate="$work/case.json" \
    --out="$work/out" >/dev/null 2>&1
  assert_rc 2 "$?" "a candidate that is not a directory is refused"
  local out rc
  out="$(bash "$RUN_CASE" --bundle="$work/base.bundle" --nonsense=1 --out="$work/out" 2>&1)"; rc=$?
  assert_rc 2 "$rc" "an unknown flag is refused"
  assert_contains "$out" "unknown argument" "the refusal names the flag"
}

# When: one invocation dispatches several cells of a case
# Then: the pool writes one measure per cell plus the benchmark, and at the cap the
# cells' concurrent windows follow the cap: never past it, and two together at two
test_pool_dispatches_cells_under_the_cap() {
  local work="$TMP/run_case_pool"
  make_stub_workspace "$work" "$POOL_STUB"
  write_case "$work/case.json" "$work" "a:candidate" "b:candidate" "c:candidate"
  max_open() { awk '/^S /{o++} /^E /{o--} o>m{m=o} END{print m+0}' "$1"; }
  POOL_LOG="$work/seq.log" EVAL_MAX_PARALLEL=1 PATH="$work/bin:$PATH" bash "$RUN_CASE" \
    --case="$work/case.json" --cells=a,b,c --runs=1 --out="$work/seq" >/dev/null 2>&1
  assert_eq "$(jq -r '.a.committed' "$work/seq/benchmark.json")" "1" "cell a committed"
  assert_eq "$(jq -r '.b.committed' "$work/seq/benchmark.json")" "1" "cell b committed"
  assert_eq "$(jq -r '.c.committed' "$work/seq/benchmark.json")" "1" "cell c committed"
  assert_eq "$(jq -r '.batch.stop' "$work/seq/benchmark.json")" "null" "a clean batch records no stop"
  assert_eq "$(jq -c '.batch.cells_run' "$work/seq/benchmark.json")" '["a","b","c"]' "every cell ran"
  assert_eq "$(jq -c '.batch.cells_remaining' "$work/seq/benchmark.json")" '[]' "no cell remained"
  assert_eq "$(jq -r '.analysis.non_discriminating | length' "$work/seq/benchmark.json")" "4" "the analysis names the assertions that pass everywhere"
  assert_eq "$(jq -r '.analysis.cells_without_spread | length' "$work/seq/benchmark.json")" "3" "the analysis names the cells with no spread"
  assert_eq "$(jq -r '.analysis.failed_assertions | length' "$work/seq/benchmark.json")" "0" "a clean batch failed no assertion"
  assert_eq "$(max_open "$work/seq.log")" "1" "at the cap of one, one run window is open at a time"
  POOL_LOG="$work/par.log" EVAL_MAX_PARALLEL=2 PATH="$work/bin:$PATH" bash "$RUN_CASE" \
    --case="$work/case.json" --cells=a,b,c --runs=1 --out="$work/par" >/dev/null 2>&1
  assert_eq "$(max_open "$work/par.log")" "2" "at the cap of two, two run windows overlap"
}

# When: --check validates a complete case declaration
# Then: the valid case is accepted with exit 0
# When: a case breaks a validation rule
# Then: --check rejects it with exit 2
test_run_case_check_accepts_a_valid_case() {
  local work="$TMP/check_ok"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  local out rc
  out="$(bash "$RUN_CASE" --check="$work/case.json" 2>&1)"; rc=$?
  assert_rc 0 "$rc" "--check accepts a valid case"
  assert_contains "$out" "case ok" "the accepted case is named"
  jq '.harness.stop_classes = ["timeout", "unattributed"]' "$work/case.json" >"$work/stop_ok.json"
  out="$(bash "$RUN_CASE" --check="$work/stop_ok.json" 2>&1)"; rc=$?
  assert_rc 0 "$rc" "--check accepts a declared stop class"
}

test_run_case_check_proves_a_check_against_its_known_bad() {
  local work="$TMP/check_known_bad"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  mkdir -p "$work/kb_bad"
  jq '.harness.design = {method: "A/B", primary_measure: "the commit format", valid_n: 2, attrition: "invalid runs leave the means"}
      | .harness.checks = [{id: "prefix", role: "gate", known_bad: "kb_bad"}]
      | del(.harness.observation)
      | .harness.decision.rule = "the subject beats the control"
      | .harness.decision.control = "with_overlay"' \
    "$work/case.json" >"$work/design.json"
  local rc=0 out
  out="$(bash "$RUN_CASE" --check="$work/design.json" 2>&1)" || rc=$?
  assert_rc 0 "$rc" "--check accepts a check that fails its known-bad"
  mkdir -p "$work/kb_good"
  git -C "$work/kb_good" init -q
  git -C "$work/kb_good" -c user.email=a -c user.name=a commit -q --allow-empty -m "feat: x"
  jq '.harness.checks = [{id: "prefix", role: "gate", known_bad: "kb_good"}]' "$work/design.json" >"$work/passing.json"
  rc=0
  out="$(bash "$RUN_CASE" --check="$work/passing.json" 2>&1)" || rc=$?
  assert_rc 2 "$rc" "--check rejects a check that passes its known-bad"
  assert_contains "$out" "passes its known_bad" "the rejection names the false case"
  jq 'del(.harness.checks)' "$work/design.json" >"$work/nochecks.json"
  rc=0
  out="$(bash "$RUN_CASE" --check="$work/nochecks.json" 2>&1)" || rc=$?
  assert_rc 2 "$rc" "--check rejects a design without checks"
}

# When: a case declares one configuration
# Then: a graded case is rejected, and an observation is accepted
test_run_case_check_rejects_a_single_configuration() {
  local work="$TMP/check_single"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  jq 'del(.harness.configurations.aa_overlay)' "$work/case.json" >"$work/one.json"
  local out rc=0
  out="$(bash "$RUN_CASE" --check="$work/one.json" 2>&1)" || rc=$?
  assert_rc 0 "$rc" "an observation with one configuration is accepted"
  mkdir -p "$work/kb_bad"
  jq '.harness.design = {method: "A/B", primary_measure: "the commit format", valid_n: 2, attrition: "invalid runs leave the means"}
      | .harness.checks = [{id: "prefix", role: "gate", known_bad: "kb_bad"}]
      | del(.harness.observation)
      | .harness.decision.rule = "the subject beats the control"
      | .harness.decision.control = "with_overlay"' "$work/one.json" >"$work/graded_one.json"
  rc=0
  out="$(bash "$RUN_CASE" --check="$work/graded_one.json" 2>&1)" || rc=$?
  assert_rc 2 "$rc" "a graded case with one configuration is rejected"
  assert_contains "$out" "graded case needs at least two configurations" "the rejection names the comparison"
}

test_run_case_check_rejects_a_hash_mismatch() {
  local work="$TMP/check_hash"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  local zeros
  zeros="$(printf '0%.0s' {1..64})"
  jq --arg z "$zeros" '.harness.fixture_sha256.bundle = $z' "$work/case.json" >"$work/bad.json"
  local rc=0
  bash "$RUN_CASE" --check="$work/bad.json" >/dev/null 2>&1 || rc=$?
  assert_rc 2 "$rc" "a hash mismatch is rejected"
}

test_run_case_check_rejects_a_configuration_without_a_source() {
  local work="$TMP/check_nosource"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  jq '.harness.configurations.aa_overlay = {}' "$work/case.json" >"$work/nosource.json"
  local rc=0
  bash "$RUN_CASE" --check="$work/nosource.json" >/dev/null 2>&1 || rc=$?
  assert_rc 2 "$rc" "a configuration without a source is rejected"
}

# When: --check validates stop_classes
# Then: an unknown class or a repeated class is rejected
test_run_case_check_rejects_an_unknown_stop_class() {
  local work="$TMP/check_stop"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  jq '.harness.stop_classes = ["nope"]' "$work/case.json" >"$work/bad.json"
  local rc=0
  bash "$RUN_CASE" --check="$work/bad.json" >/dev/null 2>&1 || rc=$?
  assert_rc 2 "$rc" "an unknown stop class is rejected"
  jq '.harness.stop_classes = ["timeout", "timeout"]' "$work/case.json" >"$work/dup.json"
  rc=0
  bash "$RUN_CASE" --check="$work/dup.json" >/dev/null 2>&1 || rc=$?
  assert_rc 2 "$rc" "a repeated stop class is rejected"
}

# When: two runs of a case exit 0 and 1
# Then: the measure separates them and reports the invalid rate
test_run_case_reports_valid_and_invalid_runs() {
  local work="$TMP/run_case_valid"
  make_stub_workspace "$work" "$MIXED_STUB"
  run_stub_case "$work" "$work/out" 2 >/dev/null 2>&1
  local summary="$work/out/measure-stub.json"
  assert_eq "$(jq -r '.valid' "$summary")" "1" "the zero-exit run is valid"
  assert_eq "$(jq -r '.invalid' "$summary")" "1" "the non-zero run is invalid"
  assert_eq "$(jq -r '.invalid_rate' "$summary")" "0.5" "the invalid rate is one half"
  assert_eq "$(jq -r '.correctness_runs | length' "$summary")" "1" "the distribution holds only the valid run"
  assert_eq "$(jq -r '.correctness_sd' "$summary")" "0" "one sample has no spread"
}

# When: a graded case assembles its grade dir
# Then: the assembled names carry no label, and only the map restores it
test_run_case_writes_a_sanitized_grade_dir() {
  local work="$TMP/run_case_grade"
  make_stub_workspace "$work" "$COMMIT_STUB"
  run_stub_case "$work" "$work/out" 1 >/dev/null 2>&1
  local grade="$work/out/grade"
  assert_file_exists "$grade/case-01.txt" "the raw case is renamed"
  assert_contains "$(cat "$grade/case-01.txt")" "--- committed change ---" "the committed change is carried into the grade"
  assert_empty "$(find "$grade" -type f -name '*stub*' | head -1)" "no assembled file name carries the label"
  assert_eq "$(jq -r '.cases["case-01"]' "$work/out/grade-map.json")" "stub-1" "the map restores the label outside the grade dir"
}

run_test test_measure_all_rules_pass
run_test test_measure_rejects_missing_prefix
run_test test_measure_rejects_long_subject
run_test test_measure_rejects_long_body
run_test test_measure_rejects_path_list
run_test test_measure_reports_missing_commit
run_test test_measure_session_attributes_cost_per_turn
run_test test_run_case_scores_a_stub_run
run_test test_run_case_leaves_no_worktree
run_test test_run_case_keeps_the_work_root_on_request
run_test test_run_case_neutralises_the_run_root
run_test test_run_case_writes_a_change_bundle
run_test test_run_case_writes_a_patch_for_a_dirty_run
run_test test_run_case_measure_only_needs_a_work_root
run_test test_run_case_runs_a_case_file_declaration
# When: a configuration declares only a package root and no overlay
# Then: the run proceeds, because the package root is the whole variable
test_run_case_runs_a_package_root_only_case() {
  local work="$TMP/run_case_package_only"
  make_stub_workspace "$work" "$COMMIT_STUB"
  mkdir -p "$work/pkg/skills/stub-skill"
  printf 'stub skill body\n' >"$work/pkg/skills/stub-skill/SKILL.md"
  mkdir -p "$work/pi"
  printf '{}\n' >"$work/pi/settings.json"
  local bsha psha
  bsha="$(sha256sum "$work/base.bundle" | awk '{print $1}')"
  psha="$(sha256sum "$work/change.patch" | awk '{print $1}')"
  jq -n --arg root "$work" --arg measure "$MEASURE" --arg b "$bsha" --arg p "$psha" '
    {harness: {fixture_root: $root, bundle: "base.bundle", patch: "change.patch",
               measure: $measure, prompt: "Land the pending work.",
               configurations: {stub: {package_root: "pkg"}},
               fixture_sha256: {bundle: $b, patch: $p},
               observation: "the package root is the subject, not a hypothesis",
               decision: {runs: 2}}}' >"$work/case.json"
  PATH="$work/bin:$PATH" EVAL_MODEL="stub-provider/stub-model" EVAL_THINKING="high" \
    EVAL_CONFIG_DIR="$work/pi" EVAL_RECOMMENDATIONS_FILE="$work/pi/none.md" \
    bash "$RUN_CASE" --case="$work/case.json" --config=stub --runs=1 --out="$work/out" >/dev/null 2>&1
  assert_eq "$(jq -r '.committed' "$work/out/measure-stub.json")" "1" "a package-root-only case runs"
  assert_file_exists "$work/out/case-stub/config/skills/stub-skill/SKILL.md" "the package root is seeded"
}

run_test test_run_case_seeds_a_package_root_onto_the_config_copy
# When: a fixture needs no workload patch
# Then: the run proceeds, and the clone is the whole fixture
test_run_case_accepts_an_empty_patch() {
  local work="$TMP/run_case_empty_patch"
  make_stub_workspace "$work" "$COMMIT_STUB"
  : >"$work/empty.patch"
  PATH="$work/bin:$PATH" EVAL_MODEL="stub-provider/stub-model" EVAL_THINKING="high" \
    EVAL_CONFIG_DIR="$HOME/.pi/agent" EVAL_RECOMMENDATIONS_FILE="$work/none.md" \
    bash "$RUN_CASE" --bundle="$work/base.bundle" --patch="$work/empty.patch" --measure="$MEASURE" \
      --candidate="$work/candidate" --runs=1 --out="$work/out" --label=stub >/dev/null 2>&1
  assert_eq "$(jq -r '.committed' "$work/out/measure-stub.json")" "1" "an empty patch runs"
}

# When: a report measure reads a project that holds report.jsonl
# Then: it reports the file and its line count
test_measure_report_records_the_report() {
  local work="$TMP/measure_report"
  make_repo_with_base "$work"
  printf '{"skill":"doc-maintenance","file":"a.md"}\n' >"$work/report.jsonl"
  local out
  out="$(bash "$REPO_ROOT/.agents/skills/evals/scripts/measure_report.sh" "$work" 1)"
  assert_eq "$(jq -r '.report_present' <<<"$out")" "true" "the report is seen"
  assert_eq "$(jq -r '.report_lines' <<<"$out")" "1" "the line count"
  assert_eq "$(jq -r '.assertions[0].pass' <<<"$out")" "true" "the report assertion passes"
}

# When: a case names its report path instead of the default
# Then: the measure reads that path
test_measure_report_reads_a_named_path() {
  local work="$TMP/measure_report_named"
  make_repo_with_base "$work"
  printf 'found\n' >"$work/findings.jsonl"
  local out
  out="$(bash "$REPO_ROOT/.agents/skills/evals/scripts/measure_report.sh" "$work" 1 findings.jsonl)"
  assert_eq "$(jq -r '.report_present' <<<"$out")" "true" "the named report is seen"
  assert_eq "$(jq -r '.report_lines' <<<"$out")" "1" "the named report is counted"
}

# When: an ad-hoc run names no measure
# Then: the harness refuses before it clones
test_run_case_needs_a_measure() {
  local work="$TMP/run_case_no_measure"
  make_stub_workspace "$work" "$COMMIT_STUB"
  local rc=0
  bash "$RUN_CASE" --bundle="$work/base.bundle" --patch="$work/change.patch" \
    --candidate="$work/candidate" --runs=1 --out="$work/out" >/dev/null 2>&1 || rc=$?
  assert_rc 2 "$rc" "a run with no measure is refused"
}

# When: no recommendations file is named and no per-user table exists
# Then: the harness falls back to the repository's committed role table
test_run_case_uses_the_repository_role_table() {
  local work="$TMP/run_case_default_table"
  make_stub_workspace "$work" "$COMMIT_STUB"
  local home="$work/home"
  mkdir -p "$home/.pi"
  PATH="$work/bin:$PATH" HOME="$home" EVAL_CONFIG_DIR="$work/pi" \
    env -u EVAL_RECOMMENDATIONS_FILE -u PROJECT_DIR -u DISPATCH_REC_FILE \
    bash "$RUN_CASE" --bundle="$work/base.bundle" --patch="$work/change.patch" \
      --measure="$MEASURE" --candidate="$work/candidate" --runs=1 \
      --out="$work/out" --label="default-table" >/dev/null 2>&1
  assert_eq "$(jq -r '.valid' "$work/out/measure-default-table.json")" "1" "the repository table resolves the role"
}

run_test test_run_case_accepts_an_empty_patch
run_test test_run_case_uses_the_repository_role_table
run_test test_measure_report_records_the_report
run_test test_measure_report_reads_a_named_path
run_test test_run_case_needs_a_measure
run_test test_run_case_runs_a_package_root_only_case
run_test test_run_case_defaults_the_output_root
run_test test_run_case_refuses_misset_arguments
run_test test_pool_dispatches_cells_under_the_cap
run_test test_run_case_check_accepts_a_valid_case
run_test test_run_case_check_proves_a_check_against_its_known_bad
run_test test_run_case_check_rejects_a_single_configuration
run_test test_run_case_check_rejects_a_hash_mismatch
run_test test_run_case_check_rejects_a_configuration_without_a_source
# When: one run matches a declared stop class
# Then: the pool halts new cells, and the batch names the class and the split
test_pool_stops_and_names_the_remaining_cells() {
  local work="$TMP/pool_stop"
  make_stub_workspace "$work" "$FAIL_STUB"
  write_case "$work/case.json" "$work" "a:candidate" "b:candidate" "c:candidate"
  jq '.harness.stop_classes = ["exit-nonzero"]' "$work/case.json" >"$work/stop.json"
  EVAL_MAX_PARALLEL=1 PATH="$work/bin:$PATH" bash "$RUN_CASE" \
    --case="$work/stop.json" --cells=a,b,c --runs=1 --out="$work/out" >/dev/null 2>&1
  local bench="$work/out/benchmark.json"
  assert_eq "$(jq -r '.batch.stop.class' "$bench")" "exit-nonzero" "the stop class is named"
  assert_eq "$(jq -r '.batch.stop.cell' "$bench")" "a" "the stopped cell is named"
  assert_eq "$(jq -r '.batch.stop.run' "$bench")" "1" "the stopped run is named"
  assert_eq "$(jq -c '.batch.cells_run' "$bench")" '["a"]' "only the launched cell ran"
  assert_eq "$(jq -c '.batch.cells_remaining' "$bench")" '["b","c"]' "the unlaunched cells remain"
}

# When: a case carries a decision rule but no design and checks
# Then: --check refuses it, and accepts the complete graded triple without min_effect
test_run_case_check_requires_the_graded_triple() {
  local work="$TMP/check_triple"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  jq 'del(.harness.observation)
      | .harness.decision.rule = "the subject beats the control"
      | .harness.decision.control = "with_overlay"' "$work/case.json" >"$work/rule.json"
  local out rc=0
  out="$(bash "$RUN_CASE" --check="$work/rule.json" 2>&1)" || rc=$?
  assert_rc 2 "$rc" "a decision rule without design and checks is rejected"
  assert_contains "$out" "graded case declares design and checks" "the rejection names the graded triple"
  mkdir -p "$work/kb_bad"
  jq '.harness.design = {method: "A/B", primary_measure: "the commit format", valid_n: 2, attrition: "invalid runs leave the means"}
      | .harness.checks = [{id: "prefix", role: "gate", known_bad: "kb_bad"}]' "$work/rule.json" >"$work/graded.json"
  rc=0
  out="$(bash "$RUN_CASE" --check="$work/graded.json" 2>&1)" || rc=$?
  assert_rc 0 "$rc" "the complete graded triple is accepted"
  assert_eq "$(jq -r '.harness.decision | has("min_effect")' "$work/graded.json")" "false" "a graded declaration needs no min_effect"
}

# When: a case declares neither a decision rule nor an observation
# Then: --check refuses it, and an observation that carries a design is refused too
test_run_case_check_requires_a_declared_kind() {
  local work="$TMP/check_kind"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  jq 'del(.harness.observation)' "$work/case.json" >"$work/undeclared.json"
  local out rc=0
  out="$(bash "$RUN_CASE" --check="$work/undeclared.json" 2>&1)" || rc=$?
  assert_rc 2 "$rc" "a case with no rule and no observation is rejected"
  assert_contains "$out" "declares observation" "the rejection names the missing kind"
  jq '.harness.design = {method: "A/B", primary_measure: "the commit format", valid_n: 2, attrition: "invalid runs leave the means"}' \
    "$work/case.json" >"$work/obs_design.json"
  rc=0
  out="$(bash "$RUN_CASE" --check="$work/obs_design.json" 2>&1)" || rc=$?
  assert_rc 2 "$rc" "an observation that carries a design is rejected"
  assert_contains "$out" "observation declares no design or checks" "the rejection names the observation shape"
}

# When: a run is given a declaration --check would reject
# Then: it refuses before it resolves the fixture or creates the output
test_run_case_refuses_an_unvalidated_declaration() {
  local work="$TMP/run_case_refuse_decl"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_case "$work/case.json" "$work" "only:candidate"
  jq 'del(.harness.observation)' "$work/case.json" >"$work/bad.json"
  local out rc=0
  out="$(PATH="$work/bin:$PATH" bash "$RUN_CASE" --case="$work/bad.json" --config=only --runs=1 --out="$work/out" 2>&1)" || rc=$?
  assert_rc 2 "$rc" "the run path refuses a declaration --check rejects"
  assert_contains "$out" "case rejected" "the refusal names the declaration rule"
  assert_eq "$(find "$work/out" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')" "0" "the refusal creates no output"
}

# When: a --cells dispatch is given a rejected declaration
# Then: the parent refuses before it schedules any cell
test_pool_refuses_an_unvalidated_declaration() {
  local work="$TMP/pool_refuse_decl"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_case "$work/case.json" "$work" "a:candidate" "b:candidate"
  jq 'del(.harness.observation)' "$work/case.json" >"$work/bad.json"
  local rc=0
  PATH="$work/bin:$PATH" bash "$RUN_CASE" --case="$work/bad.json" --cells=a,b --runs=1 --out="$work/out" >/dev/null 2>&1 || rc=$?
  assert_rc 2 "$rc" "--cells refuses a rejected declaration"
  assert_eq "$(find "$work/out" -maxdepth 1 -name 'cell-*' 2>/dev/null | wc -l | tr -d ' ')" "0" "no cell was scheduled"
}

run_test test_run_case_check_rejects_an_unknown_stop_class
run_test test_run_case_check_requires_the_graded_triple
run_test test_run_case_check_requires_a_declared_kind
run_test test_run_case_refuses_an_unvalidated_declaration
run_test test_pool_refuses_an_unvalidated_declaration
run_test test_pool_stops_and_names_the_remaining_cells
run_test test_run_case_reports_valid_and_invalid_runs
# When: a case file sits beside its fixture root, given as a relative path
# Then: the harness resolves it from the case file directory, not the caller PWD
test_run_case_resolves_a_relative_fixture_root() {
  local work="$TMP/run_case_relative"
  make_stub_workspace "$work" "$COMMIT_STUB"
  jq -n --arg measure "$MEASURE" \
    --arg b "$(sha256sum "$work/base.bundle" | awk '{print $1}')" \
    --arg p "$(sha256sum "$work/change.patch" | awk '{print $1}')" '
    {harness: {fixture_root: ".", bundle: "base.bundle", patch: "change.patch",
               measure: $measure, prompt: "Land the pending work.",
               configurations: {stub: {overlay: "candidate"}},
               fixture_sha256: {bundle: $b, patch: $p},
               observation: "the relative root is the subject, not a hypothesis",
               decision: {runs: 2}}}' >"$work/case.json"
  PATH="$work/bin:$PATH" EVAL_MODEL="stub-provider/stub-model" EVAL_THINKING="high" \
    EVAL_CONFIG_DIR="$work/pi" EVAL_RECOMMENDATIONS_FILE="$work/pi/model-recommendations.md" \
    bash "$RUN_CASE" --case="$work/case.json" --config=stub --runs=1 --out="$work/out" >/dev/null 2>&1
  assert_eq "$(jq -r '.committed' "$work/out/measure-stub.json")" "1" "the relative fixture root resolves"
}

run_test test_run_case_writes_a_sanitized_grade_dir
# When: a declared fixture no longer matches its hash
# Then: the run path refuses before it clones
test_run_case_rejects_a_changed_fixture() {
  local work="$TMP/run_case_changed"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  printf '\n# drift\n' >>"$work/change.patch"
  local rc=0
  PATH="$work/bin:$PATH" EVAL_MODEL="stub-provider/stub-model" EVAL_THINKING="high" \
    EVAL_CONFIG_DIR="$work/pi" EVAL_RECOMMENDATIONS_FILE="$work/pi/none.md" \
    bash "$RUN_CASE" --case="$work/case.json" --config=with_overlay --runs=1 --out="$work/out" >/dev/null 2>&1 || rc=$?
  assert_rc 2 "$rc" "a changed fixture is refused"
  assert_eq "$(compgen -G "$work/out/measure-*.json" | wc -l | tr -d ' ')" "0" "no run started"
}

# When: the case declares a run count and the caller does not pass --runs
# Then: the declared count drives the run
test_run_case_uses_the_declared_run_count() {
  local work="$TMP/run_case_declared_runs"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  jq '.harness.decision.runs = 2' "$work/case.json" >"$work/two.json"
  PATH="$work/bin:$PATH" EVAL_MODEL="stub-provider/stub-model" EVAL_THINKING="high" \
    EVAL_CONFIG_DIR="$work/pi" EVAL_RECOMMENDATIONS_FILE="$work/pi/none.md" \
    bash "$RUN_CASE" --case="$work/two.json" --config=with_overlay --out="$work/out" >/dev/null 2>&1
  assert_eq "$(jq -r '.runs' "$work/out/measure-with_overlay.json")" "2" "the declared run count drives the run"
}

# When: a case declares its overlay as the starting state
# Then: the overlay is committed in the base, and the delivery excludes it
test_run_case_commits_a_declared_starting_overlay() {
  local work="$TMP/run_case_overlay_committed"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_case "$work/case.json" "$work" "with_overlay:candidate"
  jq '.harness.overlay_committed = true' "$work/case.json" >"$work/committed.json"
  PATH="$work/bin:$PATH" EVAL_MODEL="stub-provider/stub-model" EVAL_THINKING="high" \
    EVAL_CONFIG_DIR="$work/pi" EVAL_RECOMMENDATIONS_FILE="$work/pi/model-recommendations.md" \
    bash "$RUN_CASE" --case="$work/committed.json" --config=with_overlay --runs=1 \
      --out="$work/out" >/dev/null 2>&1
  local run="$work/out/case-with_overlay/run-1"
  assert_eq "$(cat "$run/base-count")" "2" "the starting overlay is a base commit"
  assert_eq "$(jq -r '.committed' "$work/out/measure-with_overlay.json")" "1" \
    "the run's own commit is counted above the overlay"
}

# When: the agent commits without naming an author
# Then: the clone carries an identity, so the commit lands and the run is scored
test_run_case_clone_carries_a_git_identity() {
  local work="$TMP/run_case_identity"
  make_stub_workspace "$work" "$IDENTITY_STUB"
  run_stub_case "$work" "$work/out" 1 >/dev/null 2>&1
  assert_eq "$(jq -r '.committed' "$work/out/measure-stub.json")" "1" "a commit with no identity flags lands"
}

run_test test_run_case_resolves_a_relative_fixture_root
run_test test_run_case_rejects_a_changed_fixture
run_test test_run_case_uses_the_declared_run_count
run_test test_run_case_commits_a_declared_starting_overlay
run_test test_run_case_clone_carries_a_git_identity


# When: a case file and an experiment file are compiled into a declaration
# Then: the declaration carries the fixture hashes recomputed from the files,
#       and --check accepts it
test_compile_declaration_recomputes_the_fixture_hashes() {
  local work="$TMP/compile_decl"
  make_stub_workspace "$work" "$COMMIT_STUB"
  write_checked_case "$work/case.json" "$work" with_overlay aa_overlay
  jq 'del(.harness)' "$work/case.json" >"$work/caseonly.json"
  jq '{harness: .harness}' "$work/case.json" >"$work/experiment.json"
  local rc=0 out
  out="$(bash "$COMPILE" "$work/caseonly.json" "$work/experiment.json" --out="$work/decl.json" 2>&1)" || rc=$?
  assert_rc 0 "$rc" "the compiler writes a declaration"
  local want got
  want="$(sha256sum "$work/base.bundle" | awk '{print $1}')"
  got="$(jq -r '.harness.fixture_sha256.bundle' "$work/decl.json")"
  assert_eq "$got" "$want" "the declaration carries the recomputed bundle hash"
  rc=0
  bash "$RUN_CASE" --check="$work/decl.json" >/dev/null 2>&1 || rc=$?
  assert_rc 0 "$rc" "the generated declaration passes --check"
  jq --arg z "$(printf '0%.0s' {1..64})" '.harness.fixture_sha256.bundle = $z' "$work/decl.json" >"$work/stale.json"
  rc=0
  bash "$RUN_CASE" --check="$work/stale.json" >/dev/null 2>&1 || rc=$?
  assert_rc 2 "$rc" "--check rejects a hand-edited hash"
}
run_test test_compile_declaration_recomputes_the_fixture_hashes
test_done
