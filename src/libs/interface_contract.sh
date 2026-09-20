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
#
# Mismatch policy (ADR interface_contract_compatibility.md rollover): the
# contract is authoritative -- a drift or missing label refuses preflight, and
# the agent entrypoint hard-stops on a container<->container mismatch. There is
# no runtime escape hatch: an override would be a backdoor that weakens the
# contract. The interim container-sig check retired in P3.
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

# image_contract_version IMAGE_NAME
#   Reads the version baked into an image's `agent-sandbox.interface-contract-version`
#   label at build time. Empty when the image is missing or was built before
#   the label existed.
image_contract_version() {
  local image_name="${1:?image_contract_version requires an image name}"
  docker image inspect --format '{{index .Config.Labels "agent-sandbox.interface-contract-version"}}' "$image_name" 2>/dev/null
}