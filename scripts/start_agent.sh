#!/usr/bin/env bash
# scripts/start_agent.sh
# Usage:
#   ./start_agent.sh <mode> [--serve] --name=<project_name> --project=<path> [--sandbox=<path>] [--env=<env>] [--provider=<n>]
#
# Modes:
#   standard    --  normal execution, network access allowed (--serve toggles
#                   provider serve mode, port exposed at SERVE_PORT)
#   dry-run     --  e2e check: always rebuilds current source, exercises the
#                   container pipeline (fresh + resume passes), verifies, tears
#                   down; --fast skips the rebuild
#
# Required flags:
#   --name=<project_name>   display name; used for log output
#   --project=<path>        absolute WSL/Linux path to the project directory on the host
#
# Optional flags:
#   --sandbox=<path>        absolute WSL/Linux path to the sandbox directory
#   --env=<env>             .env file: an absolute path or a name relative to SANDBOX_DIR (default: .env)
#   --provider=<n>          provider name (required)
#
# Responsibility: host-side pre-flight only  --  path validation, .env loading,
# git validation, workspace setup, delivery preparation.
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

# Shared flag-parsing helpers (parse_help_flag, check_base_flags).
# common.sh does not touch script-dir variables  --  this script's own value above stands.
source "$REPO_ROOT/src/libs/common.sh"
source "$REPO_ROOT/src/libs/cli.sh"

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
  dry-run     --  e2e check: always rebuilds current source, exercises the
                  full container pipeline (fresh pass + resume pass), verifies
                  records + image identity, then tears down. --fast skips the
                  rebuild.

Flags (all required except --sandbox/--env):
  --name=<n>       display name; used for image names and log output (required)
  --project=<path> absolute WSL/Linux path to the project directory on the host (required)
  --sandbox=<path> absolute WSL/Linux path to the sandbox directory
  --env=<rel>      .env file: an absolute path or a name relative to SANDBOX_DIR (default: .env)
  --provider=<n>   provider name (required  --  no default; e.g. pi, hermes, opencode)

Optional flags:
  --refresh   rebuild sandbox and provider images, then start a new session (standard start only)
  --rebuild   force a full rebuild with --no-cache, then start a new session (also valid for dry-run)
  --delivery=<d>  delivery model: copy|mount (default copy; mount binds the host worktree)
  --flatten   flattened history: fresh git-init baseline, no host history (default: full history)
  --fast      dry-run only: skip the image build and run existing images
              (dry-run without --fast always rebuilds current source first)
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
  export SESSION_ID; SESSION_ID=$(session_id_derive "$SANDBOX_DIR" "$HOST_HEAD_SHA" "$SESSION_TS")
  # Dry-run labeling (not routing): the DRYRUN_SID_PREFIX flows into every
  # derived name -- compose project, containers, network, volume, registry
  # record -- so dry-run machinery self-identifies. Aids diagnosis when a run
  # leaves residue and keeps the workspace tidy; collision prevention comes
  # from the unique per-run id, not the prefix. The prefix and its predicate
  # are canonically defined in session_inventory.sh.
  if [[ "$MODE" == "dry-run" ]]; then
    export SESSION_ID="${DRYRUN_SID_PREFIX}${SESSION_ID}"
  fi
}

# -------------------------
# CLI entry point
# -------------------------
main() {
  # Handle --help/-h before any mode or flag validation, so both
  #   start_agent.sh --help
  #   start_agent.sh standard --help
  # print the full usage and exit cleanly. Reuses the canonical parse_help_flag,
  # which returns 0 when help was requested; the caller owns the exit.
  if parse_help_flag "$@"; then
    exit 0
  fi

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
  # ENV_REL is the --env parse target; its default .env is read by
  # env_resolve_identity in the sourced session_env.sh, which ShellCheck
  # cannot trace across `source`.
  # shellcheck disable=SC2034
  ENV_REL=".env"
  PROVIDER_NAME=""
  REFRESH=false
  REBUILD=false
  FAST=false
  INTERACTIVE=false
  SERVE=false
  _CLI_UNKNOWN_WORD="Unknown flag"
  # Delivery is a command input, not environment state: the default is parsed
  # once here, at ingestion. It is never exported and never read from the
  # environment; downstream consumers receive it as an explicit --delivery
  # argument. Resume never uses this default -- it recovers delivery from the
  # persisted record.
  DELIVERY="copy"
  # FLATTEN is a command input, not environment state: parsed once here, at
  # ingestion, and passed down as an explicit --flatten argument (parallel to
  # DELIVERY). Never read from ambient env downstream. Resume recovers it from
  # the persisted record.
  FLATTEN=false

  parse_args usage \
    --name=PROJECT_NAME \
    --project=PROJECT_DIR \
    --sandbox=SANDBOX_DIR_OVERRIDE \
    --env=ENV_REL \
    --provider=PROVIDER_NAME \
    --refresh \
    --rebuild \
    --fast \
    --interactive \
    --serve \
    --flatten \
    --delivery=DELIVERY \
    -- "$@"
  local prc=$?
  if [[ $prc -eq 2 ]]; then exit 0; fi
  [[ $prc -eq 0 ]] || exit 1

  case "$DELIVERY" in
    copy|mount) ;;
    *)
      echo "Error: invalid --delivery: $DELIVERY (expected 'copy' or 'mount')" >&2
      exit 1
      ;;
  esac

  # Serve is a toggle on start, not a positional mode.
  if [[ "$SERVE" == true ]]; then
    if [[ "$MODE" != "standard" ]]; then
      echo "Error: --serve requires standard mode." >&2
      exit 1
    fi
    MODE="serve"
  fi

  # Dry-run build policy: dry-run is the operator's e2e of CURRENT source, so
  # the default is always-rebuild (a dry-run never silently reuses stale
  # images); the build uses cache layers where they exist. --rebuild is the
  # stronger form: rebuild passing --no-cache. --refresh is redundant with the
  # default and rejected; --fast is the looser invocation that skips the build
  # and is dry-run only (mirror of the --refresh rejection: a silently
  # no-op flag is how contracts rot).
  if [[ "$FAST" == true && "$MODE" != "dry-run" ]]; then
    echo "Error: --fast is only valid for dry-run." >&2
    exit 1
  fi
  if [[ "$MODE" == "dry-run" ]]; then
    if [[ "$REFRESH" == true ]]; then
      echo "Error: --refresh is not valid for dry-run (dry-run always rebuilds; drop the flag)." >&2
      exit 1
    fi
    if [[ "$FAST" == true ]]; then
      if [[ "$REBUILD" == true ]]; then
        echo "Error: --fast cannot be combined with --rebuild (one builds everything, the other builds nothing)." >&2
        exit 1
      fi
      echo "Fast dry-run: skipping image build (running existing images)"
    else
      REFRESH=true
    fi
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

  # Canonicalize the sandbox dir once so identity, compose labels, and any
  # downstream filter agree regardless of path spelling. Fails loudly when
  # unresolvable (the dir must exist for start to proceed).
  local canon_dir
  if ! canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")"; then exit 1; fi
  SANDBOX_DIR="$canon_dir"

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
  # DRYRUN_SID_PREFIX + session_is_dry_run (canonical dry-run id labeling).
  source "$REPO_ROOT/src/libs/session_inventory.sh"
  session_env_common_init "$PROJECT_NAME" "$PROJECT_DIR" "$SANDBOX_DIR"
  
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
  echo "Session ID: $SESSION_ID"
  echo "Sandbox container name: $SANDBOX_CONTAINER_NAME"
  echo "Agent container name: $AGENT_CONTAINER_NAME"
  
  # -------------------------
  # Workspace directory setup and delivery preparation
  # -------------------------
  if [[ "$DELIVERY" == "mount" ]]; then
    # Mount delivery: materialize the host worktree (bind-mounted into the
    # container) via the shared delivery dispatcher (snapshot_deliver; full
    # copies .git, flatten inits a baseline). The container writes the
    # SESSION_STATE init marker into the worktree .git.
    mkdir -p "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"
    source "$REPO_ROOT/src/capability/snapshot.sh"
  
    if [[ ! -d "$WORKTREE_DIR/.git" ]]; then
      # Unborn HEAD: fails here with a readable message for direct
      # invocation; the harness session-env gate already rejected an empty
      # repository before delivery dispatch. The seed path fires the same
      # guard (matching invariant, both deliveries).
      if ! git -C "$PROJECT_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
        echo "Error: repository at $PROJECT_DIR has no commits. Make an initial commit before starting a session." >&2
        exit 1
      fi
      echo "Mount delivery: materializing worktree at $WORKTREE_DIR"
      # Shared delivery dispatcher: full (default) copies .git for full history;
      # flatten syncs the worktree then inits a fresh baseline. Record the
      # delivery-history mode in the worktree config so reuse can detect a
      # later mismatch (persist, re-consume -- never infer).
      snapshot_deliver "$PROJECT_DIR" "$WORKTREE_DIR" "$FLATTEN" \
        || { echo "Error: mount worktree materialization failed ($WORKTREE_DIR)" >&2; exit 1; }
      git -C "$WORKTREE_DIR" config agent-sandbox.flatten "$FLATTEN" \
        || { echo "Error: recording mount worktree history mode failed" >&2; exit 1; }
      echo "Mount worktree baseline ready."
    else
      # Reuse semantics: a materialized worktree keeps its delivery-history
      # mode. Read the recorded mode; refuse a mismatch rather than silently
      # serve a full worktree to a flatten request (or vice versa). A worktree
      # without the key predates the flatten contract (it is a flatten-style
      # baseline) -- its mode is unknown, so refuse rather than mislabel it as
      # full.
      local recorded_flatten
      recorded_flatten="$(git -C "$WORKTREE_DIR" config agent-sandbox.flatten 2>/dev/null || echo "")"
      if [[ -z "$recorded_flatten" ]]; then
        echo "Error: mount worktree at $WORKTREE_DIR has no recorded history mode (pre-dates the flatten contract)." >&2
        echo "  Recreate it: remove $WORKTREE_DIR and start again." >&2
        exit 1
      fi
      # The recorded mode is a boolean literal (true|false). Refuse any other
      # value in the clear: do not attempt to interpret an unknown value.
      case "$recorded_flatten" in
        true|false) ;;
        *)
          echo "Error: mount worktree at $WORKTREE_DIR records an invalid history mode: $recorded_flatten (expected true or false)." >&2
          echo "  Recreate it: remove $WORKTREE_DIR and start again." >&2
          exit 1
          ;;
      esac
      if [[ "$recorded_flatten" != "$FLATTEN" ]]; then
        echo "Error: mount worktree at $WORKTREE_DIR is $([[ $recorded_flatten == true ]] && echo flattened || echo full) but this start requested $([[ $FLATTEN == true ]] && echo flatten || echo full)." >&2
        echo "  A worktree keeps its first delivery-history mode. Use a different --sandbox or remove $WORKTREE_DIR." >&2
        exit 1
      fi
      echo "Mount delivery: worktree already materialized at $WORKTREE_DIR"
    fi
  else
    # Copy delivery: no host-side staging. The one-shot seeder service fills
    # the session volume before the sandbox container starts (helper
    # transport; see seed_volume.sh and the seed step in run_agent.sh).
    mkdir -p "$CHANGES_DIR" "$INPUT_DIR" "$OUTPUT_DIR"
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
  # Preflight. --fast must not silently build: with build_missing=false
  # preflight fails with the remediation error (build first) instead of
  # silently building behind the "skip build" flag.
  # -------------------------
  if [[ "$FAST" == true ]]; then
    preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT" false
  else
    preflight "$PROVIDER_NAME" "$PROJECT_NAME" "$REPO_ROOT"
  fi
  
  # -------------------------
  # Dispatch to run_agent.sh
  # -------------------------
  # Compose generation and container lifecycle are owned by scripts/run_agent.sh.
  # All .env variables and derived image names are already exported above.
  # start always begins a NEW session, so the previous session's volume is always
  # reset: run_agent.sh destroys the existing volume before starting fresh containers.
  RESET_VOLUME_FLAG="--reset-volume"
  
  local flatten_arg=()
  [[ "$FLATTEN" == true ]] && flatten_arg=(--flatten)

  exec "$REPO_ROOT/scripts/run_agent.sh" "$MODE" \
    --name="$PROJECT_NAME" \
    --sandbox="$SANDBOX_DIR" \
    --env="$ENV_FILE" \
    --provider="$PROVIDER_NAME" \
    --delivery="$DELIVERY" \
    "${flatten_arg[@]}" \
    $RESET_VOLUME_FLAG

}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
