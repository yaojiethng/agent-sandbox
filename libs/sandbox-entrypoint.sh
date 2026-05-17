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
# Pre-flight checks
# -------------------------
# Critical invariants that must hold for every session start.
# CRITICAL failures exit non-zero (container fails healthcheck).
# WARN failures log but do not exit — the session can proceed.

PREFLIGHT_FAILS=0
_preflight_crit() {
  local msg="$1"; shift
  if "$@" 2>/dev/null; then
    echo "  PREFLIGHT PASS: $msg"
  else
    echo "  PREFLIGHT FAIL: $msg" >&2
    PREFLIGHT_FAILS=$(( PREFLIGHT_FAILS + 1 ))
  fi
}
_preflight_warn() {
  local msg="$1"; shift
  if "$@" 2>/dev/null; then
    echo "  PREFLIGHT PASS: $msg"
  else
    echo "  PREFLIGHT WARN: $msg" >&2
  fi
}

echo "--- pre-flight checks ---"

# SESSION_STATE written by snapshot_init_git
_preflight_crit "SESSION_STATE has init_sha" \
  bash -c 's="$(cat /home/agentuser/sandbox/.git/SESSION_STATE 2>/dev/null)"; [[ "$s" == *init_sha=* ]]'
_preflight_crit "SESSION_STATE has session_ts" \
  bash -c 's="$(cat /home/agentuser/sandbox/.git/SESSION_STATE 2>/dev/null)"; [[ "$s" == *session_ts=* ]]'

# Mount checks
_preflight_crit "SNAPSHOT_DIR is readable (snapshot mount)"           test -f "$SNAPSHOT_DIR/baseline.tar"
_preflight_crit "CHANGES_DIR is writable (session-diffs mount)"      touch "$CHANGES_DIR/.preflight_write_test" && rm -f "$CHANGES_DIR/.preflight_write_test"
_preflight_crit "INPUT_DIR is readable (brief mount)"                test -d "$INPUT_DIR"
_preflight_crit "OUTPUT_DIR is writable (output mount)"              touch "$OUTPUT_DIR/.preflight_write_test" && rm -f "$OUTPUT_DIR/.preflight_write_test"

# WARN: AGENTS.md in sandbox (project context loaded by pi via CWD discovery)
_preflight_warn "AGENTS.md present in sandbox (project context)"  test -f "$SANDBOX_DIR/AGENTS.md"
# WARN: AGENTS.md at AGENT_HOME (pi-specific global context — seeded by provider config)
_preflight_warn "AGENTS.md present at AGENT_HOME (pi context)"  test -f "${AGENT_HOME:-~/.pi}/AGENTS.md"
_preflight_warn "Working tree is clean"                              bash -c 'cd "$SANDBOX_DIR"; [[ -z "$(git status --short)" ]]'

echo "--- pre-flight: $([ "$PREFLIGHT_FAILS" -eq 0 ] && echo 'ALL CHECKS PASSED' || echo "$PREFLIGHT_FAILS FAILURE(S)") ---"

if [[ "$PREFLIGHT_FAILS" -gt 0 ]]; then
  exit 1
fi

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