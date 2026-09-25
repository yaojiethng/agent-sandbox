#!/usr/bin/env bash
# tests/test_reasoner_container_contract.sh
# Unit tests for `container_contract_check` -- the container<->container
# interface-contract check the reasoning entrypoint calls (ADR
# interface_contract_compatibility.md, P2).
#
# The check compares the agent image's baked interface-contract version against
# the sandbox's recorded version (SESSION_STATE.interface_contract_version,
# written by the sandbox at init from its own bake). The contract is
# authoritative: a definite mismatch returns 1 (orchestration error); a missing
# record key or file returns 0 with a warning (upgrade path). There is no
# runtime policy flag.
#
# The function under test lives in src/libs/session_state.sh, so the test
# sources the library directly -- no entrypoint extraction, no test seam.
#
# Run:   bash tests/test_reasoner_container_contract.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

source "$REPO_ROOT/src/libs/session_state.sh"

# _run_check SANDBOX_DIR  --  run the check against a fixture sandbox directory
# (the directory that holds .git/SESSION_STATE); leaves the exit code in $?.
_run_check() {
  container_contract_check "$1"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# Given: a record holding this image's interface_contract_version
# When:  container_contract_check runs
# Then:  it returns 0 and prints nothing
# Asserts: an aligned container pair passes silently.
test_agent_baked_equals_sandbox_recorded_silent() {
  local sandbox="$FIXTURE_DIR/sandbox"
  mkdir -p "$sandbox/.git"
  printf 'init_sha=abc\ninterface_contract_version=%s\n' "$(interface_contract_version)" > "$sandbox/.git/SESSION_STATE"
  local out rc=0
  out="$(_run_check "$sandbox" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "aligned: agent bake == sandbox record passes"
  assert_empty "$out" "aligned: container to container check stays silent"
}

# Given: a record holding a different version
# When:  container_contract_check runs
# Then:  it returns non-zero and prints the FATAL mismatch with the orchestration cause
# Asserts: a definite mismatch is a hard stop.
test_definite_mismatch_hard_stops() {
  local sandbox="$FIXTURE_DIR/sandbox"
  mkdir -p "$sandbox/.git"
  printf 'interface_contract_version=9\n' > "$sandbox/.git/SESSION_STATE"
  local out rc=0
  out="$(_run_check "$sandbox" 2>&1)" || rc=$?
  assert_ne "$rc" "0" "container contract mismatch returns non-zero"
  assert_contains "$out" "FATAL: container contract mismatch" \
      "mismatch is marked the fatal orchestration signal"
  assert_contains "$out" "different contract revisions" \
      "mismatch names the orchestration cause"
}

# Given: a record without the interface_contract_version key
# When:  container_contract_check runs
# Then:  it returns 0 and warns that the image predates the check
# Asserts: the upgrade path proceeds instead of aborting.
test_missing_record_key_warns_not_aborts() {
  local sandbox="$FIXTURE_DIR/keyless/sandbox"
  mkdir -p "$sandbox/.git"
  printf 'init_sha=abc\nsession_ts=2026\n' > "$sandbox/.git/SESSION_STATE"  # no interface_contract_version key
  local out rc=0
  out="$(_run_check "$sandbox" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "missing record key warns, does not fail (upgrade path)"
  assert_contains "$out" "predates the interface-contract check" \
      "missing record key names the pre-record image cause"
}

# Given: no SESSION_STATE at all
# When:  container_contract_check runs
# Then:  it returns 0 and warns that no record exists
# Asserts: the file guard warns rather than failing a redirection under set -e.
test_missing_record_file_warns_not_aborts() {
  # Distinct from a missing key: no SESSION_STATE at all. The file guard must
  # prevent a redirection failure under `set -e` and warn instead.
  local sandbox="$FIXTURE_DIR/norec/sandbox"
  mkdir -p "$sandbox/.git"
  local out rc=0
  out="$(_run_check "$sandbox" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "missing record file warns, does not fail"
  assert_contains "$out" "no SESSION_STATE" \
      "missing record file names the missing record"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

run_test test_agent_baked_equals_sandbox_recorded_silent
run_test test_definite_mismatch_hard_stops
run_test test_missing_record_key_warns_not_aborts
run_test test_missing_record_file_warns_not_aborts

test_done
