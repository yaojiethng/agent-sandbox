#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Usage:
#   agent-sandbox onboard  --name=<n> --project=<path> --sandbox=<path>
#   agent-sandbox build    [--target=<targets>] --name=<n> --project=<path> --sandbox=<path>
#   agent-sandbox start    --provider=<n> --name=<n> --project=<path> --sandbox=<path> [--rebuild] [flags]
#   agent-sandbox serve    --provider=<n> --name=<n> --project=<path> --sandbox=<path> [--rebuild] [flags]
#   agent-sandbox dry-run  --provider=<n> --name=<n> --project=<path> --sandbox=<path> [--rebuild] [flags]
#   agent-sandbox stop     --sandbox=<path>
#   agent-sandbox apply    --project=<path> --sandbox=<path> [--channel=<c>] [--branch=<n>] [--session=<name>] [--diff=<path>] [--force]
#   agent-sandbox draft    --project=<path> --sandbox=<path> [--channel=<c>] [--session=<name>] [--branch-from=<hash>] [--diffs=<range>] [--branch-summary=<slug>]
#   agent-sandbox confirm  --project=<path> --sandbox=<path> [--target=<branch>]
#   agent-sandbox reject   --project=<path> --sandbox=<path>
#
# --channel values:
#   draft:  session (default), autosave, bundles
#   apply:  diffs (default), autosave, session
#
# --target accepts: all, sandbox, <provider>, or comma-separated combinations
#   agent-sandbox build --target=all
#   agent-sandbox build --target=hermes
#   agent-sandbox build --target=hermes,sandbox

set -euo pipefail

AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"

source "$AGENT_SANDBOX_REPO/libs/containers.sh"
source "$AGENT_SANDBOX_REPO/libs/draft_workflow.sh"
source "$AGENT_SANDBOX_REPO/libs/diff_workflow.sh"

SUBCOMMAND="${1:-}"
shift || true

if [[ -z "$SUBCOMMAND" ]]; then
  echo "Usage: agent-sandbox <onboard|build|start|serve|dry-run|stop|apply> <flags>"
  exit 1
fi

# -------------------------
# Flag parsing (shared)
# -------------------------
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR=""
BRANCH=""
SESSION_ARG=""
TARGET_BRANCH=""
PROVIDER_NAME=""
REBUILD=false
REBUILD_BASE=false
DIFF_ARG=""
FORCE=false
BRANCH_FROM=""
DIFFS=""
BRANCH_SUMMARY=""
CHANNEL=""
PASSTHROUGH=()

parse_flags() {
  for ARG in "$@"; do
    case "$ARG" in
      --name=*)        PROJECT_NAME="${ARG#--name=}" ;;
      --project=*)     PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)     SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --branch=*)      BRANCH="${ARG#--branch=}" ;;
      --session=*)     SESSION_ARG="${ARG#--session=}" ;;
      --target=*)      TARGET_BRANCH="${ARG#--target=}" ;;
      --branch-from=*) BRANCH_FROM="${ARG#--branch-from=}" ;;
      --diffs=*)       DIFFS="${ARG#--diffs=}" ;;
      --branch-summary=*) BRANCH_SUMMARY="${ARG#--branch-summary=}" ;;
      --diff=*)        DIFF_ARG="${ARG#--diff=}" ;;
      --channel=*)     CHANNEL="${ARG#--channel=}" ;;
      --force)         FORCE=true ;;
      --provider=*)    PROVIDER_NAME="${ARG#--provider=}" ;;
      --rebuild)       REBUILD=true ;;
      --rebuild-base)  REBUILD_BASE=true ;;
      *)               PASSTHROUGH+=("$ARG") ;;
    esac
  done
}

require_run_args() {
  local SUBCOMMAND="$1"
  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --name, --project, and --sandbox are required"
    exit 1
  fi
  if [[ -z "$PROVIDER_NAME" ]]; then
    echo "Error: --provider is required. Example: agent-sandbox $SUBCOMMAND --provider=hermes ..."
    exit 1
  fi
}

rebuild_if_requested() {
  if [[ "$REBUILD" == true ]]; then
    echo "Rebuilding sandbox and provider: $PROVIDER_NAME..."
    build_sandbox "$PROJECT_NAME" "$SANDBOX_DIR" "$AGENT_SANDBOX_REPO"
    build_agent   "$PROVIDER_NAME" "$PROJECT_NAME" "$AGENT_SANDBOX_REPO" $([ "$REBUILD_BASE" == true ] && echo "--rebuild-base")
  fi
}

# -------------------------
# Channel routers
# -------------------------

# resolve_source_for_draft SANDBOX_DIR CHANNEL SESSION_ARG
#   Resolves a SOURCE_DIR (directory containing patches/) and SESSION_NAME
#   for the draft command. Prints tab-separated SOURCE_DIR and SESSION_NAME.
#   Returns 1 on error.
resolve_source_for_draft() {
  local SANDBOX_DIR="$1"
  local CHANNEL="$2"
  local SESSION_ARG="$3"

  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local BASE_DIR=""
  local SUBDIR=""

  case "$CHANNEL" in
    session)
      BASE_DIR="$WORKSPACE_DIR/session-diffs"
      SUBDIR="session"
      ;;
    autosave)
      BASE_DIR="$WORKSPACE_DIR/session-diffs"
      SUBDIR="autosave"
      ;;
    bundles)
      BASE_DIR="$WORKSPACE_DIR/output/bundles"
      SUBDIR=""
      ;;
    *)
      echo "Error: unknown channel for draft: $CHANNEL" >&2
      echo "  Valid: session, autosave, bundles" >&2
      return 1
      ;;
  esac

  if [[ -n "$SESSION_ARG" ]]; then
    if [[ "$SESSION_ARG" == /* ]]; then
      echo "Error: --session does not accept absolute paths. Use a session name." >&2
      return 1
    fi

    local TARGET_DIR
    if [[ -n "$SUBDIR" ]]; then
      TARGET_DIR="$BASE_DIR/$SESSION_ARG/$SUBDIR"
    else
      TARGET_DIR="$BASE_DIR/$SESSION_ARG"
    fi

    if [[ ! -d "$TARGET_DIR" ]]; then
      echo "Error: session not found: $TARGET_DIR" >&2
      return 1
    fi

    local SESSION_NAME
    if [[ -n "$SUBDIR" ]]; then
      SESSION_NAME=$(basename "$(dirname "$TARGET_DIR")")
    else
      SESSION_NAME=$(basename "$TARGET_DIR")
    fi

    printf '%s\t%s\n' "$TARGET_DIR" "$SESSION_NAME"
    return 0
  fi

  # Auto-resolve: find latest directory with patches/*.diff
  if [[ ! -d "$BASE_DIR" ]]; then
    echo "Error: no exports found for channel '$CHANNEL'" >&2
    return 1
  fi

  local LATEST=""
  while IFS= read -r CANDIDATE; do
    [[ -z "$CANDIDATE" ]] && continue
    local CHECK_DIR
    if [[ -n "$SUBDIR" ]]; then
      CHECK_DIR="$CANDIDATE/$SUBDIR"
    else
      CHECK_DIR="$CANDIDATE"
    fi
    if [[ -d "$CHECK_DIR/patches" ]] && \
       ls "$CHECK_DIR/patches/"*.diff >/dev/null 2>&1; then
      LATEST="$CHECK_DIR"
      break
    fi
  done < <(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r)

  if [[ -z "$LATEST" ]]; then
    echo "Error: no completed session found for channel '$CHANNEL'" >&2
    echo "  Directory: $BASE_DIR" >&2
    return 1
  fi

  local SESSION_NAME
  if [[ -n "$SUBDIR" ]]; then
    SESSION_NAME=$(basename "$(dirname "$LATEST")")
  else
    SESSION_NAME=$(basename "$LATEST")
  fi

  printf '%s\t%s\n' "$LATEST" "$SESSION_NAME"
}

# resolve_diff_for_apply SANDBOX_DIR CHANNEL SESSION_ARG
#   Resolves the file path to uncommitted.diff for the apply command.
#   Prints the file path. Returns 1 on error.
resolve_diff_for_apply() {
  local SANDBOX_DIR="$1"
  local CHANNEL="$2"
  local SESSION_ARG="$3"

  local WORKSPACE_DIR="$SANDBOX_DIR/.workspace"
  local BASE_DIR=""
  local SUBDIR=""

  case "$CHANNEL" in
    diffs)
      BASE_DIR="$WORKSPACE_DIR/output/diffs"
      SUBDIR=""
      ;;
    autosave)
      BASE_DIR="$WORKSPACE_DIR/session-diffs"
      SUBDIR="autosave"
      ;;
    session)
      BASE_DIR="$WORKSPACE_DIR/session-diffs"
      SUBDIR="session"
      ;;
    *)
      echo "Error: unknown channel for apply: $CHANNEL" >&2
      echo "  Valid: diffs, autosave, session" >&2
      return 1
      ;;
  esac

  local TARGET_DIR=""

  if [[ -n "$SESSION_ARG" ]]; then
    if [[ "$SESSION_ARG" == /* ]]; then
      echo "Error: --session does not accept absolute paths. Use a session name." >&2
      return 1
    fi

    if [[ -n "$SUBDIR" ]]; then
      TARGET_DIR="$BASE_DIR/$SESSION_ARG/$SUBDIR"
    else
      TARGET_DIR="$BASE_DIR/$SESSION_ARG"
    fi

    if [[ ! -d "$TARGET_DIR" ]]; then
      echo "Error: session not found: $TARGET_DIR" >&2
      return 1
    fi
  else
    # Auto-resolve: find latest directory
    if [[ ! -d "$BASE_DIR" ]]; then
      echo "Error: no exports found for channel '$CHANNEL'" >&2
      return 1
    fi

    TARGET_DIR=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)
    if [[ -z "$TARGET_DIR" ]]; then
      echo "Error: no sessions found for channel '$CHANNEL'" >&2
      return 1
    fi
  fi

  local DIFF_FILE="$TARGET_DIR/uncommitted.diff"

  if [[ ! -f "$DIFF_FILE" ]]; then
    echo "Error: uncommitted.diff not found: $DIFF_FILE" >&2
    return 1
  fi

  echo "$DIFF_FILE"
}

# -------------------------
# Dispatch
# -------------------------
case "$SUBCOMMAND" in

  onboard)
    exec "$SCRIPTS/onboard.sh" "$@"
    ;;

  build)
    BUILD_TARGET=""
    REBUILD_BASE_FLAG=""
    TARGET_FLAG_SEEN=false
    REMAINING=()
    for ARG in "$@"; do
      case "$ARG" in
        --target=*)
          TARGET_FLAG_SEEN=true
          BUILD_TARGET="${ARG#--target=}"
          ;;
        --rebuild-base) REBUILD_BASE_FLAG="--rebuild-base" ;;
        *) REMAINING+=("$ARG") ;;
      esac
    done
    parse_flags "${REMAINING[@]}"

    # --target= with no value is an error
    if [[ "$TARGET_FLAG_SEEN" == true && -z "$BUILD_TARGET" ]]; then
      echo "Error: --target requires a value. Use --target=all, --target=sandbox, or --target=<provider>[,<provider>]"
      exit 1
    fi

    # --target absent or --target=all → build everything
    if [[ -z "$BUILD_TARGET" || "$BUILD_TARGET" == "all" ]]; then
      build_sandbox "$PROJECT_NAME" "$SANDBOX_DIR" "$AGENT_SANDBOX_REPO"
      for BASE_DOCKERFILE in "$AGENT_SANDBOX_REPO/providers/"*/base.Dockerfile; do
        [[ -f "$BASE_DOCKERFILE" ]] || continue
        DISCOVERED_PROVIDER="$(basename "$(dirname "$BASE_DOCKERFILE")")"
        build_agent "$DISCOVERED_PROVIDER" "$PROJECT_NAME" "$AGENT_SANDBOX_REPO" $REBUILD_BASE_FLAG
      done
    else
      # Split comma-separated list; build sandbox first if present
      IFS=',' read -ra BUILD_TARGETS <<< "$BUILD_TARGET"
      WANT_SANDBOX=false
      PROVIDER_TARGETS=()
      for T in "${BUILD_TARGETS[@]}"; do
        if [[ "$T" == "sandbox" ]]; then
          WANT_SANDBOX=true
        else
          PROVIDER_TARGETS+=("$T")
        fi
      done
      if [[ "$WANT_SANDBOX" == true ]]; then
        build_sandbox "$PROJECT_NAME" "$SANDBOX_DIR" "$AGENT_SANDBOX_REPO"
      fi
      for P in "${PROVIDER_TARGETS[@]}"; do
        build_agent "$P" "$PROJECT_NAME" "$AGENT_SANDBOX_REPO" $REBUILD_BASE_FLAG
      done
    fi
    ;;

  start)
    parse_flags "$@"
    require_run_args start
    rebuild_if_requested
    "$SCRIPTS/start_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --provider="$PROVIDER_NAME" \
      "${PASSTHROUGH[@]}"
    ;;

  serve)
    parse_flags "$@"
    require_run_args serve
    rebuild_if_requested
    "$SCRIPTS/start_agent.sh" serve \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --provider="$PROVIDER_NAME" \
      "${PASSTHROUGH[@]}"
    ;;

  dry-run)
    parse_flags "$@"
    require_run_args dry-run
    rebuild_if_requested
    "$SCRIPTS/start_agent.sh" dry-run \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --provider="$PROVIDER_NAME" \
      "${PASSTHROUGH[@]}"
    ;;

  stop)
    parse_flags "$@"
    if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name and --sandbox are required"
      exit 1
    fi
    exec "$SCRIPTS/stop.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR"
    ;;

  apply)
    parse_flags "$@"
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi

    [[ -z "$CHANNEL" ]] && CHANNEL="diffs"

    local DIFF_FILE=""
    if [[ -n "$DIFF_ARG" ]]; then
      DIFF_FILE="$DIFF_ARG"
    else
      DIFF_FILE=$(resolve_diff_for_apply "$SANDBOX_DIR" "$CHANNEL" "$SESSION_ARG") || exit 1
    fi

    apply_run "$PROJECT_DIR" "$DIFF_FILE" "$BRANCH" "$FORCE"
    ;;

  draft)
    parse_flags "$@"
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi

    [[ -z "$CHANNEL" ]] && CHANNEL="session"

    local RESOLVE_RESULT SOURCE_DIR SESSION_NAME
    RESOLVE_RESULT=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL" "$SESSION_ARG") || exit 1
    SOURCE_DIR="${RESOLVE_RESULT%%$'\t'*}"
    SESSION_NAME="${RESOLVE_RESULT##*$'\t'}"

    draft_run "$PROJECT_DIR" "$SOURCE_DIR" "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY" "$SESSION_NAME"
    ;;

  confirm)
    parse_flags "$@"
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi
    confirm_run "$PROJECT_DIR" "$SANDBOX_DIR" "$TARGET_BRANCH"
    ;;

  reject)
    parse_flags "$@"
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi
    reject_run "$PROJECT_DIR" "$SANDBOX_DIR"
    ;;

  *)
    echo "Unknown subcommand: $SUBCOMMAND"
    echo "Valid subcommands: onboard, build, start, serve, dry-run, stop, apply, draft, confirm, reject"
    exit 1
    ;;
esac
