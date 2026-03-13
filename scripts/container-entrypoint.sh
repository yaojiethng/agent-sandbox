#!/usr/bin/env bash
# container-entrypoint.sh
# Sandbox setup + diff staging + autosave

set -euo pipefail

shopt -s nullglob

# Redirect all entrypoint output to stderr so it doesn't pollute the TUI.
# View with: docker logs <container_name>
exec 1>&2

ROOT="/home/agentuser"

# -------------------------
# Directory names from env
# Defined in start_agent.sh and passed via -e at docker run time.
# -------------------------
AGENT_INPUT_DIR_NAME="${AGENT_INPUT_DIR_NAME:-.agent-input}"
AGENT_WORKSPACE_DIR_NAME="${AGENT_WORKSPACE_DIR_NAME:-.workspace}"

AGENT_INPUT_DIR="$ROOT/$AGENT_INPUT_DIR_NAME"
AGENT_WORKSPACE_DIR="$ROOT/$AGENT_WORKSPACE_DIR_NAME"

SNAPSHOT_DIR="$AGENT_INPUT_DIR/snapshot"
SANDBOX_DIR="$ROOT/sandbox"
CHANGES_DIR="$AGENT_WORKSPACE_DIR/changes"

AUTOSAVE_INTERVAL="${AUTOSAVE_INTERVAL:-60}"  # 0 disables

mkdir -p "$CHANGES_DIR"

# -------------------------
# Snapshot pipeline (container side)
# -------------------------
source /lib/snapshot.sh

# Gate 2 — confirm mounted snapshot is intact before unpacking.
snapshot_validate "$SNAPSHOT_DIR"

# Clear any previous sandbox state to prevent stale git index issues.
# cd back to ROOT first — snapshot_init_git changes cwd and rm -rf would
# otherwise leave the shell in a deleted directory on the next run.
rm -rf "$SANDBOX_DIR"
cd "$ROOT"

# Copy snapshot into container-local sandbox/.
snapshot_copy_to_sandbox "$SNAPSHOT_DIR" "$SANDBOX_DIR"

# Confirm files landed — catch silent copy failures before init.
file_count=$(find "$SANDBOX_DIR" -type f | wc -l)
if [[ "$file_count" -eq 0 ]]; then
  echo "Error: sandbox is empty after copy — snapshot may be missing files." >&2
  echo "  Snapshot dir: $SNAPSHOT_DIR" >&2
  echo "  Run: ls -la $SNAPSHOT_DIR" >&2
  exit 1
fi
echo "Copied $file_count file(s) into sandbox."

# Initialise git baseline. Failure here means the container cannot start.
# Command substitution runs snapshot_init_git in a subshell, containing its
# internal cd. The explicit cd "$ROOT" afterward guards against any cwd leak.
BASELINE_SHA=$(snapshot_init_git "$SANDBOX_DIR") || {
  echo "Error: sandbox git initialisation failed — container cannot start." >&2
  echo "  Check sandbox contents: ls -la $SANDBOX_DIR" >&2
  exit 1
}
cd "$ROOT"

echo "Sandbox ready. Baseline: $BASELINE_SHA"

# -------------------------
# Copy brief into sandbox root
# -------------------------
if [[ -f "$AGENT_INPUT_DIR/brief.md" ]]; then
  cp -p "$AGENT_INPUT_DIR/brief.md" "$SANDBOX_DIR/AGENTS.md"
fi

# -------------------------
# Copy operator input files into sandbox
# -------------------------
# Contents of .agent-input/input/ are copied into sandbox/ so the agent
# can read task files, path lists, and other operator-provided materials
# alongside the project snapshot. The agent cannot write back to this channel.
if [[ -d "$AGENT_INPUT_DIR/input" ]]; then
  input_count=$(find "$AGENT_INPUT_DIR/input" -type f | wc -l)
  if [[ "$input_count" -gt 0 ]]; then
    cp -a "$AGENT_INPUT_DIR/input/." "$SANDBOX_DIR/"
    echo "Copied $input_count operator input file(s) into sandbox."
  fi
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
