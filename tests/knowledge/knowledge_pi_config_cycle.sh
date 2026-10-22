#!/usr/bin/env bash
# tests/knowledge/knowledge_pi_config_cycle.sh
#
# Knowledge test: Pi-specific config knowledge - the shipped settings.json and
# the model scope it opens on.
#
# Documents the behavioural assumptions about:
#   a) The shipped settings.json carries the harness roots in one key: `packages`
#      names the image-baked /opt/workflow/agent, whose conventional `prompts`
#      and `skills` subdirectories pi loads as roots, and a second entry names the
#      coding-agent module, whose own conventional subdirectories load the same
#      way. That file is image-owned: entrypoint.sh seeds AGENT_HOME from the
#      config template at every start, so the key comes back each session even if
#      a session rewrites the file. No `skills` or `prompts` list exists, because
#      it would name those same two roots again.
#   b) The scope head names the configured default. Pi's `findInitialModel`
#      selects `scopedModels[0]` and reaches `defaultProvider`/`defaultModel`
#      only when the scope is empty, so the first `enabledModels` entry decides
#      the model every session starts on.
#
# This test is Pi-specific because:
#  - settings.json is a Pi config file (other providers use their own format)
#  - the agent/ subdirectory under AGENT_HOME is a Pi config quirk
#  - the /opt/workflow/agent paths exist in every provider image, but only Pi
#    reads them through settings.json keys
#
# Historical note:
#   This file was named knowledge_provider_config_cycle.sh and was later
#   renamed. The copy-in/copy-out tests it once carried were removed when that
#   mechanism was retired; the test simulated it with local `cp -r` helpers
#   rather than exercising the harness. Provider config now travels as the
#   image's template, seeded into AGENT_HOME at every start, plus the
#   subdirectories the provider overlay bind-mounts.
#
# Reference:
#  - src/reasoning/providers/pi/config/agent/settings.json (the image template)
#  - src/reasoning/entrypoint.sh (_provision_agent_home)
#  - src/build/container-interface.json (the template's source and image path)
#  - docs/reference/provider_lifecycle.md ("Config Flow and Fragility Notes")
#  - .agents/skills/testing/references/test-homes.md (knowledge test format)
#
# Not run by make test. Run manually:
#   bash tests/knowledge/knowledge_pi_config_cycle.sh

set -uo pipefail

TEST_KNOWLEDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_KNOWLEDGE_DIR/../libs/test_common.sh"

SETTINGS="/home/agentuser/sandbox/src/reasoning/providers/pi/config/agent/settings.json"

# ---------------------------------------------------------------------------
# Test 1: the shipped settings carries the harness roots
# ---------------------------------------------------------------------------

# The packages key is the switch, and each entry contributes its conventional
# `prompts` and `skills` subdirectories as roots. No `skills` or `prompts` list
# names a harness root, because the package route already reaches both.
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

# ---------------------------------------------------------------------------
# Test 2: the scope head names the configured default
# ---------------------------------------------------------------------------

# pi's `findInitialModel` selects `scopedModels[0]` and only reaches
# `defaultProvider`/`defaultModel` when the scope is empty, so the first entry
# of `enabledModels` decides which model every session starts on. A list whose
# head does not name the default is not a tidier list; it is a different
# default, applied silently. Measured on 0.87.1 and reported upstream in
# devlog/discussions/20261002-report-draft-default_model_resolution_bug.md.
test_scope_head_names_the_default() {
  echo ""
  echo "--- Scope head names the configured default ---"

  if ! command -v jq &>/dev/null; then
    echo "    SKIP: jq not available"
    return
  fi
  if [[ ! -f "$SETTINGS" ]]; then
    echo "    FAIL: the pi config template is not at $SETTINGS"
    return
  fi

  local head provider model expected
  head=$(jq -r '.enabledModels[0] // ""' "$SETTINGS")
  provider=$(jq -r '.defaultProvider // ""' "$SETTINGS")
  model=$(jq -r '.defaultModel // ""' "$SETTINGS")
  expected="${provider}/${model}"

  if [[ -z "$head" ]]; then
    fail "enabledModels is empty, so the scope does not constrain anything"
  elif [[ "$head" == "$expected" ]]; then
    pass "scope head '${head}' is the configured default"
  else
    fail "scope head '${head}' is not the configured default '${expected}'; pi starts on the scope head"
  fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== Knowledge Test: Pi Config Knowledge ==="
echo ""

test_shipped_settings_names_harness_roots

test_scope_head_names_the_default

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
