#!/usr/bin/env bash
# tests/test_checkpoint.sh
# SESSION_ID identity-derivation contract tests.
#
# The derivation formula lives in src/libs/session_env.sh (session_id_derive,
# sandbox_dir_canon) as the single canonical home. start_agent.sh and
# resume_agent.sh both use these helpers. These tests execute the PRODUCTION
# functions directly  --  no copies, no drift guards needed.
#
# Model: one hash over all identity factors, canonicalized sandbox dir first:
#   SESSION_ID = sha256(canon(SANDBOX_DIR) : HOST_HEAD_SHA : SESSION_TS)[0:6]
# The separate SANDBOX_ID intermediate was removed (see ADR 20260831).

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/session_env.sh"

test_session_id_returns_6_chars() {
  local out
  out=$(session_id_derive "/tmp/sandbox" "deadbeef1234" "20260831-120000")
  if [[ ${#out} -eq 6 ]]; then
    pass "SESSION_ID: 6 characters"
  else
    fail "SESSION_ID returned ${#out} chars"
  fi
}

test_session_id_is_hex() {
  local out
  out=$(session_id_derive "/tmp/sandbox" "deadbeef1234" "20260831-120000")
  if [[ "$out" =~ ^[a-f0-9]{6}$ ]]; then
    pass "SESSION_ID: valid lowercase hex"
  else
    fail "SESSION_ID not hex: $out"
  fi
}

test_session_id_stable_across_calls() {
  if [[ "$(session_id_derive /d s1 20260831-120000)" == "$(session_id_derive /d s1 20260831-120000)" ]]; then
    pass "SESSION_ID: deterministic for identical inputs"
  else
    fail "SESSION_ID not deterministic"
  fi
}

test_session_id_sensitive_to_all_factors() {
  if [[ "$(session_id_derive /d s1 20260831-120000)" != "$(session_id_derive /d2 s1 20260831-120000)" \
     && "$(session_id_derive /d s1 20260831-120000)" != "$(session_id_derive /d s2 20260831-120000)" \
     && "$(session_id_derive /d s1 20260831-120000)" != "$(session_id_derive /d s1 20260831-120001)" ]]
  then
    pass "SESSION_ID: sensitive to sandbox dir, head SHA, and timestamp"
  else
    fail "SESSION_ID collides on differing inputs"
  fi
}

# Multiple spellings of one folder must converge to one SESSION_ID (the
# canonicalization contract -- see ADR 20260831).
test_session_id_converges_across_path_spellings() {
  local base
  base="$(mktemp -d)"
  mkdir -p "$base/sub"
  ln -sfn "$base/sub" "$base/link"

  local abs sub_link trailing rel
  abs="$base/sub"
  sub_link="$base/link"
  trailing="$base/sub/"
  rel="$base/./sub"

  local id1 id2 id3 id4
  id1=$(session_id_derive "$abs"        "deadbeef" "20260831-120000")
  id2=$(session_id_derive "$sub_link"   "deadbeef" "20260831-120000")
  id3=$(session_id_derive "$trailing"   "deadbeef" "20260831-120000")
  id4=$(session_id_derive "$rel"        "deadbeef" "20260831-120000")

  rm -rf "$base"

  if [[ "$id1" == "$id2" && "$id1" == "$id3" && "$id1" == "$id4" ]]; then
    pass "SESSION_ID: all spellings of one folder converge"
  else
    fail "SESSION_ID did not converge: abs=$id1 link=$id2 slash=$id3 rel=$id4"
  fi
}

test_sandbox_id_functions_removed() {
  if ! declare -f sandbox_id_derive >/dev/null 2>&1; then
    pass "sandbox_id_derive removed"
  else
    fail "sandbox_id_derive still present"
  fi
  if declare -f sandbox_dir_canon >/dev/null 2>&1; then
    pass "sandbox_dir_canon present"
  else
    fail "sandbox_dir_canon missing"
  fi
}

# Both entrypoints must go through the shared helpers  --  no inline re-derivation.
test_no_inline_identity_pipelines_remain() {
  local N
  N=$(grep -c 'SESSION_ID=.*sha256sum' "$REPO_ROOT/scripts/start_agent.sh" \
            "$REPO_ROOT/scripts/resume_agent.sh" | awk -F: '{s+=$2} END {print s}')
  if [[ "$N" -eq 0 ]]; then
    pass "no inline sha256sum identity pipelines remain in start/resume scripts"
  else
    fail "inline SESSION_ID derivation reappeared ($N occurrences)  --  use session_id_derive"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_session_id_returns_6_chars
run_test test_session_id_is_hex
run_test test_session_id_stable_across_calls
run_test test_session_id_sensitive_to_all_factors
run_test test_session_id_converges_across_path_spellings
run_test test_sandbox_id_functions_removed
run_test test_no_inline_identity_pipelines_remain

test_done test_checkpoint.sh