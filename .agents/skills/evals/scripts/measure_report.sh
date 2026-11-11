#!/usr/bin/env bash
# measure_report.sh -- score one fixture's maintenance report.
#
# usage: measure_report.sh <project-dir> <base-commit-count> [report-path]
# prints one JSON object. The report is a JSONL file at the project root,
# written by the run; an optional third argument names another path, relative to
# the project or absolute. This measure records whether it exists and how large it
# is; the findings themselves are graded blind, not here.
set -uo pipefail

PROJ="${1:?usage: measure_report.sh <project-dir> <base-commit-count> [report-path]}"
BASE_COUNT="${2:?usage: measure_report.sh <project-dir> <base-commit-count> [report-path]}"
REPORT_PATH="${3:-report.jsonl}"

count="$(git -C "$PROJ" rev-list --count HEAD 2>/dev/null)"
dirty="$(git -C "$PROJ" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
new_commits=$(( count - BASE_COUNT ))

case "$REPORT_PATH" in
/*) report="$REPORT_PATH" ;;
*) report="$PROJ/$REPORT_PATH" ;;
esac
present=false; lines=0; bytes=0
if [[ -f "$report" ]]; then
  present=true
  lines="$(wc -l <"$report" | tr -d ' ')"
  bytes="$(wc -c <"$report" | tr -d ' ')"
fi

committed=false; (( new_commits >= 1 )) && committed=true
clean=false; (( dirty == 0 )) && clean=true

evidence="no report file"
[[ "$present" == true ]] && evidence="$lines lines, $bytes bytes"

jq -n --argjson committed "$committed" --argjson new_commits "$new_commits" --argjson clean "$clean" \
  --argjson present "$present" --argjson lines "$lines" --argjson bytes "$bytes" --arg evidence "$evidence" '
  {committed: $committed, new_commits: $new_commits, clean: $clean,
   report_present: $present, report_lines: $lines, report_bytes: $bytes,
   assertions: [{id: "report_present", text: "the report file exists", pass: $present, evidence: $evidence}]}'
