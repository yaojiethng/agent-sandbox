#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Host-side CLI tool for managing agent-sandbox sessions and exports.
# All subcommands run on the host — never inside a container.
# Inside the container, invoke lib scripts directly (see prompt templates).
#
# Usage:
#   agent-sandbox onboard  --name=<n> --project=<path> --sandbox=<path>
#   agent-sandbox build    [--targets=<targets>] --name=<n> --project=<path> --sandbox=<path>
#   agent-sandbox start    --provider=<n> --name=<n> --project=<path> --sandbox=<path> [--refresh|--rebuild] [flags]
#   agent-sandbox serve    --provider=<n> --name=<n> --project=<path> --sandbox=<path> [--refresh|--rebuild] [flags]
#   agent-sandbox dry-run  --provider=<n> --name=<n> --project=<path> --sandbox=<path> [--refresh|--rebuild] [flags]
#   agent-sandbox stop     --name=<n> --sandbox=<path>
#   agent-sandbox apply    --project=<path> --sandbox=<path> [--branch=<n>] [--channel=<channel>] [--session=<name>] [--diff=<path>] [--force]
#   agent-sandbox draft    --project=<path> --sandbox=<path> [--channel=<channel>] [--session=<name>] [--branch-summary=<slug>] [--diffs=<start>..<end>]
#   agent-sandbox confirm  --project=<path> --sandbox=<path> [--target=<branch>]
#   agent-sandbox reject   --project=<path> --sandbox=<path>
#   agent-sandbox package-diff   --sandbox=<path> [--to=<dir>] [--session-summary=<text>] [--all|--baseline=<sha>]
#   agent-sandbox package-branch --sandbox=<path> [--to=<dir>] [--session-summary=<text>] [--baseline=<sha>]
#
# --targets accepts: all, sandbox, <provider>, or comma-separated combinations
#   agent-sandbox build --targets=all
#   agent-sandbox build --targets=hermes
#   agent-sandbox build --targets=hermes,sandbox
#
# --target (singular) is deprecated and will error.

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
    echo "Usage: agent-sandbox <onboard|build|start|serve|dry-run|stop|prune|apply|draft|confirm|reject> <flags>"
    exit 1
  fi

  # -------------------------
  # Flag parsing (shared)
  # -------------------------
  local PROJECT_NAME=""
  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local -a PASSTHROUGH=()

  parse_flags() {
    for ARG in "$@"; do
      case "$ARG" in
        --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
        --project=*) PROJECT_DIR="${ARG#--project=}" ;;
        --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
        *)           PASSTHROUGH+=("$ARG") ;;
      esac
    done
  }

  require_base_args() {
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name, --project, and --sandbox are required"
      exit 1
    fi
  }

  # -------------------------
  # Dispatch
  # -------------------------
  case "$SUBCOMMAND" in

    onboard)
      parse_flags "$@"
      require_base_args
      exec "$SCRIPTS/onboard.sh" \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    build)
      parse_flags "$@"
      require_base_args
      exec bash "$SCRIPTS/build.sh" \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    start)
      parse_flags "$@"
      require_base_args
      "$SCRIPTS/start_agent.sh" standard \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    serve)
      parse_flags "$@"
      require_base_args
      "$SCRIPTS/start_agent.sh" serve \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    dry-run)
      parse_flags "$@"
      require_base_args
      "$SCRIPTS/start_agent.sh" dry-run \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    stop)
      parse_flags "$@"
      if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
        echo "Error: --name and --sandbox are required"
        exit 1
      fi
      exec "$SCRIPTS/stop.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR" "${PASSTHROUGH[@]}"
      ;;

    prune)
      parse_flags "$@"
      if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
        echo "Error: --name and --sandbox are required"
        exit 1
      fi
      exec "$SCRIPTS/prune.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR"
      ;;

    apply)
      parse_flags "$@"
      if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
        echo "Error: --project and --sandbox are required"
        exit 1
      fi

      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/apply.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    draft)
      parse_flags "$@"
      if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
        echo "Error: --project and --sandbox are required"
        exit 1
      fi

      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/draft.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
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
        "${PASSTHROUGH[@]}"
      ;;

    reject)
      parse_flags "$@"
      if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
        echo "Error: --project and --sandbox are required"
        exit 1
      fi
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/reject.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
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

      exec bash "$AGENT_SANDBOX_REPO/src/libs/package_diff.sh" \
        "${PASSTHROUGH[@]}"
      ;;

    package-branch)
      parse_flags "$@"
      if [[ -z "$SANDBOX_DIR" ]]; then
        echo "Error: --sandbox is required"
        exit 1
      fi

      exec bash "$AGENT_SANDBOX_REPO/src/libs/package_branch.sh" \
        "${PASSTHROUGH[@]}"
      ;;

    help)
      if [[ -z "${1:-}" ]]; then
        echo "Usage: agent-sandbox <subcommand> [flags]"
        echo ""
        echo "Valid subcommands: onboard, build, start, serve, dry-run, stop, prune, apply, draft, confirm, reject, package-diff, package-branch"
        echo ""
        echo "Run 'agent-sandbox help <subcommand>' for detailed usage."
        exit 0
      fi

      local SUB="$1"
      case "$SUB" in
        onboard|build|stop|prune)
          exec bash "$SCRIPTS/$SUB.sh" --help ;;
        apply|draft|confirm|reject)
          exec bash "$SCRIPTS/workflows/$SUB.sh" --help ;;
        start|serve|dry-run)
          exec bash "$SCRIPTS/start_agent.sh" --help ;;
        package-diff)
          exec bash "$AGENT_SANDBOX_REPO/src/libs/package_diff.sh" --help ;;
        package-branch)
          exec bash "$AGENT_SANDBOX_REPO/src/libs/package_branch.sh" --help ;;
        *)
          echo "Unknown subcommand: $SUB" >&2
          exit 1 ;;
      esac
      ;;

    *)
      echo "Unknown subcommand: $SUBCOMMAND"
      echo "Valid subcommands: onboard, build, start, serve, dry-run, stop, prune, apply, draft, confirm, reject, package-diff, package-branch"
      exit 1
      ;;
  esac
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
