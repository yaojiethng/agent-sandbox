#!/usr/bin/env bash
# sandbox-entrypoint.sh (capability layer)
# Snapshot unpacking, git baseline, diff pipeline, autosave.
#
# Sequence:
#   1. snapshot_validate (gate 2)       — confirm .snapshot/ is intact
#   2. snapshot_init_git                — git init + baseline commit; records baseline SHA
#   3. register EXIT trap → _session_export — fires on any exit; waits for git lockfile,
#                                         runs session export, falls back to autosave on failure
#   4. register TERM trap → exit 0      — docker stop sends SIGTERM to PID 1; clean exit
#                                         ensures EXIT trap fires reliably
#   5. start autosave loop              — if AUTOSAVE_INTERVAL > 0; logs every attempt to stderr
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

# Workspace paths are passed as absolute env vars from the compose template
# (x-workspace anchor). Fallback to dirs_resolve only if unset (testing).
SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"
SNAPSHOT_DIR="${SNAPSHOT_DIR:-}"
CHANGES_DIR="${CHANGES_DIR:-}"
INPUT_DIR="${INPUT_DIR:-}"
OUTPUT_DIR="${OUTPUT_DIR:-}"

if [[ -z "$SNAPSHOT_DIR" || -z "$CHANGES_DIR" || -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
  # Fallback: derive paths from dirs.sh (testing env where compose not used)
  source /opt/sandbox/lib/dirs.sh
  WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
fi

AUTOSAVE_INTERVAL="${AUTOSAVE_INTERVAL:-60}"  # 0 disables

AUTOSAVE_PID=""

mkdir -p "$CHANGES_DIR"

# -------------------------
# Preflight: verify container libs
# -------------------------
# /opt/sandbox/lib/ is baked into the image at build time. If files are
# missing, the image is stale and must be rebuilt with `make build`.
#
# Files required for startup are CRITICAL — container aborts if absent.
# Files needed later are WARN — container continues but certain operations
# (diff pipeline, routing) will fail at runtime.
LIB_DIR="/opt/sandbox/lib"
for entry in "dirs.sh:CRITICAL" "session_state.sh:CRITICAL" "snapshot.sh:CRITICAL" \
             "diff_export.sh:WARN" "routing.sh:WARN" "package_branch.sh:WARN" \
             "package_diff.sh:WARN"; do
  lib="${entry%%:*}"
  severity="${entry##*:}"
  if [[ ! -f "$LIB_DIR/$lib" ]]; then
    if [[ "$severity" == "CRITICAL" ]]; then
      echo "FATAL: $LIB_DIR/$lib is missing — image is stale, rebuild with 'make build'" >&2
      exit 1
    else
      echo "WARN: $LIB_DIR/$lib is missing — image may be stale" >&2
    fi
  fi
done
unset LIB_DIR

# -------------------------
# Snapshot pipeline (container side)
# -------------------------
source /opt/sandbox/lib/session_state.sh
source /opt/sandbox/lib/snapshot.sh

if [[ -d "$SANDBOX_DIR/.git" ]]; then
  # Resume path: volume has existing git state from a previous session.
  # Skip snapshot_init_git and SESSION_STATE init — state is intact.
  # Workspace paths are still written in case this is a post-migration
  # resume where SESSION_STATE exists but path fields are from an old layout.
  echo "Resuming existing volume — git state found at $SANDBOX_DIR/.git"
  if [[ ! -f "$SANDBOX_DIR/.git/SESSION_STATE" ]]; then
    echo "WARN: SESSION_STATE missing from existing volume — some features may not work" >&2
  else
    # Upgrade path: on first resume after upgrading from pre-Phase-1.5,
    # SESSION_STATE may have identity values that don't match the current
    # env vars (set from .run-identity or freshly computed). Update to
    # match so that package_branch and diff_export use consistent identity.
    _sr=$(session_state_read "$SANDBOX_DIR" "run_id" 2>/dev/null || true)
    if [[ -n "$_sr" && "$_sr" != "${RUN_ID:-}" ]]; then
      echo "Upgrade path: SESSION_STATE.run_id ($_sr) differs from RUN_ID (${RUN_ID:-}) — updating" >&2
      session_state_write "$SANDBOX_DIR" "run_id" "${RUN_ID:-}"
      session_state_write "$SANDBOX_DIR" "session_ts" "${SESSION_TS:-}"
      session_state_write "$SANDBOX_DIR" "host_head_sha" "${HOST_HEAD_SHA:-}"
    fi
  fi
  session_state_write "$SANDBOX_DIR" "changes_dir"  "$CHANGES_DIR"
  session_state_write "$SANDBOX_DIR" "snapshot_dir" "$SNAPSHOT_DIR"
  session_state_write "$SANDBOX_DIR" "input_dir"    "$INPUT_DIR"
  session_state_write "$SANDBOX_DIR" "output_dir"   "$OUTPUT_DIR"
else
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
  # Write workspace paths so downstream consumers can read them deterministically.
  session_state_write "$SANDBOX_DIR" "changes_dir"  "$CHANGES_DIR"
  session_state_write "$SANDBOX_DIR" "snapshot_dir" "$SNAPSHOT_DIR"
  session_state_write "$SANDBOX_DIR" "input_dir"    "$INPUT_DIR"
  session_state_write "$SANDBOX_DIR" "output_dir"   "$OUTPUT_DIR"

  echo "Sandbox ready. Baseline recorded in SESSION_STATE."
fi
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
  local _err
  if _err=$("$@" 2>&1 >/dev/null); then
    echo "  PREFLIGHT PASS: $msg"
  else
    echo "  PREFLIGHT FAIL: $msg${_err:+ — ${_err%%$'\n'*}}" >&2
    PREFLIGHT_FAILS=$(( PREFLIGHT_FAILS + 1 ))
  fi
}
_preflight_warn() {
  local msg="$1"; shift
  local _err
  if _err=$("$@" 2>&1 >/dev/null); then
    echo "  PREFLIGHT PASS: $msg"
  else
    echo "  PREFLIGHT WARN: $msg${_err:+ — ${_err%%$'\n'*}}" >&2
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
# viable for provider-entrypoint only
# _preflight_crit "INPUT_DIR is readable (brief mount)"                test -d "$INPUT_DIR"
# _preflight_crit "OUTPUT_DIR is writable (output mount)"              touch "$OUTPUT_DIR/.preflight_write_test" && rm -f "$OUTPUT_DIR/.preflight_write_test"

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
source /opt/sandbox/lib/diff_export.sh
source /opt/sandbox/lib/routing.sh

# _session_export SANDBOX_DIR CHANGES_DIR SESSION_TS BRANCH RUN_ID
# Runs the final session export on container exit.
# 1. Waits for git lockfile to settle (autosave may have been mid-operation)
# 2. Runs diff_export to the session export path
# 3. On failure, falls back to the most recent autosave if one exists
# 4. Writes .export-status in both the session dir and CHANGES_DIR root
_session_export() {
  local _sandbox_dir="$1" _changes_dir="$2" _session_ts="$3" _branch="$4" _run_id="$5"

  wait_git_lockfile "$_sandbox_dir"

  local _exit_dir
  _exit_dir=$(session_export_path "$_changes_dir" "session" "$_session_ts" "$_branch" "$_run_id")
  mkdir -p "$_exit_dir"

  if diff_export "$_sandbox_dir" "$_exit_dir" "$_run_id"; then
    echo "session-export: SUCCESS — artefacts written to $_exit_dir" >&2
    _write_export_status "$_changes_dir" "SUCCESS" "$(date -u +%Y%m%d-%H%M%S)" "0" 2>/dev/null || true
    return
  fi

  echo "session-export: FAILED — final export incomplete" >&2

  # Fallback: find the most recent autosave directory
  local _autosave_base
  _autosave_base=$(resolve_channel_base_dir "autosave") || true
  local _latest_autosave
  _latest_autosave=$(resolve_latest_dir "${_autosave_base:-}" 2>/dev/null) || true

  if [[ -n "$_latest_autosave" ]]; then
    echo "session-export: falling back to autosave: $_latest_autosave" >&2
    # Copy autosave artefacts into the session dir so the operator
    # has the latest checkpoint at the expected session path
    cp -r "$_latest_autosave"/* "$_exit_dir/" 2>/dev/null || true
  else
    echo "session-export: no autosave fallback available — session artefacts may be lost" >&2
  fi

  _write_export_status "$_changes_dir" "FAIL" "$(date -u +%Y%m%d-%H%M%S)" "1" 2>/dev/null || true
}

# On exit: kill autosave subshell if running, wait for git lockfile to settle,
# then write session export via _session_export.
#
# Uses session_export_path from routing.sh to construct the output path
# under CHANGES_DIR/session/<SESSION_TS>-<BRANCH>-<RUN_ID>/, then calls
# diff_export which delegates to package_branch.
#
# If diff_export fails, falls back to the most recent autosave.
trap '[[ -n "$AUTOSAVE_PID" ]] && kill "$AUTOSAVE_PID" 2>/dev/null || true
     _session_export "$SANDBOX_DIR" "$CHANGES_DIR" "${SESSION_TS:-unknown}" "${SANITIZED_HOST_BRANCH:-unknown}" "${RUN_ID:-}"' EXIT

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
# path under CHANGES_DIR/autosave/<SESSION_TS>-<BRANCH>-<RUN_ID>/, then
# calls diff_export which delegates to package_branch.
# PID is tracked so the EXIT trap can kill the subshell cleanly on shutdown.
#
# Every save attempt is logged to stderr (visible via docker logs).
# On failure, writes a timestamped error log for diagnosis.
if [[ "$AUTOSAVE_INTERVAL" -gt 0 ]]; then
  (
    while true; do
      sleep "$AUTOSAVE_INTERVAL"
      _as_ts=$(date -u +%Y%m%d-%H%M%S)
      _as_dir=$(session_export_path "$CHANGES_DIR" "autosave" "${SESSION_TS:-unknown}" "${SANITIZED_HOST_BRANCH:-unknown}" "${RUN_ID:-}")
      mkdir -p "$_as_dir"
      echo "autosave: checkpoint started — ${_as_dir}" >&2
      if diff_export "$SANDBOX_DIR" "$_as_dir" "${RUN_ID:-}"; then
        echo "autosave: checkpoint SUCCESS — ${_as_dir}" >&2
      else
        _as_ec=$?
        echo "autosave: checkpoint FAILED (exit $_as_ec) — ${_as_dir}" >&2
      fi
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