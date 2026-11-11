#!/usr/bin/env bash
# scripts/check_eval_layout.sh
# The eval layout has one owner: .agents/skills/evals/assets/layout.json. The two
# consumers read it through layout.sh, so no second statement of where a case, a
# fixture or a run's artefacts live survives in code.
#
# The gate fails when the declaration does not parse, when a consumer does not
# source the reader, when a consumer reads a key the declaration does not carry,
# or when a declared key no consumer reads. The last is dead weight: a key only a
# reader maintains is a statement nothing holds to the tree.
#
# Usage: bash scripts/check_eval_layout.sh [repo-root]
# Exit:  0 = clean, 1 = a finding

set -uo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LAYOUT="$REPO_ROOT/.agents/skills/evals/assets/layout.json"
CONSUMERS=(
  "$REPO_ROOT/.agents/skills/evals/scripts/run_case.sh"
  "$REPO_ROOT/scripts/check_eval_fixtures.sh"
)

findings=0
report() { printf '%s\n' "$*"; }

if ! jq -e 'type == "object" and length > 0 and all(.[]; type == "string" and length > 0)' \
  "$LAYOUT" >/dev/null 2>&1; then
  report "LAYOUT  $LAYOUT  is not an object of non-empty strings"
  exit 1
fi

declared="$(jq -r 'keys[]' "$LAYOUT" | sort)"
read_keys=""
for consumer in "${CONSUMERS[@]}"; do
  if [[ ! -f "$consumer" ]]; then
    report "CONSUMER  ${consumer#"$REPO_ROOT"/}  is missing"
    findings=$((findings + 1))
    continue
  fi
  if ! grep -q 'layout\.sh' "$consumer"; then
    report "CONSUMER  ${consumer#"$REPO_ROOT"/}  does not source layout.sh"
    findings=$((findings + 1))
  fi
  read_keys="$read_keys"$'\n'"$(grep -ho 'layout_get [A-Za-z0-9_]*' "$consumer" | awk '{print $2}')"
done
read_keys="$(printf '%s\n' "$read_keys" | sed '/^$/d' | sort -u)"

while IFS= read -r key; do
  [[ -n "$key" ]] || continue
  grep -qxF "$key" <<<"$declared" \
    || { report "KEY  $key  is read by a consumer and not declared"; findings=$((findings + 1)); }
done <<<"$read_keys"

while IFS= read -r key; do
  [[ -n "$key" ]] || continue
  grep -qxF "$key" <<<"$read_keys" \
    || { report "KEY  $key  is declared and no consumer reads it"; findings=$((findings + 1)); }
done <<<"$declared"

if (( findings > 0 )); then
  report "Eval-layout gate: $findings finding(s) across $(wc -w <<<"$declared") declared key(s)."
  exit 1
fi

report "Eval-layout gate: clean across $(wc -w <<<"$declared") declared key(s) and ${#CONSUMERS[@]} consumer(s)."
