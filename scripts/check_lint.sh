#!/usr/bin/env bash
# scripts/check_lint.sh
# ShellCheck gate over all tracked shell scripts (src/, scripts/, tests/,
# test/). BLOCKING since handover 20260823-15: exits nonzero on any warning.
#
# History: baseline at introduction (20260823-07) was 31 warnings, held
# non-gating until cleared. Suppression policy: targeted `# shellcheck
# disable=SCxxxx` with a rationale comment -- never a blanket disable.
# Known intentional suppressions:
#   - SC2034 in draft_state.sh: printf -v dynamic assignment targets
#   - SC2064 in snapshot.sh: trap expansion-now is required because the
#     variable is function-local and must be baked into the trap body
#   - SC1090 on runtime-resolved source paths that are -f validated first

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
  echo "Blocking gate: fix the findings above (targeted directives allowed
with rationale for known false-positive classes; see file header)." >&2
fi

if (( WARNINGS == 0 )); then
  echo "Clean"
fi
exit "$WARNINGS"
