#!/usr/bin/env bash
set -euo pipefail
pass=0; fail=0; check() { local label="$1" pat="$2" file="$3" invert="${4:-}"; if [ -z "$invert" ]; then if grep -q "$pat" "$file" 2>/dev/null; then echo "  PASS: $label"; pass=$((pass+1)); else echo "  FAIL: $label"; fail=$((fail+1)); fi; else if grep -q "$pat" "$file" 2>/dev/null; then echo "  FAIL: $label"; fail=$((fail+1)); else echo "  PASS: $label"; pass=$((pass+1)); fi; fi; }

F="docs/operations/iteration_policy.md"

echo "=== Gate 2 AC template (Step 5 Details) ==="
check "T1: Literal table header with Verified by column" '\| # \| Criterion \| Verifiable by \| Verified by \|' "$F"
check "T2: Example row with Agent checkmark" '\| 1 \| .* \| .* \| Agent ✅ \|' "$F"

echo ""
echo "=== Gate 3 / Step 7 AC status template (Step 7 Details) ==="
check "T3: Literal table header with Status column" '\| # \| Criterion \| Verifiable by \| Status \|' "$F"
check "T4: Example row with Accepted" '\| 1 \| .* \| .* \| Accepted \|' "$F"
check "T5: Contrast warning present (do not reuse Gate 2 format)" "Do not reuse the Gate 2 format" "$F"

echo ""
echo "=== Scope proposal template (Step 2 Details) ==="
check "T6: Bold session type line with type and justification" '\*\*Session type:\*\*.*—' "$F"
check "T7: Bold In scope header" '\*\*In scope:\*\*' "$F"
check "T8: Bold Deferred header" '\*\*Deferred:\*\*' "$F"
check "T9: Bold Questions header" '\*\*Questions:\*\*' "$F"

echo ""
echo "=== RESULT: $pass PASS, $fail FAIL ==="
