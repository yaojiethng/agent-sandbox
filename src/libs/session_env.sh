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
#   resolve_and_init <project_name> <project_dir> <sandbox_dir>
#     Phase 1  --  the identity triple arrives as arguments, already resolved
#     by the chain entry (explicit flag > .env > error, once, in
#     env_resolve_identity). This function does not resolve and does not load:
#     it validates the git repo, derives harness paths via dirs_resolve, and
#     exports host uid/gid. No key of the record becomes a child's environment.
#   session_env_names <project_name> <provider_name> <sandbox_dir> <session_id>
#     Phase 2  --  needs SESSION_ID. Derives image/container names, the sanitised
#     host branch, and delivery vars.

_self_session_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$_self_session_dir/build/image.sh"
source "$_self_session_dir/libs/env.sh"
source "$_self_session_dir/libs/env_resolve.sh"
source "$_self_session_dir/libs/dirs.sh"
source "$_self_session_dir/libs/session_inventory.sh"

# resolve_and_init <project_name> <project_dir> <sandbox_dir>
#   Phase 1 (no SESSION_ID needed): the identity triple arrives as arguments,
#   already resolved once by the chain entry. This function resolves and loads
#   nothing: it validates the git repo, derives harness paths via dirs_resolve,
#   and exports host uid/gid. ENV_FILE arrives from the same resolution (the
#   single --env path contract, via default_env_file), so there is no second
#   site that opens the .env, and a reader that needs a record value asks for
#   it by key.
resolve_and_init() {
  local project_name="${1:?resolve_and_init requires a resolved project_name}"
  local project_dir="${2:?resolve_and_init requires a resolved project_dir}"
  local sandbox_dir="${3:?resolve_and_init requires a resolved sandbox_dir}"

  # The record must exist before its view opens.
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env not found: $ENV_FILE" >&2
    echo "  SANDBOX_DIR has not been onboarded. Run:" >&2
    echo "    agent-sandbox onboard --name=$project_name --project=$project_dir --sandbox=$sandbox_dir" >&2
    return 1
  fi

  # The resolved identity is the harness's own value, exported so the process
  # chain reads one triple rather than re-deriving it.
  export PROJECT_NAME="$project_name"
  export PROJECT_DIR="$project_dir"
  export SANDBOX_DIR="$sandbox_dir"

  # Git validation uses the resolved project dir.
  if [[ ! -d "$project_dir/.git" ]]; then
    echo "Error: PROJECT_DIR is not a git repository: $project_dir" >&2
    return 1
  fi
  if ! git_head_resolvable "$project_dir"; then
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

  # The process view, opened once for this entry. Phase 2 reads record values
  # from it; a view the resolver already opened for this file is reused rather
  # than parsed again.
  env_record_view "$ENV_FILE"
}

# env_record_get KEY
#   Reads KEY from the view resolve_and_init opened. Empty when the record has no
#   such key, which is how an optional setting states its default.
env_record_get() {
  record_get ENV_RECORD "${1:?env_record_get requires a key}"
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
  branch="$(project_current_ref "$PROJECT_DIR")"
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
  #
  # The worktree path is an optional run input: the invocation's own value,
  # then the record's, then the conventional sibling. A record key with a stated
  # default is not an error when absent, so it is read from the opened view
  # rather than required through the resolution primitive.
  local recorded_worktree
  recorded_worktree="$(env_record_get WORKTREE_DIR)"
  export WORKTREE_DIR="${WORKTREE_DIR:-${recorded_worktree:-$sandbox_dir/.worktree}}"
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
