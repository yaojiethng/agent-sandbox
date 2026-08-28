#!/usr/bin/env bash
# tests/test_checkpoint.sh
# SANDBOX_ID / SESSION_ID identity-derivation contract tests.
#
# The derivation formulas live in src/libs/session_env.sh (sandbox_id_derive,
# session_id_derive) as the single canonical home. start_agent.sh and
# resume_agent.sh both call them. These tests execute the PRODUCTION
# functions directly  --  no copies, no drift guards needed.
#
# History: before extraction, the formula was duplicated inline in both
# scripts and this suite tested a third copy of its own making (a tautology).
# The drift guards from that era are gone because there is nothing left to
# guard against.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/session_env.sh"

test_sandbox_id_returns_8_chars() {
  local out
  out=$(sandbox_id_derive "/some/sandbox" "deadbeef1234")
  if [[ ${#out} -eq 8 ]]; then
    pass "SANDBOX_ID: 8 characters"
  else
    fail "SANDBOX_ID returned ${#out} chars"
  fi
}

test_sandbox_id_is_hex() {
  local out
  out=$(sandbox_id_derive "/some/sandbox" "deadbeef1234")
  if [[ "$out" =~ ^[a-f0-9]{8}$ ]]; then
    pass "SANDBOX_ID: valid lowercase hex"
  else
    fail "SANDBOX_ID not hex: $out"
  fi
}

test_sandbox_id_stable_across_calls() {
  if [[ "$(sandbox_id_derive /d s1)" == "$(sandbox_id_derive /d s1)" ]]; then
    pass "SANDBOX_ID: deterministic for identical inputs"
  else
    fail "SANDBOX_ID not deterministic"
  fi
}

test_sandbox_id_differs_for_different_inputs() {
  if [[ "$(sandbox_id_derive /d s1)" != "$(sandbox_id_derive /d s2)" \
     && "$(sandbox_id_derive /d1 s)" != "$(sandbox_id_derive /d2 s)" ]]
  then
    pass "SANDBOX_ID: sensitive to both sandbox dir and head SHA"
  else
    fail "SANDBOX_ID collides on differing inputs"
  fi
}

test_session_id_is_6_char_hex_and_sandbox_dependent() {
  local sid out
  sid=$(sandbox_id_derive /d s1)
  out=$(session_id_derive "20260821-120000" "$sid")
  if [[ "$out" =~ ^[a-f0-9]{6}$ && "$out" != "$(session_id_derive "20260821-120001" "$sid")" ]]
  then
    pass "SESSION_ID: 6-char hex, sensitive to timestamp and sandbox id"
  else
    fail "SESSION_ID broken: '$out'"
  fi
}

# Both entrypoints must go through the shared helpers  --  no inline re-derivation.
test_no_inline_identity_pipelines_remain() {
  local N
  N=$(grep -c 'SANDBOX_ID=.*sha256sum' "$REPO_ROOT/scripts/start_agent.sh" \
            "$REPO_ROOT/scripts/resume_agent.sh" | awk -F: '{s+=$2} END {print s}')
  if [[ "$N" -eq 0 ]]; then
    pass "no inline sha256sum identity pipelines remain in start/resume scripts"
  else
    fail "inline SANDBOX_ID derivation reappeared ($N occurrences)  --  use sandbox_id_derive"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_sandbox_id_returns_8_chars
run_test test_sandbox_id_is_hex
run_test test_sandbox_id_stable_across_calls
run_test test_sandbox_id_differs_for_different_inputs
run_test test_session_id_is_6_char_hex_and_sandbox_dependent
run_test test_no_inline_identity_pipelines_remain

test_done test_checkpoint.sh
