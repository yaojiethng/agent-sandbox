#!/usr/bin/env bash
# measure_commit.sh -- score one fixture's delivery commit against the commit-message format rules.
#
# usage: measure_commit.sh <project-dir> <base-commit-count>
# prints one JSON object. Rules: type prefix, subject at most 50 characters,
# body at most 280 characters, no path list in the body.
set -uo pipefail

PROJ="${1:?usage: measure_commit.sh <project-dir> <base-commit-count>}"
BASE_COUNT="${2:?usage: measure_commit.sh <project-dir> <base-commit-count>}"
TYPES="feat fix refactor docs plan chore workflow test build"

subject="$(git -C "$PROJ" log -1 --format=%s 2>/dev/null)"
body="$(git -C "$PROJ" log -1 --format=%b 2>/dev/null)"
dirty="$(git -C "$PROJ" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
count="$(git -C "$PROJ" rev-list --count HEAD 2>/dev/null)"

prefix_ok=false
if [[ "$subject" == *": "* ]]; then
  prefix="${subject%%:*}"
  for t in $TYPES; do
    [[ "$prefix" == "$t" ]] && prefix_ok=true
  done
fi

subject_len=${#subject}
body_len=${#body}
subject_len_ok=false; (( subject_len <= 50 )) && subject_len_ok=true
body_len_ok=false; (( body_len <= 280 )) && body_len_ok=true

no_path_list=true
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*[-*] ]] && no_path_list=false
  [[ "$line" =~ (^|[[:space:]])(src|docs|devlog|scripts|tests|workflow)/ ]] && no_path_list=false
  [[ "$line" =~ [A-Za-z0-9_./-]+\.(md|sh|mjs|js|json|yml|yaml|ts) ]] && no_path_list=false
done <<<"$body"

new_commits=$(( count - BASE_COUNT ))
committed=false; one_commit=false; clean=false
(( new_commits >= 1 )) && committed=true
(( new_commits == 1 )) && one_commit=true
(( dirty == 0 )) && clean=true

rules=0
[[ "$prefix_ok" == true ]] && rules=$((rules + 1))
[[ "$subject_len_ok" == true ]] && rules=$((rules + 1))
[[ "$body_len_ok" == true ]] && rules=$((rules + 1))
[[ "$no_path_list" == true ]] && rules=$((rules + 1))

printf '{"committed":%s,"one_commit":%s,"new_commits":%s,"clean":%s,"subject_len":%s,"body_chars":%s,"prefix_ok":%s,"subject_len_ok":%s,"body_len_ok":%s,"no_path_list":%s,"rules_satisfied":%s,"rules_total":4}\n' \
  "$committed" "$one_commit" "$new_commits" "$clean" "$subject_len" "$body_len" "$prefix_ok" "$subject_len_ok" "$body_len_ok" "$no_path_list" "$rules"
