#!/usr/bin/env bash
# tests/test_reasoner_container_contract.sh
# Unit tests for the agent (reasoning) entrypoint's container<->container
# interface-contract check `_check_container_contract` (ADR
# interface_contract_compatibility.md, P2).
#
# The check compares the agent image's baked interface-contract version against
# the sandbox's recorded version (SESSION_STATE.interface_contract_version,
# written by the sandbox at init from its own bake). The contract is
# authoritative: a definite mismatch hard-stops the agent (orchestration
# error), a missing record key or file warns (upgrade path), and a missing
# lib skips silently. There is no runtime policy flag.
#
# Run:   bash tests/test_reasoner_container_contract.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

ENTRYPOINT="$REPO_ROOT/src/reasoning/entrypoint.sh"

# Extract the function under test from the LIVE entrypoint source. Source the
# whole entrypoint is impossible (its top-level code ends in `exit`); inline
# copies test dead text. The prerequisite check fails with one named error if
# the function moves. Matches the _provision_agent_home extraction pattern.
CONTRACT_SRC="$(sed -n '/^_check_container_contract()/,/^}/p' "$ENTRYPOINT")"
if [[ -z "$CONTRACT_SRC" ]]; then
  echo "FATAL: prerequisite missing: _check_container_contract() not extractable from $ENTRYPOINT" >&2
  echo "       Update tests/test_reasoner_container_contract.sh if the function moved or was renamed." >&2
  exit 1
fi
eval "$CONTRACT_SRC"

# The agent lib seam points at the repo's real interface_contract.sh, so the
# agent-baked constant matches the current source. Source it here so the test
# bodies can read interface_contract_version() directly; the function under
# test re-sources it via the CONTRACT_LIB seam for the container path.
source "$REPO_ROOT/src/libs/interface_contract.sh"
LIB_UNDER_TEST="$REPO_ROOT/src/libs/interface_contract.sh"

# _run_check ...  --  run _check_container_contract against a fixture sandbox
# record; returns its exit code.
#   $1  state_file  --  the SESSION_STATE fixture (host-readable)
_run_check() {
  local state_file="$1"; shift
  # Production: SANDBOX_ROOT + SANDBOX_DIR_NAME=sandbox -> the sandbox dir that
  # holds .git/SESSION_STATE. For a fixture state_file at
  # <ROOT>/sandbox/.git/SESSION_STATE, ROOT is the fixture parent three levels up.
  local sandbox_root
  sandbox_root="$(dirname "$(dirname "$(dirname "$state_file")")")"
  CONTRACT_LIB="$LIB_UNDER_TEST" \
  SANDBOX_ROOT="$sandbox_root" \
  _check_container_contract "$@" < /dev/null
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_agent_baked_equals_sandbox_recorded_silent() {
  local state="$FIXTURE_DIR/sandbox/.git/SESSION_STATE"
  mkdir -p "$(dirname "$state")"
  printf 'init_sha=abc\ninterface_contract_version=%s\n' "$(interface_contract_version)" > "$state"
  local out rc=0
  out="$(_run_check "$state" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "aligned: agent bake == sandbox record passes"
  assert_empty "$out" "aligned: container to container check stays silent"
}

test_definite_mismatch_hard_stops() {
  local state="$FIXTURE_DIR/sandbox/.git/SESSION_STATE"
  mkdir -p "$(dirname "$state")"
  printf 'interface_contract_version=9\n' > "$state"
  local out rc=0
  out="$(_run_check "$state" 2>&1)" || rc=$?
  assert_ne "$rc" "0" "container contract mismatch hard-stops (non-zero exit)"
  assert_contains "$out" "FATAL: container contract mismatch" \
      "hard stop is marked the fatal orchestration signal"
  assert_contains "$out" "different contract revisions" \
      "hard stop names the orchestration cause"
}

test_missing_record_key_warns_not_aborts() {
  local state="$FIXTURE_DIR/keyless/sandbox/.git/SESSION_STATE"
  mkdir -p "$(dirname "$state")"
  printf 'init_sha=abc\nsession_ts=2026\n' > "$state"  # no interface_contract_version key
  local out rc=0
  out="$(_run_check "$state" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "missing record key warns, does not hard-stop (upgrade path)"
  assert_contains "$out" "predates the interface-contract check" \
      "missing record key names the pre-record image cause"
}

test_missing_record_file_warns_not_aborts() {
  # Distinct from a missing key: no SESSION_STATE at all. Under the entrypoint's
  # `set -euo pipefail`, the unguarded while-read would abort the shell; the
  # file guard must prevent that and warn instead. Uses its own fixture dir so
  # an earlier test's record file does not satisfy the check.
  local state="$FIXTURE_DIR/norec/sandbox/.git/SESSION_STATE"
  local out rc=0
  out="$(_run_check "$state" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "missing record file warns, does not hard-stop"
  assert_contains "$out" "no SESSION_STATE" \
      "missing record file names the missing record"
}

test_missing_lib_skips_silently() {
  local state="$FIXTURE_DIR/sandbox/.git/SESSION_STATE"
  mkdir -p "$(dirname "$state")"
  printf 'interface_contract_version=1\n' > "$state"
  local out rc=0
  out="$(CONTRACT_LIB="$FIXTURE_DIR/nonexistent.sh" \
        SANDBOX_ROOT="$(dirname "$(dirname "$(dirname "$state")")")" \
        _check_container_contract < /dev/null 2>&1)" || rc=$?
  assert_eq "$rc" "0" "missing lib: check skips silently"
  assert_empty "$out" "missing lib: no diagnostic emitted"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

run_test test_agent_baked_equals_sandbox_recorded_silent
run_test test_definite_mismatch_hard_stops
run_test test_missing_record_key_warns_not_aborts
run_test test_missing_record_file_warns_not_aborts
run_test test_missing_lib_skips_silently