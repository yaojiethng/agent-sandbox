#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Host-side CLI tool for managing agent-sandbox sessions and exports.
# All subcommands run on the host  --  never inside a container.
# Inside the container, invoke lib scripts directly (see prompt templates).
#
# Usage:
#   agent-sandbox onboard  --name=<n> --project=<path> --sandbox=<path>
#   agent-sandbox build    [--targets=<targets>] [identity] [--env=<path>]
#   agent-sandbox start    [--serve] --provider=<n> [identity] [--env=<path>] [--refresh|--rebuild] [flags]
#   agent-sandbox dry-run  --provider=<n> [identity] [--env=<path>] [--fast] [flags]
#   agent-sandbox resume   [identity] [--env=<path>] [--session-id=<id>] [--list] [--interactive]
#   agent-sandbox stop     [identity] [--env=<path>] [--session-id=<id>] [--prune]
#   agent-sandbox prune    [identity] [--env=<path>] [--stale=<kind>] [--provider=<n>] [--age-days=<n>] [--interactive] [--dry-run]
#   agent-sandbox apply    --project=<path> --sandbox=<path> --diff=<path> [--branch=<n>] [--force] [--interactive]
#   agent-sandbox draft    --project=<path> --sandbox=<path> [--channel=<channel>] [--bundle=<name>] [--branch-summary=<slug>] [--diffs=<start>..<end>] [--force] [--permissive]
#   agent-sandbox confirm  --project=<path> --sandbox=<path> [--target=<branch>]
#   agent-sandbox reject   --project=<path> --sandbox=<path>
#   agent-sandbox package-branch --sandbox=<path> [--to=<dir>] [--bundle-summary=<text>] [--baseline=<sha>]
#
# --env=<path> is an absolute path or a name relative to the sandbox dir; it sets
# the per-sandbox .env used for both identity resolution and the run's env load.
#
# identity = [--name=<n>] [--project=<path>] [--sandbox=<path>]. Every command
# keeps a hard identity requirement, but it need not be passed per invocation:
# each missing field resolves from the AGENT_SANDBOX_<KEY> env level, then the
# per-sandbox .env located via --env (else <sandbox>/.env, else the invocation
# CWD). onboard is the exception: it creates the .env and requires
# --name/--project/--sandbox. The sandbox Makefile passes --env=$(ENV_FILE).
#
# --targets accepts: all, sandbox, <provider>, or comma-separated combinations
#   agent-sandbox build --targets=all
#   agent-sandbox build --targets=hermes
#   agent-sandbox build --targets=hermes,sandbox
#
# --target (singular) is deprecated and will error.

set -euo pipefail

# Self-locating dispatcher (ADR harness_versioning.md, host surface): the
# installed CLI is a symlink into the repo, so resolving $0 yields the repo
# itself -- the installed tool IS the working tree's copy and no independent
# host version exists by construction. Rollback is `git checkout <sha>`.
_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
AGENT_SANDBOX_REPO="$(cd "$(dirname "$_SELF")/.." && pwd)"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"

# No top-level sources  --  each dispatch case handles its own dependencies.
# This file is a pure dispatch table: validate required flags, exec the target.

# =============================================================================
# CLI entry point
# =============================================================================
# When sourced (for tests), only functions are defined  --  dispatch is not run.
# When executed directly, main() parses flags and dispatches to subcommands.

main() {
  local SUBCOMMAND="${1:-}"
  shift || true

  if [[ -z "$SUBCOMMAND" ]]; then
    echo "Usage: agent-sandbox <onboard|build|start|dry-run|resume|stop|prune|apply|draft|confirm|reject> <flags>"
    exit 1
  fi

  # -------------------------
  # Flag parsing (shared)
  # -------------------------
  local PROJECT_NAME=""
  local PROJECT_DIR=""
  local SANDBOX_DIR=""
  local ENV_PATH=""
  local -a PASSTHROUGH=()

  parse_flags() {
    for ARG in "$@"; do
      case "$ARG" in
        --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
        --project=*) PROJECT_DIR="${ARG#--project=}" ;;
        --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
        --env=*)     ENV_PATH="${ARG#--env=}" ;;
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

  # resolve_identity [name dir sandbox]  --  thin-interface seam.
  #
  # Fills missing identity fields instead of demanding flags per invocation:
  # for each requested field, explicit flag > AGENT_SANDBOX_<KEY> env var > the
  # per-sandbox .env (--env path, else <sandbox>/.env, else the invocation CWD).
  # onboard is exempt (it creates the .env). Every command keeps its hard
  # identity requirement: an unresolvable field is a loud error, not a default.
  resolve_identity() {
    local need_name=false need_dir=false need_sandbox=false _r
    local missing=false
    for _r in "$@"; do
      case "$_r" in
        name)    need_name=true ;;
        dir)     need_dir=true ;;
        sandbox) need_sandbox=true ;;
      esac
    done
    if $need_name && [[ -z "$PROJECT_NAME" ]]; then missing=true; fi
    if $need_dir && [[ -z "$PROJECT_DIR" ]]; then missing=true; fi
    if $need_sandbox && [[ -z "$SANDBOX_DIR" ]]; then missing=true; fi
    if $missing; then
      # shellcheck disable=SC1090
      source "$AGENT_SANDBOX_REPO/src/libs/env_resolve.sh"
      local ep="$ENV_PATH"
      if $need_sandbox && [[ -z "$SANDBOX_DIR" ]]; then
        # A relative --env has no sandbox anchor yet: read SANDBOX from the CWD
        # .env fallback so the sandbox-relative contract can apply afterwards.
        local sbx_file="$ep"
        if [[ -n "$sbx_file" && "$sbx_file" != /* ]]; then
          sbx_file="$(default_env_file "")"
        fi
        SANDBOX_DIR="$(env_resolve_value "" AGENT_SANDBOX_SANDBOX_DIR SANDBOX_DIR "$sbx_file")" \
          || { echo "Error: --sandbox not set and unresolvable (AGENT_SANDBOX_SANDBOX_DIR, or .env via --env/CWD). Run: agent-sandbox onboard --sandbox=<path>" >&2; exit 1; }
      fi
      # --env contract: absolute -> the path; relative -> a name relative to the
      # sandbox dir; empty -> <sandbox>/.env. One meaning across resolver and leaf.
      if [[ -z "$ep" ]]; then
        ep="$(default_env_file "$SANDBOX_DIR")"
      elif [[ "$ep" != /* ]]; then
        ep="$SANDBOX_DIR/$ep"
      fi
      if $need_dir && [[ -z "$PROJECT_DIR" ]]; then
        PROJECT_DIR="$(env_resolve_value "" AGENT_SANDBOX_PROJECT_DIR PROJECT_DIR "$ep")" \
          || { echo "Error: --project not set and unresolvable (AGENT_SANDBOX_PROJECT_DIR or .env). Run: agent-sandbox onboard --project=<path>" >&2; exit 1; }
      fi
      if $need_name && [[ -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME="$(env_resolve_value "" AGENT_SANDBOX_PROJECT_NAME PROJECT_NAME "$ep")" \
          || { echo "Error: --name not set and unresolvable (AGENT_SANDBOX_PROJECT_NAME or .env). Run: agent-sandbox onboard --name=<name>" >&2; exit 1; }
      fi
    fi
  }

  # Shared subcommand list  --  single source of truth for the valid set.
  print_subcommand_list() {
    echo "Valid subcommands: onboard, build, start, dry-run, resume, stop, prune, apply, draft, confirm, reject, package-branch"
  }

  # Route '<sub> --help', 'help <sub>', and 'help --help' to the child's own
  # help (or, for help itself, to the subcommand list). Exec's so the child
  # prints its own usage  --  the dispatcher only locates it.
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
      resume)
        exec bash "$SCRIPTS/resume_agent.sh" --help ;;
      apply|draft|confirm|reject)
        exec bash "$SCRIPTS/workflows/$sub.sh" --help ;;
      start|dry-run)
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
  # per-case required-arg checks below  --  mirroring each leaf script's own
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
      resolve_identity name dir sandbox
      exec bash "$SCRIPTS/build.sh" \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    start)
      resolve_identity name dir sandbox
      exec bash "$SCRIPTS/start_agent.sh" standard \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --env="$ENV_PATH" \
        "${PASSTHROUGH[@]}"
      ;;

    dry-run)
      resolve_identity name dir sandbox
      exec bash "$SCRIPTS/start_agent.sh" dry-run \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --env="$ENV_PATH" \
        "${PASSTHROUGH[@]}"
      ;;

    stop)
      resolve_identity name dir sandbox
      exec bash "$SCRIPTS/stop.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR" --project="$PROJECT_DIR" "${PASSTHROUGH[@]}"
      ;;

    resume)
      resolve_identity sandbox
      exec bash "$SCRIPTS/resume_agent.sh" \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --env="$ENV_PATH" \
        "${PASSTHROUGH[@]}"
      ;;

    prune)
      resolve_identity name dir sandbox
      exec bash "$SCRIPTS/prune.sh" --name="$PROJECT_NAME" --project="$PROJECT_DIR" --sandbox="$SANDBOX_DIR" "${PASSTHROUGH[@]}"
      ;;

    apply)
      resolve_identity dir sandbox
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/apply.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    draft)
      resolve_identity dir sandbox
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/draft.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    confirm)
      resolve_identity dir sandbox
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/confirm.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    reject)
      resolve_identity dir sandbox
      exec bash "$AGENT_SANDBOX_REPO/scripts/workflows/reject.sh" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        "${PASSTHROUGH[@]}"
      ;;

    package-branch)
      resolve_identity sandbox
      exec bash "$AGENT_SANDBOX_REPO/src/libs/package_branch.sh" \
        --sandbox="$SANDBOX_DIR" \
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
