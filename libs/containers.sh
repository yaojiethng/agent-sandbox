#!/usr/bin/env bash
# libs/containers.sh
# Shared container lifecycle library for agent-sandbox.
#
# Provides:
#   agent_image_name   — compute reasoning layer image name from provider + project
#   sandbox_image_name — compute capability layer image name from project
#   build_agent        — build the reasoning layer image for a given provider + project
#   build_sandbox      — build the capability layer image for a given project
#   build_all          — build both images
#   preflight          — verify both images exist; error with instructions if not

# -------------------------
# Naming conventions
# -------------------------

# agent_image_name <provider> <project_name>
# Returns: <provider>-agent-<project> (lowercased)
agent_image_name() {
  local PROVIDER="${1:?agent_image_name requires provider}"
  local PROJECT="${2:?agent_image_name requires project name}"
  echo "${PROVIDER}-agent-${PROJECT,,}"
}

# sandbox_image_name <project_name>
# Returns: sandbox-<project> (lowercased)
sandbox_image_name() {
  local PROJECT="${1:?sandbox_image_name requires project name}"
  echo "sandbox-${PROJECT,,}"
}

# Container names match image names — one session per project at a time.
# container_name: is set in the compose template to enforce this.

# agent_container_name <provider> <project_name>
agent_container_name() { agent_image_name "$1" "$2"; }

# sandbox_container_name <project_name>
sandbox_container_name() { sandbox_image_name "$1"; }

# sandbox_container_name <project_name>
# Returns: <project>-sandbox (lowercased) — matches container_name in compose template
sandbox_container_name() {
  local PROJECT="${1:?sandbox_container_name requires project name}"
  echo "${PROJECT,,}-sandbox"
}

# agent_container_name <provider> <project_name>
# Returns: <project>-agent (lowercased) — matches container_name in compose template
agent_container_name() {
  local PROJECT="${2:?agent_container_name requires project name}"
  echo "${PROJECT,,}-agent"
}

# -------------------------
# Build helpers
# -------------------------

# build_agent <provider> <project_name> <repo_root> [--no-cache]
build_agent() {
  local PROVIDER="${1:?build_agent requires provider}"
  local PROJECT="${2:?build_agent requires project name}"
  local REPO_ROOT="${3:?build_agent requires repo root}"
  local NO_CACHE="${4:-}"

  local BUILD_SCRIPT="$REPO_ROOT/providers/$PROVIDER/build.sh"
  if [[ ! -f "$BUILD_SCRIPT" ]]; then
    echo "Error: build script not found for provider '$PROVIDER': $BUILD_SCRIPT"
    exit 1
  fi

  "$BUILD_SCRIPT" --name="$PROJECT" ${NO_CACHE:+--no-cache}
}

# build_sandbox <project_name> <sandbox_dir> <repo_root> [--no-cache]
build_sandbox() {
  local PROJECT="${1:?build_sandbox requires project name}"
  local SANDBOX_DIR="${2:?build_sandbox requires sandbox dir}"
  local REPO_ROOT="${3:?build_sandbox requires repo root}"
  local NO_CACHE="${4:-}"

  local BUILD_SCRIPT="$REPO_ROOT/scripts/build_sandbox.sh"
  if [[ ! -f "$BUILD_SCRIPT" ]]; then
    echo "Error: build_sandbox.sh not found: $BUILD_SCRIPT"
    exit 1
  fi

  "$BUILD_SCRIPT" --name="$PROJECT" --sandbox="$SANDBOX_DIR" ${NO_CACHE:+--no-cache}
}

# build_all <provider> <project_name> <sandbox_dir> <repo_root> [--no-cache]
build_all() {
  local PROVIDER="$1"
  local PROJECT="$2"
  local SANDBOX_DIR="$3"
  local REPO_ROOT="$4"
  local NO_CACHE="${5:-}"

  build_sandbox "$PROJECT" "$SANDBOX_DIR" "$REPO_ROOT" "$NO_CACHE"
  build_agent   "$PROVIDER" "$PROJECT" "$REPO_ROOT" "$NO_CACHE"
}

# -------------------------
# Preflight
# -------------------------

# preflight <provider> <project_name> <repo_root>
# Checks that both images exist. Errors with build instructions if not.
preflight() {
  local PROVIDER="${1:?preflight requires provider}"
  local PROJECT="${2:?preflight requires project name}"
  local REPO_ROOT="${3:?preflight requires repo root}"

  local SANDBOX_IMAGE; SANDBOX_IMAGE=$(sandbox_image_name "$PROJECT")
  local AGENT_IMAGE;   AGENT_IMAGE=$(agent_image_name "$PROVIDER" "$PROJECT")
  local MISSING=false

  if ! docker image inspect "$SANDBOX_IMAGE" >/dev/null 2>&1; then
    echo "Image not found: $SANDBOX_IMAGE"
    MISSING=true
  fi
  if ! docker image inspect "$AGENT_IMAGE" >/dev/null 2>&1; then
    echo "Image not found: $AGENT_IMAGE"
    MISSING=true
  fi

  if [[ "$MISSING" == true ]]; then
    echo "One or more required images are missing. Build them with:"
    echo "  agent-sandbox build all --name=$PROJECT --sandbox=<path>"
    exit 1
  fi
}
