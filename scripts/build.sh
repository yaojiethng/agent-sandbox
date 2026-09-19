#!/usr/bin/env bash
# scripts/build.sh
# Build orchestration  --  builds Docker images for agent and sandbox layers.
# Sourced by host scripts (start_agent.sh, run_agent.sh, agent-sandbox.sh).
#
# Sources:
#   src/build/image.sh   --  image naming + identity (image_digest)
#   libs/interface_contract.sh   --  interface-contract version (authoritative)
#   libs/cli.sh          --  flag parsing
#
# Provides:
#   build_image    - run docker build using repo root as context
#   build_agent    - three-tier build (shared -> provider-base -> provider-image)
#   build_sandbox  - build the capability layer image for a given project
#   preflight      - verify both images exist; build if missing

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/src/libs/interface_contract.sh"
source "$REPO_ROOT/src/libs/cli.sh"


# -------------------------
# Build execution
# -------------------------

# build_image <image_name> <dockerfile> <repo_root> <stamp_contract> <no_cache> [docker build args...]
# Builds using repo root as docker build context.
# Injects the interface-contract-version label for the contract check (ADR
# interface_contract_compatibility.md) on tier-3 images only (stamp_contract
# non-empty); tiers 1/2 shared bases carry no baked harness content and pass
# an empty stamp_contract.
build_image() {
  local image_name="${1:?build_image requires image_name}"
  local dockerfile="${2:?build_image requires dockerfile}"
  local repo_root="${3:?build_image requires repo_root}"
  local stamp_contract="${4:-}"
  local no_cache="${5:-}"
  shift 5

  local build_cmd=(docker build --quiet)
  [[ -n "$no_cache" ]] && build_cmd+=(--no-cache)
  build_cmd+=(-t "$image_name" -f "$dockerfile")
  # Tier-3 images (those with baked harness content) carry the contract
  # version; tiers 1/2 are shared bases with no baked harness content.
  [[ -n "$stamp_contract" ]] && build_cmd+=(--label "agent-sandbox.interface-contract-version=$(interface_contract_version)")
  build_cmd+=("$@" "$repo_root")

  # Run docker build with --quiet: per-step progress output (the cached-step
  # staircase) is suppressed so the harness log stays clean; failures still
  # surface their error text. The exit status is captured so a failure surfaces
  # a single, descriptive message instead of a bare `set -e` abort. `_build_rc`
  # defaults to a non-zero sentinel (fail closed): the `&& ... || ...` capture
  # clears it to 0 on success or the build's real status on failure, so a path
  # that never runs a build still reports failure rather than silently passing.
  local _build_rc=1
  echo "Building image: $image_name"
  "${build_cmd[@]}" && _build_rc=0 || _build_rc=$?
  [[ $_build_rc -eq 0 ]] && echo "  Build complete: $image_name"

  if [[ $_build_rc -ne 0 ]]; then
    echo "build_image: ERROR build FAILED for $image_name (exit $_build_rc)." >&2
    exit 1
  fi
}

# build_agent <provider> <project_name> <repo_root> [--no-cache] [--uid UID] [--gid GID]
# Three-tier build:
#   1. agent-node-base (shared  --  node.dockerfile)
#   2. <provider>-base (provider-specific  --  providers/<n>/base.dockerfile)
#   3. <provider>-agent-<project> (final  --  providers/<n>/provider.dockerfile)
#
# Tier 1 cached across all providers on this machine.
# Tier 2 cached per-provider.
# Tier 3 rebuilt on every build_agent call (picks up project-specific content).
#
# --no-cache: rebuild tiers 1 and 2 from scratch.
# --uid/--gid: thread host UID/GID into Dockerfiles for UID mapping.
build_agent() {
  local provider="${1:?build_agent requires provider}"
  local project="${2:?build_agent requires project name}"
  local repo_root="${3:?build_agent requires repo root}"
  local no_cache="${4:-}"
  local host_uid="${5:-}"
  local host_gid="${6:-}"

  local cache_flag=""
  if [[ -n "$no_cache" ]]; then
    cache_flag="--no-cache"
  fi

  # Build args for UID mapping
  local uid_args=()
  if [[ -n "$host_uid" ]]; then
    uid_args+=(--build-arg "HOST_UID=$host_uid")
  fi
  if [[ -n "$host_gid" ]]; then
    uid_args+=(--build-arg "HOST_GID=$host_gid")
  fi

  # Tier 1: shared node base
  local shared_base; shared_base="$(shared_base_image_name)"
  local shared_dockerfile="$repo_root/src/reasoning/node.dockerfile"

  # Tier 2: provider-specific base
  local agent_base_image; agent_base_image="$(agent_base_image_name "$provider")"
  local agent_base_dockerfile="$repo_root/src/reasoning/providers/$provider/base.dockerfile"

  # Tier 3: final provider image
  local provider_image; provider_image="$(agent_image_name "$provider" "$project")"
  local provider_dockerfile="$repo_root/src/reasoning/providers/$provider/provider.dockerfile"

  # Validate files exist
  if [[ ! -f "$shared_dockerfile" ]]; then
    echo "build_agent: ERROR: shared base Dockerfile not found: $shared_dockerfile" >&2
    exit 1
  fi
  if [[ ! -f "$agent_base_dockerfile" ]]; then
    echo "build_agent: ERROR: provider base Dockerfile not found: $agent_base_dockerfile" >&2
    exit 1
  fi
  if [[ ! -f "$provider_dockerfile" ]]; then
    echo "build_agent: ERROR: provider Dockerfile not found: $provider_dockerfile" >&2
    exit 1
  fi

  # --- Helper: build image only if missing (or --no-cache forces rebuild) ---
  # Arguments: image dockerfile context_dir [stamp_contract] [cache_flag] [extra docker build args...]
  build_if_missing() {
    local image="$1" dockerfile="$2" context_dir="$3"
    local stamp_contract="${4:-}"
    local cache="${5:-}"
    shift 5
    if ! docker image inspect "$image" >/dev/null 2>&1 || [[ -n "$no_cache" ]]; then
      build_image "$image" "$dockerfile" "$context_dir" "$stamp_contract" "$cache" "$@"
    else
      echo "Image exists, skipping: $image"
    fi
  }

  # Tier 1: shared node base  --  no contract label (no sandbox/workflow content)
  build_if_missing "$shared_base" "$shared_dockerfile" "$repo_root" "" "$cache_flag" \
    "${uid_args[@]+${uid_args[@]}}"

  # Tier 2: provider-specific base  --  no contract label (no sandbox/workflow content)
  build_if_missing "$agent_base_image" "$agent_base_dockerfile" "$repo_root" "" "$cache_flag" \
    --build-arg "BASE_IMAGE=$shared_base" \
    "${uid_args[@]+${uid_args[@]}}"

  # Tier 3: always build provider image  --  carries the contract label
  build_image "$provider_image" "$provider_dockerfile" "$repo_root" "1" "" \
    --build-arg "BASE_IMAGE=$agent_base_image" \
    "${uid_args[@]+${uid_args[@]}}"
}

# build_sandbox <project_name> <repo_root> [--uid UID] [--gid GID]
# Builds the capability layer image (sandbox-<project>).
build_sandbox() {
  local project="${1:?build_sandbox requires project name}"
  local repo_root="${2:?build_sandbox requires repo root}"
  local host_uid="${3:-}"
  local host_gid="${4:-}"

  local dockerfile="$repo_root/src/capability/dockerfile"
  if [[ ! -f "$dockerfile" ]]; then
    echo "build_sandbox: ERROR: Dockerfile not found: $dockerfile" >&2
    exit 1
  fi

  local image; image="$(sandbox_image_name "$project")"

  local uid_args=()
  if [[ -n "$host_uid" ]]; then
    uid_args+=(--build-arg "HOST_UID=$host_uid")
  fi
  if [[ -n "$host_gid" ]]; then
    uid_args+=(--build-arg "HOST_GID=$host_gid")
  fi

  build_image "$image" "$dockerfile" "$repo_root" "1" "" "${uid_args[@]+${uid_args[@]}}"
}

# -------------------------
# Preflight
# -------------------------

# preflight <provider> <project_name> <repo_root>
# Checks that both images exist. Build before running rather than failing.
preflight() {
  local provider="${1:?preflight requires provider}"
  local project="${2:?preflight requires project name}"
  local repo_root="${3:?preflight requires repo root}"
  local build_missing="${4:-true}"  # resume passes false  --  a resume must not rebuild

  local sandbox_image; sandbox_image=$(sandbox_image_name "$project")
  local agent_image;   agent_image=$(agent_image_name "$provider" "$project")
  local missing=false

  if ! docker image inspect "$sandbox_image" >/dev/null 2>&1; then
    echo "Image not found: $sandbox_image"
    missing=true
  fi
  if ! docker image inspect "$agent_image" >/dev/null 2>&1; then
    echo "Image not found: $agent_image"
    missing=true
  fi

  if [[ "$missing" == true ]]; then
    if [[ "$build_missing" == "true" ]]; then
      echo "One or more required images are missing. Building them now."
      build_sandbox "$project" "$repo_root"
      build_agent   "$provider" "$project" "$repo_root"
      # Staleness check skipped for fresh builds
      return 0
    else
      echo "Error: required images are missing and resume does not build." >&2
      echo "  Run 'make start' (or 'make build') to build them first." >&2
      return 1
    fi
  fi

  # --- Interface-contract version check (authoritative) ---
  # ADR interface_contract_compatibility.md. The contract is authoritative:
  # a drift or missing label refuses preflight (non-zero) so start fails
  # closed. No runtime escape hatch -- an override would be a backdoor.
  _check_interface_contract "$sandbox_image" || return 1
  _check_interface_contract "$agent_image"   || return 1
}

# _check_interface_contract <image_name>
# Interface-contract check (ADR interface_contract_compatibility.md): refuses
# (returns 1) when the image's baked `agent-sandbox.interface-contract-version`
# label differs from the current host-side constant -- the container was built
# from a different contract revision than the working tree -- and names the
# surface and the rebuild remedy. Missing label (built before the check)
# refuses identically. Returns 0 only when aligned.
_check_interface_contract() {
  local image_name="${1:?}"

  local baked current
  baked="$(image_contract_version "$image_name")"
  if [[ -z "$baked" ]]; then
    echo "ERROR: $image_name has no interface-contract-version label (built before the interface-contract check)." >&2
    echo "  The image predates the interface contract; rebuild with --rebuild." >&2
    return 1
  fi
  current="$(interface_contract_version)"
  if [[ "$baked" != "$current" ]]; then
    echo "ERROR: $image_name interface-contract version $baked differs from current source ($current)." >&2
    echo "  Rebuild with --rebuild to align the container with the current contract." >&2
    return 1
  fi
}

# =============================================================================
# main  --  entry point when exec'd by agent-sandbox build
# =============================================================================

# Parses operator-facing flags and calls build_sandbox/build_agent as needed.
# Expected flags: --name=<n> --project=<p> --sandbox=<s> [--targets=<t,...>] [--rebuild]
#
# --targets defaults to "all" if omitted. Use comma-separated values:
#   all                --  sandbox + all providers
#   sandbox            --  sandbox only
#   pi,hermes          --  named providers only
#   pi,sandbox         --  named provider + sandbox

usage() {
  cat <<EOF
Usage: agent-sandbox build --name=<name> --project=<path> --sandbox=<path> [options]

Builds Docker images for the sandbox and/or agent providers.

Required:
  --name=<name>       Project name (used for image tags)
  --project=<path>    Path to the project directory
  --sandbox=<path>    Path to the sandbox directory

Options:
  --targets=<list>    Comma-separated targets: all, sandbox, <provider>[,<provider>] (default: all)
  --rebuild           Force a full rebuild from scratch
EOF
}

main() {
  parse_args usage \
    --name=PROJECT_NAME \
    --project=PROJECT_DIR \
    --sandbox=SANDBOX_DIR \
    --targets=BUILD_TARGETS \
    --rebuild \
    -- "$@"
  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1
  local REBUILD_FLAG=""
  [[ "$REBUILD" == true ]] && REBUILD_FLAG="--no-cache"

  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    usage >&2
    exit 1
  fi

  local _build_self
  _build_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local REPO_ROOT
  REPO_ROOT="$(cd "$_build_self/.." && pwd)"

  if [[ -z "$BUILD_TARGETS" || "$BUILD_TARGETS" == "all" ]]; then
    build_sandbox "$PROJECT_NAME" "$REPO_ROOT"
    for BASE_DOCKERFILE in "$REPO_ROOT/src/reasoning/providers/"*/base.dockerfile; do
      [[ -f "$BASE_DOCKERFILE" ]] || continue
      local DISCOVERED_PROVIDER
      DISCOVERED_PROVIDER="$(basename "$(dirname "$BASE_DOCKERFILE")")"
      build_agent "$DISCOVERED_PROVIDER" "$PROJECT_NAME" "$REPO_ROOT" $REBUILD_FLAG
    done
  else
    IFS=',' read -ra TARGET_LIST <<< "$BUILD_TARGETS"
    local WANT_SANDBOX=false
    local -a PROVIDER_TARGETS=()
    for T in "${TARGET_LIST[@]}"; do
      if [[ "$T" == "sandbox" ]]; then
        WANT_SANDBOX=true
      else
        PROVIDER_TARGETS+=("$T")
      fi
    done
    if [[ "$WANT_SANDBOX" == true ]]; then
      build_sandbox "$PROJECT_NAME" "$REPO_ROOT"
    fi
    for P in "${PROVIDER_TARGETS[@]}"; do
      build_agent "$P" "$PROJECT_NAME" "$REPO_ROOT" $REBUILD_FLAG
    done
  fi
}

# Guard: only run main() when executed directly, not when sourced.
# Also enforce the production runtime on standalone invocation: production
# callers set `set -euo pipefail` before sourcing this file, but a standalone
# `bash build.sh` (e.g. the trace tests) inherits the caller's options. Enabling
# `-e` here makes standalone runs exercise the same failure-abort semantics as
# production, so a silent `set -e` abort after a backgrounded/piped build is
# caught.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  main "$@"
fi
