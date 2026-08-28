#!/usr/bin/env bash
# scripts/check_lint.sh
# ShellCheck report over all tracked shell scripts (src/, scripts/, tests/,
# test/). Currently NON-GATING: reports the warning count and each finding.
#
# Baseline at introduction (20260823-07): 31 warnings. The gate becomes
# blocking once the baseline reaches zero — fix findings, do not grow them.
# Known false-positive classes: SC2034 on `printf -v` dynamic assignment
# targets in draft_state.sh (suppress with a targeted directive, not a
# blanket disable).
#
# Exit 0 always while non-gating. To flip to gating: exit with the warning
# count and wire the target as blocking in CI.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FILES=()
while IFS= read -r F; do
  FILES+=("$F")
done < <(find "$REPO_ROOT/src" "$REPO_ROOT/scripts" "$REPO_ROOT/tests" "$REPO_ROOT/test" \
           -name '*.sh' -not -path '*/node_modules/*' | sort)

WARNINGS=$(shellcheck -S warning "${FILES[@]}" 2>/dev/null | grep -c '\^--' || true)

echo "ShellCheck (-S warning): $WARNINGS warnings across ${#FILES[@]} files"
if (( WARNINGS > 0 )); then
  echo ""
  echo "Run 'shellcheck -S warning <file>' for details. Gate flips to blocking at zero."
fi

if (( WARNINGS == 0 )); then
  echo "Clean — ready to enforce as a blocking gate."
fi
exit 0
