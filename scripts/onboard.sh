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
#   agent-sandbox onboard --refresh \
#     --name=<project_name> \
#     --sandbox=<path>
#
# Flags may be omitted — the script will prompt for any that are missing.
#
# What this script produces in SANDBOX_DIR:
#   Makefile                     — from template, PROJECT_NAME substituted
#   AGENTS.md                    — stub; operator fills in project context
#   .workspace/input/            — reasoning layer input channel
#   .workspace/output/           — reasoning layer output channel
#   .workspace/session-diffs/    — diff pipeline output
#   .env                         — paths + operator var stubs
#   .<provider>/                 — provider config dir, seeded from providers/<n>/config/
#
# Refresh mode (--refresh) updates versioned template files in an existing
# SANDBOX_DIR without overwriting .env operator values or AGENTS.md.

set -euo pipefail

# If set to true after the first mkdir, an ERR trap prints a cleanup
# warning so the user knows SANDBOX_DIR has partial state.
_HAS_SIDE_EFFECTS=false

trap '_maybe_cleanup' ERR

_maybe_cleanup() {
  if $_HAS_SIDE_EFFECTS; then
    echo "Warning: onboard.sh failed after creating files in SANDBOX_DIR." >&2
    echo "  Partial state may remain in: $SANDBOX_DIR" >&2
    echo "  To start fresh:" >&2
    echo "    rm -rf '$SANDBOX_DIR'" >&2
    echo "  Then re-run the command." >&2
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES="$REPO_ROOT/scripts/templates"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
  cat >&2 <<EOF
Usage: agent-sandbox onboard [--refresh] --name=<n> --project=<path> --sandbox=<path>

  --name=<project_name>   Short name for the project (used for image naming,
                          container names). No spaces. Example: my-project

  --project=<path>        Absolute WSL/Linux path to the project git repository.
                          Required for first-time onboard; optional for --refresh
                          (read from .env if omitted).

  --sandbox=<path>        Absolute WSL/Linux path to the sandbox directory
                          (created if it does not exist).

  --refresh               Update stale template files in existing SANDBOX_DIR.
                          Preserves .env operator values and AGENTS.md.

PATH FORMAT
  All paths must be WSL/Linux format, not Windows format.
  Valid:   /home/user/projects/my-project
           /mnt/c/Users/you/Projects/my-project
  Invalid: C:\\Users\\you\\Projects\\my-project
  Convert: wslpath 'C:\\Users\\you\\Projects\\my-project'
EOF
  exit 1
}

# Reads the version tag from a template file (Format: # agent-sandbox template version: N)
template_version() {
  grep -m1 "^# agent-sandbox template version:" "$1" | awk '{print $NF}'
}

# Validates path format (must be absolute WSL/Linux path, not Windows)
validate_path() {
  local NAME="$1" VAL="$2"
  if [[ "$VAL" =~ ^[A-Za-z]:[/\\] ]]; then
    echo "Error: $NAME must be a WSL/Linux path, not a Windows path." >&2
    echo "  Got:      $VAL" >&2
    echo "  Convert:  wslpath '$VAL'" >&2
    exit 1
  fi
  if [[ "$VAL" != /* ]]; then
    echo "Error: $NAME must be an absolute path." >&2
    echo "  Got: $VAL" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Flag parsing
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Prompt for missing flags
# ---------------------------------------------------------------------------
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
  echo "  Convention: alongside the project dir, e.g. ${PROJECT_DIR:-<project-dir>}/../sandbox"
  read -rp "Sandbox directory: " SANDBOX_DIR
fi



# ===========================================================================
# Refresh mode — update versioned template files only
# ===========================================================================
_validate_refresh() {
  if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --refresh requires --name and --sandbox." >&2
    usage
  fi
  validate_path "--sandbox" "$SANDBOX_DIR"
  for T in "Makefile.template"; do
    if [[ ! -f "$TEMPLATES/$T" ]]; then
      echo "Error: required template not found: $TEMPLATES/$T" >&2
      echo "  The agent-sandbox repo may be incomplete or out of date." >&2
      exit 1
    fi
  done
}
_run_refresh() {
  _validate_refresh
  _HAS_SIDE_EFFECTS=true
  mkdir -p "$SANDBOX_DIR"
  echo "Sandbox directory: $SANDBOX_DIR"
  sed "s|<project-name>|$PROJECT_NAME|g" \
    "$TEMPLATES/Makefile.template" \
    > "$SANDBOX_DIR/Makefile"
  echo "  Created: Makefile"
  local ENV_FILE="$SANDBOX_DIR/.env"

  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Warning: .env not found in $SANDBOX_DIR — template versions not recorded." >&2
    echo "  Run without --refresh to create a full .env." >&2
  else
    MAKEFILE_VERSION=$(template_version "$TEMPLATES/Makefile.template")
    sed -i \
      -e "s/^MAKEFILE_VERSION=.*/MAKEFILE_VERSION=${MAKEFILE_VERSION}/" \
      "$ENV_FILE"
    echo "  Updated: .env (template versions)"

    # Derive PROJECT_DIR from .env if not supplied via flag
    if [[ -z "$PROJECT_DIR" ]]; then
      PROJECT_DIR=$(grep -m1 '^PROJECT_DIR=' "$ENV_FILE" | cut -d= -f2-)
    fi
  fi

  echo ""
  echo "Refresh complete."
  echo ""
  echo "Template files updated to current versions."
  echo "Use 'agent-sandbox package-diff' or 'make package-diff' for host-side exports."
  echo "Rebuild images to apply changes:"
  echo "  make -C $SANDBOX_DIR build"
}

# ===========================================================================
# Provider provisioning — shared by _run_onboard
# ===========================================================================
# Single loop: appends .env.example stubs, seeds config directories with
# ACL permissions, renames env.stub, and runs provider-specific hooks.
# Must be defined before _run_onboard which calls it.
_provision_providers() {
  local ENV_FILE="$SANDBOX_DIR/.env"
  echo "  Seeding provider configs..."

  for PROVIDER_DIR in "$REPO_ROOT/providers/"*/; do
    [[ -d "$PROVIDER_DIR" ]] || continue
    local PROVIDER_NAME
    PROVIDER_NAME="$(basename "$PROVIDER_DIR")"

    # Append .env.example stubs
    local PROVIDER_ENV="$PROVIDER_DIR/.env.example"
    if [[ -f "$PROVIDER_ENV" ]]; then
      cat "$PROVIDER_ENV" >> "$ENV_FILE"
    fi

    # Seed config directory
    local PROVIDER_CONFIG_DIR="$PROVIDER_DIR/config"
    if [[ -d "$PROVIDER_CONFIG_DIR" ]] && [[ -n "$(ls -A "$PROVIDER_CONFIG_DIR" 2>/dev/null)" ]]; then
      local PROVIDER_SANDBOX_DIR="$SANDBOX_DIR/.$PROVIDER_NAME"
      mkdir -p "$PROVIDER_SANDBOX_DIR"
      # chmod forces dirs=775, files=664 at write time, avoiding umask
      # overshadoing that cp -r would cause.
      rsync -rt --chmod=Du=rwx,Dg=rwx,Do=rx,Fu=rw,Fg=rw,Fo=r \
        "$PROVIDER_CONFIG_DIR/." "$PROVIDER_SANDBOX_DIR/"

      # Interim ACL permission fix — replaced by UID Mapping in M2.7 Track C
      setfacl -R -m u:1001:rwx,m:rwx "$PROVIDER_SANDBOX_DIR"
      setfacl -R -d -m u:1001:rwx,m:rwx "$PROVIDER_SANDBOX_DIR"

      # Rename env.stub to .env if present
      if [[ -f "$PROVIDER_SANDBOX_DIR/env.stub" ]]; then
        mv "$PROVIDER_SANDBOX_DIR/env.stub" "$PROVIDER_SANDBOX_DIR/.env"
      fi

      echo "    .$PROVIDER_NAME/ (provider config — fill in secrets before first run)"
    fi

    # Run provider-specific setup hook
    local PROVIDER_SETUP="$PROVIDER_DIR/onboard.sh"
    if [[ -f "$PROVIDER_SETUP" ]]; then
      if ! source "$PROVIDER_SETUP"; then
        echo "Error: provider setup hook failed: $PROVIDER_SETUP" >&2
        echo "  Fix the error in $PROVIDER_SETUP before retrying." >&2
        exit 1
      fi
    fi
  done
}

# ===========================================================================
# Onboard mode — first-time full setup
# ===========================================================================
_validate_onboard() {
  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: project name, project directory, and sandbox directory are all required." >&2
    usage
  fi
  validate_path "--sandbox" "$SANDBOX_DIR"
  validate_path "--project" "$PROJECT_DIR"
  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: project directory does not exist: $PROJECT_DIR" >&2
    exit 1
  fi
  for T in "Makefile.template"; do
    if [[ ! -f "$TEMPLATES/$T" ]]; then
      echo "Error: required template not found: $TEMPLATES/$T" >&2
      echo "  The agent-sandbox repo may be incomplete or out of date." >&2
      exit 1
    fi
  done
  for F in "docker-compose.yml" "Makefile" ".env"; do
    if [[ -e "$SANDBOX_DIR/$F" ]]; then
      echo "Error: SANDBOX_DIR already contains '$F': $SANDBOX_DIR" >&2
      echo "  Onboarding aborted to avoid overwriting an existing setup." >&2
      echo "  To update stale template files without a full re-onboard, use:" >&2
      echo "    agent-sandbox onboard --refresh --name=<n> --project=<path> --sandbox=<path>" >&2
      exit 1
    fi
  done
}
_run_onboard() {
  _validate_onboard
  _HAS_SIDE_EFFECTS=true
  mkdir -p "$SANDBOX_DIR"
  echo "Sandbox directory: $SANDBOX_DIR"
  sed "s|<project-name>|$PROJECT_NAME|g" \
    "$TEMPLATES/Makefile.template" \
    > "$SANDBOX_DIR/Makefile"
  echo "  Created: Makefile"
  # -----------------------------------------------------------------------
  # AGENTS.md stub
  # -----------------------------------------------------------------------
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

  # -----------------------------------------------------------------------
  # Workspace directories
  # -----------------------------------------------------------------------
  mkdir -p "$SANDBOX_DIR/.workspace/input"
  mkdir -p "$SANDBOX_DIR/.workspace/output"
  mkdir -p "$SANDBOX_DIR/.workspace/session-diffs"
  setfacl -R -m u:1001:rwx "$SANDBOX_DIR/.workspace"
  setfacl -R -d -m u:1001:rwx "$SANDBOX_DIR/.workspace"
  echo "  Created: .workspace/input/, .workspace/output/, .workspace/session-diffs/"

  # -----------------------------------------------------------------------
  # .env
  # -----------------------------------------------------------------------
  local ENV_FILE="$SANDBOX_DIR/.env"
  MAKEFILE_VERSION=$(template_version "$TEMPLATES/Makefile.template")

  cat > "$ENV_FILE" <<ENVEOF
# agent-sandbox runtime configuration for: ${PROJECT_NAME}
# Generated by: agent-sandbox onboard
# Do not commit this file.

# --- Project paths (set at onboard time, stable for this machine) ---
PROJECT_DIR=${PROJECT_DIR}
SANDBOX_DIR=${SANDBOX_DIR}

# --- Template versions (set at onboard time) ---
# Used by build scripts to detect stale onboarded files.
# To refresh: agent-sandbox onboard --refresh --name=${PROJECT_NAME} --project=${PROJECT_DIR} --sandbox=${SANDBOX_DIR}
MAKEFILE_VERSION=${MAKEFILE_VERSION}

# --- Operator configuration (review and adjust before first run) ---
# Install directory for the agent-sandbox CLI (used by: make install)
INSTALL_DIR=~/.local/bin
# Port for serve mode (make serve)
SERVE_PORT=46553
# Autosave interval in seconds (how often session checkpoints are written mid-session)
AUTOSAVE_INTERVAL=60
ENVEOF

  echo "  Created: .env"

  # -----------------------------------------------------------------------
  # Provider provisioning (single loop: .env stubs + config seeding + hooks)
  # -----------------------------------------------------------------------
  _provision_providers

  # -----------------------------------------------------------------------

  # -----------------------------------------------------------------------
  # Summary
  # -----------------------------------------------------------------------
  echo ""
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
}

# ===========================================================================
# Mode dispatch
# ===========================================================================
if [[ "$REFRESH" == true ]]; then
  _run_refresh
else
  _run_onboard
fi
