#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Host-side CLI tool for managing agent-sandbox sessions and exports.
# All subcommands run on the host — never inside a container.
# Inside the container, invoke lib scripts directly (see prompt templates).
#
# Usage:
#   agent-sandbox onboard  --name=<n> --project=<path> --sandbox=<path>
#   agent-sandbox build    [--target=<targets>] --name=<n> --project=<path> --sandbox=<path>
#   agent-sandbox start    --provider=<n> --name=<n> --project=<path> --sandbox=<path> [--refresh|--rebuild] [flags]
#   agent-sandbox serve    --provider=<n> --name=<n> --project=<path> --sandbox=<path> [--refresh|--rebuild] [flags]
#   agent-sandbox dry-run  --provider=<n> --name=<n> --project=<path> --sandbox=<path> [--refresh|--rebuild] [flags]
#   agent-sandbox stop     --sandbox=<path>
#   agent-sandbox apply    --project=<path> --sandbox=<path> [--branch=<n>] [--channel=<channel>] [--session=<name>] [--diff=<path>] [--force]
#   agent-sandbox draft    --project=<path> --sandbox=<path> [--channel=<channel>] [--session=<name>] [--branch-summary=<slug>] [--diffs=<start>..<end>]
#   agent-sandbox confirm  --project=<path> --sandbox=<path> [--target=<branch>]
#   agent-sandbox reject   --project=<path> --sandbox=<path>
#   agent-sandbox package-diff   --sandbox=<path> [--to=<dir>] [--session-summary=<text>] [--all|--baseline=<sha>]
#   agent-sandbox package-branch --sandbox=<path> [--to=<dir>] [--session-summary=<text>] [--baseline=<sha>]
#
# --target accepts: all, sandbox, <provider>, or comma-separated combinations
#   agent-sandbox build --target=all
#   agent-sandbox build --target=hermes
#   agent-sandbox build --target=hermes,sandbox

set -euo pipefail

AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"

# No top-level sources — each dispatch case handles its own dependencies.
# This file is a pure dispatch table: validate required flags, exec the target.

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
  local CHANNEL_ARG=""
  local TARGET_BRANCH=""
  local PROVIDER_NAME=""
  local REFRESH=false
  local REBUILD=false
  local DIFF_ARG=""
  local FORCE=false
  local INTERACTIVE=false
  local BRANCH_FROM=""
  local DIFFS=""
  local BRANCH_SUMMARY=""
  local TO_ARG=""
  local SESSION_SUMMARY_ARG=""
  local ALL_FLAG=false
  local BASELINE_ARG=""
  local -a PASSTHROUGH=()

  parse_flags() {
    for ARG in "$@"; do
      case "$ARG" in
        --name=*)        PROJECT_NAME="${ARG#--name=}" ;;
        --project=*)     PROJECT_DIR="${ARG#--project=}" ;;
        --sandbox=*)     SANDBOX_DIR="${ARG#--sandbox=}" ;;
        --branch=*)      BRANCH="${ARG#--branch=}" ;;
        --session=*)     SESSION_ARG="${ARG#--session=}" ;;
        --channel=*)     CHANNEL_ARG="${ARG#--channel=}" ;;
        --target=*)      TARGET_BRANCH="${ARG#--target=}" ;;
        --branch-from=*) BRANCH_FROM="${ARG#--branch-from=}" ;;
        --diffs=*)       DIFFS="${ARG#--diffs=}" ;;
        --branch-summary=*) BRANCH_SUMMARY="${ARG#--branch-summary=}" ;;
        --to=*)          TO_ARG="${ARG#--to=}" ;;
        --session-summary=*) SESSION_SUMMARY_ARG="${ARG#--session-summary=}" ;;
        --all)           ALL_FLAG=true ;;
        --baseline=*)    BASELINE_ARG="${ARG#--baseline=}" ;;
        --diff=*)        DIFF_ARG="${ARG#--diff=}" ;;
        --force)         FORCE=true ;;
        --interactive)   INTERACTIVE=true ;;
        --provider=*)    PROVIDER_NAME="${ARG#--provider=}" ;;
        --refresh)       REFRESH=true ;;
        --rebuild)       REBUILD=true ;;
        *)               PASSTHROUGH+=("$ARG") ;;
      esac
    done
  }

  require_base_args() {
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name, --project, and --sandbox are required"
      exit 1
    fi
  }

  require_provider_args() {
    if [[ -z "$PROVIDER_NAME" ]]; then
      echo "Error: --provider is required. Example: agent-sandbox start --provider=hermes ..."
      exit 1
    fi
  }

  rebuild_flags() {
    # --rebuild supersedes --refresh: if both are set, emit only --rebuild.
    if [[ "$REBUILD" == true ]]; then
      echo " --rebuild"
    elif [[ "$REFRESH" == true ]]; then
      echo " --refresh"
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
      parse_flags "$@"
      require_base_args

      # Normalise --target (singular, legacy) to --targets (plural, current)
      local TARGETS_ARG=""
      for ARG in "$@"; do
        case "$ARG" in
          --target=*)  TARGETS_ARG="--targets=${ARG#--target=}" ;;
          --targets=*) TARGETS_ARG="$ARG" ;;
        esac
      done

      exec bash "$SCRIPTS/build.sh" \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        ${TARGETS_ARG:---targets=all} \
        $( [[ "$REBUILD" == true ]] && echo "--rebuild" )
      ;;

    start)
      parse_flags "$@"
      require_base_args
      require_provider_args
      "$SCRIPTS/start_agent.sh" standard \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --provider="$PROVIDER_NAME" \
        $(rebuild_flags) \
        "${PASSTHROUGH[@]}"
      ;;

    serve)
      parse_flags "$@"
      require_base_args
      require_provider_args
      "$SCRIPTS/start_agent.sh" serve \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --provider="$PROVIDER_NAME" \
        $(rebuild_flags) \
        "${PASSTHROUGH[@]}"
      ;;

    dry-run)
      parse_flags "$@"
      require_base_args
      require_provider_args
      "$SCRIPTS/start_agent.sh" dry-run \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --provider="$PROVIDER_NAME" \
        $(rebuild_flags) \
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

      # exec workflow script — interactive handling is inside apply.sh's main()
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/apply.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        $( [[ -n "$CHANNEL_ARG" ]] && echo "--channel=$CHANNEL_ARG" ) \
        $( [[ -n "$SESSION_ARG" ]] && echo "--session=$SESSION_ARG" ) \
        $( [[ -n "$DIFF_ARG" ]] && echo "--diff=$DIFF_ARG" ) \
        $( [[ -n "$BRANCH" ]] && echo "--branch=$BRANCH" ) \
        $( [[ "$FORCE" == true ]] && echo "--force" ) \
        $( [[ "$INTERACTIVE" == true ]] && echo "--interactive" )
      ;;

    draft)
      parse_flags "$@"
      if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
        echo "Error: --project and --sandbox are required"
        exit 1
      fi

      # exec workflow script — interactive handling is inside draft.sh's main()
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/draft.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        $( [[ -n "$CHANNEL_ARG" ]] && echo "--channel=$CHANNEL_ARG" ) \
        $( [[ -n "$SESSION_ARG" ]] && echo "--session=$SESSION_ARG" ) \
        $( [[ -n "$BRANCH_FROM" ]] && echo "--branch-from=$BRANCH_FROM" ) \
        $( [[ -n "$DIFFS" ]] && echo "--diffs=$DIFFS" ) \
        $( [[ -n "$BRANCH_SUMMARY" ]] && echo "--branch-summary=$BRANCH_SUMMARY" ) \
        $( [[ "$INTERACTIVE" == true ]] && echo "--interactive" )
      ;;

    confirm)
      parse_flags "$@"
      if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
        echo "Error: --project and --sandbox are required"
        exit 1
      fi
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/confirm.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        $( [[ -n "$TARGET_BRANCH" ]] && echo "--target=$TARGET_BRANCH" )
      ;;

    reject)
      parse_flags "$@"
      if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
        echo "Error: --project and --sandbox are required"
        exit 1
      fi
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/reject.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR"
      ;;

    package-diff)
      parse_flags "$@"
      if [[ -z "$SANDBOX_DIR" ]]; then
        echo "Error: --sandbox is required"
        exit 1
      fi

      local ENV_FILE="$SANDBOX_DIR/.env"
      if [[ ! -f "$ENV_FILE" ]]; then
        echo "Error: .env not found in $SANDBOX_DIR" >&2
        echo "  Run 'agent-sandbox onboard' first to create it." >&2
        exit 1
      fi

      # Derive INPUT_DIR from SANDBOX_DIR
      source "$AGENT_SANDBOX_REPO/src/libs/dirs.sh"
      dirs_resolve "$SANDBOX_DIR"

      if [[ -n "$TO_ARG" ]]; then
        local TO_DIR="$TO_ARG"
      else
        local TO_DIR="$INPUT_DIR"
      fi

      exec bash "$AGENT_SANDBOX_REPO/src/libs/package_diff.sh" \
        --to="$TO_DIR" \
        $( [[ -n "$SESSION_SUMMARY_ARG" ]] && echo "--session-summary=$SESSION_SUMMARY_ARG" ) \
        $( [[ "$ALL_FLAG" == true ]] && echo "--all" ) \
        $( [[ -n "$BASELINE_ARG" ]] && echo "--baseline=$BASELINE_ARG" )
      ;;

    package-branch)
      parse_flags "$@"
      if [[ -z "$SANDBOX_DIR" ]]; then
        echo "Error: --sandbox is required"
        exit 1
      fi

      # Derive INPUT_DIR from SANDBOX_DIR
      source "$AGENT_SANDBOX_REPO/src/libs/dirs.sh"
      dirs_resolve "$SANDBOX_DIR"

      if [[ -n "$TO_ARG" ]]; then
        local TO_DIR="$TO_ARG"
      else
        local TO_DIR="$INPUT_DIR"
      fi

      exec bash "$AGENT_SANDBOX_REPO/src/libs/package_branch.sh" \
        --to="$TO_DIR" \
        $( [[ -n "$SESSION_SUMMARY_ARG" ]] && echo "--session-summary=$SESSION_SUMMARY_ARG" ) \
        $( [[ -n "$BASELINE_ARG" ]] && echo "--baseline=$BASELINE_ARG" )
      ;;

    *)
      echo "Unknown subcommand: $SUBCOMMAND"
      echo "Valid subcommands: onboard, build, start, serve, dry-run, stop, apply, draft, confirm, reject, package-diff, package-branch"
      exit 1
      ;;
  esac
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
