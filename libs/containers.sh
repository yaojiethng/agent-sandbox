#!/usr/bin/env bash
# libs/containers.sh
# Shared container lifecycle library for agent-sandbox.
#
# Provides:
#   agent_base_image_name  - compute reasoning layer base image name from provider
#   agent_image_name       - compute reasoning layer image name from provider + project
#   sandbox_image_name     - compute capability layer image name from project
#   build_context_sandbox  - populate a temp dir with sandbox build context files
#   build_context_agent    - populate a temp dir with agent build context files
#   build_image            - compute digest and run docker build
#   build_agent            - build the reasoning layer images for a given provider + project
#   build_sandbox          - build the capability layer image for a given project
#   preflight              - verify both images exist; error with instructions if not

# -------------------------
# Naming conventions
# -------------------------

# agent_base_image_name <provider>
# Returns: <provider>-base (lowercased)
# Base images contain stable install layers and are not project-specific.
agent_base_image_name() {
  local provider="${1:?agent_base_image_name requires provider}"
  echo "$(echo "$provider" | tr '[:upper:]' '[:lower:]')-base"
}

# agent_image_name <provider> <project_name>
# Returns: <provider>-agent-<project> (lowercased)
agent_image_name() {
  local provider="${1:?agent_image_name requires provider}"
  local project="${2:?agent_image_name requires project name}"
  echo "${provider}-agent-$(echo "$project" | tr '[:upper:]' '[:lower:]')"
}

# sandbox_image_name <project_name>
# Returns: sandbox-<project> (lowercased)
sandbox_image_name() {
  local project="${1:?sandbox_image_name requires project name}"
  echo "sandbox-$(echo "$project" | tr '[:upper:]' '[:lower:]')"
}

# -------------------------
# Build context
# -------------------------

# _build_context_copy <src> <dst>
# Copies a single file into the build context. Hard error if src is missing.
_build_context_copy() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "$src" ]]; then
    echo "build_context: missing required file: $src" >&2
    return 1
  fi

  cp "$src" "$dst"
}

# build_context_sandbox <repo_root>
# Creates and populates a temp dir with files required for a sandbox image build.
# Prints the temp dir path to stdout. Caller is responsible for cleanup.
build_context_sandbox() {
  local repo_root="${1:?build_context_sandbox requires repo_root}"
  local context_dir=""
  context_dir=$(mktemp -d)
  trap '[[ -n "$context_dir" ]] && rm -rf "$context_dir"' ERR

  _build_context_copy "$repo_root/libs/sandbox-entrypoint.sh"     "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/dirs.sh"                    "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/snapshot.sh"                "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/diff.sh"                    "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/session.sh"                 "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/routing.sh"                 "$context_dir/" || return 1

  # docs/
  mkdir -p "$context_dir/docs" || return 1
  cp -r "$repo_root/docs/architecture" "$context_dir/docs/architecture" || return 1
  cp -r "$repo_root/docs/concepts"     "$context_dir/docs/concepts"     || return 1

  echo "$context_dir"
}

# build_context_agent <repo_root> <provider>
# Creates and populates a temp dir with files required for an agent image build.
# Injects harness-owned files (dirs.sh, provider-entrypoint.sh).
# Provider config is not baked into the image - it is populated at onboard time
# into $SANDBOX_DIR/.<provider>/ and bind-mounted at runtime.
# Prints the temp dir path to stdout. Caller is responsible for cleanup.
build_context_agent() {
  local repo_root="${1:?build_context_agent requires repo_root}"
  local provider="${2:?build_context_agent requires provider}"
  local context_dir=""
  context_dir=$(mktemp -d)
  trap '[[ -n "$context_dir" ]] && rm -rf "$context_dir"' ERR

  # Harness-owned files - required for all providers.
  _build_context_copy "$repo_root/libs/dirs.sh"                    "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/provider-entrypoint.sh"     "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/package_diff.sh"            "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/package_branch.sh"          "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/session.sh"                 "$context_dir/" || return 1
  _build_context_copy "$repo_root/libs/routing.sh"                 "$context_dir/" || return 1
  # docs/
  mkdir -p "$context_dir/docs" || return 1
  cp -r "$repo_root/docs/architecture" "$context_dir/docs/architecture" || return 1
  cp -r "$repo_root/docs/concepts"     "$context_dir/docs/concepts"     || return 1

  # agent workflow files/ — prompts and skills the agent uses at runtime
  mkdir -p "$context_dir/agent" || return 1
  cp -r "$repo_root/agent/skills"  "$context_dir/agent/skills"  || return 1
  cp -r "$repo_root/agent/prompts" "$context_dir/agent/prompts" || return 1

  echo "$context_dir"
}

# -------------------------
# Build helpers
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
#
# Default behaviour: base image is skipped if it already exists; provider image is always rebuilt.
# --no-cache-base: forces a full rebuild of both base and provider with --no-cache.
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

  local dockerfile="$repo_root/libs/sandbox.Dockerfile"
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
# Equivalent to the operator running: make build TARGET=<provider>,sandbox
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