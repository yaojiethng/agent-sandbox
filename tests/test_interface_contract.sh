#!/usr/bin/env bash
# tests/test_interface_contract.sh
# Unit tests for src/libs/interface_contract.sh (interface-contract version,
# ADR interface_contract_compatibility.md) and build.sh's warn-only preflight
# check `_check_interface_contract` (P0, parallel with container-sig).
#
# Covers:
#   interface_contract_version          --  positive integer constant
#   image_contract_version              --  baked label read via docker (stubbed)
#   record_contract_version             --  SESSION_STATE stamp read (no docker)
#   _check_interface_contract           --  drifted label warns, aligned silent,
#                                        missing label warns (built before check)

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"
source "$REPO_ROOT/src/libs/interface_contract.sh"
source "$REPO_ROOT/scripts/build.sh"

# =============================================================================
# interface_contract_version
# =============================================================================

test_interface_contract_version_is_positive_integer() {
  local v
  v="$(interface_contract_version)"
  if [[ "$v" =~ ^[0-9]+$ ]] && (( v > 0 )); then
    pass "interface_contract_version is a positive integer"
  else
    fail "interface_contract_version is not a positive integer (got '$v')"
  fi
}

# =============================================================================
# image_contract_version  (docker label read, stubbed)
# =============================================================================

test_image_contract_version_reads_baked_label() {
  local got
  got="$(PATH="$STUB_DIR:$PATH" DOCKER_STUB_IMAGE_CONTRACT_VERSION="7" \
        image_contract_version "test-image" </dev/null)"
  assert_eq "$got" "7" "image_contract_version reads the baked label via docker"
}

test_image_contract_version_per_image_map() {
  local got
  got="$(PATH="$STUB_DIR:$PATH" \
        DOCKER_STUB_IMAGE_CONTRACT_VERSIONS="a:1 b:2" \
        image_contract_version "b" </dev/null)"
  assert_eq "$got" "2" "image_contract_version honors the per-image map"
}

test_image_contract_version_empty_for_unlabeled_image() {
  local got
  got="$(PATH="$STUB_DIR:$PATH" \
        image_contract_version "unlabeled-image" </dev/null)"
  assert_empty "$got" "image_contract_version is empty when the label is absent"
}

# =============================================================================
# record_contract_version  (SESSION_STATE stamp, host-readable, no docker)
# =============================================================================

test_record_contract_version_reads_stamp() {
  local state="$FIXTURE_DIR/SESSION_STATE"
  mkdir -p "$(dirname "$state")"
  printf 'init_sha=abc\ninterface_contract_version=3\nsession_ts=2026\n' > "$state"
  assert_eq "$(record_contract_version "$state")" "3" \
      "record_contract_version reads the stamped key"
}

test_record_contract_version_empty_when_key_missing() {
  local state="$FIXTURE_DIR/SESSION_STATE2"
  mkdir -p "$(dirname "$state")"
  printf 'init_sha=abc\n' > "$state"
  assert_empty "$(record_contract_version "$state")" \
      "record_contract_version is empty when the key is absent"
}

# =============================================================================
# _check_interface_contract  (warn-only; container-sig untouched)
# =============================================================================

test_check_interface_contract_warns_on_drifted_label() {
  local out
  out="$(PATH="$STUB_DIR:$PATH" DOCKER_STUB_IMAGE_CONTRACT_VERSION="2" \
        _check_interface_contract "test-image" 2>&1)"
  assert_contains "$out" "interface-contract version 2 differs from current source" \
      "preflight: drifted contract version warns"
}

test_check_interface_contract_silent_on_aligned() {
  local current
  current="$(interface_contract_version)"
  local out
  out="$(PATH="$STUB_DIR:$PATH" DOCKER_STUB_IMAGE_CONTRACT_VERSION="$current" \
        _check_interface_contract "test-image" 2>&1)"
  assert_empty "$out" "preflight: aligned contract version stays silent"
}

test_check_interface_contract_warns_on_missing_label() {
  local out
  out="$(PATH="$STUB_DIR:$PATH" \
        _check_interface_contract "pre-label-image" 2>&1)"
  assert_contains "$out" "has no interface-contract-version label" \
      "preflight: missing label warns (built before the check)"
}

# =============================================================================
# interface_contract_strict  (mismatch-policy flag, ADR rollover)
# =============================================================================

test_interface_contract_strict_defaults_to_warn() {
  assert_eq "$(interface_contract_strict)" "0" \
      "interface_contract_strict defaults to warn (parallel phase)"
}

test_interface_contract_strict_env_override_1() {
  assert_eq "$(INTERFACE_CONTRACT_STRICT=1 interface_contract_strict)" "1" \
      "interface_contract_strict honors INTERFACE_CONTRACT_STRICT=1"
}

test_interface_contract_strict_env_override_0() {
  assert_eq "$(INTERFACE_CONTRACT_STRICT=0 interface_contract_strict)" "0" \
      "interface_contract_strict honors INTERFACE_CONTRACT_STRICT=0"
}

# =============================================================================
# _check_interface_contract  (strict policy refuses preflight)
# =============================================================================

test_check_interface_contract_strict_refuses_drift() {
  local rc=0 out
  out="$(PATH="$STUB_DIR:$PATH" INTERFACE_CONTRACT_STRICT=1 \
        DOCKER_STUB_IMAGE_CONTRACT_VERSION="9" \
        _check_interface_contract "test-image" 2>&1)" || rc=$?
  assert_eq "$rc" "1" "strict policy: drifted label refuses preflight"
  assert_contains "$out" "ERROR" "strict policy: refusal is marked an error"
  assert_contains "$out" "version 9 differs from current source" \
      "strict policy: refusal names the drifted surface"
}

test_check_interface_contract_strict_refuses_missing_label() {
  local rc=0 out
  out="$(PATH="$STUB_DIR:$PATH" INTERFACE_CONTRACT_STRICT=1 \
        _check_interface_contract "pre-label-image" 2>&1)" || rc=$?
  assert_eq "$rc" "1" "strict policy: missing label refuses preflight"
  assert_contains "$out" "predates the interface contract" \
      "strict policy: missing-label refusal names the rebuild remedy"
}

test_check_interface_contract_strict_silent_on_aligned() {
  local current out rc=0
  current="$(interface_contract_version)"
  out="$(PATH="$STUB_DIR:$PATH" INTERFACE_CONTRACT_STRICT=1 \
        DOCKER_STUB_IMAGE_CONTRACT_VERSION="$current" \
        _check_interface_contract "test-image" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "strict policy: aligned label passes preflight"
  assert_empty "$out" "strict policy: aligned label stays silent"
}

# =============================================================================
# Runner
# =============================================================================

run_test test_interface_contract_version_is_positive_integer
run_test test_image_contract_version_reads_baked_label
run_test test_image_contract_version_per_image_map
run_test test_image_contract_version_empty_for_unlabeled_image
run_test test_record_contract_version_reads_stamp
run_test test_record_contract_version_empty_when_key_missing
run_test test_check_interface_contract_warns_on_drifted_label
run_test test_check_interface_contract_silent_on_aligned
run_test test_check_interface_contract_warns_on_missing_label
run_test test_interface_contract_strict_defaults_to_warn
run_test test_interface_contract_strict_env_override_1
run_test test_interface_contract_strict_env_override_0
run_test test_check_interface_contract_strict_refuses_drift
run_test test_check_interface_contract_strict_refuses_missing_label
run_test test_check_interface_contract_strict_silent_on_aligned