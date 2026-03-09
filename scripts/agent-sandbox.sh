#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Usage:
#   agent-sandbox start         --name=<n> --root=<path> [--brief=<rel>] [--env=<rel>] [--serve]
#   agent-sandbox dry-run       --name=<n> --root=<path> [--brief=<rel>] [--env=<rel>]
#   agent-sandbox build         --name=<n> --root=<path> [--no-cache]
#   agent-sandbox apply         --root=<path> [--branch=<n>]
#   agent-sandbox rebuild <subcommand> <flags>  — force rebuild then dispatch

set -euo pipefail

AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"
PROVIDER="$AGENT_SANDBOX_REPO/providers/opencode"

SUBCOMMAND="${1:-}"
shift || true

if [[ -z "$SUBCOMMAND" ]]; then
  echo "Usage: agent-sandbox <start|dry-run|build|apply|rebuild> <flags>"
  exit 1
fi

# -------------------------
# Rebuild — force build then re-exec with remaining args
# -------------------------
# Must be handled before flag parsing so it works with any subcommand.
if [[ "$SUBCOMMAND" == "rebuild" ]]; then
  if [[ -z "${1:-}" ]]; then
    echo "Usage: agent-sandbox rebuild <start|dry-run> --name=<n> --root=<path> ..."
    exit 1
  fi
  # Extract --name and --root from remaining args for the build step.
  _NAME=""
  _ROOT=""
  for _ARG in "$@"; do
    case "$_ARG" in
      --name=*) _NAME="${_ARG#--name=}" ;;
      --root=*) _ROOT="${_ARG#--root=}" ;;
    esac
  done
  if [[ -z "$_NAME" || -z "$_ROOT" ]]; then
    echo "Error: rebuild requires --name and --root"
    exit 1
  fi
  echo "Rebuilding image: opencode-agent-$_NAME"
  "$PROVIDER/build_agent.sh" --name="$_NAME" --root="$_ROOT"
  exec "$0" "$@"
fi

# -------------------------
# Flag parsing (shared)
# -------------------------
PROJECT_NAME=""
PROJECT_ROOT=""
BRANCH=""
PASSTHROUGH=()

for ARG in "$@"; do
  case "$ARG" in
    --name=*)   PROJECT_NAME="${ARG#--name=}" ;;
    --root=*)   PROJECT_ROOT="${ARG#--root=}" ;;
    --branch=*) BRANCH="${ARG#--branch=}" ;;
    *)          PASSTHROUGH+=("$ARG") ;;
  esac
done

# -------------------------
# Build helper
# -------------------------
maybe_build() {
  local IMAGE_NAME="opencode-agent-$PROJECT_NAME"
  if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Image not found, building: $IMAGE_NAME"
    "$PROVIDER/build_agent.sh" --name="$PROJECT_NAME" --root="$PROJECT_ROOT"
  fi
}

# -------------------------
# Dispatch
# -------------------------
case "$SUBCOMMAND" in
  start)
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_ROOT" ]]; then
      echo "Error: --name and --root are required"
      exit 1
    fi
    maybe_build
    "$PROVIDER/start_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --root="$PROJECT_ROOT" \
      "${PASSTHROUGH[@]}"
    ;;

  dry-run)
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_ROOT" ]]; then
      echo "Error: --name and --root are required"
      exit 1
    fi
    maybe_build
    "$PROVIDER/start_agent.sh" dry-run \
      --name="$PROJECT_NAME" \
      --root="$PROJECT_ROOT" \
      "${PASSTHROUGH[@]}"
    ;;

  build)
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_ROOT" ]]; then
      echo "Error: --name and --root are required"
      exit 1
    fi
    "$PROVIDER/build_agent.sh" \
      --name="$PROJECT_NAME" \
      --root="$PROJECT_ROOT" \
      "${PASSTHROUGH[@]}"
    ;;

  apply)
    if [[ -z "$PROJECT_ROOT" ]]; then
      echo "Error: --root is required"
      exit 1
    fi
    "$SCRIPTS/apply_workspace.sh" \
      --root="$PROJECT_ROOT" \
      ${BRANCH:+--branch="$BRANCH"}
    ;;

  *)
    echo "Unknown subcommand: $SUBCOMMAND"
    echo "Valid subcommands: start, dry-run, build, apply, rebuild"
    exit 1
    ;;
esac
