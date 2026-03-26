#!/usr/bin/env bash
# scripts/onboard.sh
#
# Onboards a project into agent-sandbox using the general (coding project)
# workflow. Produces a working SANDBOX_DIR from templates with no manual
# file placement required.
#
# Usage:
#   agent-sandbox onboard \
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
#   docker-compose.dry-run.yml   — dry-run overlay
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
# REPO_ROOT assumes this script lives at scripts/
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES="$REPO_ROOT/libs/_templates"


# -------------------------
# Usage
# -------------------------
usage() {
  cat >&2 <<EOF
Usage: agent-sandbox onboard --name=<n> --project=<path> --sandbox=<path>

  --name=<project_name>   Short name for the project (used for image naming,
                          container names). No spaces. Example: my-project

  --project=<path>        Absolute WSL/Linux path to the project git repository.
                          Example: /mnt/c/Users/you/Projects/my-project

  --sandbox=<path>        Absolute WSL/Linux path to the sandbox directory
                          (will be created if it does not exist).
                          Example: /mnt/c/Users/you/Projects/my-project-sandbox

  --refresh               Update stale template files (Makefile) in an existing
                          SANDBOX_DIR without a full re-onboard. Preserves .env
                          operator values and agents.md. Run after a harness update.

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
REFRESH=false

for ARG in "$@"; do
  case "$ARG" in
    --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
    --project=*)  PROJECT_DIR="${ARG#--project=}" ;;
    --sandbox=*)  SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --refresh)    REFRESH=true ;;
    -h|--help)    usage ;;
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

if [[ "$REFRESH" != true && -z "$PROJECT_DIR" ]]; then
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

if [[ "$REFRESH" == true ]]; then
  if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --refresh requires --name and --sandbox." >&2
    usage
  fi
else
  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: project name, project directory, and sandbox directory are all required." >&2
    usage
  fi
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

validate_path "--sandbox" "$SANDBOX_DIR"

if [[ "$REFRESH" != true ]]; then
  validate_path "--project" "$PROJECT_DIR"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: project directory does not exist: $PROJECT_DIR" >&2
    exit 1
  fi
fi

# -------------------------
# Template presence check
# -------------------------
REQUIRED_TEMPLATES=(
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

if [[ "$REFRESH" == true ]]; then
  echo "Refresh mode: updating versioned template files in $SANDBOX_DIR"
else
  for F in "${GUARD_FILES[@]}"; do
    if [[ -e "$SANDBOX_DIR/$F" ]]; then
      echo "Error: SANDBOX_DIR already contains '$F': $SANDBOX_DIR" >&2
      echo "  Onboarding aborted to avoid overwriting an existing setup." >&2
      echo "  To update stale template files without a full re-onboard, use:" >&2
      echo "    agent-sandbox onboard --refresh --name=<n> --project=<path> --sandbox=<path>" >&2
      exit 1
    fi
  done
fi

# -------------------------
# Create SANDBOX_DIR
# -------------------------
mkdir -p "$SANDBOX_DIR"
echo "Sandbox directory: $SANDBOX_DIR"

# -------------------------
# Template version extraction
# -------------------------
# Reads the version tag from a template file.
# Format: # agent-sandbox template version: N
template_version() {
  grep -m1 "^# agent-sandbox template version:" "$1" | awk '{print $NF}'
}

# -------------------------
# Makefile
# -------------------------
MAKEFILE_VERSION=$(template_version "$TEMPLATES/Makefile.template")
# Only PROJECT_NAME is substituted here — PROJECT_DIR and SANDBOX_DIR
# are written to .env and read by the Makefile via -include .env.
sed "s|<project-name>|$PROJECT_NAME|g" \
  "$TEMPLATES/Makefile.template" \
  > "$SANDBOX_DIR/Makefile"
echo "  Created: Makefile"

# -------------------------
# agents.md stub
# -------------------------
if [[ "$REFRESH" != true ]]; then
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
fi

# -------------------------
# Workspace directories
# -------------------------
if [[ "$REFRESH" != true ]]; then
mkdir -p "$SANDBOX_DIR/.workspace/input"
mkdir -p "$SANDBOX_DIR/.workspace/output"
mkdir -p "$SANDBOX_DIR/.workspace/changes"
echo "  Created: .workspace/input/, .workspace/output/, .workspace/changes/"
fi

# -------------------------
# .env
# -------------------------
SNAPSHOT_DIR="$SANDBOX_DIR/.snapshot"
CHANGES_DIR="$SANDBOX_DIR/.workspace/changes"
INPUT_DIR="$SANDBOX_DIR/.workspace/input"
OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"

if [[ "$REFRESH" == true ]]; then
  # In refresh mode: update only the template version lines in the existing .env.
  # Operator-set values (SERVE_PORT, provider credentials, etc.) are preserved.
  ENV_FILE="$SANDBOX_DIR/.env"
  if [[ -f "$ENV_FILE" ]]; then
    sed -i \
      -e "s/^MAKEFILE_VERSION=.*/MAKEFILE_VERSION=${MAKEFILE_VERSION}/" \
      "$ENV_FILE"
    echo "  Updated: .env (template versions)"
  else
    echo "Warning: .env not found in $SANDBOX_DIR — template versions not recorded." >&2
    echo "  Run without --refresh to create a full .env." >&2
  fi
else
  ENV_FILE="$SANDBOX_DIR/.env"

  cat > "$ENV_FILE" <<ENVEOF
# agent-sandbox runtime configuration for: ${PROJECT_NAME}
# Generated by: agent-sandbox onboard
# Do not commit this file.

# --- Project paths (set at onboard time, stable for this machine) ---
PROJECT_DIR=${PROJECT_DIR}
SANDBOX_DIR=${SANDBOX_DIR}

# --- Derived paths ---
SNAPSHOT_DIR=${SNAPSHOT_DIR}
CHANGES_DIR=${CHANGES_DIR}
INPUT_DIR=${INPUT_DIR}
OUTPUT_DIR=${OUTPUT_DIR}

# --- Template versions (set at onboard time) ---
# Used by build scripts to detect stale onboarded files.
# To refresh: agent-sandbox onboard --refresh --name=${PROJECT_NAME} --project=${PROJECT_DIR} --sandbox=${SANDBOX_DIR}
MAKEFILE_VERSION=${MAKEFILE_VERSION}

# --- Operator configuration (review and adjust before first run) ---
# Install directory for the agent-sandbox CLI (used by: make install)
INSTALL_DIR=~/.local/bin
# Port for serve mode (make serve)
SERVE_PORT=46553
# Autosave interval in seconds (how often staged.diff is written mid-session)
AUTOSAVE_INTERVAL=60
ENVEOF

  # Append provider-specific stubs from each providers/<name>/.env.example
  for PROVIDER_ENV in "$REPO_ROOT/providers/"*"/.env.example"; do
    if [[ -f "$PROVIDER_ENV" ]]; then
      cat "$PROVIDER_ENV" >> "$ENV_FILE"
    fi
  done
  echo "  Appended: provider-specific .env stubs"

  echo "  Created: .env"
fi

# -------------------------
# Summary
# -------------------------
echo ""
if [[ "$REFRESH" == true ]]; then
  echo "Refresh complete."
  echo ""
  echo "Template files updated to current versions."
  echo "Rebuild images to apply changes:"
  echo "  make -C $SANDBOX_DIR build"
else
  echo "Onboarding complete."
  echo ""
  echo "Before running for the first time:"
  echo "  1. Edit $SANDBOX_DIR/agents.md — add project context for the agent"
  echo "  2. Review $SANDBOX_DIR/.env — set SERVE_PORT, INSTALL_DIR, and any provider credentials"
  echo "  3. Run: make -C $SANDBOX_DIR build"
  echo "  4. Run: make -C $SANDBOX_DIR dry-run"
  echo ""
  echo "To start a session: make -C $SANDBOX_DIR start"
fi
