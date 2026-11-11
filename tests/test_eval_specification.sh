#!/usr/bin/env bash
# TEST_DEADLINE: 120
# Tests: .agents/skills/evals/scripts/run_case.sh and measure_session.mjs against
# the experiment specification in .agents/skills/evals/references/specification.md.
source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_CASE="$REPO_ROOT/.agents/skills/evals/scripts/run_case.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# session_json <stop-reason> <path-read> -- one assistant turn, shaped like the runtime's.
session_json() {
  local stop="$1" target="$2"
  printf '{"type":"message","timestamp":"2026-11-07T00:00:00Z","message":{"role":"assistant","provider":"stub-provider","model":"stub-model","stopReason":"stop","rawStopReason":"%s","durationMs":1200,"usage":{"input":1000,"output":50,"totalTokens":1050},"content":[{"type":"toolCall","id":"c1","name":"read","arguments":{"path":"%s"}}]}}\n' \
    "$stop" "$target"
}

# make_workspace <dir> <stub-body>
make_workspace() {
  local work="$1" stub="$2" base="$1/base"
  mkdir -p "$work/bin" "$work/candidate/.agents/skills/git-discipline" "$work/pi"
  mkdir -p "$base/.agents/skills/git-discipline"
  git -C "$base" init -q
  printf '# agents\n' >"$base/AGENTS.md"
  printf '## The fold\n' >"$base/.agents/skills/git-discipline/SKILL.md"
  git -C "$base" add -A
  git -C "$base" -c user.email=t@t -c user.name=t commit -q -m "fixture state"
  git -C "$base" bundle create "$work/base.bundle" --all >/dev/null 2>&1
  printf 'change\n' >>"$base/.agents/skills/git-discipline/SKILL.md"
  git -C "$base" diff >"$work/change.patch"
  git -C "$base" checkout -q -- .
  cp "$base/AGENTS.md" "$work/candidate/AGENTS.md"
  cp "$base/.agents/skills/git-discipline/SKILL.md" \
    "$work/candidate/.agents/skills/git-discipline/SKILL.md"
  printf '%s\n' "$stub" >"$work/bin/pi"
  chmod +x "$work/bin/pi"
  printf '{}\n' >"$work/pi/settings.json"
  printf '_ORCHESTRATOR: stub-provider/stub-model at low\n' >"$work/pi/model-recommendations.md"
}

# The stub takes its session path from the argv the entrypoint builds, so the
# transcript is the file the runner will measure.
commit_stub() { # <stub-start> <raw-stop> <path-read>
  cat <<EOF
#!/usr/bin/env bash
session=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in --session) session="\$2"; shift 2 ;; *) shift ;; esac
done
git add -A
git commit -q -m "docs: land the policy change" -m "Folded into the iteration it corrects."
[ -n "\$session" ] && printf '%s\n' '$(session_json "$2" "$3")' >"\$session"
exit 0
EOF
}

no_commit_stub() { # <raw-stop> <path-read> -- the same transcript, no commit
  cat <<EOF
#!/usr/bin/env bash
session=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in --session) session="\$2"; shift 2 ;; *) shift ;; esac
done
[ -n "\$session" ] && printf '%s\n' '$(session_json "$1" "$2")' >"\$session"
exit 0
EOF
}

run_case() { # <work> <out> <runs> [extra args...]
  local work="$1" out="$2" runs="$3"
  shift 3
  PATH="$work/bin:$PATH" \
    EVAL_MODEL="stub-provider/stub-model" EVAL_THINKING="high" \
    EVAL_CONFIG_DIR="$work/pi" \
    EVAL_RECOMMENDATIONS_FILE="$work/pi/model-recommendations.md" \
    bash "$RUN_CASE" --bundle="$work/base.bundle" --patch="$work/change.patch" \
    --measure="$REPO_ROOT/.agents/skills/evals/scripts/measure_commit.sh" \
    --candidate="$work/candidate" --runs="$runs" --out="$out" --label="${LABEL:-stub}" "$@"
}

# When: two configurations run, one that must win and one that must lose
# Then: A1 separates them in the known direction
test_specification_separates_a_known_answer() {
  local win="$TMP/known_win" lose="$TMP/known_lose"
  make_workspace "$win" "$(commit_stub x completed AGENTS.md)"
  make_workspace "$lose" "$(no_commit_stub completed AGENTS.md)"
  run_case "$win" "$win/out" 1 >/dev/null 2>&1
  run_case "$lose" "$lose/out" 1 >/dev/null 2>&1
  assert_eq "$(jq -r '.correctness' "$win/out/measure-stub.json")" "1" "the treated cell passes"
  assert_eq "$(jq -r '.correctness // 0' "$lose/out/measure-stub.json")" "0" "the untreated cell fails"
}

# When: the same configuration runs twice
# Then: A1's delta is zero and its spread is zero, which is the noise floor
test_specification_reports_an_aa_pair_as_zero() {
  local a="$TMP/aa_a" b="$TMP/aa_b"
  make_workspace "$a" "$(commit_stub x completed AGENTS.md)"
  make_workspace "$b" "$(commit_stub x completed AGENTS.md)"
  run_case "$a" "$a/out" 2 >/dev/null 2>&1
  run_case "$b" "$b/out" 2 >/dev/null 2>&1
  assert_eq "$(jq -r '.correctness' "$a/out/measure-stub.json")" \
    "$(jq -r '.correctness' "$b/out/measure-stub.json")" "the two arms agree"
  assert_eq "$(jq -r '.correctness_sd' "$a/out/measure-stub.json")" "0" "the arm has no spread"
}

# When: a run's transcript ends on an abnormal stop reason
# Then: A2 marks the cell invalid and --require-valid refuses the run
test_specification_refuses_a_severed_stream() {
  local work="$TMP/severed"
  make_workspace "$work" "$(commit_stub x error AGENTS.md)"
  run_case "$work" "$work/out" 1 >/dev/null 2>&1
  assert_eq "$(jq -r '.invalid' "$work/out/measure-stub.json")" "1" "the severed cell is invalid"
  assert_eq "$(jq -r '.invalid_rate' "$work/out/measure-stub.json")" "1" "the invalid rate is one"
  run_case "$work" "$work/out2" 1 --require-valid >/dev/null 2>&1
  assert_eq "$?" "3" "--require-valid refuses the run"
}

# When: a run opens a path in the harness's own repository
# Then: A2 counts the escape and the cell is not evidence
test_specification_counts_an_escape() {
  local work="$TMP/escape"
  make_workspace "$work" "$(commit_stub x completed "$REPO_ROOT/AGENTS.md")"
  run_case "$work" "$work/out" 1 >/dev/null 2>&1
  assert_eq "$(jq -r '.escaped_runs' "$work/out/measure-stub.json")" "1" "the escape is counted"
  assert_eq "$(jq -r '.invalid' "$work/out/measure-stub.json")" "1" "an escaped cell is invalid"
}

# When: a run leaves a transcript
# Then: A3 and A5 read it, so the run is attributable and costed
test_specification_attributes_and_costs_a_run() {
  local work="$TMP/attributed"
  make_workspace "$work" "$(commit_stub x completed AGENTS.md)"
  run_case "$work" "$work/out" 1 >/dev/null 2>&1
  assert_eq "$(jq -r '.unattributed' "$work/out/measure-stub.json")" "0" "the run is attributable"
  assert_eq "$(jq -r '.tokens_total' "$work/out/measure-stub.json")" "1050" "the tokens are read"
  assert_eq "$(jq -r '.turns' "$work/out/measure-stub.json")" "1" "the turn is counted"
}

# When: a run leaves its transcript in its own config home
# Then: A3 and A5 find it without being told the path
test_specification_finds_a_session_by_working_directory() {
  local work="$TMP/found_by_cwd" proj="$TMP/found_by_cwd/repo" slug
  mkdir -p "$proj" "$work/home/sessions"
  slug="--$(printf %s "$proj" | tr "/" "-" | sed "s/^-//")--"
  mkdir -p "$work/home/sessions/$slug"
  printf "%s\n" "$(session_json completed AGENTS.md)" >"$work/home/sessions/$slug/s.jsonl"
  local out
  out="$(PI_CODING_AGENT_DIR="$work/home" node "$REPO_ROOT/.agents/skills/evals/scripts/measure_session.mjs" --root "$proj" --repo-root "$REPO_ROOT" --work-root /nonexistent)"
  assert_eq "$(jq -r .turns <<<"$out")" "1" "the transcript is found by its working directory"
}

run_test test_specification_separates_a_known_answer
run_test test_specification_reports_an_aa_pair_as_zero
run_test test_specification_refuses_a_severed_stream
run_test test_specification_counts_an_escape
run_test test_specification_attributes_and_costs_a_run
run_test test_specification_finds_a_session_by_working_directory

test_done
