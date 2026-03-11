#!/usr/bin/env bash
# .vault/scripts/checkpoint-prune.sh
#
# Prunes old checkpoint branches, keeping the N most recent.
# Never touches the checkpoint/latest tag or any non-checkpoint branches.
#
# Checkpoint branches follow the naming pattern: checkpoint/YYYY-MM-DD[-label]
# Sorted lexicographically (ISO date prefix ensures correct order).
#
# Usage:
#   bash .vault/scripts/checkpoint-prune.sh --vault=<path> --keep=<n>
#
# --vault   Path to vault root (required)
# --keep    Number of most recent checkpoint branches to keep (required)

set -euo pipefail

# -------------------------
# Args
# -------------------------
VAULT_DIR=""
KEEP=""

for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULT_DIR="${arg#--vault=}" ;;
    --keep=*)  KEEP="${arg#--keep=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VAULT_DIR" || -z "$KEEP" ]]; then
  echo "Usage: bash .vault/scripts/checkpoint-prune.sh --vault=<path> --keep=<n>" >&2
  exit 1
fi

if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [[ "$KEEP" -lt 1 ]]; then
  echo "ERROR: --keep must be a positive integer" >&2
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
# List checkpoint branches (sorted oldest-first)
# Excludes: checkpoint/latest (tag, not branch)
# -------------------------
info "Scanning checkpoint branches"
cd "$VAULT_DIR"

mapfile -t ALL_CHECKPOINTS < <(
  git branch --list 'checkpoint/*' --format='%(refname:short)' \
    | sort
)

TOTAL="${#ALL_CHECKPOINTS[@]}"
log "Found $TOTAL checkpoint branch(es)"

if [[ "$TOTAL" -eq 0 ]]; then
  echo ""
  echo "No checkpoint branches found. Nothing to prune."
  exit 0
fi

# -------------------------
# Determine which to delete
# -------------------------
if [[ "$TOTAL" -le "$KEEP" ]]; then
  echo ""
  echo "Only $TOTAL checkpoint(s) exist; keeping all (--keep=${KEEP}). Nothing to prune."
  exit 0
fi

DELETE_COUNT=$(( TOTAL - KEEP ))
# Oldest are first in sorted order — delete from the front
TO_DELETE=("${ALL_CHECKPOINTS[@]:0:$DELETE_COUNT}")
TO_KEEP=("${ALL_CHECKPOINTS[@]:$DELETE_COUNT}")

log ""
log "Keeping ($KEEP):"
for b in "${TO_KEEP[@]}"; do
  sha=$(git rev-parse --short "$b")
  log "  $b ($sha)"
done

log ""
log "Deleting ($DELETE_COUNT):"
for b in "${TO_DELETE[@]}"; do
  sha=$(git rev-parse --short "$b")
  log "  $b ($sha)"
done

# -------------------------
# Confirm and delete
# -------------------------
echo ""
read -r -p "  Proceed with deletion? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "  Aborted."
  exit 0
fi

echo ""
for b in "${TO_DELETE[@]}"; do
  git branch -D "$b"
  log "Deleted: $b"
done

echo ""
echo "Pruned $DELETE_COUNT checkpoint branch(es). $KEEP retained."
