#!/usr/bin/env bash
# scripts/check_eval_entrypoint.sh
# Holds the eval runner to one caller class: its own skill and the test suite.
#
# Why a gate. A behaviour eval is expensive, writes outside the repository and
# grades a run against a frozen fixture, so a second caller is a second set of
# assumptions about all three. The runner is therefore reached through the evals
# skill, and the only other caller is the suite that tests it. Without a check,
# the next prompt that "just needs one measurement" becomes the third caller and
# nothing reports it.
#
# Usage: bash scripts/check_eval_entrypoint.sh
# Exit:  0 = every caller is allowed, 1 = a finding

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${EVAL_RUNNER:-run_case.sh}"

findings=0
callers=0

while IFS= read -r file; do
  rel="${file#"$REPO_ROOT"/}"
  callers=$((callers + 1))
  case "$rel" in
  .agents/skills/evals/* | tests/* | scripts/check_eval_*.sh) ;;
  *)
    echo "CALLER  $rel names $RUNNER outside the eval skill and the suite"
    findings=$((findings + 1))
    ;;
  esac
done < <(grep -rlF -- "$RUNNER" \
  "$REPO_ROOT/scripts" "$REPO_ROOT/src" "$REPO_ROOT/workflow" "$REPO_ROOT/.agents" 2>/dev/null \
  | grep -v '/\.git/' | sort || true)

if [[ "$findings" -gt 0 ]]; then
  echo "Eval-entrypoint gate: $findings finding(s) across $callers caller(s)."
  exit 1
fi

echo "Eval-entrypoint gate: clean; the runner is named by its skill and the suite only."
