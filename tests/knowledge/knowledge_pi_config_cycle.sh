#!/usr/bin/env bash
set -uo pipefail

TEST_KNOWLEDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_KNOWLEDGE_DIR/../libs/test_common.sh"

REPO_ROOT="$(cd "$TEST_KNOWLEDGE_DIR/../.." && pwd)"
SETTINGS="$REPO_ROOT/src/reasoning/agent-runtime/pi/config/agent/settings.json"

test_shipped_settings_names_harness_roots() {
  echo ""
  echo "--- Shipped settings names the harness roots ---"

  if ! command -v jq &>/dev/null; then
    echo "    SKIP: jq not available"
    return
  fi
  if [[ ! -f "$SETTINGS" ]]; then
    echo "    FAIL: the pi config template is not at $SETTINGS"
    return
  fi

  local key value expected
  for pair in "packages:/opt/workflow/agent" "packages:/opt/workflow/agent/modules/coding-agent"; do
    key="${pair%%:*}"
    expected="${pair#*:}"
    value="$(jq -r --arg key "$key" '.[$key] // [] | join(",")' "$SETTINGS")"
    if [[ ",$value," == *",$expected,"* ]]; then
      pass "$key names $expected"
    else
      fail "$key reads '$value', not naming $expected"
    fi
  done

  local lists
  lists="$(jq -r '[(.skills // [])[], (.prompts // [])[]] | join(",")' "$SETTINGS")"
  if [[ "$lists" != *"/opt/workflow/agent"* ]]; then
    pass "no skills or prompts list names a harness root"
  else
    fail "a skills or prompts list names a harness root: $lists"
  fi
}

echo "=== Knowledge Test: Pi Config Knowledge ==="
echo ""

test_shipped_settings_names_harness_roots

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
