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
#   agent-sandbox start    [--serve] --provider=<n> [identity] [--env=<path>] [--refresh|--rebuild] [--interactive] [flags]
#   agent-sandbox dry-run  --provider=<n> [identity] [--env=<path>] [--fast] [flags]
#   agent-sandbox resume   [identity] [--env=<path>] [--session-id=<id>] [--list] [--interactive]
#   agent-sandbox stop     [identity] [--env=<path>] [--session-id=<id>] [--prune]
#   agent-sandbox prune    [identity] [--env=<path>] [--stale=<kind>] [--provider=<n>] [--age-days=<n>] [--interactive] [--dry-run]
#   agent-sandbox apply    --project=<path> --sandbox=<path> --diff=<path> [--branch=<n>] [--force] [--interactive]
#   agent-sandbox draft    --project=<path> --sandbox=<path> [--channel=<channel>] [--bundle=<name>] [--branch-summary=<slug>] [--diffs=<start>..<end>] [--force] [--permissive] [--interactive]
#   agent-sandbox confirm  --project=<path> --sandbox=<path> [--target=<branch>] [--new]
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
# An already-exported AGENT_SANDBOX_REPO wins (tests preset it before sourcing).
_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$(dirname "$_SELF")/.." && pwd)}"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"

# Shared parsing and the resolver core are sourced once at module scope; the
# dispatcher is a thin route table over them. Identity flags become optional via
# resolve_identity, which delegates to the canonical resolver.
source "$AGENT_SANDBOX_REPO/src/libs/common.sh"
source "$AGENT_SANDBOX_REPO/src/libs/cli.sh"
source "$AGENT_SANDBOX_REPO/src/libs/env_resolve.sh"

# Dispatcher state, reset by main() on every invocation (tests call main twice).
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR=""
ENV_REL=""
PASSTHROUGH=()

# =============================================================================
# Helpers (file scope)
# =============================================================================

# require_base_args  --  onboard's hard requirement (it creates the .env, so it
# cannot resolve identity from one).
require_base_args() {
  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --name, --project, and --sandbox are required"
    exit 1
  fi
}

# resolve_identity [name dir sandbox]  --  thin-interface seam over the
# canonical resolver. For each requested field: explicit > AGENT_SANDBOX_<KEY>
# > the .env (via ENV_REL, else <sandbox>/.env, else CWD) > a hard error.
# onboard is exempt. The resolver emits the single per-key error message and
# exports the normalized ENV_FILE.
resolve_identity() {
  env_resolve_identity "$PROJECT_NAME" "$PROJECT_DIR" "$SANDBOX_DIR" "$ENV_REL" "$@" || exit 1
}

# print_subcommand_list  --  single source of truth for the valid set.
print_subcommand_list() {
  echo "Valid subcommands: onboard, build, start, dry-run, resume, stop, prune, apply, draft, confirm, reject, package-branch"
}

# route_help SUB  --  '<sub> --help', 'help <sub>', and 'help --help' route to
# the child's own help (or, for help itself, to the subcommand list). Exec's so
# the child prints its own usage  --  the dispatcher only locates it.
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

  PROJECT_NAME=""
  PROJECT_DIR=""
  SANDBOX_DIR=""
  ENV_REL=""
  PASSTHROUGH=()

  # Identity and --env parse through the canonical cli.sh spec; every other
  # argument is collected in order and forwarded to the leaf unchanged.
  parse_args_collect PASSTHROUGH --env=ENV_REL \
      --name=PROJECT_NAME --project=PROJECT_DIR --sandbox=SANDBOX_DIR \
      -- "$@"

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
        --env="$ENV_REL" \
        "${PASSTHROUGH[@]}"
      ;;

    dry-run)
      resolve_identity name dir sandbox
      exec bash "$SCRIPTS/start_agent.sh" dry-run \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --env="$ENV_REL" \
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
        --env="$ENV_REL" \
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