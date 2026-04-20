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
#   Makefile                     — from template, PROJECT_NAME substituted
#   AGENTS.md                    — stub; operator fills in project context
#   .workspace/input/            — reasoning layer input channel
#   .workspace/output/           — reasoning layer output channel
#   .workspace/session-diffs/    — diff pipeline output  # renamed from changes/ in M2.3
#   .env                         — paths + operator var stubs
#   .<provider>/                 — provider config dir, seeded from providers/<n>/config/
#                                  for each provider present in the repo
#
# The operator must review AGENTS.md and .env before the first run.
# Provider config stubs in .<provider>/ must be populated with real values
# (e.g. API keys) before the first run.
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

  --refresh               Update stale template files (Makefile) and re-register git
                          aliases in an existing SANDBOX_DIR. Preserves .env operator
                          values and AGENTS.md. Pass --project to ensure git aliases
                          are re-registered. Run after a harness update.

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
sed "s|<project-name>|$PROJECT_NAME|g" \
  "$TEMPLATES/Makefile.template" \
  > "$SANDBOX_DIR/Makefile"
echo "  Created: Makefile"

# -------------------------
# AGENTS.md stub
# -------------------------
if [[ "$REFRESH" != true ]]; then
cat > "$SANDBOX_DIR/AGENTS.md" <<EOF
# Agent Context Brief — ${PROJECT_NAME}

## Project
<!-- Describe what this project is, what it does, and its current state. -->

## Constraints
<!-- Project-specific constraints: coding standards, conventions, files not to touch. -->

## Output
<!-- What good output looks like: expected file changes, patterns to follow. -->
EOF
echo "  Created: AGENTS.md (stub — fill in before first run)"
fi

# -------------------------
# Workspace directories
# -------------------------
if [[ "$REFRESH" != true ]]; then
mkdir -p "$SANDBOX_DIR/.workspace/input"
mkdir -p "$SANDBOX_DIR/.workspace/output"
mkdir -p "$SANDBOX_DIR/.workspace/session-diffs"
echo "  Created: .workspace/input/, .workspace/output/, .workspace/session-diffs/"
fi

# -------------------------
# Git alias — package-diff
# -------------------------
# Register a local git alias in PROJECT_DIR so the operator and agent can
# invoke package-diff.sh without knowing the harness install path.
# Local scope (.git/config) keeps the alias project-scoped — no global
# pollution. Lost on fresh clone; re-registered by re-running onboard.
if [[ -n "$PROJECT_DIR" ]]; then
  PACKAGE_DIFF_SCRIPT="$REPO_ROOT/libs/package-diff.sh"
  if git -C "$PROJECT_DIR" config --local \
      alias.package-diff "!bash $PACKAGE_DIFF_SCRIPT" 2>/dev/null; then
    echo "  Registered: git alias 'package-diff' in $PROJECT_DIR/.git/config"
  else
    echo "Warning: could not register git alias 'package-diff' in $PROJECT_DIR." >&2
    echo "  Register manually:" >&2
    echo "    git config --local alias.package-diff '!bash $PACKAGE_DIFF_SCRIPT'" >&2
  fi
fi

# -------------------------
# .env
# -------------------------
SNAPSHOT_DIR="$SANDBOX_DIR/.snapshot"
CHANGES_DIR="$SANDBOX_DIR/.workspace/session-diffs"
INPUT_DIR="$SANDBOX_DIR/.workspace/input"
OUTPUT_DIR="$SANDBOX_DIR/.workspace/output"

if [[ "$REFRESH" == true ]]; then
  ENV_FILE="$SANDBOX_DIR/.env"
  if [[ -f "$ENV_FILE" ]]; then
    sed -i \
      -e "s/^MAKEFILE_VERSION=.*/MAKEFILE_VERSION=${MAKEFILE_VERSION}/" \
      "$ENV_FILE"
    echo "  Updated: .env (template versions)"
    # Derive PROJECT_DIR from .env if not supplied via flag — needed for alias
    # re-registration. make refresh does not pass --project.
    if [[ -z "$PROJECT_DIR" ]]; then
      PROJECT_DIR=$(grep -m1 '^PROJECT_DIR=' "$ENV_FILE" | cut -d= -f2-)
    fi
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
# Provider config seeding
# -------------------------
# For each provider that ships a config/ directory, copy its contents into
# $SANDBOX_DIR/.<provider>/ as the starting state for the first session.
# env.stub is renamed to .env — the agent expects .env; env.stub is the
# committed name used to avoid .gitignore matches in the repo.
# The operator must fill in secrets (e.g. API keys) before the first run.
# These files are never baked into provider images.
if [[ "$REFRESH" != true ]]; then
  for PROVIDER_CONFIG_DIR in "$REPO_ROOT/providers/"*/config; do
    if [[ ! -d "$PROVIDER_CONFIG_DIR" ]]; then
      continue
    fi
    if [[ -z "$(ls -A "$PROVIDER_CONFIG_DIR" 2>/dev/null)" ]]; then
      continue
    fi

    PROVIDER_NAME="$(basename "$(dirname "$PROVIDER_CONFIG_DIR")")"
    PROVIDER_SANDBOX_DIR="$SANDBOX_DIR/.$PROVIDER_NAME"

    mkdir -p "$PROVIDER_SANDBOX_DIR"
    cp -r "$PROVIDER_CONFIG_DIR/." "$PROVIDER_SANDBOX_DIR/"

    # Rename env.stub to .env if present.
    if [[ -f "$PROVIDER_SANDBOX_DIR/env.stub" ]]; then
      mv "$PROVIDER_SANDBOX_DIR/env.stub" "$PROVIDER_SANDBOX_DIR/.env"
    fi

    echo "  Created: .$PROVIDER_NAME/ (provider config — fill in secrets before first run)"
  done
fi

# -------------------------
# Summary
# -------------------------
echo ""
if [[ "$REFRESH" == true ]]; then
  echo "Refresh complete."
  echo ""
  echo "Template files updated to current versions."
  if [[ -n "$PROJECT_DIR" ]]; then
    echo "Git alias 'package-diff' re-registered in $PROJECT_DIR/.git/config."
  else
    echo "Git alias not re-registered — PROJECT_DIR could not be resolved from .env."
    echo "  Run: git config --local alias.package-diff '!bash $REPO_ROOT/libs/package-diff.sh'"
  fi
  echo "Rebuild images to apply changes:"
  echo "  make -C $SANDBOX_DIR build"
else
  echo "Onboarding complete."
  echo ""
  echo "Before running for the first time:"
  echo "  1. Edit $SANDBOX_DIR/AGENTS.md — add project context for the agent"
  echo "  2. Review $SANDBOX_DIR/.env — set SERVE_PORT, INSTALL_DIR, and any provider credentials"
  echo "  3. Fill in secrets in $SANDBOX_DIR/.<provider>/ for each provider you intend to use"
  echo "  4. Run: make -C $SANDBOX_DIR build"
  echo "  5. Run: make -C $SANDBOX_DIR dry-run"
  echo ""
  echo "To start a session: make -C $SANDBOX_DIR start"
fi
