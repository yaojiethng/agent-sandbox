#!/usr/bin/env bash
# sandbox-entrypoint.sh (capability layer)
# Snapshot unpacking, git baseline, diff pipeline, autosave.
#
# Sequence:
#   1. snapshot_validate (gate 2)       — confirm .snapshot/ is intact
#   2. snapshot_copy_to_sandbox         — copy snapshot into sandbox/ (clean at container start)
#   3. snapshot_init_git                — git init + baseline commit; records baseline SHA
#   4. register EXIT trap → diff        — fires on any exit; commits pending changes,
#                                         writes staged.diff, kills autosave subshell
#   5. register TERM trap → exit 0      — docker stop sends SIGTERM to PID 1; clean exit
#                                         ensures EXIT trap fires reliably
#   6. start autosave loop              — if AUTOSAVE_INTERVAL > 0
#   7. wait                             — stays running while reasoning layer is active
#
# The reasoning layer container exits first. The harness then stops this
# container via docker stop, which sends SIGTERM to PID 1 (this script).
# SIGTERM triggers the TERM trap → exit 0 → EXIT trap → diff written.
#
# Environment variables (all have defaults defined in libs/dirs.sh,
# override via docker run -e or compose .env):
#   SNAPSHOT_DIR_NAME      — name of the snapshot mount directory  (default: .snapshot)
#   SANDBOX_DIR_NAME       — name of the sandbox directory         (default: sandbox)
#   CHANGES_DIR_NAME       — name of the diff output subdirectory  (default: workspace/session-diffs)
#   AUTOSAVE_INTERVAL      — autosave interval in seconds; 0 disables (default: 60)

set -euo pipefail

shopt -s nullglob

# Redirect all entrypoint output to stderr so it doesn't pollute agent output.
# View with: docker logs <container_name>
exec 1>&2

ROOT="/home/agentuser"

# Directory name defaults — single source of truth.
# Override via environment variables without rebuilding the image.
source /libs/dirs.sh

SNAPSHOT_DIR="$ROOT/$SNAPSHOT_DIR_NAME"
SANDBOX_DIR="$ROOT/$SANDBOX_DIR_NAME"
# The capability layer mounts workspace/session-diffs/ only — not the workspace parent.
# The diff pipeline writes exclusively to this subdirectory.
# Writing outside workspace/session-diffs/ from the capability layer is a bug.
CHANGES_DIR="$ROOT/$CHANGES_DIR_NAME"

AUTOSAVE_INTERVAL="${AUTOSAVE_INTERVAL:-60}"  # 0 disables

AUTOSAVE_PID=""

mkdir -p "$CHANGES_DIR"

# -------------------------
# Snapshot pipeline (container side)
# -------------------------
source /libs/snapshot.sh

# Gate 2 — confirm mounted snapshot is intact before unpacking.
snapshot_validate "$SNAPSHOT_DIR"

# Copy snapshot into sandbox/.
# sandbox/ starts clean from the image — no stale content to clear.
# The reasoning layer accesses this directory via --volumes-from, so it
# sees exactly what the capability layer writes here and nothing else.
snapshot_copy_to_sandbox "$SNAPSHOT_DIR" "$SANDBOX_DIR"

# Confirm files landed — catch silent copy failures before git init.
file_count=$(find "$SANDBOX_DIR" -type f | wc -l)
if [[ "$file_count" -eq 0 ]]; then
  echo "Error: sandbox is empty after copy — snapshot may be missing files." >&2
  echo "  Snapshot dir: $SNAPSHOT_DIR" >&2
  echo "  Run: ls -la $SNAPSHOT_DIR" >&2
  exit 1
fi
echo "Copied $file_count file(s) into sandbox."

# Initialise git baseline. Failure here means the container cannot start.
BASELINE_SHA=$(snapshot_init_git "$SANDBOX_DIR" "$SNAPSHOT_DIR") || {
  echo "Error: sandbox git initialisation failed — container cannot start." >&2
  echo "  Check sandbox contents: ls -la $SANDBOX_DIR" >&2
  exit 1
}

echo "Sandbox ready. Baseline: $BASELINE_SHA"
echo "Working tree status:"
git -C "$SANDBOX_DIR" status --short | sed 's/^/  /'
echo "  (empty = clean working tree)"

# -------------------------
# Diff pipeline
# -------------------------
source /libs/diff.sh

# On exit: kill autosave subshell if running, commit any pending changes,
# write staged.diff. Runs on any exit — clean shutdown, SIGTERM, or error.
trap '[[ -n "$AUTOSAVE_PID" ]] && kill "$AUTOSAVE_PID" 2>/dev/null || true
     diff_on_exit "$SANDBOX_DIR" "$BASELINE_SHA" "$CHANGES_DIR" "${SESSION_NAME:-}"' EXIT

# On SIGTERM (docker stop): exit cleanly so EXIT trap fires with code 0.
# Without this, SIGTERM interrupts wait and bash exits with 128+15=143,
# which some tooling treats as an error even though this is the expected
# shutdown path.
trap 'exit 0' TERM

# -------------------------
# Optional autosave loop
# -------------------------
# Writes autosave.diff on interval without committing — provides incremental
# checkpoints during a session without disturbing the baseline diff.
# PID is tracked so the EXIT trap can kill the subshell cleanly on shutdown.
if [[ "$AUTOSAVE_INTERVAL" -gt 0 ]]; then
  (
    while true; do
      sleep "$AUTOSAVE_INTERVAL"
      diff_on_autosave "$SANDBOX_DIR" "$BASELINE_SHA" "$CHANGES_DIR" "${SESSION_NAME:-}"
    done
  ) &
  AUTOSAVE_PID=$!
fi

# -------------------------
# Stay alive while reasoning layer runs
# -------------------------
# The reasoning layer container mounts sandbox/ from this container via
# --volumes-from. If the capability layer is not running, the reasoning
# layer cannot start. The harness stops this container after the
# reasoning layer exits.
#
# sleep infinity runs in the background; wait blocks the shell on it.
# This keeps bash as PID 1 and the signal-receiving process — SIGTERM
# from docker stop is delivered to bash, the TERM trap fires, exit 0
# triggers the EXIT trap, and the diff pipeline runs.
# Plain `sleep infinity` as a foreground process receives the signal
# directly and exits, bypassing the bash trap entirely.
sleep infinity &
wait $!