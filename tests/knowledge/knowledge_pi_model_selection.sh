#!/usr/bin/env bash
set -uo pipefail

TEST_KNOWLEDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_KNOWLEDGE_DIR/../libs/test_common.sh"

HELPER="$TEST_KNOWLEDGE_DIR/../libs/pi_model_selection.mjs"

run_case() {
  local scenario="$1" expected="$2" selected
  selected="$(node "$HELPER" "$scenario" 2>&1)"
  if [[ $? -ne 0 ]]; then
    fail "$scenario: $selected"
    return
  fi
  assert_eq "$selected" "$expected" "$scenario selects $expected"
}

echo "=== Knowledge Test: Pi Model Selection ==="
echo ""

run_case all-providers deepseek/deepseek-flash
run_case no-deepseek opencode-go/deepseek-v4.1-flash
run_case no-opencode deepseek/deepseek-flash
run_case openrouter-only openrouter/~deepseek/deepseek-flash-latest

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
