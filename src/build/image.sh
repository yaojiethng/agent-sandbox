#!/usr/bin/env bash
# build/image.sh
# Container image naming and identity functions.
# Sourced by scripts/build.sh and scripts/run_agent.sh.
#
# Provides:
#   agent_base_image_name  - compute reasoning layer base image name from provider
#   agent_image_name       - compute reasoning layer image name from provider + project
#   sandbox_image_name     - compute capability layer image name from project
#   image_digest           - image ID digest (content identity of the built image)

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
# Returns: <provider>-agent-<project> (project lowercased; provider verbatim)
agent_image_name() {
  local provider="${1:?agent_image_name requires provider}"
  local project="${2:?agent_image_name requires project name}"
  echo "${provider}-agent-$(echo "$project" | tr '[:upper:]' '[:lower:]')"
}

# shared_base_image_name
# Returns: agent-node-base (shared reasoning layer base image)
# All providers inherit from this. Defined here rather than hardcoded in
# build orchestrators so the constant has a single canonical source.
shared_base_image_name() {
  echo "agent-node-base"
}

# sandbox_image_name <project_name>
# Returns: sandbox-<project> (lowercased)
sandbox_image_name() {
  local project="${1:?sandbox_image_name requires project name}"
  echo "sandbox-$(echo "$project" | tr '[:upper:]' '[:lower:]')"
}

# -------------------------
# Image identity
# -------------------------

# image_digest IMAGE_NAME
# Content identity of a built image: the image ID digest (`sha256:...`), which
# content-addresses the image config and, through it, every layer. Used as the
# per-session recorded image version (ADR harness_versioning.md). Empty when
# docker is unavailable or the image does not exist -- compose_generate treats
# that as a hard error.
image_digest() {
  local image_name="${1:?image_digest requires an image name}"
  docker image inspect --format '{{.Id}}' "$image_name" 2>/dev/null
}
