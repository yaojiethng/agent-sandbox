#!/usr/bin/env bash
# scripts/build_container.sh
# Usage:
#   build_container.sh --type=sandbox --name=<project> --sandbox=<path> [--rebuild-base]
#   build_container.sh --type=agent   --name=<project> --provider=<n>   [--rebuild-base]
#
# Builds Docker images for agent-sandbox.
#
# sandbox: builds the capability layer image (sandbox-<project>)
# agent:   builds the reasoning layer provider image (<provider>-agent-<project>),
#          and the base image (<provider>-base) if it does not exist or --rebuild-base is set.
#
# Default behaviour: base image is skipped if it already exists; provider image is always rebuilt.
# --rebuild-base:    forces a full rebuild of both base and provider with --no-cache.
#
# All naming conventions are derived from libs/containers.sh.
# All build context population is delegated to libs/containers.sh.
# No provider names or image names are hardcoded here.

set -euo pipefail

# -------------------------
# Paths
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/libs/containers.sh"

# -------------------------
# Flag parsing
# -------------------------
local_type=""
local_name=""
local_provider=""
local_sandbox=""
local_rebuild_base=""

for arg in "$@"; do
  case "$arg" in
    --type=*)        local_type="${arg#--type=}" ;;
    --name=*)        local_name="${arg#--name=}" ;;
    --provider=*)    local_provider="${arg#--provider=}" ;;
    --sandbox=*)     local_sandbox="${arg#--sandbox=}" ;;
    --rebuild-base)  local_rebuild_base="--no-cache" ;;
    *)
      echo "Unknown flag: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$local_type" ]]; then
  echo "Error: --type is required (sandbox or agent)" >&2
  exit 1
fi

if [[ -z "$local_name" ]]; then
  echo "Error: --name is required" >&2
  exit 1
fi

# -------------------------
# Sandbox build
# -------------------------
if [[ "$local_type" == "sandbox" ]]; then
  if [[ -z "$local_sandbox" ]]; then
    echo "Error: --sandbox is required for --type=sandbox" >&2
    exit 1
  fi

  local_dockerfile="$REPO_ROOT/libs/sandbox.Dockerfile"
  if [[ ! -f "$local_dockerfile" ]]; then
    echo "Error: sandbox Dockerfile not found: $local_dockerfile" >&2
    exit 1
  fi

  local_image="$(sandbox_image_name "$local_name")"
  local_context="$(build_context_sandbox "$REPO_ROOT")"
  trap 'rm -rf "$local_context"' EXIT

  build_image "$local_image" "$local_dockerfile" "$local_context" ""
  exit 0
fi

# -------------------------
# Agent build
# -------------------------
if [[ "$local_type" == "agent" ]]; then
  if [[ -z "$local_provider" ]]; then
    echo "Error: --provider is required for --type=agent" >&2
    exit 1
  fi

  local_base_image="$(agent_base_image_name "$local_provider")"
  local_base_dockerfile="$REPO_ROOT/providers/$local_provider/base.Dockerfile"
  local_provider_image="$(agent_image_name "$local_provider" "$local_name")"
  local_provider_dockerfile="$REPO_ROOT/providers/$local_provider/provider.Dockerfile"

  if [[ ! -f "$local_base_dockerfile" ]]; then
    echo "Error: base Dockerfile not found: $local_base_dockerfile" >&2
    exit 1
  fi

  if [[ ! -f "$local_provider_dockerfile" ]]; then
    echo "Error: provider Dockerfile not found: $local_provider_dockerfile" >&2
    exit 1
  fi

  local_context="$(build_context_agent "$REPO_ROOT")"
  trap 'rm -rf "$local_context"' EXIT

  # Build base image if missing or --rebuild-base
  if ! docker image inspect "$local_base_image" >/dev/null 2>&1 || [[ -n "$local_rebuild_base" ]]; then
    build_image "$local_base_image" "$local_base_dockerfile" "$local_context" "$local_rebuild_base"
  else
    echo "Base image exists, skipping: $local_base_image"
  fi

  # Always build provider image
  build_image "$local_provider_image" "$local_provider_dockerfile" "$local_context" "" \
    --build-arg "BASE_IMAGE=$local_base_image"
  exit 0
fi

echo "Error: unknown --type '$local_type' (expected: sandbox or agent)" >&2
exit 1
