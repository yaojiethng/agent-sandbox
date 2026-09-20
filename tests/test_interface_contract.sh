#!/usr/bin/env bash
# tests/test_interface_contract.sh
# Unit tests for src/libs/interface_contract.sh (interface-contract version,
# ADR interface_contract_compatibility.md) and build.sh's authoritative
# preflight check `_check_interface_contract`.
#
# Covers:
#   interface_contract_version          --  positive integer constant
#   image_contract_version              --  baked label read via docker (stubbed)
#   _check_interface_contract           --  refuses drift and a missing label,
#                                        silent when aligned (authoritative)

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
# _check_interface_contract  (authoritative)
# =============================================================================

test_check_interface_contract_silent_on_aligned() {
  local current out rc=0
  current="$(interface_contract_version)"
  out="$(PATH="$STUB_DIR:$PATH" DOCKER_STUB_IMAGE_CONTRACT_VERSION="$current" \
        _check_interface_contract "test-image" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "preflight: aligned contract version passes"
  assert_empty "$out" "preflight: aligned contract version stays silent"
}

test_check_interface_contract_refuses_drift() {
  local rc=0 out
  out="$(PATH="$STUB_DIR:$PATH" DOCKER_STUB_IMAGE_CONTRACT_VERSION="2" \
        _check_interface_contract "test-image" 2>&1)" || rc=$?
  assert_eq "$rc" "1" "preflight: drifted contract version refuses"
  assert_contains "$out" "ERROR" "preflight: refusal is marked an error"
  assert_contains "$out" "interface-contract version 2 differs from current source" \
      "preflight: refusal names the drifted surface"
}

test_check_interface_contract_refuses_missing_label() {
  local rc=0 out
  out="$(PATH="$STUB_DIR:$PATH" \
        _check_interface_contract "pre-label-image" 2>&1)" || rc=$?
  assert_eq "$rc" "1" "preflight: missing label refuses"
  assert_contains "$out" "has no interface-contract-version label" \
      "preflight: missing-label refusal names the cause"
  assert_contains "$out" "predates the interface contract" \
      "preflight: missing-label refusal names the rebuild remedy"
}

# =============================================================================
# Runner
# =============================================================================

run_test test_interface_contract_version_is_positive_integer
run_test test_image_contract_version_reads_baked_label
run_test test_image_contract_version_per_image_map
run_test test_image_contract_version_empty_for_unlabeled_image
run_test test_check_interface_contract_silent_on_aligned
run_test test_check_interface_contract_refuses_drift
run_test test_check_interface_contract_refuses_missing_label