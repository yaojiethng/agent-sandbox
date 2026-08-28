#!/usr/bin/env bash
# libs/session_env.sh — shared host-side session environment bootstrap.
#
# Sourced by the host-side session entrypoints (start_agent.sh, resume_agent.sh).
# Given a session's core inputs, derives and exports the full set of paths,
# image names, container names, branch, and delivery vars that run_agent.sh and
# the compose pipeline consume. This is the single canonical home for the
# host-side prelude, so the entrypoints do not re-derive it in parallel.
#
# Provides:
#   session_env_common_init <sandbox_dir> <project_name> <project_dir>
#     Phase 1 — no SESSION_ID needed. Loads the sandbox .env, validates the
#     git repo, derives harness paths via dirs_resolve, exports host uid/gid.
#   session_env_names <project_name> <provider_name> <sandbox_dir> <session_id>
#     Phase 2 — needs SESSION_ID. Derives image/container names, the sanitised
#     host branch, and delivery vars.
#
# Sourced by the host-side session entrypoints (start_agent.sh, resume_agent.sh).
# Both functions export into the caller's scope for run_agent.sh and compose.

_self_session_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$_self_session_dir/build/image.sh"
source "$_self_session_dir/libs/dirs.sh"

# session_env_common_init <sandbox_dir> <project_name> <project_dir>
#   Phase 1 (no SESSION_ID needed): loads .env, validates git, derives harness
#   paths via dirs_resolve, exports host uid/gid. Called by start_agent.sh before
#   identity is computed and by resume_agent.sh after it recovers the record.
session_env_common_init() {
  local sandbox_dir="${1:?session_env_common_init requires sandbox_dir}"
  local project_name="${2:?session_env_common_init requires project_name}"
  local project_dir="${3:?session_env_common_init requires project_dir}"

  export PROJECT_NAME="$project_name"
  export PROJECT_DIR="$project_dir"

  # .env loading
  ENV_FILE="$sandbox_dir/${ENV_REL:-.env}"
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env not found: $ENV_FILE" >&2
    echo "  SANDBOX_DIR has not been onboarded. Run:" >&2
    echo "    agent-sandbox onboard --name=$project_name --project=$project_dir --sandbox=$sandbox_dir" >&2
    return 1
  fi

  # Source only simple KEY=VALUE lines; skip comments and blanks.
  while IFS='=' read -r KEY VALUE || [[ -n "$KEY" ]]; do
    [[ "$KEY" =~ ^#.*$ || -z "$KEY" ]] && continue
    KEY="${KEY//[$'\r\n\t ']/}"
    VALUE="${VALUE//[$'\r\n']/}"
    VALUE="${VALUE#"${VALUE%%[! ]*}"}"
    VALUE="${VALUE%"${VALUE##*[! ]}"}"
    export "$KEY=$VALUE"
  done < "$ENV_FILE"

  # Git validation
  if [[ ! -d "$project_dir/.git" ]]; then
    echo "Error: PROJECT_DIR is not a git repository: $project_dir" >&2
    return 1
  fi
  if ! git -C "$project_dir" rev-parse HEAD >/dev/null 2>&1; then
    echo "Error: git repository has no commits: $project_dir" >&2
    echo "  Create an initial commit first:" >&2
    echo "    git -C '$project_dir' add -A" >&2
    echo "    git -C '$project_dir' commit -m 'initial'" >&2
    return 1
  fi

  # Derived harness paths via canonical dirs_resolve
  dirs_resolve "$sandbox_dir"

  export HOST_UID; HOST_UID="$(id -u)"
  export HOST_GID; HOST_GID="$(id -g)"
  export ENV_FILE
}

# session_env_names <project_name> <provider_name> <sandbox_dir> <session_id>
#   Phase 2 (needs SESSION_ID): derives image + container names, host branch,
#   and delivery vars. Call after identity is known.
session_env_names() {
  local project_name="${1:?session_env_names requires project_name}"
  local provider_name="${2:?session_env_names requires provider_name}"
  local sandbox_dir="${3:?session_env_names requires sandbox_dir}"
  local session_id="${4:?session_env_names requires session_id}"

  export PROVIDER_NAME="$provider_name"
  export SESSION_ID="$session_id"

  # Host branch (sanitised; detached HEAD → short SHA)
  local branch
  branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ "$branch" == "HEAD" || -z "$branch" ]]; then
    branch="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || true)"
  fi
  local sanitized_branch
  sanitized_branch="$(echo "$branch" | sed 's/[^a-zA-Z0-9._-]/-/g')"
  export SANITIZED_HOST_BRANCH="$sanitized_branch"

  # Image + container names
  local sandbox_image
  sandbox_image="$(sandbox_image_name "$project_name")"
  export SANDBOX_IMAGE_NAME="$sandbox_image"
  local agent_image
  agent_image="$(agent_image_name "$provider_name" "$project_name")"
  export AGENT_IMAGE_NAME="$agent_image"
  export SANDBOX_CONTAINER_NAME="sandbox-${project_name}-${session_id}"
  export AGENT_CONTAINER_NAME="${provider_name}-${project_name}-${session_id}"

  # Delivery + host identity
  export SANDBOX_TYPE="${SANDBOX_TYPE:-copy}"
  export WORKTREE_DIR="${WORKTREE_DIR:-$sandbox_dir/.worktree}"
}
# sandbox_id_derive SANDBOX_DIR HOST_HEAD_SHA
#   Derives the 8-char hex session-identity hash shared by start and resume.
#   Single canonical home for the formula (previously duplicated inline in
#   start_agent.sh and resume_agent.sh).
sandbox_id_derive() {
  echo "${1}:${2}" | sha256sum | cut -c1-8
}

# session_id_derive SESSION_TS SANDBOX_ID
#   Derives the 6-char hex per-session id from the timestamp and sandbox id.
session_id_derive() {
  echo "${1}:${2}" | sha256sum | cut -c1-6
}
