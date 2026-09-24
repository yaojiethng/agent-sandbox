#!/usr/bin/env bash
# scripts/check_test_order.sh
# Order-independence gate (M3.1 U6). Each test file runs twice: once in
# registration order, once with REVERSE_RUN=1 (test_done flushes the
# registrations in reverse). Per-test subshell isolation means order cannot
# matter, so a file whose reversed unit counts differ from its normal counts
# is order-dependent -- the gate proves the isolation or names the offender.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tests" && pwd)"

# run_file FILE MODE -- executes FILE and prints its unit marker tallies.
run_file() {
  local FILE="$1" MODE="$2" OUT
  if [[ "$MODE" == reversed ]]; then
    OUT=$(REVERSE_RUN=1 bash "$FILE" 2>&1)
  else
    OUT=$(bash "$FILE" 2>&1)
  fi
  local rc=$?
  local passed failed
  passed=$(grep -c "^  PASS:" <<<"$OUT")
  failed=$(grep -c "^  FAIL:" <<<"$OUT")
  printf '%s %s %s\n' "$rc" "$passed" "$failed"
}

ORDER_DEPENDENT=0
FILE_COUNT=0

while IFS= read -r FILE; do
  [[ -n "$FILE" ]] || continue
  FILE_COUNT=$((FILE_COUNT + 1))
  NORMAL=$(run_file "$FILE" normal)
  REVERSED=$(run_file "$FILE" reversed)
  if [[ "$NORMAL" != "$REVERSED" ]]; then
    echo "ORDER-DEPENDENT: $(basename "$FILE")"
    echo "  normal   (rc, pass, fail): $NORMAL"
    echo "  reversed (rc, pass, fail): $REVERSED"
    ORDER_DEPENDENT=$((ORDER_DEPENDENT + 1))
  fi
done < <(find "$TESTS_DIR" -maxdepth 1 -name 'test_*.sh' | sort)

echo "$FILE_COUNT test files checked, $ORDER_DEPENDENT order-dependent"

if [[ "$ORDER_DEPENDENT" -gt 0 ]]; then
  exit 1
fi