#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Usage:
#   agent-sandbox onboard  --name=<n> --project=<path> --sandbox=<path>
#   agent-sandbox build    [sandbox|agent|all] --name=<n> --project=<path> --sandbox=<path>
#   agent-sandbox start    --name=<n> --project=<path> --sandbox=<path> [--brief=<rel>] [--env=<rel>] [--serve]
#   agent-sandbox serve    --name=<n> --project=<path> --sandbox=<path> [--brief=<rel>] [--env=<rel>]
#   agent-sandbox dry-run  --name=<n> --project=<path> --sandbox=<path> [--brief=<rel>] [--env=<rel>]
#   agent-sandbox rebuild  [start|dry-run|serve] --name=<n> --project=<path> --sandbox=<path> [flags]
#   agent-sandbox apply    --project=<path> --sandbox=<path> [--branch=<n>]

set -euo pipefail

AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"

SCRIPTS="$AGENT_SANDBOX_REPO/scripts"
PROVIDER="$AGENT_SANDBOX_REPO/providers/opencode"

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
PASSTHROUGH=()

parse_flags() {
  for ARG in "$@"; do
    case "$ARG" in
      --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
      --project=*) PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --branch=*)  BRANCH="${ARG#--branch=}" ;;
      *)           PASSTHROUGH+=("$ARG") ;;
    esac
  done
}

# -------------------------
# Build helpers
# -------------------------
build_sandbox_image() {
  if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: build sandbox requires --name and --sandbox"
    exit 1
  fi
  "$SCRIPTS/build_sandbox.sh" \
    --name="$PROJECT_NAME" \
    --sandbox="$SANDBOX_DIR"
}

build_agent_image() {
  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" ]]; then
    echo "Error: build agent requires --name and --project"
    exit 1
  fi
  "$PROVIDER/build_agent.sh" \
    --name="$PROJECT_NAME" \
    --project="$PROJECT_DIR"
}

build_all_images() {
  build_sandbox_image
  build_agent_image
}

# -------------------------
# Preflight — build both images if either is absent
# -------------------------
preflight() {
  local SANDBOX_IMAGE="agent-sandbox-${PROJECT_NAME,,}"
  local AGENT_IMAGE="opencode-agent-${PROJECT_NAME,,}"
  local MISSING=false

  if ! docker image inspect "$SANDBOX_IMAGE" >/dev/null 2>&1; then
    echo "Image not found: $SANDBOX_IMAGE"
    MISSING=true
  fi
  if ! docker image inspect "$AGENT_IMAGE" >/dev/null 2>&1; then
    echo "Image not found: $AGENT_IMAGE"
    MISSING=true
  fi

  if [[ "$MISSING" == true ]]; then
    echo "Building all images..."
    build_all_images
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
    # Optional variant as next positional arg: sandbox | agent | all
    # No variant (or explicit 'all') builds both.
    BUILD_VARIANT="${1:-all}"
    case "$BUILD_VARIANT" in
      sandbox|agent|all) shift || true ;;
      --*) BUILD_VARIANT="all" ;;  # no variant given, flags follow immediately
      *)
        echo "Unknown build variant: $BUILD_VARIANT"
        echo "Usage: agent-sandbox build [sandbox|agent|all] --name=<n> --project=<path> --sandbox=<path>"
        exit 1
        ;;
    esac
    parse_flags "$@"
    case "$BUILD_VARIANT" in
      sandbox) build_sandbox_image ;;
      agent)   build_agent_image ;;
      all)     build_all_images ;;
    esac
    ;;

  start)
    parse_flags "$@"
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name, --project, and --sandbox are required"
      exit 1
    fi
    preflight
    "$PROVIDER/start_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      "${PASSTHROUGH[@]}"
    ;;

  serve)
    parse_flags "$@"
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name, --project, and --sandbox are required"
      exit 1
    fi
    preflight
    "$PROVIDER/start_agent.sh" standard \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
      --serve \
      "${PASSTHROUGH[@]}"
    ;;

  dry-run)
    parse_flags "$@"
    if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
      echo "Error: --name, --project, and --sandbox are required"
      exit 1
    fi
    preflight
    "$PROVIDER/start_agent.sh" dry-run \
      --name="$PROJECT_NAME" \
      --project="$PROJECT_DIR" \
      --sandbox="$SANDBOX_DIR" \
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
    build_all_images
    # Re-dispatch to the target mode
    case "$REBUILD_MODE" in
      start)
        exec "$0" start \
          --name="$PROJECT_NAME" \
          --project="$PROJECT_DIR" \
          --sandbox="$SANDBOX_DIR" \
          "${PASSTHROUGH[@]}"
        ;;
      serve)
        exec "$0" start \
          --name="$PROJECT_NAME" \
          --project="$PROJECT_DIR" \
          --sandbox="$SANDBOX_DIR" \
          --serve \
          "${PASSTHROUGH[@]}"
        ;;
      dry-run)
        exec "$0" dry-run \
          --name="$PROJECT_NAME" \
          --project="$PROJECT_DIR" \
          --sandbox="$SANDBOX_DIR" \
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
