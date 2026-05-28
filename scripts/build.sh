#!/usr/bin/env bash
# scripts/build.sh
# Build orchestration — builds Docker images for agent and sandbox layers.
# Sourced by host scripts (start_agent.sh, run_agent.sh, agent-sandbox.sh).
#
# Sources:
#   build/image.sh   — image naming functions
#   build/context.sh — build context preparation
#
# Provides:
#   build_image    - compute digest and run docker build
#   build_agent    - three-tier build (shared → provider-base → provider-image)
#   build_sandbox  - build the capability layer image for a given project
#   preflight      - verify both images exist; build if missing

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/src/build/context.sh"

# -------------------------
# Build execution
# -------------------------

# Track temp build contexts for trap cleanup
_BUILD_CONTEXT_DIRS=()

# cleanup_build_context
# Removes any tracked temp build context directories on exit.
# Called via EXIT trap set by build_agent and build_sandbox.
cleanup_build_context() {
  local rc=$?
  local dir
  for dir in "${_BUILD_CONTEXT_DIRS[@]}"; do
    [[ -d "$dir" ]] && rm -rf "$dir"
  done
  exit $rc
}

# build_image <image_name> <dockerfile> <context_dir> <no_cache> [docker build args...]
# Computes a digest of the context and runs docker build.
build_image() {
  local image_name="${1:?build_image requires image_name}"
  local dockerfile="${2:?build_image requires dockerfile}"
  local context_dir="${3:?build_image requires context_dir}"
  local no_cache="${4:-}"
  shift 4

  local digest
  digest=$(context_digest "$context_dir")

  echo "Building image: $image_name"
  docker build $no_cache \
    --label "agent-sandbox.digest=$digest" \
    -t "$image_name" \
    -f "$dockerfile" \
    "$@" \
    "$context_dir"
  echo "Build complete: $image_name"
}

# build_agent <provider> <project_name> <repo_root> [--no-cache] [--uid UID] [--gid GID]
# Three-tier build:
#   1. agent-node-base (shared — node.dockerfile)
#   2. <provider>-base (provider-specific — providers/<n>/base.dockerfile)
#   3. <provider>-agent-<project> (final — providers/<n>/provider.dockerfile)
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

  # Tier 1: shared node base — doesn't need the provider build context
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

  # Build context for tiers 2 and 3 (tier 1 uses repo root as context)
  local context
  context="$(build_context_agent "$repo_root" "$provider")"
  _BUILD_CONTEXT_DIRS+=("$context")

  # --- Helper: build image only if missing (or --no-cache forces rebuild) ---
  # Named function in bash is always global, but defining it here keeps
  # the code colocated with its usage. Defined fresh on each build_agent call.
  # shellcheck disable=SC2119
  build_if_missing() {
    local image="$1" dockerfile="$2" context_dir="$3"
    shift 3
    if ! docker image inspect "$image" >/dev/null 2>&1 || [[ -n "$no_cache" ]]; then
      build_image "$image" "$dockerfile" "$context_dir" "$cache_flag" "$@"
    else
      echo "Image exists, skipping: $image"
    fi
  }

  # Trap to clean up temp build context on exit
  trap cleanup_build_context EXIT

  # Tier 1: shared node base
  build_if_missing "$shared_base" "$shared_dockerfile" "$repo_root" \
    "${uid_args[@]+${uid_args[@]}}"

  # Tier 2: provider-specific base
  build_if_missing "$agent_base_image" "$agent_base_dockerfile" "$context" \
    --build-arg "BASE_IMAGE=$shared_base" \
    "${uid_args[@]+${uid_args[@]}}"

  # Tier 3: always build provider image
  build_image "$provider_image" "$provider_dockerfile" "$context" "" \
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
  local context
  context="$(build_context_sandbox "$repo_root")"
  _BUILD_CONTEXT_DIRS+=("$context")

  trap cleanup_build_context EXIT

  local uid_args=()
  if [[ -n "$host_uid" ]]; then
    uid_args+=(--build-arg "HOST_UID=$host_uid")
  fi
  if [[ -n "$host_gid" ]]; then
    uid_args+=(--build-arg "HOST_GID=$host_gid")
  fi

  build_image "$image" "$dockerfile" "$context" "" "${uid_args[@]+${uid_args[@]}}"
}

# -------------------------
# Preflight
# -------------------------

# preflight <provider> <project_name> <repo_root> <sandbox_dir>
# Checks that both images exist. Build before running rather than failing.
preflight() {
  local provider="${1:?preflight requires provider}"
  local project="${2:?preflight requires project name}"
  local repo_root="${3:?preflight requires repo root}"
  local sandbox_dir="${4:?preflight requires sandbox dir}"

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
    echo "One or more required images are missing. Building them now."
    build_sandbox "$project" "$repo_root"
    build_agent   "$provider" "$project" "$repo_root"
  fi
}

# =============================================================================
# main — entry point when exec'd by agent-sandbox build
# =============================================================================

# Parses operator-facing flags and calls build_sandbox/build_agent as needed.
# Expected flags: --name=<n> --project=<p> --sandbox=<s> [--targets=<t,...>] [--rebuild]
#
# --targets defaults to "all" if omitted. Use comma-separated values:
#   all               — sandbox + all providers
#   sandbox           — sandbox only
#   pi,hermes         — named providers only
#   pi,sandbox        — named provider + sandbox
main() {
  local PROJECT_NAME=""
  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local BUILD_TARGETS=""
  local REBUILD_FLAG=""

  for ARG in "$@"; do
    case "$ARG" in
      --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
      --project=*) PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --targets=*) BUILD_TARGETS="${ARG#--targets=}" ;;
      --rebuild)   REBUILD_FLAG="--no-cache" ;;
      *)
        echo "Error: unknown flag: $ARG" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --name, --project, and --sandbox are required" >&2
    echo "  Usage: agent-sandbox build --name=<project> --project=<path> --sandbox=<path> [--targets=<t>] [--rebuild]" >&2
    exit 1
  fi

  # Resolve repo root from our own path (scripts/build.sh → repo root)
  local _build_self
  _build_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local REPO_ROOT
  REPO_ROOT="$(cd "$_build_self/.." && pwd)"
  AGENT_SANDBOX_REPO="$REPO_ROOT"

  # Source our dependencies (image naming, build context)
  source "$REPO_ROOT/src/build/image.sh"
  source "$REPO_ROOT/src/build/context.sh"

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

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
