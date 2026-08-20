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
#   agent-sandbox apply    --project=<path> --sandbox=<path> --diff=<path> [--branch=<n>] [--force] [--interactive]
#   agent-sandbox draft    --project=<path> --sandbox=<path> [--channel=<channel>] [--bundle=<name>] [--branch-summary=<slug>] [--diffs=<start>..<end>] [--force] [--permissive]
#   agent-sandbox confirm  --project=<path> --sandbox=<path> [--target=<branch>]
#   agent-sandbox reject   --project=<path> --sandbox=<path>
#   agent-sandbox package-branch --sandbox=<path> [--to=<dir>] [--bundle-summary=<text>] [--baseline=<sha>]
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

  require_name_sandbox() {
    if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name and --sandbox are required"
      exit 1
    fi
  }

  require_project_sandbox() {
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi
  }

  # Shared subcommand list — single source of truth for the valid set.
  print_subcommand_list() {
    echo "Valid subcommands: onboard, build, start, serve, dry-run, stop, prune, apply, draft, confirm, reject, package-branch"
  }

  # Route '<sub> --help', 'help <sub>', and 'help --help' to the child's own
  # help (or, for help itself, to the subcommand list). Exec's so the child
  # prints its own usage — the dispatcher only locates it.
  route_help() {
    local sub="$1"
    case "$sub" in
      help)
        echo "Usage: agent-sandbox <subcommand> [flags]"
        echo ""
        print_subcommand_list
        echo ""
        echo "Run 'agent-sandbox help <subcommand>' for detailed usage."
        exit 0
        ;;
      onboard|build|stop|prune)
        exec bash "$SCRIPTS/$sub.sh" --help ;;
      apply|draft|confirm|reject)
        exec bash "$SCRIPTS/workflows/$sub.sh" --help ;;
      start|serve|dry-run)
        exec bash "$SCRIPTS/start_agent.sh" --help ;;
      package-branch)
        exec bash "$AGENT_SANDBOX_REPO/src/libs/package_branch.sh" --help ;;
      *)
        echo "Unknown subcommand: $sub" >&2
        exit 1 ;;
    esac
  }

  # Parse shared flags once, then route. Every subcommand consumes the same
  # flag set; only the required-arg and child-script differ per branch.
  parse_flags "$@"

  # --help/-h on any subcommand delegates to the child's own help BEFORE the
  # per-case required-arg checks below — mirroring each leaf script's own
  # convention (parse_help_flag runs before arg validation). This makes
  # `agent-sandbox <sub> --help` work uniformly for every subcommand, and
  # `agent-sandbox help --help` show help's own page (the subcommand list).
  for _arg in "$@"; do
    case "$_arg" in
      --help|-h) route_help "$SUBCOMMAND" ;;
    esac
  done

  # -------------------------
  # Dispatch
  # -------------------------
  case "$SUBCOMMAND" in

    onboard)
      require_base_args
      exec bash "$SCRIPTS/onboard.sh" \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    build)
      require_base_args
      exec bash "$SCRIPTS/build.sh" \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    start)
      require_base_args
      exec bash "$SCRIPTS/start_agent.sh" standard \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    serve)
      require_base_args
      exec bash "$SCRIPTS/start_agent.sh" serve \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    dry-run)
      require_base_args
      exec bash "$SCRIPTS/start_agent.sh" dry-run \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    stop)
      require_name_sandbox
      exec bash "$SCRIPTS/stop.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR" "${PASSTHROUGH[@]}"
      ;;

    prune)
      require_name_sandbox
      exec bash "$SCRIPTS/prune.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR" "${PASSTHROUGH[@]}"
      ;;

    apply)
      require_project_sandbox
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/apply.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    draft)
      require_project_sandbox
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/draft.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    confirm)
      require_project_sandbox
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/confirm.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    reject)
      require_project_sandbox
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/reject.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    package-branch)
      if [[ -z "$SANDBOX_DIR" ]]; then
        echo "Error: --sandbox is required"
        exit 1
      fi
      exec bash "$AGENT_SANDBOX_REPO/src/libs/package_branch.sh" \
        "${PASSTHROUGH[@]}"
      ;;

    help)
      # help is itself a subcommand; its page is the subcommand list.
      # Bare 'help' -> route_help help (prints the list). 'help <sub>' and
      # 'help --help' are handled by route_help too (no recursion).
      route_help "${1:-help}"
      ;;

    *)
      echo "Unknown subcommand: $SUBCOMMAND"
      print_subcommand_list
      exit 1
      ;;
  esac
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
