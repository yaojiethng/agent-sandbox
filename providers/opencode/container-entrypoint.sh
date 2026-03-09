#!/usr/bin/env bash
# container-entrypoint.sh
# Sandbox setup + diff staging + autosave

set -euo pipefail

shopt -s nullglob

# Redirect all entrypoint output to stderr so it doesn't pollute the TUI.
# View with: docker logs <container_name>
exec 1>&2

ROOT="/home/agentuser"

BOOTSTRAP_DIR="$ROOT/.bootstrap"
SNAPSHOT_DIR="$BOOTSTRAP_DIR/snapshot"
SANDBOX_DIR="$ROOT/sandbox"
WORKSPACE_DIR="$ROOT/.workspace"
CHANGES_DIR="$WORKSPACE_DIR/changes"

AUTOSAVE_INTERVAL="${AUTOSAVE_INTERVAL:-60}"  # 0 disables

mkdir -p "$CHANGES_DIR"

# -------------------------
# Snapshot pipeline (container side)
# -------------------------
source /lib/snapshot.sh

# Gate 2 — confirm mounted snapshot is intact before unpacking.
snapshot_validate "$SNAPSHOT_DIR"

# Copy snapshot into container-local sandbox/ and initialise git baseline.
snapshot_copy_to_sandbox "$SNAPSHOT_DIR" "$SANDBOX_DIR"
BASELINE_SHA=$(snapshot_init_git "$SANDBOX_DIR")

echo "Sandbox ready. Baseline: $BASELINE_SHA"

# -------------------------
# Copy brief into sandbox root
# -------------------------
if [[ -f "$BOOTSTRAP_DIR/brief.md" ]]; then
  cp -p "$BOOTSTRAP_DIR/brief.md" "$SANDBOX_DIR/brief.md"
fi

# -------------------------
# Diff pipeline
# -------------------------
source /lib/diff.sh

# On exit: commit any pending changes and write staged.diff.
trap 'diff_on_exit "$SANDBOX_DIR" "$BASELINE_SHA" "$CHANGES_DIR"' EXIT

# Optional autosave: write autosave.diff on interval without committing.
if [[ "$AUTOSAVE_INTERVAL" -gt 0 ]]; then
  (
    while true; do
      sleep "$AUTOSAVE_INTERVAL"
      diff_on_autosave "$SANDBOX_DIR" "$BASELINE_SHA" "$CHANGES_DIR"
    done
  ) &
fi

# -------------------------
# Execute OpenCode
# -------------------------
# Run without exec so the EXIT trap fires in this shell when OpenCode exits.
"$@"
