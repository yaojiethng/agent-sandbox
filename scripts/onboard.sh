#!/usr/bin/env bash
# workflow/general/scripts/onboard.sh
#
# Onboards a project into agent-sandbox using the general (coding project)
# workflow. Produces a working SANDBOX_DIR from templates with no manual
# file placement required.
#
# Usage:
#   agent-sandbox onboard general \
#     --name=<project_name> \
#     --project=<path> \
#     --sandbox=<path>
#
# Flags may be omitted — the script will prompt for any that are missing.
#
# PATH FORMAT
#   All paths must be WSL/Linux format, not Windows format.
#   Examples of valid paths:
#     /home/user/projects/my-project
#     /mnt/c/Users/you/Projects/my-project
#   Examples of invalid paths (will be rejected):
#     C:\Users\you\Projects\my-project
#     C:/Users/you/Projects/my-project
#   To convert a Windows path to WSL format:
#     wslpath 'C:\Users\you\Projects\my-project'
#
# What this script produces in SANDBOX_DIR:
#   docker-compose.yml           — from template, PROJECT_NAME substituted
#   docker-compose.serve.yml     — serve overlay
#   docker-compose.dry-run.yml   — dry-run overlay
#   Dockerfile.sandbox           — default capability layer Dockerfile
#   Makefile                     — from template, PROJECT_NAME substituted
#   agents.md                    — stub; operator fills in project context
#   .workspace/input/            — reasoning layer input channel
#   .workspace/output/           — reasoning layer output channel
#   .workspace/changes/          — diff pipeline output
#   .env                         — paths + operator var stubs
#
# The operator must review agents.md and .env before the first run.
# .env must never be committed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT assumes this script lives at workflow/general/scripts/
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES="$REPO_ROOT/libs/_templates"


# -------------------------
# Usage
# -------------------------
usage() {
  cat >&2 <<EOF
Usage: agent-sandbox onboard general --name=<n> --project=<path> --sandbox=<path>

  --name=<project_name>   Short name for the project (used for image naming,
                          container names). No spaces. Example: my-project

  --project=<path>        Absolute WSL/Linux path to the project git repository.
                          Example: /mnt/c/Users/you/Projects/my-project

  --sandbox=<path>        Absolute WSL/Linux path to the sandbox directory
                          (will be created if it does not exist).
                          Example: /mnt/c/Users/you/Projects/my-project-sandbox

PATH FORMAT
  All paths must be WSL/Linux format, not Windows format.
  To convert a Windows path:  wslpath 'C:\\your\\path'

  Valid:   /home/user/projects/my-project
           /mnt/c/Users/you/Projects/my-project
  Invalid: C:\\Users\\you\\Projects\\my-project
           C:/Users/you/Projects/my-project
EOF
  exit 1
}

# -------------------------
# Flag parsing
# -------------------------
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR=""

for ARG in "$@"; do
  case "$ARG" in
    --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
    --project=*) PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
    -h|--help)   usage ;;
    *)
      echo "Unknown flag: $ARG" >&2
      usage
      ;;
  esac
done

# -------------------------
# Prompt for missing flags
# -------------------------
if [[ -z "$PROJECT_NAME" ]]; then
  read -rp "Project name (no spaces, used for image/container naming): " PROJECT_NAME
fi

if [[ -z "$PROJECT_DIR" ]]; then
  echo "Project directory: absolute WSL/Linux path to the project git repo."
  echo "  To convert a Windows path: wslpath 'C:\\your\\path'"
  read -rp "Project directory: " PROJECT_DIR
fi

if [[ -z "$SANDBOX_DIR" ]]; then
  echo "Sandbox directory: absolute WSL/Linux path where sandbox files will be created."
  echo "  To convert a Windows path: wslpath 'C:\\your\\path'"
  echo "  Convention: alongside the project dir, e.g. ${PROJECT_DIR}/../sandbox"
  read -rp "Sandbox directory: " SANDBOX_DIR
fi

if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
  echo "Error: project name, project directory, and sandbox directory are all required." >&2
  usage
fi

# -------------------------
# Path validation
# -------------------------
validate_path() {
  local NAME="$1" VAL="$2"
  # Reject Windows-style paths (C:\ or C:/)
  if [[ "$VAL" =~ ^[A-Za-z]:[/\\] ]]; then
    echo "Error: $NAME must be a WSL/Linux path, not a Windows path." >&2
    echo "  Got:      $VAL" >&2
    echo "  Convert:  wslpath '$VAL'" >&2
    echo "" >&2
    echo "  Valid formats:" >&2
    echo "    /home/user/projects/my-project" >&2
    echo "    /mnt/c/Users/you/Projects/my-project" >&2
    exit 1
  fi
  # Must be absolute
  if [[ "$VAL" != /* ]]; then
    echo "Error: $NAME must be an absolute path." >&2
    echo "  Got: $VAL" >&2
    exit 1
  fi
}

validate_path "--project" "$PROJECT_DIR"
validate_path "--sandbox" "$SANDBOX_DIR"

# -------------------------
# Project directory checks
# -------------------------
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: project directory does not exist: $PROJECT_DIR" >&2
  exit 1
fi

# -------------------------
# Template presence check
# -------------------------
REQUIRED_TEMPLATES=(
  "docker-compose.yml.template"
  "docker-compose.serve.yml.template"
  "docker-compose.dry-run.yml.template"
  "dockerfile-default.sandbox"
  "Makefile.template"
)

for T in "${REQUIRED_TEMPLATES[@]}"; do
  if [[ ! -f "$TEMPLATES/$T" ]]; then
    echo "Error: required template not found: $TEMPLATES/$T" >&2
    echo "  The agent-sandbox repo may be incomplete or out of date." >&2
    exit 1
  fi
done

# -------------------------
# Guard: abort if SANDBOX_DIR already contains onboard outputs
# -------------------------
GUARD_FILES=("docker-compose.yml" "Makefile" ".env")

for F in "${GUARD_FILES[@]}"; do
  if [[ -e "$SANDBOX_DIR/$F" ]]; then
    echo "Error: SANDBOX_DIR already contains '$F': $SANDBOX_DIR" >&2
    echo "  Onboarding aborted to avoid overwriting an existing setup." >&2
    echo "  To re-onboard, remove SANDBOX_DIR or the conflicting files first." >&2
    exit 1
  fi
done

# -------------------------
# Create SANDBOX_DIR
# -------------------------
mkdir -p "$SANDBOX_DIR"
echo "Sandbox directory: $SANDBOX_DIR"

# -------------------------
# Compose files
# -------------------------
sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
  "$TEMPLATES/docker-compose.yml.template" \
  > "$SANDBOX_DIR/docker-compose.yml"
echo "  Created: docker-compose.yml"

cp "$TEMPLATES/docker-compose.serve.yml.template"   "$SANDBOX_DIR/docker-compose.serve.yml"
echo "  Created: docker-compose.serve.yml"

cp "$TEMPLATES/docker-compose.dry-run.yml.template" "$SANDBOX_DIR/docker-compose.dry-run.yml"
echo "  Created: docker-compose.dry-run.yml"

# -------------------------
# Dockerfile.sandbox
# -------------------------
cp "$TEMPLATES/dockerfile-default.sandbox" "$SANDBOX_DIR/Dockerfile.sandbox"
echo "  Created: Dockerfile.sandbox"

# -------------------------
# Makefile
# -------------------------
# Only PROJECT_NAME is substituted here — PROJECT_DIR and SANDBOX_DIR
# are written to .env and read by the Makefile via -include .env.
sed "s|<project-name>|$PROJECT_NAME|g" \
  "$TEMPLATES/Makefile.template" \
  > "$SANDBOX_DIR/Makefile"
echo "  Created: Makefile"

# -------------------------
# agents.md stub
# -------------------------
cat > "$SANDBOX_DIR/agents.md" <<EOF
# Agent Context Brief — ${PROJECT_NAME}

## Project
<!-- Describe what this project is, what it does, and its current state. -->

## Constraints
<!-- Project-specific constraints: coding standards, conventions, files not to touch. -->

## Output
<!-- What good output looks like: expected file changes, patterns to follow. -->
EOF
echo "  Created: agents.md (stub — fill in before first run)"

# -------------------------
# Workspace directories
# -------------------------
mkdir -p "$SANDBOX_DIR/.workspace/input"
mkdir -p "$SANDBOX_DIR/.workspace/output"
mkdir -p "$SANDBOX_DIR/.workspace/changes"
echo "  Created: .workspace/input/, .workspace/output/, .workspace/changes/"

# -------------------------
# .env
# -------------------------
SANDBOX_IMAGE_NAME="agent-sandbox-${PROJECT_NAME,,}"
AGENT_IMAGE_NAME="opencode-agent-${PROJECT_NAME,,}"

SNAPSHOT_DIR="$SANDBOX_DIR/.snapshot"
CHANGES_DIR="$SANDBOX_DIR/.workspace/changes"
INPUT_DIR="$SANDBOX_DIR/.workspace/input"
OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"

cat > "$SANDBOX_DIR/.env" <<EOF
# agent-sandbox runtime configuration for: ${PROJECT_NAME}
# Generated by: agent-sandbox onboard general
# Do not commit this file.

# --- Project paths (set at onboard time, stable for this machine) ---
PROJECT_DIR=${PROJECT_DIR}
SANDBOX_DIR=${SANDBOX_DIR}

# --- Derived paths ---
SNAPSHOT_DIR=${SNAPSHOT_DIR}
CHANGES_DIR=${CHANGES_DIR}
INPUT_DIR=${INPUT_DIR}
OUTPUT_DIR=${OUTPUT_DIR}
SANDBOX_IMAGE_NAME=${SANDBOX_IMAGE_NAME}
AGENT_IMAGE_NAME=${AGENT_IMAGE_NAME}

# --- Operator configuration (review and adjust before first run) ---
# Install directory for the agent-sandbox CLI (used by: make install)
INSTALL_DIR=~/.local/bin
# Port for serve mode (make serve)
SERVE_PORT=46553
# OpenCode server password (leave empty to disable authentication)
OPENCODE_SERVER_PASSWORD=
# Autosave interval in seconds (how often staged.diff is written mid-session)
AUTOSAVE_INTERVAL=60
EOF
echo "  Created: .env"

# -------------------------
# Summary
# -------------------------
echo ""
echo "Onboarding complete."
echo ""
echo "Before running for the first time:"
echo "  1. Edit $SANDBOX_DIR/agents.md — add project context for the agent"
echo "  2. Review $SANDBOX_DIR/.env — set SERVE_PORT, OPENCODE_SERVER_PASSWORD, INSTALL_DIR if needed"
echo "  3. Run: make -C $SANDBOX_DIR build-all"
echo "  4. Run: make -C $SANDBOX_DIR dry-run"
echo ""
echo "To start a session: make -C $SANDBOX_DIR start"
