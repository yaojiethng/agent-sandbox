#!/usr/bin/env bash
# .vault/scripts/vault-init.sh
#
# Initializes or refreshes git + LFS setup for an Obsidian vault.
#
# Safe to re-run. On subsequent runs:
#   - Regenerates .gitattributes (picks up newly seen extensions)
#   - Skips git init, LFS install, .gitignore, and first commit
#   - Stages .gitattributes changes for operator review
#
# Backup file behavior:
#   - Live file exists, backup missing  → creates backup from live (operator stages)
#   - Live file missing, backup exists  → seeds live from backup (included in init commit)
#   - Both exist                        → skips
#   - Neither exists                    → skips
#
# Usage:
#   bash .vault/scripts/vault-init.sh --vault=<path>
#
# Prerequisites: git, git-lfs

set -euo pipefail

# -------------------------
# Locate lib relative to this script
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../libs" && pwd)"

source "${LIB_DIR}/classify.sh"
source "${LIB_DIR}/gitattributes.sh"

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
  echo "Usage: bash .vault/scripts/vault-init.sh --vault=<path>" >&2
  exit 1
fi

if [[ ! -d "$VAULT_DIR" ]]; then
  echo "ERROR: vault directory not found: $VAULT_DIR" >&2
  exit 1
fi

VAULT_DIR="$(cd "$VAULT_DIR" && pwd)"
VAULT_NAME="$(basename "$VAULT_DIR")"
TODAY="$(date +%Y-%m-%d)"

# -------------------------
# Helpers
# -------------------------
log()  { echo "  $*"; }
info() { echo; echo "=== $* ==="; }

require() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: required tool '$1' not found. Install it and re-run." >&2
    exit 1
  fi
}

# -------------------------
# Preflight
# -------------------------
require git
require git-lfs

ALREADY_INITIALIZED=0
if [[ -d "$VAULT_DIR/.git" ]]; then
  ALREADY_INITIALIZED=1
fi

# -------------------------
# Classify extensions
# -------------------------
info "Discovering file types"
classify_extensions "$VAULT_DIR"
print_classification

# -------------------------
# Generate .gitattributes
# -------------------------
info "Generating .gitattributes"
generate_gitattributes "$VAULT_DIR/.gitattributes"
log ".gitattributes written"

# -------------------------
# First-run only: git init, LFS, .gitignore
# -------------------------
if [[ "$ALREADY_INITIALIZED" -eq 0 ]]; then
  info "Initializing repository"

  cd "$VAULT_DIR"
  git init --quiet
  git lfs install --local
  log "git + LFS initialized"

  generate_gitignore "$VAULT_DIR/.gitignore"
  log ".gitignore written"
  log ""
  log "NOTE: To enable plugin version tracking, edit .gitignore and"
  log "      remove the '.obsidian/plugins/' line. See vault-onboarding.md."
fi

# -------------------------
# Backup file handling
# -------------------------
info "Checking backup files"

handle_backup() {
  local live_file="$1"
  local backup_file="$2"
  local label="$3"

  if [[ -f "$live_file" && ! -f "$backup_file" ]]; then
    cp "$live_file" "$backup_file"
    log "Created ${label} backup: $(basename "$backup_file") (stage and commit when ready)"
  elif [[ ! -f "$live_file" && -f "$backup_file" ]]; then
    cp "$backup_file" "$live_file"
    log "Seeded ${label} from backup: $(basename "$live_file") (will be included in init commit)"
  elif [[ -f "$live_file" && -f "$backup_file" ]]; then
    log "${label}: both live and backup present — skipping"
  else
    log "${label}: neither live nor backup found — skipping"
  fi
}

OBSIDIAN_DIR="$VAULT_DIR/.obsidian"
handle_backup \
  "$OBSIDIAN_DIR/app.json" \
  "$OBSIDIAN_DIR/app.backup.json" \
  "app.json"

handle_backup \
  "$OBSIDIAN_DIR/appearance.json" \
  "$OBSIDIAN_DIR/appearance.backup.json" \
  "appearance.json"

# -------------------------
# First commit (first run only)
# -------------------------
if [[ "$ALREADY_INITIALIZED" -eq 0 ]]; then
  info "Creating baseline commit"
  cd "$VAULT_DIR"
  git add -A
  git commit --quiet -m "init: ${VAULT_NAME} ${TODAY}"
  BASELINE_SHA=$(git rev-parse HEAD)
  log "Baseline commit: $BASELINE_SHA"
  log ""
  log "Vault initialized. Next steps:"
  log "  1. Review .gitignore — uncomment .obsidian/plugins/ to track plugin versions"
  log "  2. Review .gitattributes — verify extension classifications"
  log "  3. Run checkpoint-create.sh to snapshot this baseline"
else
  info "Refreshing existing repository"
  cd "$VAULT_DIR"
  git add .gitattributes
  if git diff --cached --quiet; then
    log ".gitattributes unchanged — nothing to stage"
  else
    log ".gitattributes updated — staged for commit"
    log "Review with: git diff --cached"
    log "Commit when ready: git commit -m 'chore: refresh .gitattributes'"
  fi
fi
