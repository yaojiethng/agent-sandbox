#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Usage:
#   agent-sandbox start         --name=<n> --root=<path> [--brief=<rel>] [--env=<rel>] [--serve] [--rebuild]
#   agent-sandbox dry-run       --name=<n> --root=<path> [--brief=<rel>] [--env=<rel>] [--rebuild]
#   agent-sandbox build         --name=<n> --root=<path> [--no-cache]
#   agent-sandbox apply         --root=<path> [--branch=<n>]

set -euo pipefail

AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"
PROVIDER="$AGENT_SANDBOX_REPO/providers/opencode"

SUBCOMMAND="${1:-}"
shift || true

if [[ -z "$SUBCOMMAND" ]]; then
  echo "Usage: agent-sandbox <start|dry-run|build|apply|apply-branch> <flags>"
  exit 1
fi

# -------------------------
# Flag parsing (shared)
# -------------------------
PROJECT_NAME=""
PROJECT_ROOT=""
BRANCH=""
REBUILD=false
PASSTHROUGH=()

for ARG in "$@"; do
  case "$ARG" in
    --name=*)        PROJECT_NAME="${ARG#--name=}" ;;
    --root=*)        PROJECT_ROOT="${ARG#--root=}" ;;
    --branch=*)      BRANCH="${ARG#--branch=}" ;;
    --rebuild)   REBUILD=true ;;
    *)               PASSTHROUGH+=("$ARG") ;;
  esac
done

# -------------------------
# Build helper
# -------------------------
maybe_build() {
  local IMAGE_NAME="opencode-agent-$PROJECT_NAME"
  local IMAGE_EXISTS
  IMAGE_EXISTS=$(docker image inspect "$IMAGE_NAME" >/dev/null 2>&1 && echo yes || echo no)

  if [[ "$REBUILD" == true ]]; then
    echo "Force-building image: $IMAGE_NAME"
    "$PROVIDER/build_agent.sh" --name="$PROJECT_NAME" --root="$PROJECT_ROOT"
  elif [[ "$IMAGE_EXISTS" != yes ]]; then
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
    echo "Valid subcommands: start, dry-run, build, apply"
    exit 1
    ;;
esac
