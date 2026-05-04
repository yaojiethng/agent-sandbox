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
#   agent-sandbox apply    --project=<path> --sandbox=<path> [--branch=<n>] [--session=<name|path>] [--diff=<path>] [--force]
#   agent-sandbox draft    --project=<path> --sandbox=<path> [--session=<name|path>] [--branch-summary=<slug>]
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
source "$AGENT_SANDBOX_REPO/libs/draft_workflow.sh"
source "$AGENT_SANDBOX_REPO/libs/diff_workflow.sh"

# =============================================================================
# CLI entry point
# =============================================================================
# When sourced (for tests), only functions are defined — dispatch is not run.
# When executed directly, main() parses flags and dispatches to subcommands.

main() {
  local SUBCOMMAND="${1:-}"
  shift || true

  if [[ -z "$SUBCOMMAND" ]]; then
    echo "Usage: agent-sandbox <onboard|build|start|serve|dry-run|stop|apply|draft|confirm|reject> <flags>"
    exit 1
  fi

  # -------------------------
  # Flag parsing (shared)
  # -------------------------
  local PROJECT_NAME=""
  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local BRANCH=""
  local SESSION_ARG=""
  local TARGET_BRANCH=""
  local PROVIDER_NAME=""
  local REBUILD=false
  local REBUILD_BASE=false
  local DIFF_ARG=""
  local FORCE=false
  local BRANCH_FROM=""
  local DIFFS=""
  local BRANCH_SUMMARY=""
  local -a PASSTHROUGH=()

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
  # Dispatch
  # -------------------------
  case "$SUBCOMMAND" in

    onboard)
      exec "$SCRIPTS/onboard.sh" "$@"
      ;;

    build)
      local BUILD_TARGET=""
      local REBUILD_BASE_FLAG=""
      local TARGET_FLAG_SEEN=false
      local -a REMAINING=()
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

      if [[ "$TARGET_FLAG_SEEN" == true && -z "$BUILD_TARGET" ]]; then
        echo "Error: --target requires a value. Use --target=all, --target=sandbox, or --target=<provider>[,<provider>]"
        exit 1
      fi

      if [[ -z "$BUILD_TARGET" || "$BUILD_TARGET" == "all" ]]; then
        build_sandbox "$PROJECT_NAME" "$SANDBOX_DIR" "$AGENT_SANDBOX_REPO"
        for BASE_DOCKERFILE in "$AGENT_SANDBOX_REPO/providers/"*/base.Dockerfile; do
          [[ -f "$BASE_DOCKERFILE" ]] || continue
          local DISCOVERED_PROVIDER
          DISCOVERED_PROVIDER="$(basename "$(dirname "$BASE_DOCKERFILE")")"
          build_agent "$DISCOVERED_PROVIDER" "$PROJECT_NAME" "$AGENT_SANDBOX_REPO" $REBUILD_BASE_FLAG
        done
      else
        IFS=',' read -ra BUILD_TARGETS <<< "$BUILD_TARGET"
        local WANT_SANDBOX=false
        local -a PROVIDER_TARGETS=()
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
          build_agent "$P" "$PROJECT_NAME" "$SANDBOX_DIR" "$AGENT_SANDBOX_REPO" $REBUILD_BASE_FLAG
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
      apply_run "$PROJECT_DIR" "$SANDBOX_DIR" "$SESSION_ARG" "$DIFF_ARG" "$BRANCH" "$FORCE"
      ;;

    draft)
      parse_flags "$@"
      if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
        echo "Error: --project and --sandbox are required"
        exit 1
      fi
      draft_run "$PROJECT_DIR" "$SANDBOX_DIR" "$SESSION_ARG" "$BRANCH_FROM" "$DIFFS" "$BRANCH_SUMMARY"
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
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
