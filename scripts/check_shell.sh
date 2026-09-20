#!/usr/bin/env bash
# scripts/check_shell.sh
# ShellCheck gate over all tracked shell scripts (src/, scripts/, tests/).
# BLOCKING since handover 20260823-15: exits nonzero on any warning.
#
# Exit codes: 0 = no findings, 1 = findings OR the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# docs/development/bash-coding-conventions.md 3.2).
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

# Fail closed: the gate cannot report "clean" when it never ran. A missing tool
# or an empty file set is a finding, not a pass.
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "ShellCheck gate: shellcheck is not installed; cannot run the gate." >&2
  exit 1
fi

SCAN_DIRS=("$REPO_ROOT/src" "$REPO_ROOT/scripts" "$REPO_ROOT/tests")
# Test seam: a fixture root exercises the missing-directory and empty-file-set
# guards without disturbing the real scan.
if [[ -n "${SHELLCHECK_SCAN_ROOT:-}" ]]; then
  SCAN_DIRS=("$SHELLCHECK_SCAN_ROOT/src" "$SHELLCHECK_SCAN_ROOT/scripts" "$SHELLCHECK_SCAN_ROOT/tests")
fi

FILES=()
for d in "${SCAN_DIRS[@]}"; do
  if [[ ! -d "$d" ]]; then
    echo "ShellCheck gate: $d is missing; cannot determine the file set." >&2
    exit 1
  fi
done
while IFS= read -r F; do
  FILES+=("$F")
done < <(find "${SCAN_DIRS[@]}" -name '*.sh' -not -path '*/node_modules/*' | sort)

if (( ${#FILES[@]} == 0 )); then
  echo "ShellCheck gate: no shell files found under $REPO_ROOT; cannot run the gate." >&2
  exit 1
fi

SC_RC=0
OUTPUT=$(shellcheck -S warning "${FILES[@]}" 2>&1) || SC_RC=$?
WARNINGS=$(printf '%s' "$OUTPUT" | grep -c '\^--' || true)

# The exit code is a verdict: a clean run with no findings. Two things can make
# that false -- findings the marker scan did not parse, and a tool that could
# not run. Both fail the gate; the wording distinguishes them.
echo "ShellCheck (-S warning): $WARNINGS warnings across ${#FILES[@]} files"
if (( SC_RC > 1 )); then
  printf '%s\n' "$OUTPUT"
  echo "ShellCheck gate: shellcheck exited $SC_RC; cannot run the gate." >&2
  exit 1
fi
# A comment whose first token is the tool name is parsed as a directive, which
# the tool reports as SC1072/SC1073 with its own wording. Those codes alone
# cover every parse failure, so match the wording: an ordinary syntax error must
# fall through to the generic findings message rather than receive a remedy that
# cannot work.
if (( SC_RC != 0 )) && grep -q "Couldn't parse this shellcheck directive" <<<"$OUTPUT"; then
  printf '%s\n' "$OUTPUT"
  echo "ShellCheck gate: a comment starting with the word 'shellcheck' is parsed as a directive." >&2
  echo "  Reword the line so the tool name is not the first token after '#'." >&2
  exit 1
fi
if (( SC_RC != 0 || WARNINGS > 0 )); then
  printf '%s\n' "$OUTPUT"
  echo ""
  echo "Blocking gate: fix the findings above (targeted directives allowed
with rationale for known false-positive classes; see file header)." >&2
  exit 1
fi

echo "Clean"
exit 0
