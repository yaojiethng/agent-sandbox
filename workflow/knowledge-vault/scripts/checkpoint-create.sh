#!/usr/bin/env bash
# .vault/scripts/checkpoint-create.sh
#
# Creates a named checkpoint of the current vault state.
#
# Creates:
#   - A dated branch: checkpoint/YYYY-MM-DD
#   - Updates the force tag: checkpoint/latest
#
# LFS objects are fetched locally before branching to ensure the
# checkpoint is self-contained from the local cache. No remote push.
#
# Usage:
#   bash .vault/scripts/checkpoint-create.sh --vault=<path> [--label=<name>]
#
# --vault   Path to vault root (required)
# --label   Optional suffix appended to branch name: checkpoint/YYYY-MM-DD-<label>

set -euo pipefail

# -------------------------
# Args
# -------------------------
VAULT_DIR=""
LABEL=""

for arg in "$@"; do
  case "$arg" in
    --vault=*)  VAULT_DIR="${arg#--vault=}" ;;
    --label=*)  LABEL="${arg#--label=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VAULT_DIR" ]]; then
  echo "Usage: bash .vault/scripts/checkpoint-create.sh --vault=<path> [--label=<name>]" >&2
  exit 1
fi

if [[ ! -d "$VAULT_DIR/.git" ]]; then
  echo "ERROR: not a git repository: $VAULT_DIR" >&2
  echo "       Run vault-init.sh first." >&2
  exit 1
fi

VAULT_DIR="$(cd "$VAULT_DIR" && pwd)"

# -------------------------
# Helpers
# -------------------------
log()  { echo "  $*"; }
info() { echo; echo "=== $* ==="; }

# -------------------------
# Build branch name
# -------------------------
TODAY="$(date +%Y-%m-%d)"
if [[ -n "$LABEL" ]]; then
  BRANCH="checkpoint/${TODAY}-${LABEL}"
else
  BRANCH="checkpoint/${TODAY}"
fi

# -------------------------
# Ensure working tree is clean
# -------------------------
info "Pre-flight"
cd "$VAULT_DIR"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree has uncommitted changes." >&2
  echo "       Commit or stash before creating a checkpoint." >&2
  exit 1
fi
log "Working tree clean"

# -------------------------
# Fetch LFS objects into local cache
# -------------------------
info "Fetching LFS objects"
git lfs fetch --all 2>/dev/null && log "LFS objects fetched" \
  || log "WARNING: git lfs fetch returned non-zero — checkpoint may be incomplete"

# -------------------------
# Create checkpoint branch
# -------------------------
info "Creating checkpoint"

CURRENT_SHA=$(git rev-parse HEAD)

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  echo "ERROR: branch '${BRANCH}' already exists." >&2
  echo "       Use --label to append a suffix, or delete the existing branch first." >&2
  exit 1
fi

git branch "$BRANCH"
log "Created branch: $BRANCH (${CURRENT_SHA:0:8})"

# Force-update the latest tag
git tag -f checkpoint/latest
log "Updated tag: checkpoint/latest → ${CURRENT_SHA:0:8}"

echo ""
echo "Checkpoint created: $BRANCH"
echo "  SHA: $CURRENT_SHA"
echo ""
echo "To roll back: bash .vault/scripts/checkpoint-rollback.sh --vault=<path> --checkpoint=${BRANCH}"
