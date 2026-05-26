#!/usr/bin/env bash
# build/image.sh
# Container image naming and identity functions.
# Sourced by build/context.sh and scripts/build.sh.
#
# Provides:
#   agent_base_image_name  - compute reasoning layer base image name from provider
#   agent_image_name       - compute reasoning layer image name from provider + project
#   sandbox_image_name     - compute capability layer image name from project
#   worktree_id_derive     - derive WORKTREE_ID from project directory path

# -------------------------
# Image naming
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
# Container identity
# -------------------------

# worktree_id_derive <project_dir>
# Derive WORKTREE_ID from PROJECT_DIR absolute path.
# Returns 8-character hex hash for namespacing per-worktree.
worktree_id_derive() {
  local PROJECT_DIR="$1"
  echo "$PROJECT_DIR" | sha256sum | cut -c1-8
}

# agent_shared_base_name <provider>
agent_shared_base_name() {
  local provider="${1:?agent_shared_base_name requires provider}"
  case "$(echo "$provider" | tr '[:upper:]' '[:lower:]')" in
    hermes) echo "agent-python-base" ;;
    *)      echo "agent-node-base" ;;
  esac
}

# sandbox_shared_base_name
sandbox_shared_base_name() {
  echo "sandbox-ubuntu-base"
}
