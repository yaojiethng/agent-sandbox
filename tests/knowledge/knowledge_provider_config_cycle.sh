#!/usr/bin/env bash
# tests/knowledge/knowledge_provider_config_cycle.sh
#
# Knowledge test: provider config copy-in/copy-out cycle and pi settings persistence.
#
# Documents the behavioural assumptions about:
#   a) The copy-in mechanism (PROVIDER_CONFIG_DIR -> AGENT_HOME)
#   b) The copy-out mechanism (AGENT_HOME -> PROVIDER_CONFIG_DIR)
#   c) Whether pi preserves unknown/extension keys in settings.json across its
#      own save cycle
#
# Background:
#   The provider-entrypoint.sh performs copy-in at session start and copy-out
#   at session exit. The settings.json in the provider config includes custom
#   keys (skills, prompts) that reference image-baked paths at /opt/workflow/.
#   If pi rewrites settings.json at runtime without preserving these custom keys,
#   the next session loses its ability to find the image-baked skills/prompts.
#
# Reference:
#   - providers/pi/config/agent/settings.json (onboard source — has custom keys)
#   - libs/provider-entrypoint.sh (copy-in / copy-out mechanism)
#   - docs/architecture/provider_lifecycle.md ("Config Flow and Fragility Notes")
#   - docs/concepts/agent_workflow.md ("Skills and Prompts Layer Model")
#   - docs/operations/testing_policy.md (knowledge test format)
#
# Not run by make test. Run manually:
#   bash tests/knowledge/knowledge_provider_config_cycle.sh

set -uo pipefail

PASS=0
FAIL=0
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# Create a mock provider config directory with the settings that the onboard
# source provides (including custom skills/prompts keys).
make_provider_config() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir/agent"

  cat > "$dir/agent/settings.json" << 'JSON'
{
  "lastChangelogVersion": "0.67.6",
  "defaultProvider": "deepseek",
  "defaultModel": "deepseek/deepseek-v4-flash",
  "defaultThinkingLevel": "minimal",
  "followUpMode": "all",
  "enablePromptCommands": true,
  "skills": ["/opt/workflow/agent/skills"],
  "prompts": ["/opt/workflow/agent/prompts"],
  "compaction": {
    "enabled": true,
    "reserveTokens": 32768,
    "keepRecentTokens": 20000
  }
}
JSON

  # Seed a provider-layer prompt (like providers/pi/config/agent/prompts/)
  mkdir -p "$dir/agent/prompts"
  echo "---" > "$dir/agent/prompts/pi-agent.md"
  echo "description: Mock pi-agent prompt" >> "$dir/agent/prompts/pi-agent.md"
  echo "---" >> "$dir/agent/prompts/pi-agent.md"
}

# Simulate copy-in: PROVIDER_CONFIG_DIR/ -> AGENT_HOME/
simulate_copy_in() {
  local src="$1"
  local dest="$2"
  if [[ -d "$src" ]] && [[ -n "$(ls -A "$src" 2>/dev/null)" ]]; then
    mkdir -p "$dest"
    cp -r "$src/." "$dest/"
  fi
}

# Simulate copy-out: AGENT_HOME/ -> PROVIDER_CONFIG_DIR/
simulate_copy_out() {
  local src="$1"
  local dest="$2"
  if [[ -d "$src" ]] && [[ -n "$(ls -A "$src" 2>/dev/null)" ]]; then
    mkdir -p "$dest"
    cp -r "$src/." "$dest/"
  fi
}

# ---------------------------------------------------------------------------
# Test 1: Copy-in preserves all settings keys
# ---------------------------------------------------------------------------

test_copy_in_preserves_keys() {
  local prov="$FIXTURE_DIR/t1_prov"
  local agent="$FIXTURE_DIR/t1_agent"

  make_provider_config "$prov"
  simulate_copy_in "$prov" "$agent"

  if [[ ! -f "$agent/agent/settings.json" ]]; then
    fail "settings.json not found after copy-in"
    return
  fi

  if grep -q '"skills"' "$agent/agent/settings.json"; then
    pass "copy-in preserves 'skills' key in settings.json"
  else
    fail "copy-in LOST 'skills' key in settings.json"
  fi

  if grep -q '"prompts"' "$agent/agent/settings.json"; then
    pass "copy-in preserves 'prompts' key in settings.json"
  else
    fail "copy-in LOST 'prompts' key in settings.json"
  fi

  if [[ -f "$agent/agent/prompts/pi-agent.md" ]]; then
    pass "copy-in preserves provider prompt files"
  else
    fail "copy-in LOST provider prompt files"
  fi
}

# ---------------------------------------------------------------------------
# Test 2: Copy-out preserves whatever AGENT_HOME has at exit (lossless)
# ---------------------------------------------------------------------------

test_copy_out_is_lossless() {
  local agent="$FIXTURE_DIR/t2_agent"
  local prov="$FIXTURE_DIR/t2_prov"

  rm -rf "$agent" "$prov"
  mkdir -p "$agent/agent"
  cat > "$agent/agent/settings.json" << 'JSON'
{
  "lastChangelogVersion": "0.70.6",
  "defaultThinkingLevel": "off",
  "defaultProvider": "deepseek",
  "defaultModel": "deepseek-v4-flash",
  "skills": ["/opt/workflow/agent/skills"],
  "prompts": ["/opt/workflow/agent/prompts"],
  "compaction": { "enabled": true, "reserveTokens": 32768 }
}
JSON

  simulate_copy_out "$agent" "$prov"

  if [[ ! -f "$prov/agent/settings.json" ]]; then
    fail "settings.json not found after copy-out"
    return
  fi

  if diff -q "$agent/agent/settings.json" "$prov/agent/settings.json" &>/dev/null; then
    pass "copy-out is byte-identical (lossless)"
  else
    echo "    Diff between source and copy-out target:"
    diff "$agent/agent/settings.json" "$prov/agent/settings.json" | sed 's/^/    /'
    fail "copy-out is not byte-identical"
  fi
}

# ---------------------------------------------------------------------------
# Test 3: Round-trip preserves custom keys when pi preserves them
# ---------------------------------------------------------------------------

test_round_trip_preserves_keys() {
  local prov="$FIXTURE_DIR/t3_prov"
  local agent="$FIXTURE_DIR/t3_agent"
  local prov2="$FIXTURE_DIR/t3_prov2"

  make_provider_config "$prov"
  simulate_copy_in "$prov" "$agent"

  # Simulate pi writing settings back (preserves skills/prompts via jq pass-through)
  if command -v jq &>/dev/null; then
    jq '. | {
      lastChangelogVersion, defaultProvider, defaultModel, defaultThinkingLevel,
      followUpMode, enablePromptCommands, skills, prompts, compaction, enabledModels, hideThinkingBlock
    }' "$agent/agent/settings.json" > "$agent/agent/settings.json.tmp" && \
    mv "$agent/agent/settings.json.tmp" "$agent/agent/settings.json"
  else
    # Without jq, round-trip is a no-op on content (just copy)
    cp "$agent/agent/settings.json" "$agent/agent/settings.json.tmp" && \
    mv "$agent/agent/settings.json.tmp" "$agent/agent/settings.json"
  fi

  simulate_copy_out "$agent" "$prov2"

  if [[ ! -f "$prov2/agent/settings.json" ]]; then
    fail "Round-trip: settings.json not found in final destination"
    return
  fi

  local has_skills has_prompts
  has_skills=$(grep -c '"skills"' "$prov2/agent/settings.json")
  has_prompts=$(grep -c '"prompts"' "$prov2/agent/settings.json")

  [[ "$has_skills" -gt 0 ]] && pass "Round-trip: 'skills' key survives" || fail "Round-trip: 'skills' key was LOST"
  [[ "$has_prompts" -gt 0 ]] && pass "Round-trip: 'prompts' key survives" || fail "Round-trip: 'prompts' key was LOST"
}

# ---------------------------------------------------------------------------
# Test 4: Inspect REAL system config state for the Pi provider
# ---------------------------------------------------------------------------

test_real_config_state() {
  local onboard_source="/home/agentuser/sandbox/providers/pi/config/agent/settings.json"
  local bind_mount="/opt/provider-config/agent/settings.json"
  local agent_home="$HOME/.pi/agent/settings.json"

  echo ""
  echo "    --- Real system inspection (Pi provider) ---"

  for label in "Onboard source ($onboard_source)" "Bind mount ($bind_mount)" "AGENT_HOME ($agent_home)"; do
    local path="${label#* }"
    path="${path#(}"
    path="${path%)}"
    if [[ -f "$path" ]]; then
      local size skills prompts
      size=$(wc -c < "$path")
      grep -q '"skills"' "$path" && skills="PRESENT ✓" || skills="MISSING ✗"
      grep -q '"prompts"' "$path" && prompts="PRESENT ✓" || prompts="MISSING ✗"
      echo "    ${label%% (*)}: ${size} bytes, skills=${skills}, prompts=${prompts}"
    else
      echo "    ${label%% (*)}: NOT FOUND"
    fi
  done

  echo ""

  # Key diagnostic
  if [[ -f "$onboard_source" ]] && [[ -f "$bind_mount" ]]; then
    if grep -q '"skills"' "$onboard_source" && ! grep -q '"skills"' "$bind_mount"; then
      echo "    >>> DIAGNOSIS: Onboard source has skills but bind-mount does not."
      echo "    >>> Copy-out cycle corrupted the bind-mount. Re-seed from onboard source."
    elif grep -q '"skills"' "$onboard_source" && grep -q '"skills"' "$bind_mount"; then
      echo "    >>> All locations consistent. Skills/prompts should load correctly."
    fi
  fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== Knowledge Test: Provider Config Copy-In/Copy-Out Cycle ==="
echo ""

echo "[ Copy-in preserves settings keys ]"
test_copy_in_preserves_keys

echo ""
echo "[ Copy-out is lossless ]"
test_copy_out_is_lossless

echo ""
echo "[ Round-trip preserves custom keys ]"
test_round_trip_preserves_keys

echo ""
echo "[ Real system config state ]"
test_real_config_state

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
