#!/usr/bin/env bash
# tests/extensions/pi/model-refresh/knowledge/knowledge_opencode_gateway_matrix.sh
# TEST_DEADLINE: 600
#
# Knowledge test: which opencode models accept `reasoning_effort: "none"`, the
# value a thinking-level map uses for the disabled state.
#
# The finding this records is that acceptance is PER MODEL, not a property of
# the product. Both opencode products (Zen at opencode.ai/zen, Go at
# opencode.ai/zen/go) are operated by the same company and share a gateway, yet
# space-bunny-free rejects the value with HTTP 400 on both while
# longcat-2.5-preview-free, deepseek-v4-flash and glm-5.3-flash accept it on Go.
# So an override that maps a disabled level onto "none" is only safe for a model
# that has been probed here, and copying one model's override to another is a
# live 400.
#
# This probes an external service, so it is a knowledge test and not part of
# make test. It needs OPENCODE_API_KEY in the environment and spends requests.
#
# What it does NOT establish: whether an accepted "none" actually stops
# reasoning. The gateway's reasoning-token counts are too noisy to tell
# (measured 45 tokens at "none" against 44 at "low" for glm-5.3-flash), so the
# README records that as open rather than working.
#
# Reference:
#   src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md
#     -- the dated table this test reproduces.
#
# Not run by make test. Run manually:
#   OPENCODE_API_KEY=... bash tests/extensions/pi/model-refresh/knowledge/knowledge_opencode_gateway_matrix.sh

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_DIR="$(cd "$HERE/.." && pwd)"
REPO_TOP="$(cd "$SUITE_DIR/../../../.." && pwd)"
# shellcheck source=../../../libs/test_common.sh
source "$REPO_TOP/tests/libs/test_common.sh"

test_setup

# -------------------------
# Helpers
# -------------------------

# Echoes the terminal HTTP status pi reported, or "ok" when the request
# succeeded. A 400 from the gateway is the signal under test, so it is data and
# not a test failure.
probe_status() {
  local provider="$1" model="$2" out rc
  out="$(PI_CODING_AGENT_DIR="$FIXTURE_DIR" timeout 90 pi -p -ne -np -nc \
    --provider "$provider" --model "$model" --thinking off --no-session "probe" 2>&1 </dev/null)"
  rc=$?
  if ((rc == 0)); then
    echo "ok"
    return 0
  fi
  case "$out" in
    *400*) echo "400" ;;
    *402*) echo "402" ;;
    *403*) echo "403" ;;
    *404*) echo "404" ;;
    *) echo "rc=$rc" ;;
  esac
}

# Writes a models.json mapping one model's disabled level onto "none".
write_none_override() {
  local provider="$1" model="$2"
  cat >"$FIXTURE_DIR/models.json" <<MODELS
{
  "providers": {
    "${provider}": {
      "modelOverrides": {
        "${model}": { "thinkingLevelMap": { "off": "none" } }
      }
    }
  }
}
MODELS
}

# -------------------------
# Tests
# -------------------------

test_the_key_is_present() {
  if [[ -n "${OPENCODE_API_KEY:-}" ]]; then
    pass "OPENCODE_API_KEY is set"
  else
    skip "OPENCODE_API_KEY is not set: the gateway cannot be probed"
  fi
}

test_space_bunny_free_rejects_the_disabled_effort() {
  write_none_override "opencode-go" "space-bunny-free"
  local status
  status="$(probe_status "opencode-go" "space-bunny-free")"
  if [[ "$status" == "400" ]]; then
    pass "space-bunny-free on opencode-go rejects reasoning_effort none with 400"
  else
    fail "space-bunny-free on opencode-go rejects reasoning_effort none with 400 (got $status)"
  fi
}

test_longcat_accepts_the_disabled_effort() {
  write_none_override "opencode-go" "longcat-2.5-preview-free"
  local status
  status="$(probe_status "opencode-go" "longcat-2.5-preview-free")"
  if [[ "$status" == "ok" ]]; then
    pass "longcat-2.5-preview-free on opencode-go accepts reasoning_effort none"
  else
    fail "longcat-2.5-preview-free on opencode-go accepts reasoning_effort none (got $status)"
  fi
}

test_deepseek_accepts_the_disabled_effort() {
  write_none_override "opencode-go" "deepseek-v4-flash"
  local status
  status="$(probe_status "opencode-go" "deepseek-v4-flash")"
  if [[ "$status" == "ok" ]]; then
    pass "deepseek-v4-flash on opencode-go accepts reasoning_effort none"
  else
    fail "deepseek-v4-flash on opencode-go accepts reasoning_effort none (got $status)"
  fi
}

test_the_two_products_disagree_for_the_same_free_model() {
  # The point of the test: same model, same operator, different answer. If this
  # ever agrees, the per-model rule in the README needs rewriting.
  write_none_override "opencode" "space-bunny-free"
  local zen go_status
  zen="$(probe_status "opencode" "space-bunny-free")"
  write_none_override "opencode-go" "space-bunny-free"
  go_status="$(probe_status "opencode-go" "space-bunny-free")"
  if [[ "$zen" == "400" && "$go_status" == "400" ]]; then
    pass "space-bunny-free rejects the disabled effort on both products (zen $zen, go $go_status)"
  else
    fail "space-bunny-free rejects the disabled effort on both products (zen $zen, go $go_status)"
  fi
}

test_the_zen_free_tier_refuses_non_opencode_clients() {
  # Recorded because it bounds what this test can ever cover: the Zen free tier
  # answers 403 to anything that is not the OpenCode client, so a Zen free model
  # cannot be probed from pi at all.
  write_none_override "opencode" "longcat-2.5-preview-free"
  local status
  status="$(probe_status "opencode" "longcat-2.5-preview-free")"
  if [[ "$status" == "403" ]]; then
    pass "the Zen free tier refuses a non-OpenCode client with 403"
  else
    fail "the Zen free tier refuses a non-OpenCode client with 403 (got $status)"
  fi
}

# -------------------------
# Run
# -------------------------

run_test test_the_key_is_present
run_test test_space_bunny_free_rejects_the_disabled_effort
run_test test_longcat_accepts_the_disabled_effort
run_test test_deepseek_accepts_the_disabled_effort
run_test test_the_two_products_disagree_for_the_same_free_model
run_test test_the_zen_free_tier_refuses_non_opencode_clients

test_done
