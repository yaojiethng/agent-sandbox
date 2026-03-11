#!/usr/bin/env bash
# .vault/scripts/checkpoint-rollback.sh
#
# Restores the vault to a named checkpoint branch or the latest tag.
#
# Creates a new commit on the current branch that resets the tree
# to the checkpoint state (does not rewrite history). The operator
# can inspect the result before committing further.
#
# Usage:
#   bash .vault/scripts/checkpoint-rollback.sh --vault=<path> [--checkpoint=<ref>]
#
# --vault        Path to vault root (required)
# --checkpoint   Branch or tag to roll back to (default: checkpoint/latest)

set -euo pipefail

# -------------------------
# Args
# -------------------------
VAULT_DIR=""
CHECKPOINT_REF="checkpoint/latest"

for arg in "$@"; do
  case "$arg" in
    --vault=*)       VAULT_DIR="${arg#--vault=}" ;;
    --checkpoint=*)  CHECKPOINT_REF="${arg#--checkpoint=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VAULT_DIR" ]]; then
  echo "Usage: bash .vault/scripts/checkpoint-rollback.sh --vault=<path> [--checkpoint=<ref>]" >&2
  exit 1
fi

if [[ ! -d "$VAULT_DIR/.git" ]]; then
  echo "ERROR: not a git repository: $VAULT_DIR" >&2
  exit 1
fi

VAULT_DIR="$(cd "$VAULT_DIR" && pwd)"

# -------------------------
# Helpers
# -------------------------
log()  { echo "  $*"; }
info() { echo; echo "=== $* ==="; }

# -------------------------
# Resolve checkpoint ref
# -------------------------
info "Resolving checkpoint"
cd "$VAULT_DIR"

CHECKPOINT_SHA=$(git rev-parse --verify "${CHECKPOINT_REF}" 2>/dev/null || true)
if [[ -z "$CHECKPOINT_SHA" ]]; then
  echo "ERROR: checkpoint ref not found: ${CHECKPOINT_REF}" >&2
  echo "       List available checkpoints with: git branch --list 'checkpoint/*'" >&2
  exit 1
fi

log "Checkpoint: $CHECKPOINT_REF → ${CHECKPOINT_SHA:0:8}"
CURRENT_SHA=$(git rev-parse HEAD)
log "Current HEAD: ${CURRENT_SHA:0:8}"

# -------------------------
# Ensure working tree is clean
# -------------------------
info "Pre-flight"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree has uncommitted changes." >&2
  echo "       Commit or stash before rolling back." >&2
  exit 1
fi
log "Working tree clean"

# -------------------------
# Perform rollback via merge strategy
# Resets tree to checkpoint state without rewriting history.
# -------------------------
info "Rolling back to ${CHECKPOINT_REF}"

TODAY="$(date +%Y-%m-%d)"
git merge --strategy=ours --no-commit "${CHECKPOINT_SHA}" 2>/dev/null || true
git checkout "${CHECKPOINT_SHA}" -- .
git commit -m "rollback: restore to ${CHECKPOINT_REF} (${TODAY})"

ROLLBACK_SHA=$(git rev-parse HEAD)
log "Rollback commit: ${ROLLBACK_SHA:0:8}"

# Restore LFS working tree files
git lfs checkout 2>/dev/null && log "LFS files restored" \
  || log "WARNING: git lfs checkout returned non-zero — verify attachment state"

echo ""
echo "Rollback complete."
echo "  Restored: $CHECKPOINT_REF (${CHECKPOINT_SHA:0:8})"
echo "  New HEAD:  ${ROLLBACK_SHA:0:8}"
echo ""
echo "Review the result, then commit or continue as normal."
