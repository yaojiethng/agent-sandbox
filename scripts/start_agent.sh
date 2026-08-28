#!/usr/bin/env bash
# scripts/start_agent.sh
# Usage:
#   ./start_agent.sh <mode> [--serve] --name=<project_name> --project=<path> [--sandbox=<path>] [--env=<rel>] [--provider=<n>]
#
# Modes:
#   standard    --  normal execution, network access allowed (--serve toggles
#                   provider serve mode, port exposed at SERVE_PORT)
#   dry-run     --  liveness check only, no agent started
#
# Required flags:
#   --name=<project_name>   display name; used for log output
#   --project=<path>        absolute WSL/Linux path to the project directory on the host
#
# Optional flags:
#   --sandbox=<path>        absolute WSL/Linux path to the sandbox directory
#   --env=<rel>             path to .env file, relative to SANDBOX_DIR (default: .env)
#   --provider=<n>          provider name (required)
#
# Responsibility: host-side pre-flight only  --  path validation, .env loading,
# git validation, workspace setup, snapshot pipeline.
# Compose generation and container lifecycle are owned by scripts/run_agent.sh.
#
# This script is designed to be executed, not sourced. It exports variables
# for docker compose and run_agent.sh, then replaces itself via exec  -- 
# exports do not leak back into the caller's shell.

set -euo pipefail

# -------------------------
# Paths
# -------------------------
# REPO_ROOT assumes this script lives at scripts/
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Shared flag-parsing helpers (parse_help_flag, parse_base_flags, check_base_flags).
# common.sh does not touch script-dir variables  --  this script's own value above stands.
source "$REPO_ROOT/src/libs/common.sh"

# -------------------------
# Args
# -------------------------
usage() {
  cat <<'EOF'
Usage: start_agent.sh <mode> [flags]

Host-side pre-flight and session setup for agent-sandbox. This script is an
internal implementation detail of the agent-sandbox CLI  --  prefer invoking it
through:

  agent-sandbox start     [--serve] --provider=<n> --name=<n> --project=<path> --sandbox=<path> [flags]
  agent-sandbox dry-run   --provider=<n> --name=<n> --project=<path> --sandbox=<path> [flags]

or, from a sandbox Makefile:

  make start PROVIDER=<n> [SERVE=1]
  make dry-run PROVIDER=<n>

Mode (required):
  standard    --  normal execution, network access allowed
  dry-run     --  liveness check only, no agent started

Flags (all required except --sandbox/--env):
  --name=<n>       display name; used for image names and log output (required)
  --project=<path> absolute WSL/Linux path to the project directory on the host (required)
  --sandbox=<path> absolute WSL/Linux path to the sandbox directory
  --env=<rel>      path to .env file, relative to SANDBOX_DIR (default: .env)
  --provider=<n>   provider name (required  --  no default; e.g. pi, hermes, opencode)

Optional flags:
  --refresh   rebuild sandbox and provider images, then start a new session
  --rebuild   force a full rebuild including base images, then start a new session
  --interactive  interactive config wizard: pick provider + build policy, confirm, then start

Note: start always begins a NEW session. To resume a previous session, use
`make resume` (agent-sandbox resume).

Note: --provider is required and has no default. Pass it explicitly, or use
--interactive to pick a provider from a menu (recommended when unsure).
EOF
}

validate_wsl_path() {
  local PATH_VAR="$1"
  local PATH_VAL="$2"
  if [[ "$PATH_VAL" =~ ^[A-Za-z]:\\ ]]; then
    echo "Error: $PATH_VAR must be a WSL/Linux path, not a Windows path."
    echo "  Got:      $PATH_VAL"
    echo "  Convert:  wslpath '$PATH_VAL'"
    return 1
  fi
}


# -------------------------
# Interactive config wizard (F2 design D11)
# -------------------------
# `make start INTERACTIVE=1` collects the config (provider + build policy)
# and confirms before starting. Fast path = supply PROVIDER= directly;
# args already provided override the wizard's suggestions (D1). The wizard
# runs before the provider required-check so a missing --provider can be
# filled interactively; an abort exits cleanly before any session state is
# created.
_start_providers() {
  # Actionable providers = directories under src/reasoning/providers/ that
  # carry a provider.dockerfile (mirrors build_agent's dockerfile check).
  local p
  for p in "$REPO_ROOT"/src/reasoning/providers/*/; do
    [[ -f "${p}provider.dockerfile" ]] || continue
    basename "$p"
  done
}

_start_wizard() {
  # Interactive start wizard (D11). Start mode only  --  serve/dry-run
  # interactive support is a deferred refactor (roadmap L153).
  if [[ "$MODE" != "standard" ]]; then
    echo "Error: --interactive (config wizard) is only available for standard mode." >&2
    echo "  Serve/dry-run interactive support is deferred (roadmap L153)." >&2
    exit 1
  fi

  source "$REPO_ROOT/scripts/workflows/interactive.sh"

  # Provider picker  --  only when --provider was not supplied (D1: supplied
  # args override the suggested default rather than being re-prompted).
  if [[ -z "$PROVIDER_NAME" ]]; then
    local -a PROVIDER_ENTRIES=()
    local p
    for p in $(_start_providers); do
      PROVIDER_ENTRIES+=("$p|$p")
    done

    if [[ "${#PROVIDER_ENTRIES[@]}" -eq 0 ]]; then
      echo "Error: no providers found under $REPO_ROOT/src/reasoning/providers/" >&2
      exit 1
    fi

    local chosen
    chosen="$(interactive_pick "Select a provider:" PROVIDER_ENTRIES)" || exit 1
    PROVIDER_NAME="$chosen"
  fi

  # Build policy  --  only when neither --refresh nor --rebuild was supplied (D1).
  if [[ "$REFRESH" != true && "$REBUILD" != true ]]; then
    # shellcheck disable=SC2034 # consumed by interactive_pick via nameref
    local -a BUILD_ENTRIES=(
      "none|default (no rebuild)"
      "refresh|refresh sandbox and provider images"
      "rebuild|full rebuild from scratch (incl. base)"
    )
    local policy
    policy="$(interactive_pick "Image build policy:" BUILD_ENTRIES "none")" || exit 1
    [[ "$policy" == "refresh" ]] && REFRESH=true
    [[ "$policy" == "rebuild" ]] && REBUILD=true
  fi

  # Summary + confirm. Abort exits cleanly before any session state is created.
  local build_label="default (no rebuild)"
  [[ "$REFRESH" == true ]] && build_label="refresh"
  [[ "$REBUILD" == true ]] && build_label="rebuild (full)"
  if ! interactive_confirm_or_abort "Start a new session with:" \
       "provider: $PROVIDER_NAME" \
       "build:    $build_label" \
       "name:     $PROJECT_NAME" \
       "project:  $PROJECT_DIR" \
       "sandbox:  $SANDBOX_DIR"; then
    exit 1
  fi
}

# -------------------------
# Session identity  --  always a fresh new session
# -------------------------
# start unconditionally begins a NEW session (F2 design D10). All resume logic
# (volume discovery, auto-resume, and the interactive picker) was moved out to
# the split-out `make resume` command (scripts/resume_agent.sh) in 20260821-03.
# Each start computes fresh identity; the per-run compose record
# (.compose/<session-id>.yml) is the registry and embeds the identity.

_new_session_identity() {
  # Compute fresh identity and export it for this run.
  # Called for both default new-session and --refresh paths.
  export SESSION_TS; SESSION_TS=$(date -u +%Y%m%d-%H%M%S)
  export HOST_HEAD_SHA; HOST_HEAD_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)
  export SANDBOX_ID; SANDBOX_ID=$(sandbox_id_derive "$SANDBOX_DIR" "$HOST_HEAD_SHA")
  export SESSION_ID; SESSION_ID=$(session_id_derive "$SESSION_TS" "$SANDBOX_ID")
}

# -------------------------
# CLI entry point
# -------------------------
main() {
  # Handle --help/-h before any mode or flag validation, so both
  #   start_agent.sh --help
  #   start_agent.sh standard --help
  # print the full usage and exit cleanly. Reuses the canonical parse_help_flag.
  parse_help_flag "$@"

  MODE="${1:-}"
  shift || true

  if [[ -z "$MODE" ]]; then
    echo "Error: mode is required (standard|dry-run)" >&2
    usage >&2
    exit 1
  fi

  # -------------------------
  # Flag parsing
  # -------------------------
  PROJECT_NAME=""
  PROJECT_DIR=""
  SANDBOX_DIR_OVERRIDE=""
  ENV_REL=".env"
  PROVIDER_NAME=""
  REFRESH=false
  REBUILD=false
  INTERACTIVE=false
  SERVE=false

  local ARG
  for ARG in "$@"; do
    case "$ARG" in
      --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
      --project=*)  PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)  SANDBOX_DIR_OVERRIDE="${ARG#--sandbox=}" ;;

      --env=*)      ENV_REL="${ARG#--env=}" ;;
      --provider=*) PROVIDER_NAME="${ARG#--provider=}" ;;
      --refresh)    REFRESH=true ;;
      --rebuild)    REBUILD=true ;;
      --interactive) INTERACTIVE=true ;;
      --serve)      SERVE=true ;;
      *)
        echo "Unknown flag: $ARG"
        exit 1
        ;;
    esac
  done

  # Serve is a toggle on start, not a positional mode.
  if [[ "$SERVE" == true ]]; then
    if [[ "$MODE" != "standard" ]]; then
      echo "Error: --serve requires standard mode." >&2
      exit 1
    fi
    MODE="serve"
  fi

  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" ]]; then
    echo "Error: --name and --project are required"
    exit 1
  fi

  # -------------------------
  # SANDBOX_DIR derivation
  # -------------------------
  if [[ -n "$SANDBOX_DIR_OVERRIDE" ]]; then
    SANDBOX_DIR="$SANDBOX_DIR_OVERRIDE"
  else
    SANDBOX_DIR="$(dirname "$PROJECT_DIR")/$(basename "$PROJECT_DIR")-sandbox"
  fi

  validate_wsl_path "PROJECT_DIR" "$PROJECT_DIR"
  validate_wsl_path "SANDBOX_DIR" "$SANDBOX_DIR"

  if [[ "${INTERACTIVE:-false}" == "true" ]]; then
    _start_wizard
  fi
  
  # --provider is required and deliberately has no default  --  the harness does
  # not presume a provider. Fail with a clear diagnostic rather than a cryptic
  # image-naming error downstream.
  if [[ -z "$PROVIDER_NAME" ]]; then
    echo "Error: --provider is required (no default)." >&2
    echo "  Pass it explicitly, e.g. --provider=pi" >&2
    echo "  or from a sandbox Makefile: make start PROVIDER=pi" >&2
    echo "  or use --interactive to pick from a menu" >&2
    exit 1
  fi
  
  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: PROJECT_DIR does not exist: $PROJECT_DIR"
    exit 1
  fi
  
  # -------------------------
  # Shared host-side prelude  --  phase 1 (env, git validation, derived paths, uid/gid)
  # -------------------------
  source "$REPO_ROOT/src/libs/session_env.sh"
  session_env_common_init "$SANDBOX_DIR" "$PROJECT_NAME" "$PROJECT_DIR"
  
  if [[ "${REFRESH:-false}" == "true" ]]; then
    echo "Refresh requested  --  starting new session"
  fi
  
  # start always begins a NEW session (F2 design D10). Resume lives in the
  # split-out `make resume` command; there is no resume branch here.
  echo "Starting new session"
  _new_session_identity
  
  # -------------------------
  # Shared host-side prelude  --  phase 2 (branch, image/container names, delivery)
  # -------------------------
  # Identity (SESSION_ID) is now known. Derive the remaining env consumed by
  # run_agent.sh and compose: sanitized host branch, image/container names,
  # delivery type, worktree dir.
  session_env_names "$PROJECT_NAME" "$PROVIDER_NAME" "$SANDBOX_DIR" "$SESSION_ID"
  
  echo "Host branch: $SANITIZED_HOST_BRANCH"
  echo "Host HEAD SHA: $HOST_HEAD_SHA"
  echo "Sandbox ID: $SANDBOX_ID"
  echo "Session ID: $SESSION_ID"
  echo "Sandbox container name: $SANDBOX_CONTAINER_NAME"
  echo "Agent container name: $AGENT_CONTAINER_NAME"
  
  # -------------------------
  # Workspace directory setup and snapshot pipeline
  # -------------------------
  if [[ "$SANDBOX_TYPE" == "mount" ]]; then
    # Mount delivery: materialize the host worktree (bind-mounted into the
    # container). Use the shared snapshot primitive minus baseline.tar  --  rsync
    # the working tree, then git-init + baseline commit so .git exists. The
    # container writes the SESSION_STATE init marker into the worktree .git.
    mkdir -p "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"
    source "$REPO_ROOT/src/capability/snapshot.sh"
  
    if [[ ! -d "$WORKTREE_DIR/.git" ]]; then
      echo "Mount delivery: materializing worktree at $WORKTREE_DIR"
      snapshot_copy_worktree "$PROJECT_DIR" "$WORKTREE_DIR"
      git -C "$WORKTREE_DIR" init --quiet
      git -C "$WORKTREE_DIR" config user.email "agent@sandbox"
      git -C "$WORKTREE_DIR" config user.name "agent-sandbox"
      git -C "$WORKTREE_DIR" config core.fileMode false
      git -C "$WORKTREE_DIR" add -A
      git -C "$WORKTREE_DIR" commit --allow-empty -m "agent-sandbox: baseline" --quiet
      echo "Mount worktree baseline ready."
    else
      echo "Mount delivery: worktree already materialized at $WORKTREE_DIR"
    fi
  else
    # Clean the snapshot directory before building a fresh snapshot.
    # Without this, files from a previous run that are no longer in PROJECT_DIR
    # (deleted, moved, or newly gitignored) would persist in the snapshot and
    # propagate into the sandbox.
    rm -rf "$SNAPSHOT_DIR"
    mkdir -p "$SNAPSHOT_DIR"
    mkdir -p "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"
  
    source "$REPO_ROOT/src/capability/snapshot.sh"
  
    echo "Building snapshot..."
    snapshot_copy_worktree "$PROJECT_DIR" "$SNAPSHOT_DIR"
    snapshot_archive_head "$PROJECT_DIR" "$SNAPSHOT_DIR"
  
    snapshot_validate "$SNAPSHOT_DIR"
    echo "Snapshot ready."
  fi
  
  # -------------------------
  # Rebuild (if requested)
  # -------------------------
  # Build/preflight helpers (build_sandbox/build_agent/preflight) live in build.sh,
  # which also provides the image-name functions. Source it now that identity paths
  # are settled and we are ready to (re)build/preflight for this session.
  source "$REPO_ROOT/scripts/build.sh"
  # --refresh: rebuild sandbox and provider (base skipped if exists).
  # --rebuild: rebuild everything from scratch including base (supersedes --refresh).
  # Export host UID/GID for build pipeline
  HOST_UID="$(id -u)"
  HOST_GID="$(id -g)"
  
  if [[ "$REBUILD" == true ]]; then
    echo "Rebuilding everything from scratch: $PROVIDER_NAME..."
    build_sandbox "$PROJECT_NAME" "$REPO_ROOT" "$HOST_UID" "$HOST_GID"
    build_agent "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "--no-cache" "$HOST_UID" "$HOST_GID"
  elif [[ "$REFRESH" == true ]]; then
    echo "Refreshing sandbox and provider: $PROVIDER_NAME..."
    build_sandbox "$PROJECT_NAME" "$REPO_ROOT" "$HOST_UID" "$HOST_GID"
    build_agent "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" "" "$HOST_UID" "$HOST_GID"
  fi
  
  # -------------------------
  # Preflight
  # -------------------------
  preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT"
  
  # -------------------------
  # Dispatch to run_agent.sh
  # -------------------------
  # Compose generation and container lifecycle are owned by scripts/run_agent.sh.
  # All .env variables and derived image names are already exported above.
  # start always begins a NEW session, so the previous session's volume is always
  # reset: run_agent.sh destroys the existing volume before starting fresh containers.
  RESET_VOLUME_FLAG="--reset-volume"
  
  exec "$REPO_ROOT/scripts/run_agent.sh" "$MODE" \
    --name="$PROJECT_NAME" \
    --sandbox="$SANDBOX_DIR" \
    --env="$ENV_FILE" \
    --provider="$PROVIDER_NAME" \
    $RESET_VOLUME_FLAG

}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
