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
# Flags may be omitted  --  the script will prompt for any that are missing.
#
# What this script produces in SANDBOX_DIR:
#   Makefile                      --  from template, PROJECT_NAME substituted
#   .workspace/input/             --  reasoning layer input channel
#   .workspace/output/            --  reasoning layer output channel
#   .workspace/session-diffs/     --  diff pipeline output
#   .env                          --  paths + operator var stubs
#   .<provider>/                  --  provider config dir, seeded from src/reasoning/providers/<n>/config/
#
# Refresh mode (--refresh) updates versioned template files in an existing
# SANDBOX_DIR without overwriting .env operator values.

set -euo pipefail
_maybe_cleanup() {
  if $_HAS_SIDE_EFFECTS && [[ -n "${SANDBOX_DIR:-}" ]]; then
    echo "Warning: onboard.sh failed after creating files in SANDBOX_DIR." >&2
    echo "  Partial state may remain in: $SANDBOX_DIR" >&2
    echo "  To start fresh:" >&2
    echo "    rm -rf '$SANDBOX_DIR'" >&2
    echo "  Then re-run the command." >&2
  fi
}
# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
  cat >&2 <<EOF
Usage: agent-sandbox onboard [--refresh] --name=<n> --project=<path> --sandbox=<path>

  --name=<project_name>   Short name for the project (used for image naming,
                          container names). No spaces. Example: my-project

  --project=<path>        Absolute or relative path to the project git repository.
                          Required for first-time onboard; optional for --refresh
                          (read from .env if omitted).

  --sandbox=<path>        Absolute or relative path to the sandbox directory
                          (created if it does not exist).

  --yes                   Skip the confirmation prompt (for scripting/CI).

  --refresh               Update stale template files in existing SANDBOX_DIR.
                          Preserves .env operator values.

PATH FORMAT
  All paths must be WSL/Linux format, not Windows format.
  Relative paths (., ~/foo) are resolved to absolute via realpath.
  Valid:   /home/user/projects/my-project  .  ~/sandbox/my-project
           /mnt/c/Users/you/Projects/my-project
  Invalid: C:\\Users\\you\\Projects\\my-project
  Convert: wslpath 'C:\\Users\\you\\Projects\\my-project'
EOF
}

# Reads the version tag from a template file (Format: # agent-sandbox template version: N)
# Absent marker yields empty output with rc0 -- callers treat empty as
# "unknown template version", not as failure.
template_version() {
  # Absent marker is an expected, non-error outcome (caller compares empty
  # string): absorb grep's exit 1 per bash-coding-conventions rule 4.3.
  { grep -m1 "^# agent-sandbox template version:" "$1" || true; } | awk '{print $NF}'
}

# resolve_and_validate VAR_NAME FLAG_NAME VALUE [REQUIRE_EXIST]
#
# Resolves a potentially-relative path via realpath, validates it's an
# absolute WSL/Linux path, and writes the resolved value into the named
# variable. Exits on invalid format or Windows paths.
# If REQUIRE_EXIST is true, exits if the path does not exist.
resolve_and_validate() {
  local VAR="$1" FLAG="$2" VAL="$3" REQUIRE_EXIST="${4:-false}"
  local RESOLVED

  RESOLVED="$(realpath "$VAL" 2>/dev/null || true)"
  if [[ -n "$RESOLVED" ]]; then
    VAL="$RESOLVED"
  elif [[ "$REQUIRE_EXIST" == true ]]; then
    echo "Error: $FLAG path does not exist: $VAL" >&2
    exit 1
  fi

  if [[ "$VAL" =~ ^[A-Za-z]:[/\\] ]]; then
    echo "Error: $FLAG must be a WSL/Linux path, not a Windows path." >&2
    echo "  Got:      $VAL" >&2
    echo "  Convert:  wslpath '$VAL'" >&2
    exit 1
  fi
  if [[ "$VAL" != /* ]]; then
    echo "Error: $FLAG must be an absolute or resolvable path." >&2
    echo "  Got: $VAL" >&2
    exit 1
  fi

  printf -v "$VAR" '%s' "$VAL"
}

# confirm_or_exit
#
# Prints PROJECT_DIR and SANDBOX_DIR, then prompts for confirmation
# unless running non-interactively or --yes was given.
confirm_or_exit() {
  echo ""
  echo "Project:  $PROJECT_DIR"
  echo "Sandbox:  $SANDBOX_DIR"
  echo ""

  if ! $_INTERACTIVE; then
    echo "Non-interactive mode  --  proceeding."
    echo ""
    return 0
  fi

  local REPLY
  read -r -p "Continue with onboarding? [Y/n] " REPLY
  if [[ -n "$REPLY" && "$REPLY" != [Yy] && "$REPLY" != [Yy][Ee][Ss] ]]; then
    echo "Onboarding cancelled."
    exit 0
  fi
  echo ""
}

# ===========================================================================
# Refresh mode  --  update versioned template files only
# ===========================================================================
_validate_refresh() {
  if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --refresh requires --name and --sandbox." >&2
    usage
    exit 1
  fi
  if [[ ! -f "$TEMPLATES/Makefile.template" ]]; then
    echo "Error: required template not found: $TEMPLATES/Makefile.template" >&2
    echo "  The agent-sandbox repo may be incomplete or out of date." >&2
    exit 1
  fi
}
_run_refresh() {
  _validate_refresh
  confirm_or_exit
  _HAS_SIDE_EFFECTS=true
  mkdir -p "$SANDBOX_DIR"
  echo "Sandbox directory: $SANDBOX_DIR"
  sed "s|<project-name>|$PROJECT_NAME|g" \
    "$TEMPLATES/Makefile.template" \
    > "$SANDBOX_DIR/Makefile"
  echo "  Created: Makefile"

  local ENV_FILE="$SANDBOX_DIR/.env"
  if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -n "$PROJECT_DIR" ]]; then
      _write_env_file
      echo "  Created: .env (recreated  --  PROJECT_DIR provided explicitly)"
    else
      echo "Warning: .env not found and --project not provided." >&2
      echo "  Run 'agent-sandbox onboard --refresh --project=<path> ...' to recreate." >&2
    fi
  else
    MAKEFILE_VERSION=$(template_version "$TEMPLATES/Makefile.template")
    # Empty MAKEFILE_VERSION means the template lacks a version marker; .env
    # then records an unknown version rather than failing the refresh.
    # Refresh derived path + template-version metadata in place. INSTALL_DIR is
    # operator configuration and is intentionally left untouched (no --install-dir
    # input exists to sync it to; clobbering it would undo an operator override).
    # Escape & in replacement values so a path containing it is not interpreted
    # by sed as the "whole match" substitution metacharacter.
    local _esc_pd _esc_sd
    _esc_pd=${PROJECT_DIR//&/\\&}
    _esc_sd=${SANDBOX_DIR//&/\\&}
    sed -i \
      -e "s/^MAKEFILE_VERSION=.*/MAKEFILE_VERSION=${MAKEFILE_VERSION}/" \
      -e "s|^PROJECT_DIR=.*|PROJECT_DIR=${_esc_pd}|" \
      -e "s|^SANDBOX_DIR=.*|SANDBOX_DIR=${_esc_sd}|" \
      "$ENV_FILE"
    echo "  Updated: .env (project paths + template versions)"
  fi

  # Sanity check: if we have a PROJECT_DIR now, verify it exists
  if [[ -n "$PROJECT_DIR" && ! -d "$PROJECT_DIR" ]]; then
    echo "Warning: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
    echo "  Has the project been moved? Update PROJECT_DIR in $ENV_FILE or pass --project." >&2
  fi

  echo ""
  echo "Refresh complete."
  echo ""
  echo "Template files updated to current versions."
  echo "Use 'agent-sandbox package-branch' or 'make package-branch' for host-side exports."
  echo "Rebuild images to apply changes:"
  echo "  make -C $SANDBOX_DIR build"
}

# ---------------------------------------------------------------------------
# _write_env_file
#
# Writes the .env file with project paths, template versions, and operator
# configuration stubs. Uses current values of PROJECT_DIR, SANDBOX_DIR,
# PROJECT_NAME (all resolved and validated by this point).
# Shared by _run_onboard (fresh) and _run_refresh (recreation).
# ---------------------------------------------------------------------------
_write_env_file() {
  local ENV_FILE="$SANDBOX_DIR/.env"
  local VERSION
  VERSION=$(template_version "$TEMPLATES/Makefile.template")

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
MAKEFILE_VERSION=${VERSION}

# --- Operator configuration (review and adjust before first run) ---
# Install directory for the agent-sandbox CLI (used by: make install)
INSTALL_DIR=~/.local/bin
# Port for serve mode (make serve)
SERVE_PORT=46553
# Autosave interval in seconds (how often session checkpoints are written mid-session)
AUTOSAVE_INTERVAL=60
ENVEOF
}

# ===========================================================================
# Provider provisioning  --  shared by _run_onboard
# ===========================================================================
# Single loop: appends .env.example stubs, seeds config directories with
# ACL permissions, renames env.stub, and runs provider-specific hooks.
# Must be defined before _run_onboard which calls it.
_provision_providers() {
  local ENV_FILE="$SANDBOX_DIR/.env"
  echo "  Seeding provider configs..."

  for PROVIDER_DIR in "$REPO_ROOT/src/reasoning/providers/"*/; do
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

      # UID Mapping handles permissions  --  no ACL fix needed

      # Rename env.stub to .env if present
      if [[ -f "$PROVIDER_SANDBOX_DIR/env.stub" ]]; then
        mv "$PROVIDER_SANDBOX_DIR/env.stub" "$PROVIDER_SANDBOX_DIR/.env"
      fi

      echo "    .$PROVIDER_NAME/ (provider config  --  fill in secrets before first run)"
    fi

    # Run provider-specific setup hook. The path is provider-selected and
    # validated by the -f check; ShellCheck cannot follow it statically.
    local PROVIDER_SETUP="$PROVIDER_DIR/onboard.sh"
    if [[ -f "$PROVIDER_SETUP" ]]; then
      # shellcheck disable=SC1090
      if ! source "$PROVIDER_SETUP"; then
        echo "Error: provider setup hook failed: $PROVIDER_SETUP" >&2
        echo "  Fix the error in $PROVIDER_SETUP before retrying." >&2
        exit 1
      fi
    fi
  done
}

# ===========================================================================
# Onboard mode  --  first-time full setup
# ===========================================================================
_validate_onboard() {
  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: project name, project directory, and sandbox directory are all required." >&2
    usage
    exit 1
  fi
  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: project directory does not exist: $PROJECT_DIR" >&2
    exit 1
  fi
  if [[ ! -f "$TEMPLATES/Makefile.template" ]]; then
    echo "Error: required template not found: $TEMPLATES/Makefile.template" >&2
    echo "  The agent-sandbox repo may be incomplete or out of date." >&2
    exit 1
  fi
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
  confirm_or_exit
  _HAS_SIDE_EFFECTS=true
  mkdir -p "$SANDBOX_DIR"
  echo "Sandbox directory: $SANDBOX_DIR"
  sed "s|<project-name>|$PROJECT_NAME|g" \
    "$TEMPLATES/Makefile.template" \
    > "$SANDBOX_DIR/Makefile"
  echo "  Created: Makefile"

  # -----------------------------------------------------------------------
  # Workspace directories
  # -----------------------------------------------------------------------
  mkdir -p "$SANDBOX_DIR/.workspace/input"
  mkdir -p "$SANDBOX_DIR/.workspace/output"
  mkdir -p "$SANDBOX_DIR/.workspace/session-diffs"
  # UID Mapping handles permissions  --  no ACL fix needed
  echo "  Created: .workspace/input/, .workspace/output/, .workspace/session-diffs/"

  # -----------------------------------------------------------------------
  # .env
  # -----------------------------------------------------------------------
  _write_env_file
  echo "  Created: .env"

  # -----------------------------------------------------------------------
  # Provider provisioning (single loop: .env stubs + config seeding + hooks)
  # -----------------------------------------------------------------------
  _provision_providers

  # -----------------------------------------------------------------------
  # Summary
  # -----------------------------------------------------------------------
  echo ""
  echo "Onboarding complete."
  echo ""
  echo "Before running for the first time:"
  echo "  1. Review $SANDBOX_DIR/.env  --  set SERVE_PORT, INSTALL_DIR, and any provider credentials"
  echo "  2. Fill in secrets in $SANDBOX_DIR/.<provider>/ for each provider you intend to use"
  echo "  3. Run: make -C $SANDBOX_DIR build"
  echo "  4. Run: make -C $SANDBOX_DIR dry-run"
  echo ""
  echo "To start a session: make -C $SANDBOX_DIR start"
}

# ===========================================================================
# Mode dispatch + CLI entry point
# ===========================================================================
main() {
  # If set to true after the first mkdir, the ERR trap prints a cleanup
  # warning so the user knows SANDBOX_DIR has partial state.
  _HAS_SIDE_EFFECTS=false
  trap '_maybe_cleanup' ERR

  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  TEMPLATES="$REPO_ROOT/scripts/templates"

  # Detect if running non-interactively (piped stdin or --yes flag).
  # --yes bypasses the confirmation prompt for scripting/CI.
  _INTERACTIVE=true
  if [[ ! -t 0 ]]; then
    _INTERACTIVE=false
  fi

  # ---------------------------------------------------------------------------
  # Flag parsing
  # ---------------------------------------------------------------------------
  PROJECT_NAME=""
  PROJECT_DIR=""
  SANDBOX_DIR=""
  REFRESH=false
  YES_FLAG=false

  local ARG
  for ARG in "$@"; do
    case "$ARG" in
      --name=*)     PROJECT_NAME="${ARG#--name=}" ;;
      --project=*)  PROJECT_DIR="${ARG#--project=}" ;;
      --sandbox=*)  SANDBOX_DIR="${ARG#--sandbox=}" ;;
      --refresh)    REFRESH=true ;;
      --yes)        YES_FLAG=true ;;
      -h|--help)    usage; exit 0 ;;
      *)
        echo "Unknown flag: $ARG" >&2
        usage
        exit 1
        ;;
    esac
  done

  if $YES_FLAG; then
    _INTERACTIVE=false
  fi

  # ---------------------------------------------------------------------------
  # Prompt for missing flags
  # ---------------------------------------------------------------------------
  if [[ -z "$PROJECT_NAME" ]]; then
    read -rp "Project name (no spaces, used for image/container naming): " PROJECT_NAME
  fi

  if [[ "$REFRESH" != true && -z "$PROJECT_DIR" ]]; then
    echo "Project directory: absolute or relative path to the project git repo."
    echo "  To convert a Windows path: wslpath 'C:\\your\\path'"
    read -rp "Project directory: " PROJECT_DIR
  fi

  if [[ -z "$SANDBOX_DIR" ]]; then
    echo "Sandbox directory: absolute or relative path where sandbox files will be created."
    echo "  To convert a Windows path: wslpath 'C:\\your\\path'"
    echo "  Convention: alongside the project dir, e.g. ${PROJECT_DIR:-<project-dir>}/../sandbox"
    read -rp "Sandbox directory: " SANDBOX_DIR
  fi

  # ---------------------------------------------------------------------------
  # Resolve and validate paths (always, for both modes)
  # ---------------------------------------------------------------------------
  resolve_and_validate SANDBOX_DIR "--sandbox" "$SANDBOX_DIR" false  # may not exist yet

  if [[ -n "$PROJECT_DIR" ]]; then
    resolve_and_validate PROJECT_DIR "--project" "$PROJECT_DIR" true
  fi

  # Derive PROJECT_DIR from .env if not provided (refresh mode)
  if [[ "$REFRESH" == true && -z "$PROJECT_DIR" ]]; then
    if [[ -f "$SANDBOX_DIR/.env" ]]; then
      PROJECT_DIR=$(grep -m1 '^PROJECT_DIR=' "$SANDBOX_DIR/.env" | cut -d= -f2-)
    fi
  fi

  if [[ "$REFRESH" == true ]]; then
    _run_refresh
  else
    _run_onboard
  fi
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
