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
#   agent-sandbox apply    --project=<path> --sandbox=<path> [--branch=<n>] [--session=<name>] [--force]
#   agent-sandbox draft    --project=<path> --sandbox=<path> [--session=<path>] [--branch-summary=<slug>]
#   agent-sandbox confirm  --project=<path> --sandbox=<path> [--target=<branch>]
#   agent-sandbox reject   --project=<path> --sandbox=<path>
#
# --target accepts: all, sandbox, <provider>, or comma-separated combinations
#   agent-sandbox build --target=all
#   agent-sandbox build --target=hermes
#   agent-sandbox build --target=hermes,sandbox

set -euo pipefail

AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"

source "$AGENT_SANDBOX_REPO/libs/containers.sh"

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
    "$SCRIPTS/apply_workspace.sh" apply \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      ${SESSION_ARG:+--session="$SESSION_ARG"} \
      ${BRANCH:+--branch="$BRANCH"} \
      ${FORCE:+--force}
    ;;

  draft)
    parse_flags "$@"
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi
    "$SCRIPTS/apply_workspace.sh" draft \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      ${SESSION_ARG:+--session="$SESSION_ARG"} \
      ${BRANCH_FROM:+--branch-from="$BRANCH_FROM"} \
      ${DIFFS:+--diffs="$DIFFS"} \
      ${BRANCH_SUMMARY:+--branch-summary="$BRANCH_SUMMARY"}
    ;;

  confirm)
    parse_flags "$@"
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi
    "$SCRIPTS/apply_workspace.sh" confirm \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      ${TARGET_BRANCH:+--target="$TARGET_BRANCH"}
    ;;

  reject)
    parse_flags "$@"
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi
    "$SCRIPTS/apply_workspace.sh" reject \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR"
    ;;

  *)
    echo "Unknown subcommand: $SUBCOMMAND"
    echo "Valid subcommands: onboard, build, start, serve, dry-run, stop, apply, draft, confirm, reject"
    exit 1
    ;;
esac
