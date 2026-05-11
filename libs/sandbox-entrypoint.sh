#!/usr/bin/env bash
# sandbox-entrypoint.sh (capability layer)
# Snapshot unpacking, git baseline, diff pipeline, autosave.
#
# Sequence:
#   1. snapshot_validate (gate 2)       — confirm .snapshot/ is intact
#   2. snapshot_init_git                — git init + baseline commit; records baseline SHA
#   3. register EXIT trap → diff        — fires on any exit; writes session export
#                                         via package_branch dispatcher, kills autosave subshell
#   4. register TERM trap → exit 0      — docker stop sends SIGTERM to PID 1; clean exit
#                                         ensures EXIT trap fires reliably
#   5. start autosave loop              — if AUTOSAVE_INTERVAL > 0
#   6. wait                             — stays running while reasoning layer is active
#
# The reasoning layer container exits first. The harness then stops this
# container via docker stop, which sends SIGTERM to PID 1 (this script).
# SIGTERM triggers the TERM trap → exit 0 → EXIT trap → diff written.
#
# Environment variables (all have defaults defined in libs/dirs.sh,
# override via docker run -e or compose .env):
#   SNAPSHOT_DIR_NAME      — name of the snapshot mount directory  (default: .snapshot)
#   SANDBOX_DIR_NAME       — name of the sandbox directory         (default: sandbox)
#   CHANGES_DIR_NAME       — session-diffs leaf under workspace    (default: session-diffs)
#   WORKSPACE_DIR_NAME     — workspace subdirectory name           (default: .workspace)
#   AUTOSAVE_INTERVAL      — autosave interval in seconds; 0 disables (default: 60)

set -euo pipefail

shopt -s nullglob

# Redirect all entrypoint output to stderr so it doesn't pollute agent output.
# View with: docker logs <container_name>
exec 1>&2

ROOT="/home/agentuser"

# Directory name defaults — single source of truth.
# Override via environment variables without rebuilding the image.
source /opt/sandbox/lib/dirs.sh

# Use container workspace convention (visible directory, not hidden)
WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
# SANDBOX_DIR is not set by dirs_resolve — derive from the same convention
SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"

AUTOSAVE_INTERVAL="${AUTOSAVE_INTERVAL:-60}"  # 0 disables

AUTOSAVE_PID=""

mkdir -p "$CHANGES_DIR"

# -------------------------
# Snapshot pipeline (container side)
# -------------------------
source /opt/sandbox/lib/session.sh
source /opt/sandbox/lib/snapshot.sh

# Gate 2 — confirm mounted snapshot is intact before unpacking.
snapshot_validate "$SNAPSHOT_DIR"

# The snapshot is already validated above and baseline.tar is read directly
# from the snapshot mount by snapshot_init_git — no copy needed.

# Initialise git baseline. Failure here means the container cannot start.
> /dev/null; snapshot_init_git "$SANDBOX_DIR" "$SNAPSHOT_DIR" || {
  echo "Error: sandbox git initialisation failed — container cannot start." >&2
  echo "  Check sandbox contents: ls -la $SANDBOX_DIR" >&2
  exit 1
}

# SESSION_STATE is written by snapshot_init_git internally (init_sha + session_ts).
# No additional writes needed — downstream consumers read from SESSION_STATE.

echo "Sandbox ready. Baseline recorded in SESSION_STATE."
echo "Working tree status:"
git -C "$SANDBOX_DIR" status --short | sed 's/^/  /'
echo "  (empty = clean working tree)"

# -------------------------
# Diff pipeline
# -------------------------
source /opt/sandbox/lib/diff.sh
source /opt/sandbox/lib/routing.sh

# On exit: kill autosave subshell if running, write session export via
# session_export_path + diff_export. Runs on any exit — clean shutdown,
# SIGTERM, or error.
#
# Uses session_export_path from routing.sh to construct the output path
# under CHANGES_DIR/session/<SESSION_TS>-<BRANCH>/, then calls diff_export
# which delegates to package_branch.
trap '[[ -n "$AUTOSAVE_PID" ]] && kill "$AUTOSAVE_PID" 2>/dev/null || true
     local _exit_dir="$(session_export_path "$CHANGES_DIR" "session" "${SESSION_TS:-unknown}" "${SANITIZED_HOST_BRANCH:-unknown}")"
     mkdir -p "$_exit_dir"
     diff_export "$SANDBOX_DIR" "$_exit_dir"' EXIT

# On SIGTERM (docker stop): exit cleanly so EXIT trap fires with code 0.
# Without this, SIGTERM interrupts wait and bash exits with 128+15=143,
# which some tooling treats as an error even though this is the expected
# shutdown path.
trap 'exit 0' TERM

# -------------------------
# Optional autosave loop
# -------------------------
# Writes autosave checkpoint on interval without committing — provides
# incremental checkpoints during a session without disturbing the baseline
# diff. Uses session_export_path from routing.sh to construct the output
# path under CHANGES_DIR/autosave/<SESSION_TS>-<BRANCH>/, then calls
# diff_export which delegates to package_branch.
# PID is tracked so the EXIT trap can kill the subshell cleanly on shutdown.
if [[ "$AUTOSAVE_INTERVAL" -gt 0 ]]; then
  (
    while true; do
      sleep "$AUTOSAVE_INTERVAL"
      local _as_dir="$(session_export_path "$CHANGES_DIR" "autosave" "${SESSION_TS:-unknown}" "${SANITIZED_HOST_BRANCH:-unknown}")"
      mkdir -p "$_as_dir"
      diff_export "$SANDBOX_DIR" "$_as_dir"
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