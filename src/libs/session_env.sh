#!/usr/bin/env bash
# libs/session_env.sh  --  shared host-side session environment bootstrap.
#
# Sourced by the host-side session entrypoints (start_agent.sh, resume_agent.sh).
# Given a session's core inputs, derives and exports the full set of paths,
# image names, container names, branch, and delivery vars that run_agent.sh and
# the compose pipeline consume. This is the single canonical home for the
# host-side prelude, so the entrypoints do not re-derive it in parallel.
#
# Provides:
#   session_env_common_init <sandbox_dir> <project_name> <project_dir>
#     Phase 1  --  no SESSION_ID needed. Resolves the identity triple
#     (explicit > AGENT_SANDBOX_* > .env > error), loads the sandbox .env,
#     validates the git repo, derives harness paths via dirs_resolve, and
#     exports host uid/gid. The resolved identity beats a conflicting .env
#     (flag-wins precedence, S2 of the env-precedence feature).
#   session_env_names <project_name> <provider_name> <sandbox_dir> <session_id>
#     Phase 2  --  needs SESSION_ID. Derives image/container names, the sanitised
#     host branch, and delivery vars.

_self_session_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$_self_session_dir/build/image.sh"
source "$_self_session_dir/libs/env.sh"
source "$_self_session_dir/libs/env_resolve.sh"
source "$_self_session_dir/libs/dirs.sh"

# session_env_common_init <project_name> <project_dir> <sandbox_dir>
#   Phase 1 (no SESSION_ID needed): resolves the identity triple
#   (explicit > AGENT_SANDBOX_* > .env > error), loads .env, validates git,
#   derives harness paths via dirs_resolve, exports host uid/gid. The explicit
#   identity wins over a conflicting .env value (flag-wins). Args may be empty
#   so the resolver falls back to the AGENT_SANDBOX_* env level then the .env.
session_env_common_init() {
  local arg_name="$1" arg_dir="$2" arg_sandbox="$3"

  # env_resolve_identity resolves all three fields, exports PROJECT_NAME/
  # PROJECT_DIR/SANDBOX_DIR and the normalized ENV_FILE (the single --env
  # path contract, via default_env_file).
  env_resolve_identity "$arg_name" "$arg_dir" "$arg_sandbox" "${ENV_REL:-}" || return 1
  local project_name="$PROJECT_NAME" project_dir="$PROJECT_DIR" sandbox_dir="$SANDBOX_DIR"

  # .env loading
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env not found: $ENV_FILE" >&2
    echo "  SANDBOX_DIR has not been onboarded. Run:" >&2
    echo "    agent-sandbox onboard --name=$project_name --project=$project_dir --sandbox=$sandbox_dir" >&2
    return 1
  fi

  env_load "$ENV_FILE"

  # The resolved identity wins over .env (flag-wins precedence, S2): re-assert
  # it so a conflicting .env value cannot shadow explicit input.
  export PROJECT_NAME="$project_name"
  export PROJECT_DIR="$project_dir"
  export SANDBOX_DIR="$sandbox_dir"

  # Git validation uses the resolved project dir.
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

  # Host branch (sanitised; detached HEAD -> short SHA)
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

  # Host identity. Delivery is NOT set here: it is a command input owned by
  # the invoking script (start_agent parses it; resume recovers it from the
  # session record) and is passed downstream as an explicit argument.
  export WORKTREE_DIR="${WORKTREE_DIR:-$sandbox_dir/.worktree}"
}

# session_id_derive SANDBOX_DIR HOST_HEAD_SHA SESSION_TS
#   Derives the 6-char hex per-session id from the canonical sandbox dir, the
#   host branch-point, and the session timestamp, in one hash (single canonical
#   home for the formula shared by start and resume).
#
#   `sandbox_dir_canon` (which resolves SANDBOX_DIR to its canonical absolute
#   form) is provided by src/libs/common.sh, sourced by every host entrypoint
#   before this file.
session_id_derive() {
  local dir canon
  dir="$1"; if ! canon="$(sandbox_dir_canon "$dir")"; then return 1; fi
  echo "${canon}:${2}:${3}" | sha256sum | cut -c1-6
}
