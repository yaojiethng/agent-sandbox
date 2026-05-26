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
#   build_agent    - build the reasoning layer images for a given provider + project
#   build_sandbox  - build the capability layer image for a given project
#   preflight      - verify both images exist; build if missing

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/src/build/context.sh"

# -------------------------
# Build execution
# -------------------------

# build_image <image_name> <dockerfile> <context_dir> <no_cache> [docker build args...]
# Computes a digest of the context and runs docker build.
build_image() {
  local image_name="${1:?build_image requires image_name}"
  local dockerfile="${2:?build_image requires dockerfile}"
  local context_dir="${3:?build_image requires context_dir}"
  local no_cache="${4:-}"
  shift 4

  local digest
  digest=$(find "$context_dir" -type f | sort | xargs sha256sum | sha256sum | awk '{print $1}')

  echo "Building image: $image_name"
  docker build $no_cache \
    --label "agent-sandbox.digest=$digest" \
    -t "$image_name" \
    -f "$dockerfile" \
    "$@" \
    "$context_dir"
  echo "Build complete: $image_name"
}

# build_agent <provider> <project_name> <repo_root> [--no-cache-base]
# Builds the reasoning layer provider image (<provider>-agent-<project>),
# and the base image (<provider>-base) if it does not exist or --no-cache-base is set.
build_agent() {
  local provider="${1:?build_agent requires provider}"
  local project="${2:?build_agent requires project name}"
  local repo_root="${3:?build_agent requires repo root}"
  local no_cache_base="${4:-}"
  local no_cache=""

  if [[ -n "$no_cache_base" ]]; then
    no_cache="--no-cache"
  fi

  local base_image; base_image="$(agent_base_image_name "$provider")"
  local base_dockerfile="$repo_root/providers/$provider/base.Dockerfile"
  local provider_image; provider_image="$(agent_image_name "$provider" "$project")"
  local provider_dockerfile="$repo_root/providers/$provider/provider.Dockerfile"

  if [[ ! -f "$base_dockerfile" ]]; then
    echo "Error: base Dockerfile not found: $base_dockerfile" >&2
    exit 1
  fi
  if [[ ! -f "$provider_dockerfile" ]]; then
    echo "Error: provider Dockerfile not found: $provider_dockerfile" >&2
    exit 1
  fi

  local context
  context="$(build_context_agent "$repo_root" "$provider")"
  local context_cleanup="$context"
  # shellcheck disable=SC2064
  trap "rm -rf '$context_cleanup'" EXIT

  # Build base image if missing or --no-cache-base
  if ! docker image inspect "$base_image" >/dev/null 2>&1 || [[ -n "$no_cache" ]]; then
    build_image "$base_image" "$base_dockerfile" "$context" "$no_cache"
  else
    echo "Base image exists, skipping: $base_image"
  fi

  # Always build provider image
  build_image "$provider_image" "$provider_dockerfile" "$context" "" \
    --build-arg "BASE_IMAGE=$base_image"
}

# build_sandbox <project_name> <repo_root>
# Builds the capability layer image (sandbox-<project>).
build_sandbox() {
  local project="${1:?build_sandbox requires project name}"
  local repo_root="${2:?build_sandbox requires repo root}"

  local dockerfile="$repo_root/src/capability/Dockerfile"
  if [[ ! -f "$dockerfile" ]]; then
    echo "Error: sandbox Dockerfile not found: $dockerfile" >&2
    exit 1
  fi

  local image; image="$(sandbox_image_name "$project")"
  local context
  context="$(build_context_sandbox "$repo_root")"
  local context_cleanup="$context"
  # shellcheck disable=SC2064
  trap "rm -rf '$context_cleanup'" EXIT

  build_image "$image" "$dockerfile" "$context" ""
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
