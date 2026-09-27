#!/usr/bin/env bash
# tests/test_checkpoint.sh
# SESSION_ID identity-derivation contract tests.
#
# The derivation formula lives in src/libs/session_env.sh (session_id_derive)
# using sandbox_dir_canon from src/libs/common.sh. start_agent.sh and
# resume_agent.sh both use these helpers. These tests execute the PRODUCTION
# functions directly  --  no copies, no drift guards needed.
#
# Model: one hash over all identity factors, canonicalized sandbox dir first:
#   SESSION_ID = sha256(canon(SANDBOX_DIR) : HOST_HEAD_SHA : SESSION_TS)[0:6]
# The separate SANDBOX_ID intermediate was removed (see ADR 20260831).

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/common.sh"   # sandbox_dir_canon (canonical home)
source "$REPO_ROOT/src/libs/session_env.sh"

# Given: any sandbox dir, head SHA, and timestamp
# When:  session_id_derive runs
# Then:  the result is 6 characters long
# Asserts: the hash truncation length (bite V11 proven)
test_session_id_returns_6_chars() {
  local out
  out=$(session_id_derive "/tmp/sandbox" "deadbeef1234" "20260831-120000")
  if [[ ${#out} -eq 6 ]]; then
    pass "SESSION_ID: 6 characters"
  else
    fail "SESSION_ID returned ${#out} chars"
  fi
}

# Given: the same three inputs
# When:  session_id_derive runs
# Then:  the result matches ^[a-f0-9]{6}$
# Asserts: lowercase hex output
test_session_id_is_hex() {
  local out
  out=$(session_id_derive "/tmp/sandbox" "deadbeef1234" "20260831-120000")
  assert_matches "$out" '^[a-f0-9]{6}$' "SESSION_ID: valid lowercase hex"
}

# Given: inputs that are identical between calls
# When:  session_id_derive runs twice
# Then:  the two results are equal
# Asserts: determinism for identical inputs
test_session_id_stable_across_calls() {
  if [[ "$(session_id_derive /d s1 20260831-120000)" == "$(session_id_derive /d s1 20260831-120000)" ]]; then
    pass "SESSION_ID: deterministic for identical inputs"
  else
    fail "SESSION_ID not deterministic"
  fi
}

# Given: a baseline input plus three inputs that differ in one factor each
# When:  session_id_derive runs on each
# Then:  all three results differ from the baseline result
# Asserts: every one of the three factors feeds the hash (bite V12 proven)
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
# Given: four spellings of one directory: absolute, symlink, trailing slash, and dot-relative
# When:  session_id_derive runs on each spelling
# Then:  all four ids are equal
# Asserts: the canonicalisation contract (bite V10 proven)
test_session_id_converges_across_path_spellings() {
  local base
  base="$(get_fixture_dir)"
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


  if [[ "$id1" == "$id2" && "$id1" == "$id3" && "$id1" == "$id4" ]]; then
    pass "SESSION_ID: all spellings of one folder converge"
  else
    fail "SESSION_ID did not converge: abs=$id1 link=$id2 slash=$id3 rel=$id4"
  fi
}

# Given: the ADR that removed the separate SANDBOX_ID intermediate
# When:  the shell's function table is inspected
# Then:  sandbox_id_derive is absent and sandbox_dir_canon is present from common.sh
# Asserts: the removal contract, and that session_id_derive's canonicaliser comes from common.sh
test_sandbox_id_functions_removed() {
  if ! declare -f sandbox_id_derive >/dev/null 2>&1; then
    pass "sandbox_id_derive removed"
  else
    fail "sandbox_id_derive still present"
  fi
  if declare -f sandbox_dir_canon >/dev/null 2>&1; then
    pass "sandbox_dir_canon present (from common.sh)"
  else
    fail "sandbox_dir_canon missing"
  fi
}

# Both entrypoints must go through the shared helpers  --  no inline re-derivation.
# Given: the two host entrypoints after the consolidation
# When:  grep counts SESSION_ID sha256sum re-derivations in start_agent.sh and resume_agent.sh
# Then:  the count is 0
# Asserts: the drift guard: neither entrypoint may re-implement the identity formula inline
test_no_inline_identity_pipelines_remain() {
  local N
  N=$(grep -c 'SESSION_ID=.*sha256sum' "$REPO_ROOT/scripts/start_agent.sh" \
            "$REPO_ROOT/scripts/resume_agent.sh" | awk -F: '{s+=$2} END {print s}')
  assert_eq_num "$N" "0" "no inline sha256sum identity pipelines remain in start/resume scripts"
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

