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
  mkdir -p "$dir/docs/operations"
  git -C "$dir" init -q
  printf '# agents\n' >"$dir/AGENTS.md"
  printf '## Amending\n' >"$dir/docs/operations/git_policy.md"
  git -C "$dir" add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m "fixture state"
}

commit_with() {
  local dir="$1" subject="$2" body="$3"
  printf 'change\n' >>"$dir/docs/operations/git_policy.md"
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
  commit_with "$dir" "docs: state the fold rule" "It touches docs/operations/git_policy.md and devlog/roadmap.md."
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
test_run_case_scores_a_stub_run() {
  local work="$TMP/run_case"
  local base="$work/base"
  mkdir -p "$work/bin"
  make_repo_with_base "$base"
  git -C "$base" bundle create "$work/base.bundle" --all >/dev/null 2>&1
  printf 'change\n' >>"$base/docs/operations/git_policy.md"
  git -C "$base" diff >"$work/change.patch"
  git -C "$base" checkout -q -- .

  mkdir -p "$work/candidate"
  cp "$base/AGENTS.md" "$work/candidate/AGENTS.md"
  cp "$base/docs/operations/git_policy.md" "$work/candidate/git_policy.md"

  cat >"$work/bin/pi" <<'STUB'
#!/usr/bin/env bash
git add -A
git -c user.email=t@t -c user.name=t commit -q -m "docs: land the policy change" -m "Folded into the iteration it corrects."
exit 0
STUB
  chmod +x "$work/bin/pi"

  PATH="$work/bin:$PATH" bash "$RUN_CASE" \
    --bundle="$work/base.bundle" --patch="$work/change.patch" \
    --candidate="$work/candidate" --runs=2 --out="$work/out" --label="stub" >/dev/null 2>&1
  local summary="$work/out/measure-stub.json"
  assert_file_exists "$summary"
  assert_eq "$(jq -r '.committed' "$summary")" "2" "both runs committed"
  assert_eq "$(jq -r '.correctness' "$summary")" "1" "correctness is 1"
  assert_eq "$(jq -r '.consistency' "$summary")" "1" "consistency is 1"
  assert_eq "$(jq -r '.body_chars_max' "$summary")" "38" "the body length is measured"
}

run_test test_measure_all_rules_pass
run_test test_measure_rejects_missing_prefix
run_test test_measure_rejects_long_subject
run_test test_measure_rejects_long_body
run_test test_measure_rejects_path_list
run_test test_measure_reports_missing_commit
run_test test_run_case_scores_a_stub_run

test_done
