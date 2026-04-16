#!/usr/bin/env bash
# workflow/knowledge-vault/onboard.sh
#
# One-time onboarding for an Obsidian vault into agent-sandbox.
#
# Places at vault root:
#   Makefile       — pre-filled from libs/_templates/Makefile.template
#   AGENTS.md      — agent brief starter (operator fills in before make start)
#   .vault         — relative symlink to this workflow directory
#
# Idempotent: warns and exits without changes if already onboarded.
#
# Usage:
#   workflow/knowledge-vault/onboard.sh --vault=<path>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${WORKFLOW_DIR}/../.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/libs/_templates"

# -------------------------
# Args
# -------------------------
VAULT_DIR=""

for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULT_DIR="${arg#--vault=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VAULT_DIR" ]]; then
  echo "ERROR: --vault is required." >&2
  echo "Usage: agent-sandbox onboard knowledge-vault --vault=<path>" >&2
  exit 1
fi

if [[ ! -d "$VAULT_DIR" ]]; then
  echo "ERROR: vault directory not found: $VAULT_DIR" >&2
  exit 1
fi

VAULT_DIR="$(cd "$VAULT_DIR" && pwd)"
VAULT_NAME="$(basename "$VAULT_DIR")"

# -------------------------
# Confirm this is an Obsidian vault
# -------------------------
if [[ ! -d "$VAULT_DIR/.obsidian" ]]; then
  echo "ERROR: $VAULT_DIR does not look like an Obsidian vault (.obsidian/ not found)." >&2
  exit 1
fi

# -------------------------
# Warn if Obsidian Sync appears active
# -------------------------
if [[ -f "$VAULT_DIR/.obsidian/sync.json" ]]; then
  echo "WARNING: Obsidian Sync appears to be configured for this vault."
  echo "         Before running 'make initialize', go to:"
  echo "           Obsidian → Settings → Sync → Excluded files"
  echo "         and add '.git' to prevent Sync from uploading the git object store."
  echo ""
fi

# -------------------------
# Idempotency check
# -------------------------
VAULT_LINK="$VAULT_DIR/.vault"
MAKEFILE_PATH="$VAULT_DIR/Makefile"
ENV_PATH="$VAULT_DIR/.env"

if [[ -L "$VAULT_LINK" || -f "$MAKEFILE_PATH" ]]; then
  echo "WARNING: This vault appears to have already been onboarded." >&2
  echo "         Found: $([ -L "$VAULT_LINK" ] && echo ".vault symlink ")$([ -f "$MAKEFILE_PATH" ] && echo "Makefile")" >&2
  echo "" >&2
  echo "         If initialization failed and you need to re-run it:" >&2
  echo "           cd ${VAULT_DIR} && make initialize" >&2
  echo "" >&2
  echo "         To re-onboard from scratch, remove the files above first." >&2
  exit 1
fi

# -------------------------
# Validate template exists
# -------------------------
MAKEFILE_TEMPLATE="$TEMPLATE_DIR/Makefile.template"
if [[ ! -f "$MAKEFILE_TEMPLATE" ]]; then
  echo "ERROR: Makefile template not found: $MAKEFILE_TEMPLATE" >&2
  exit 1
fi

# -------------------------
# Step 1 — Place .vault symlink
# -------------------------
echo "=== Step 1/2 — Linking vault tooling ==="
echo ""

# Relative path from vault root to this workflow directory
ln -s "$WORKFLOW_DIR" "$VAULT_LINK"
echo "  .vault → $WORKFLOW_DIR (absolute symlink)"
echo "  Add .vault to .gitignore after initialization."

# -------------------------
# Step 2 — Place Files
# -------------------------
echo ""
echo "=== Step 2/2 — Placing Files ==="
echo ""

# Substitute <project-name> placeholder, then append initialize target
sed "s/<project-name>/${VAULT_NAME}/g" "$MAKEFILE_TEMPLATE" > "$MAKEFILE_PATH"

# Append vault-specific targets using printf to preserve tab characters
printf '\ninitialize:\n\tbash .vault/scripts/vault-prepare.sh --vault=$(PROJECT_ROOT)\n' >> "$MAKEFILE_PATH"
printf '\ncheckpoint:\n\tbash .vault/scripts/checkpoint-create.sh --root=$(PROJECT_ROOT)\n' >> "$MAKEFILE_PATH"
printf '\nrollback:\n\tbash .vault/scripts/checkpoint-rollback.sh --root=$(PROJECT_ROOT)\n' >> "$MAKEFILE_PATH"
printf '\ncheckpoint-prune:\n\tbash .vault/scripts/checkpoint-prune.sh --root=$(PROJECT_ROOT) --keep=$(N)\n' >> "$MAKEFILE_PATH"

# Append vault-specific targets to .PHONY line
sed -i "s/^\.PHONY:.*$/& initialize checkpoint rollback checkpoint-prune/" "$MAKEFILE_PATH"

echo "  Makefile written"
echo "  PROJECT_NAME = ${VAULT_NAME}"
echo "  PROJECT_ROOT = (resolved at make time via \$(CURDIR))"
echo "  AGENT_BRIEF  = AGENTS.md"

touch $ENV_PATH
echo "  .env written"

BRIEF_PATH="$VAULT_DIR/AGENTS.md"
if [[ -f "$BRIEF_PATH" ]]; then
  echo "  AGENTS.md already exists — skipping"
else
  cat > "$BRIEF_PATH" <<BRIEF
# Agent Brief — ${VAULT_NAME}

## Vault
<one paragraph: what this vault contains, how it is structured, its current state>

## Constraints
<naming conventions, folders not to touch, link format requirements>

## Task
<describe the current task or migration scope here before each session>
BRIEF
  echo "  AGENTS.md written"
fi

# -------------------------
# Done
# -------------------------
echo ""
echo "Onboarding complete."
echo ""
echo "Before running 'make initialize':"
echo "  1. Verify git identity is set:"
echo "       git config --global user.name / user.email"
if [[ -f "$VAULT_DIR/.obsidian/sync.json" ]]; then
echo "  2. In Obsidian: Settings → Sync → Excluded files → add '.git'"
echo "  3. Fill in AGENTS.md with vault context and current task"
else
echo "  2. Fill in AGENTS.md with vault context and current task"
fi
echo ""
echo "Then run:"
echo "  cd ${VAULT_DIR} && make initialize"
