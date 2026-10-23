#!/usr/bin/env bash
# run_case.sh -- run one eval case against one instruction-set candidate, then score the runs.
#
# The candidate is a directory holding the two files under test, AGENTS.md and
# .agents/skills/git-discipline/SKILL.md. Every run gets its own clone of the base bundle, its own copy of
# the candidate files, and an identical uncommitted workload.
#
# The clone is scratch and lives in a work root: a temp directory removed when the
# script exits. EVAL_KEEP_WORK=1 keeps it, and --work=<dir> names the root and keeps
# it. The run's change travels as a bundle of the delta from the fixture's base
# commit, written beside the run's measure, and a run that left the tree dirty also
# writes a patch of the remainder. The measures, logs and session files stay under
# --out, so a graded case leaves no worktree behind.
#
# usage: run_case.sh --bundle=<repo.bundle> --patch=<diff> --candidate=<dir> --runs=N --out=<dir>
#                    [--label=<id>] [--work=<dir>] [--measure-only]
# with --measure-only, --work must name the root of the run being re-scored, because
# that run's worktree carries the commits to measure.
# prints a JSON summary and writes it to <out>/measure-<label>.json
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE=""; PATCH=""; CANDIDATE=""; RUNS=3; OUT=""; WORK_ROOT=""; LABEL="candidate"; MEASURE_ONLY=false
for arg in "$@"; do
  case "$arg" in
  --bundle=*) BUNDLE="${arg#*=}" ;;
  --patch=*) PATCH="${arg#*=}" ;;
  --candidate=*) CANDIDATE="${arg#*=}" ;;
  --runs=*) RUNS="${arg#*=}" ;;
  --out=*) OUT="${arg#*=}" ;;
  --work=*) WORK_ROOT="${arg#*=}" ;;
  --label=*) LABEL="${arg#*=}" ;;
  --measure-only) MEASURE_ONLY=true ;;
  *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done
if [[ "$MEASURE_ONLY" == false ]]; then
  [[ -n "$BUNDLE" && -n "$PATCH" && -n "$CANDIDATE" && -n "$OUT" ]] || { echo "usage: run_case.sh --bundle= --patch= --candidate= --out= [--runs= --label=]" >&2; exit 2; }
  [[ -f "$BUNDLE" ]] || { echo "bundle not found: $BUNDLE" >&2; exit 2; }
  [[ -f "$PATCH" ]] || { echo "patch not found: $PATCH" >&2; exit 2; }
fi
[[ -n "$OUT" ]] || { echo "--out is required" >&2; exit 2; }
[[ -f "$CANDIDATE/AGENTS.md" && -f "$CANDIDATE/.agents/skills/git-discipline/SKILL.md" ]] || { echo "candidate needs AGENTS.md and .agents/skills/git-discipline/SKILL.md: $CANDIDATE" >&2; exit 2; }

WORK_KEPT=false
if [[ -n "$WORK_ROOT" ]]; then
  WORK_KEPT=true
elif [[ "$MEASURE_ONLY" == true ]]; then
  echo "--measure-only needs --work=<dir>, the work root of the run being re-scored" >&2
  exit 2
else
  WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/eval-case-$LABEL.XXXXXX")" || { echo "cannot create a work root" >&2; exit 1; }
  [[ "${EVAL_KEEP_WORK:-0}" == "1" ]] && WORK_KEPT=true
  [[ "$WORK_KEPT" == true ]] || trap 'rm -rf "$WORK_ROOT"' EXIT
fi
mkdir -p "$WORK_ROOT"
[[ "$WORK_KEPT" == true ]] && echo "work root kept: $WORK_ROOT"

RUN_TIMEOUT="${EVAL_RUN_TIMEOUT:-600}"
CONFIG_DIR="${EVAL_CONFIG_DIR:-$HOME/.pi/agent}"

DISPATCH_SH="${EVAL_DISPATCH_SH:-$HERE/../../../../../scripts/dispatch.sh}"
# The eval default is the _ORCHESTRATOR role, resolved by the dispatch entrypoint
# and launched through the command it prints. Nothing here composes a launch flag:
# a consumer that took the model from the table and the provider from a literal
# ran the table's entry against a runtime the table did not choose, and the
# runtime forwarded the request while the provider refused it.
RECOMMENDATIONS_FILE="${EVAL_RECOMMENDATIONS_FILE:-}"
if [[ -z "$RECOMMENDATIONS_FILE" ]]; then
  if [[ -n "${PROJECT_DIR:-}" && -f "$PROJECT_DIR/.agents/model-recommendations.md" ]]; then
    RECOMMENDATIONS_FILE="$PROJECT_DIR/.agents/model-recommendations.md"
  else
    RECOMMENDATIONS_FILE="$(dirname "$CONFIG_DIR")/model-recommendations.md"
  fi
fi
# A pin is a whole assignment: EVAL_MODEL names one, and EVAL_THINKING replaces
# the level the table carries.
PIN=()
[[ -n "${EVAL_MODEL:-}" ]] && PIN+=(--model "$EVAL_MODEL")
[[ -n "${EVAL_THINKING:-}" ]] && PIN+=(--thinking "$EVAL_THINKING")
PROMPT="${EVAL_PROMPT:-The working tree holds the pending work for this iteration. Land it as the delivery commit.}"

CASE_DIR="$OUT/case-$LABEL"
mkdir -p "$CASE_DIR"
: >"$CASE_DIR/runs.jsonl"
START=$(date +%s)

if [[ "$MEASURE_ONLY" == false ]]; then
for i in $(seq 1 "$RUNS"); do
  RUN_DIR="$CASE_DIR/run-$i"
  PROJ="$WORK_ROOT/run-$i/project"
  rm -rf "$RUN_DIR" "$WORK_ROOT/run-$i"
  mkdir -p "$RUN_DIR"
  git clone -q "$BUNDLE" "$PROJ" || { echo "clone failed for run $i" >&2; exit 1; }
  cp "$CANDIDATE/AGENTS.md" "$PROJ/AGENTS.md"
  mkdir -p "$PROJ/.agents/skills/git-discipline"
  cp "$CANDIDATE/.agents/skills/git-discipline/SKILL.md" "$PROJ/.agents/skills/git-discipline/SKILL.md"
  git -C "$PROJ" apply "$PATCH" || { echo "patch failed for run $i" >&2; exit 1; }
  git -C "$PROJ" rev-list --count HEAD >"$RUN_DIR/base-count"
  git -C "$PROJ" rev-parse HEAD >"$RUN_DIR/base-sha"
  printf 'You are working in the git repository at %s. %s Work only inside that directory. Reply DONE when the commit is made.\n' \
    "$PROJ" "$PROMPT" >"$RUN_DIR/prompt.txt"
  # One door: the command comes from the entrypoint, so the runtime, the provider
  # and the model are the table's decision rather than this script's.
  CMD="$(DISPATCH_REC_FILE="$RECOMMENDATIONS_FILE" \
    DISPATCH_STATE_FILE="$RUN_DIR/dispatch-state.json" \
    bash "$DISPATCH_SH" --role _ORCHESTRATOR --brief "$RUN_DIR/prompt.txt" \
      --dir "$PROJ" --session "$RUN_DIR/session.jsonl" \
      ${PIN[@]+"${PIN[@]}"})" || { echo "the eval command cannot be resolved" >&2; exit 2; }
  (
    cd "$PROJ" || exit 1
    timeout "$RUN_TIMEOUT" env PI_CODING_AGENT_DIR="$CONFIG_DIR" bash -c "$CMD" \
      >"$RUN_DIR/run.log" 2>&1
    echo $? >"$RUN_DIR/rc"
  ) &
done
wait
fi

for i in $(seq 1 "$RUNS"); do
  RUN_DIR="$CASE_DIR/run-$i"
  PROJ="$WORK_ROOT/run-$i/project"
  bash "$HERE/measure_commit.sh" "$PROJ" "$(cat "$RUN_DIR/base-count")" >"$RUN_DIR/measure.json"
  base="$(cat "$RUN_DIR/base-sha")"
  head="$(git -C "$PROJ" rev-parse HEAD 2>/dev/null || echo "$base")"
  rm -f "$RUN_DIR/run.bundle" "$RUN_DIR/run.patch"
  [[ "$head" != "$base" ]] && { git -C "$PROJ" bundle create -q "$RUN_DIR/run.bundle" "$base..HEAD" || { echo "bundle failed for run $i" >&2; exit 1; }; }
  git -C "$PROJ" diff HEAD >"$RUN_DIR/run.patch"
  printf '{"run":%s,"rc":%s,"measure":%s}\n' \
    "$i" "$(cat "$RUN_DIR/rc" 2>/dev/null || echo 'null')" \
    "$(cat "$RUN_DIR/measure.json")" >>"$CASE_DIR/runs.jsonl"
done

jq -s --arg cand "$LABEL" --argjson runs "$RUNS" --argjson secs "$(( $(date +%s) - START ))" '
  def committed_runs: [.[] | select(.measure.committed)];
  {
    "candidate": $cand,
    runs: $runs,
    committed: (committed_runs | length),
    one_commit_rate: (([.[] | select(.measure.one_commit)] | length) / $runs),
    correctness: (if (committed_runs | length) > 0 then ((committed_runs | map(.measure.rules_satisfied / .measure.rules_total) | add) / (committed_runs | length)) else 0 end),
    consistency: (if (committed_runs | length) > 0 then (([.[] | select(.measure.committed and .measure.rules_satisfied == .measure.rules_total)] | length) / (committed_runs | length)) else 0 end),
    body_chars_mean: (if (committed_runs | length) > 0 then ((committed_runs | map(.measure.body_chars) | add) / (committed_runs | length)) else 0 end),
    body_chars_max: (if (committed_runs | length) > 0 then (committed_runs | map(.measure.body_chars) | max) else 0 end),
    subject_chars_max: (if (committed_runs | length) > 0 then (committed_runs | map(.measure.subject_len) | max) else 0 end),
    wall_seconds: $secs,
    runs_detail: map({run, rc, new_commits: .measure.new_commits, one_commit: .measure.one_commit, body_chars: .measure.body_chars, subject_len: .measure.subject_len, rules: .measure.rules_satisfied})
  }' "$CASE_DIR/runs.jsonl" | tee "$OUT/measure-$LABEL.json"
