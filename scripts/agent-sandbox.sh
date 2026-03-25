#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Usage:
#   agent-sandbox onboard  --name=<n> --project=<path> --sandbox=<path> [--provider=<n>]
#   agent-sandbox build    [sandbox|<provider>|all] --name=<n> --project=<path> --sandbox=<path> [--provider=<n>]
#   agent-sandbox start    --name=<n> --project=<path> --sandbox=<path> [--provider=<n>] [--brief=<rel>] [--env=<rel>]
#   agent-sandbox serve    --name=<n> --project=<path> --sandbox=<path> [--provider=<n>] [--brief=<rel>] [--env=<rel>]
#   agent-sandbox dry-run  --name=<n> --project=<path> --sandbox=<path> [--provider=<n>] [--brief=<rel>] [--env=<rel>]
#   agent-sandbox rebuild  [start|dry-run|serve] --name=<n> --project=<path> --sandbox=<path> [--provider=<n>] [flags]
#   agent-sandbox apply    --project=<path> --sandbox=<path> [--branch=<n>]

set -euo pipefail

AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"

source "$AGENT_SANDBOX_REPO/libs/containers.sh"

SUBCOMMAND="${1:-}"
shift || true

if [[ -z "$SUBCOMMAND" ]]; then
  echo "Usage: agent-sandbox <onboard|build|start|dry-run|rebuild|apply> <flags>"
  exit 1
fi

# -------------------------
# Flag parsing (shared)
# -------------------------
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR=""
BRANCH=""
PROVIDER_NAME="opencode"   # default provider; override with --provider=<n>
PASSTHROUGH=()

parse_flags() {
  for ARG in "$@"; do
    case "$ARG" in
      --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
      --project=*)  PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)  SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --branch=*)   BRANCH="${ARG#--branch=}" ;;
      --provider=*) PROVIDER_NAME="${ARG#--provider=}" ;;
      *)            PASSTHROUGH+=("$ARG") ;;
    esac
  done
}

# -------------------------
# Dispatch
# -------------------------
case "$SUBCOMMAND" in

  onboard)
    exec "$SCRIPTS/onboard.sh" "$@"
    ;;

  build)
    # Variant is: sandbox | <provider> | all
    # sandbox    — build capability layer image only
    # <provider> — build reasoning layer image for the named provider (e.g. opencode)
    # all        — build both (uses --provider value for reasoning layer)
    # No variant (or explicit 'all') builds both.
    BUILD_VARIANT="${1:-all}"
    case "$BUILD_VARIANT" in
      sandbox|all) shift || true ;;
      --*) BUILD_VARIANT="all" ;;  # no variant given, flags follow immediately
      *)
        # Treat any other non-flag value as a provider name
        PROVIDER_NAME="$BUILD_VARIANT"
        shift || true
        BUILD_VARIANT="provider"
        ;;
    esac
    parse_flags "$@"
    case "$BUILD_VARIANT" in
      sandbox)  build_sandbox "$PROJECT_NAME" "$SANDBOX_DIR" "$AGENT_SANDBOX_REPO" ;;
      provider) build_agent   "$PROVIDER_NAME" "$PROJECT_NAME" "$AGENT_SANDBOX_REPO" ;;
      all)      build_all     "$PROVIDER_NAME" "$PROJECT_NAME" "$SANDBOX_DIR" "$AGENT_SANDBOX_REPO" ;;
    esac
    ;;

  start)
    parse_flags "$@"
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name, --project, and --sandbox are required"
      exit 1
    fi
    "$SCRIPTS/start_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --provider="$PROVIDER_NAME" \
      "${PASSTHROUGH[@]}"
    ;;

  serve)
    parse_flags "$@"
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name, --project, and --sandbox are required"
      exit 1
    fi
    "$SCRIPTS/start_agent.sh" serve \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --provider="$PROVIDER_NAME" \
      "${PASSTHROUGH[@]}"
    ;;

  dry-run)
    parse_flags "$@"
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name, --project, and --sandbox are required"
      exit 1
    fi
    "$SCRIPTS/start_agent.sh" dry-run \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --provider="$PROVIDER_NAME" \
      "${PASSTHROUGH[@]}"
    ;;

  rebuild)
    # Variant is required: start | dry-run | serve
    REBUILD_MODE="${1:-}"
    case "$REBUILD_MODE" in
      start|dry-run|serve) shift || true ;;
      "")
        echo "Error: rebuild requires a mode: start, dry-run, or serve"
        echo "Usage: agent-sandbox rebuild <start|dry-run|serve> --name=<n> --project=<path> --sandbox=<path> [flags]"
        exit 1
        ;;
      *)
        echo "Unknown rebuild mode: $REBUILD_MODE"
        echo "Usage: agent-sandbox rebuild <start|dry-run|serve> --name=<n> --project=<path> --sandbox=<path> [flags]"
        exit 1
        ;;
    esac
    parse_flags "$@"
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: rebuild requires --name, --project, and --sandbox"
      exit 1
    fi
    echo "Rebuilding all images..."
    build_all "$PROVIDER_NAME" "$PROJECT_NAME" "$SANDBOX_DIR" "$AGENT_SANDBOX_REPO" --no-cache
    # Re-dispatch to the target mode
    case "$REBUILD_MODE" in
      start|serve|dry-run)
        exec "$0" "$REBUILD_MODE" \
          --name="$PROJECT_NAME" \
          --project="$PROJECT_DIR" \
          --sandbox="$SANDBOX_DIR" \
          --provider="$PROVIDER_NAME" \
          "${PASSTHROUGH[@]}"
        ;;
    esac
    ;;

  apply)
    parse_flags "$@"
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi
    "$SCRIPTS/apply_workspace.sh" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      ${BRANCH:+--branch="$BRANCH"}
    ;;

  *)
    echo "Unknown subcommand: $SUBCOMMAND"
    echo "Valid subcommands: onboard, build, start, serve, dry-run, rebuild, apply"
    exit 1
    ;;
esac
