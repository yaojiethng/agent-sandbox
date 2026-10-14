#!/usr/bin/env bash
# run_case.sh -- run one eval case against one instruction-set candidate, then score the runs.
#
# The candidate is a directory holding the two files under test, AGENTS.md and
# git_policy.md. Every run gets its own clone of the base bundle, its own copy of
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
[[ -f "$CANDIDATE/AGENTS.md" && -f "$CANDIDATE/git_policy.md" ]] || { echo "candidate needs AGENTS.md and git_policy.md: $CANDIDATE" >&2; exit 2; }

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

PROVIDER="${EVAL_PROVIDER:-opencode-go}"
MODEL="${EVAL_MODEL:-step-5-preview-free}"
THINKING="${EVAL_THINKING:-high}"
RUN_TIMEOUT="${EVAL_RUN_TIMEOUT:-600}"
CONFIG_DIR="${EVAL_CONFIG_DIR:-$HOME/.pi/agent}"
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
  cp "$CANDIDATE/git_policy.md" "$PROJ/docs/operations/git_policy.md"
  git -C "$PROJ" apply "$PATCH" || { echo "patch failed for run $i" >&2; exit 1; }
  git -C "$PROJ" rev-list --count HEAD >"$RUN_DIR/base-count"
  git -C "$PROJ" rev-parse HEAD >"$RUN_DIR/base-sha"
  (
    cd "$PROJ" || exit 1
    timeout "$RUN_TIMEOUT" env PI_CODING_AGENT_DIR="$CONFIG_DIR" pi -p \
      "You are working in the git repository at $PROJ. $PROMPT Work only inside that directory. Reply DONE when the commit is made." \
      --provider "$PROVIDER" --model "$MODEL" --thinking "$THINKING" \
      --session "$RUN_DIR/session.jsonl" >"$RUN_DIR/run.log" 2>&1
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
