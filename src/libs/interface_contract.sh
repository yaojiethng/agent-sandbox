#!/usr/bin/env bash
# src/libs/interface_contract.sh
# Interface-contract version (ADR interface_contract_compatibility.md).
# The single declaration of the contract version every co-resident copy is
# compared against: host source, baked image labels, and session records.
# Cross-context -- deployed to host and container (baked /opt/sandbox/lib).
#
# Provides:
#   interface_contract_version          --  the current contract version
#   image_contract_version IMAGE_NAME   --  the version baked into an image
#   record_contract_version STATE_FILE  --  the version stamped in a record
#   interface_contract_strict          --  the mismatch-policy flag (ADR rollover)
#
# Mismatch policy (ADR interface_contract_compatibility.md rollover): the
# warn/strict decision is one flag, reversible by hand. This lib is
# cross-context (host + container), so the flag travels with the code that
# enforces it. Default warn (false); the operator flips it authoritative in a
# scheduled follow-up iteration after live proof under the strict regime.
#
# Bump rule: increment INTERFACE_CONTRACT_VERSION below exactly when a
# cross-boundary contract changes (wiring shape, mount/bind shape, SANDBOX_DIR
# format, onboard command shape, host/container command semantics,
# session-record schema, docker labels the container consumes). Doc edits,
# tests, and internal refactors never bump it.

# interface_contract_version
#   Prints the current interface-contract version.
interface_contract_version() {
  echo "1"
}

# interface_contract_strict
#   Prints 1 when the mismatch policy is fail-closed (drift refuses preflight,
#   and the agent entrypoint hard-stops on a container<->container mismatch),
#   0 when it is warn-only (parallel phase). One reversible flag: override at
#   runtime with INTERFACE_CONTRACT_STRICT=0/1, or edit the default below.
interface_contract_strict() {
  if [[ "${INTERFACE_CONTRACT_STRICT:-0}" == "1" ]]; then
    echo 1
  else
    echo 0
  fi
}

# image_contract_version IMAGE_NAME
#   Reads the version baked into an image's `agent-sandbox.interface-contract-version`
#   label at build time. Empty when the image is missing or was built before
#   the label existed.
image_contract_version() {
  local image_name="${1:?image_contract_version requires an image name}"
  docker image inspect --format '{{index .Config.Labels "agent-sandbox.interface-contract-version"}}' "$image_name" 2>/dev/null
}

# record_contract_version STATE_FILE
#   Reads the version stamped into a SESSION_STATE record (key
#   `interface_contract_version=`, one per line). Empty when the key is
#   missing. The record is host-readable -- no docker involved.
record_contract_version() {
  local state_file="${1:?record_contract_version requires a state file}"
  local k v
  while IFS='=' read -r k v; do
    if [[ "$k" == "interface_contract_version" ]]; then
      echo "$v"
      return 0
    fi
  done < "$state_file"
}