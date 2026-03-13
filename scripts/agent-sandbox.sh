#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Usage:
#   agent-sandbox start         --name=<n> --project=<path> [--sandbox=<path>] [--brief=<rel>] [--env=<rel>] [--serve]
#   agent-sandbox dry-run       --name=<n> --project=<path> [--sandbox=<path>] [--brief=<rel>] [--env=<rel>]
#   agent-sandbox build         --name=<n> --project=<path> [--no-cache]
#   agent-sandbox apply         --project=<path> --sandbox=<path> [--branch=<n>]
#   agent-sandbox onboard       <workflow> <flags>  — one-time project onboarding
#   agent-sandbox rebuild       <subcommand> <flags>  — force rebuild then dispatch

set -euo pipefail

AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"
PROVIDER="$AGENT_SANDBOX_REPO/providers/opencode"

SUBCOMMAND="${1:-}"
shift || true

STALE_MSG="agent-sandbox: image may be stale — source files have changed since last build. Run: agent-sandbox rebuild <subcommand> to rebuild."

if [[ -z "$SUBCOMMAND" ]]; then
  echo "Usage: agent-sandbox <start|dry-run|build|apply|onboard|rebuild> <flags>"
  exit 1
fi

# -------------------------
# Rebuild — force build then re-exec with remaining args
# -------------------------
# Must be handled before flag parsing so it works with any subcommand.
if [[ "$SUBCOMMAND" == "rebuild" ]]; then
  if [[ -z "${1:-}" ]]; then
    echo "Usage: agent-sandbox rebuild <start|dry-run> --name=<n> --project=<path> ..."
    exit 1
  fi
  # Extract --name and --project from remaining args for the build step.
  _NAME=""
  _PROJECT=""
  for _ARG in "$@"; do
    case "$_ARG" in
      --name=*)    _NAME="${_ARG#--name=}" ;;
      --project=*) _PROJECT="${_ARG#--project=}" ;;
    esac
  done
  if [[ -z "$_NAME" || -z "$_PROJECT" ]]; then
    echo "Error: rebuild requires --name and --project"
    exit 1
  fi
  _STALE_MSG="$STALE_MSG"
  echo "Rebuilding image: opencode-agent-$_NAME"
  if ! "$PROVIDER/build_agent.sh" --name="$_NAME" --project="$_PROJECT"; then
    echo "$_STALE_MSG"
    exit 1
  fi
  exec "$0" "$@"
fi

# -------------------------
# Flag parsing (shared)
# -------------------------
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR=""
BRANCH=""
PASSTHROUGH=()

for ARG in "$@"; do
  case "$ARG" in
    --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
    --project=*) PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --branch=*)  BRANCH="${ARG#--branch=}" ;;
    *)           PASSTHROUGH+=("$ARG") ;;
  esac
done

# -------------------------
# Preflight — build-if-missing, then staleness check
# -------------------------
preflight() {
  local IMAGE_NAME="opencode-agent-$PROJECT_NAME"

  # Build if image does not exist
  if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Image not found, building: $IMAGE_NAME"
    "$PROVIDER/build_agent.sh" --name="$PROJECT_NAME" --project="$PROJECT_DIR"
    return
  fi

  # Staleness check — compare current digest against label on existing image
  source "$AGENT_SANDBOX_REPO/lib/image.sh"
  local CURRENT_DIGEST IMAGE_DIGEST
  CURRENT_DIGEST=$(image_compute_digest "$AGENT_SANDBOX_REPO" "opencode")
  IMAGE_DIGEST=$(docker inspect \
    --format '{{ index .Config.Labels "agent-sandbox.digest" }}' \
    "$IMAGE_NAME" 2>/dev/null || true)

  if [[ "$CURRENT_DIGEST" != "$IMAGE_DIGEST" ]]; then
    # Emit warning last so it is not buried — run proceeds regardless
    echo "$STALE_MSG"
  fi
}

# -------------------------
# Dispatch
# -------------------------
case "$SUBCOMMAND" in
  start)
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" ]]; then
      echo "Error: --name and --project are required"
      exit 1
    fi
    preflight
    "$PROVIDER/start_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      ${SANDBOX_DIR:+--sandbox="$SANDBOX_DIR"} \
      "${PASSTHROUGH[@]}"
    ;;

  dry-run)
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" ]]; then
      echo "Error: --name and --project are required"
      exit 1
    fi
    preflight
    "$PROVIDER/start_agent.sh" dry-run \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      ${SANDBOX_DIR:+--sandbox="$SANDBOX_DIR"} \
      "${PASSTHROUGH[@]}"
    ;;

  build)
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" ]]; then
      echo "Error: --name and --project are required"
      exit 1
    fi
    "$PROVIDER/build_agent.sh" \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      "${PASSTHROUGH[@]}"
    ;;

  apply)
    if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --project and --sandbox are required"
      exit 1
    fi
    "$SCRIPTS/apply_workspace.sh" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      ${BRANCH:+--branch="$BRANCH"}
    ;;

  onboard)
    "$SCRIPTS/onboard.sh" "$@"
    ;;

  *)
    echo "Unknown subcommand: $SUBCOMMAND"
    echo "Valid subcommands: start, dry-run, build, apply, onboard, rebuild"
    exit 1
    ;;
esac
