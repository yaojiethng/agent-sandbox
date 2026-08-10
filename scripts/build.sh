#!/usr/bin/env bash
# scripts/build.sh
# Build orchestration — builds Docker images for agent and sandbox layers.
# Sourced by host scripts (start_agent.sh, run_agent.sh, agent-sandbox.sh).
#
# Sources:
#   build/image.sh   — image naming functions
#
# Provides:
#   build_image    - run docker build using repo root as context
#   build_agent    - three-tier build (shared → provider-base → provider-image)
#   build_sandbox  - build the capability layer image for a given project
#   preflight      - verify both images exist; build if missing

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"

# -------------------------
# Container-sig source lists
# These define which source files map to /opt/sandbox/ and /opt/workflow/
# in each image type. Both build_sandbox/build_agent and _check_container_sig
# use these to compute the container-sig hash — single source of truth.
# -------------------------

# _sandbox_sig_sources
# Source paths for the sandbox image (maps to /opt/sandbox/).
_sandbox_sig_sources() {
  echo "src/libs src/capability/entrypoint.sh src/capability/snapshot.sh docs/architecture docs/concepts"
}

# _agent_sig_sources <repo_root> <provider>
# Source paths for an agent image (maps to /opt/sandbox/ + /opt/workflow/).
# Provider-specific paths (config/, preflight.sh) included when they exist.
_agent_sig_sources() {
  local repo_root="$1"
  local provider="$2"
  local sources="src/libs src/reasoning/entrypoint.sh docs/architecture docs/concepts src/reasoning/agent/skills src/reasoning/agent/prompts"
  if [[ -d "$repo_root/src/reasoning/providers/$provider/config" ]]; then
    sources="$sources src/reasoning/providers/$provider/config"
  fi
  if [[ -f "$repo_root/src/reasoning/providers/$provider/preflight.sh" ]]; then
    sources="$sources src/reasoning/providers/$provider/preflight.sh"
  fi
  echo "$sources"
}

# -------------------------
# Build execution
# -------------------------

# container_sig <repo_root> <sandbox_sources> <workflow_sources>
# Computes a deterministic SHA-256 hash of all files under the given source
# directories. The source paths are repo-relative (e.g. src/libs).
# Returns a hex string suitable for use as a Docker label value.
container_sig() {
  local repo_root="${1:?container_sig requires repo_root}"
  shift 1
  local sources=("$@")
  local find_args=()
  local src
  for src in "${sources[@]}"; do
    find_args+=("$repo_root/$src")
  done
  find "${find_args[@]}" -type f -print0 2>/dev/null \
    | sort -z \
    | xargs -0 sha256sum \
    | sha256sum \
    | awk '{print $1}'
}

# build_image <image_name> <dockerfile> <repo_root> <container_sig> <no_cache> [docker build args...]
# Builds using repo root as docker build context.
# Injects the container-sig label for staleness detection.
build_image() {
  local image_name="${1:?build_image requires image_name}"
  local dockerfile="${2:?build_image requires dockerfile}"
  local repo_root="${3:?build_image requires repo_root}"
  local sig="${4:-}"
  local no_cache="${5:-}"
  shift 5

  echo "Building image: $image_name"
  if [[ -n "$sig" ]]; then
    docker build $no_cache --progress=auto \
      --label "agent-sandbox.container-sig=$sig" \
      -t "$image_name" \
      -f "$dockerfile" \
      "$@" \
      "$repo_root"
  else
    docker build $no_cache --progress=auto \
      -t "$image_name" \
      -f "$dockerfile" \
      "$@" \
      "$repo_root"
  fi
  echo "  Build complete: $image_name"
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
  # Arguments: image dockerfile context_dir [container_sig] [cache_flag] [extra docker build args...]
  build_if_missing() {
    local image="$1" dockerfile="$2" context_dir="$3"
    local sig="${4:-}"
    local cache="${5:-}"
    shift 5
    if ! docker image inspect "$image" >/dev/null 2>&1 || [[ -n "$no_cache" ]]; then
      build_image "$image" "$dockerfile" "$context_dir" "$sig" "$cache" "$@"
    else
      echo "Image exists, skipping: $image"
    fi
  }

  # Tier 1: shared node base — no container-sig (no sandbox/workflow content)
  build_if_missing "$shared_base" "$shared_dockerfile" "$repo_root" "" "$cache_flag" \
    "${uid_args[@]+${uid_args[@]}}"

  # Tier 2: provider-specific base — no container-sig (no sandbox/workflow content)
  build_if_missing "$agent_base_image" "$agent_base_dockerfile" "$repo_root" "" "$cache_flag" \
    --build-arg "BASE_IMAGE=$shared_base" \
    "${uid_args[@]+${uid_args[@]}}"

  # Tier 3: always build provider image — with container-sig
  local provider_sig
  provider_sig="$(container_sig "$repo_root" $(_agent_sig_sources "$repo_root" "$provider"))"

  build_image "$provider_image" "$provider_dockerfile" "$repo_root" "$provider_sig" "" \
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

  local sandbox_sig
  sandbox_sig="$(container_sig "$repo_root" $(_sandbox_sig_sources))"

  local uid_args=()
  if [[ -n "$host_uid" ]]; then
    uid_args+=(--build-arg "HOST_UID=$host_uid")
  fi
  if [[ -n "$host_gid" ]]; then
    uid_args+=(--build-arg "HOST_GID=$host_gid")
  fi

  build_image "$image" "$dockerfile" "$repo_root" "$sandbox_sig" "" "${uid_args[@]+${uid_args[@]}}"
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
    # Staleness check skipped for fresh builds
    return 0
  fi

  # --- Container-sig staleness check (warning only) ---
  # Check sandbox image
  _check_container_sig "$sandbox_image" sandbox "$repo_root"
  # Check agent image
  _check_container_sig "$agent_image" agent "$provider" "$repo_root"
}

# _check_container_sig <image_name> <type: sandbox|agent> <...>
# Reads the baked container-sig label from an existing image, re-computes
# from current source files, and warns on mismatch.
# Type-specific args:
#   sandbox: <repo_root>
#   agent:   <provider> <repo_root>
_check_container_sig() {
  local image_name="${1:?}"
  local type="${2:?}"
  shift 2

  local baked_sig
  baked_sig="$(docker image inspect --format '{{ index .Config.Labels "agent-sandbox.container-sig" }}' "$image_name" 2>/dev/null || true)"

  if [[ -z "$baked_sig" ]]; then
    echo "WARNING: $image_name has no container-sig label (built before two-sig model)." >&2
    return 0
  fi

  local current_sig=""
  if [[ "$type" == "sandbox" ]]; then
    local repo_root="${1:?}"
    current_sig="$(container_sig "$repo_root" $(_sandbox_sig_sources))"
  elif [[ "$type" == "agent" ]]; then
    local provider="${1:?}"
    local repo_root="${2:?}"
    current_sig="$(container_sig "$repo_root" $(_agent_sig_sources "$repo_root" "$provider"))"
  fi

  if [[ "$baked_sig" != "$current_sig" ]]; then
    echo "WARNING: $image_name container-sig mismatch (image is stale)." >&2
    echo "  baked:    $baked_sig" >&2
    echo "  current:  $current_sig" >&2
    echo "  Rebuild with --rebuild to update." >&2
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
  for ARG in "$@"; do
    case "$ARG" in
      --help|-h) usage; exit 0 ;;
    esac
  done

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
        echo "Unknown argument: $ARG" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

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

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
