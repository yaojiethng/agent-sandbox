#!/usr/bin/env bash
# dry_run_reasoning.sh
# Diagnostic checks run inside the reasoning layer (agent) container during a dry-run.
# Bind-mounted at /dry_run_reasoning.sh via the dry-run compose overlay.
#
# This script is the reasoning layer counterpart to dry_run_capability.sh (capability
# layer). It validates the reasoning layer's perspective of the host-container seam:
#   - Can read what the capability layer wrote (SESSION_STATE, CHANGES_DIR markers)
#   - Can access its own mounts (INPUT_DIR, OUTPUT_DIR)
#   - stdin/TTY are correctly wired
#
# For capability-layer checks (image files, sandbox entrypoint, diff pipeline),
# see dry_run_capability.sh.
#
# Exit codes:
#   0 — all CRITICAL checks passed (warnings may exist)
#   1 — one or more CRITICAL checks failed
#
# Check severity:
#   CRITICAL — infrastructure is broken; the run would fail or produce wrong results
#   WARN     — something is missing or unexpected; worth reviewing before production use

# Intentionally no set -e: all checks must run even when some fail.
# Intentionally no set -u: env vars are checked explicitly with guards.
set -o pipefail

ROOT="/home/agentuser"
source /opt/sandbox/lib/session.sh

# Paths are passed as absolute env vars from the compose template.
# Fallback to dirs.sh only if unset (testing without compose).
SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"
CHANGES_DIR="${CHANGES_DIR:-}"
INPUT_DIR="${INPUT_DIR:-}"
OUTPUT_DIR="${OUTPUT_DIR:-}"

if [[ -z "$CHANGES_DIR" || -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
  source /opt/sandbox/lib/dirs.sh
  WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
fi

# ---------------------------------------------------------------------------
# Check framework
# ---------------------------------------------------------------------------

CRITICAL_FAILS=0
WARN_FAILS=0

_pass() { printf "  PASS  %s\n" "$1"; }
_fail() { printf "  FAIL  %s\n" "$1${2:+  ($2)}"; CRITICAL_FAILS=$(( CRITICAL_FAILS + 1 )); }
_warn() { printf "  WARN  %s\n" "$1${2:+  ($2)}"; WARN_FAILS=$(( WARN_FAILS + 1 )); }

critical() {
  local name="$1"; shift
  if "$@" 2>/dev/null; then _pass "$name"; else _fail "$name"; fi
}

warn_check() {
  local name="$1"; shift
  if "$@" 2>/dev/null; then _pass "$name"; else _warn "$name"; fi
}

section() { printf "\n=== %s ===\n" "$1"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_is_writable() {
  local dir="$1" testfile="$1/.dryrun_write_test"
  if touch "$testfile" 2>/dev/null; then rm -f "$testfile" 2>/dev/null; return 0; fi
  return 1
}

_is_readonly() {
  _is_writable "$1" && return 1 || return 0
}

_stdin_not_devnull() {
  local stdin_ino null_ino
  stdin_ino=$(stat -L /proc/$$/fd/0 2>/dev/null | awk '/Inode/{print $2}') || return 0
  null_ino=$(stat /dev/null 2>/dev/null | awk '/Inode/{print $2}') || return 0
  [[ "$stdin_ino" != "$null_ino" ]]
}

# ---------------------------------------------------------------------------
# Identity & environment checks
# ---------------------------------------------------------------------------

section "identity"
id
warn_check "running as non-root" bash -c '[[ "$(id -u)" -ne 0 ]]'

section "environment variables"
critical "AGENT_HOME is set"          bash -c '[[ -n "${AGENT_HOME:-}" ]]'
critical "PROVIDER_NAME is set"       bash -c '[[ -n "${PROVIDER_NAME:-}" ]]'
# PROVIDER_CONFIG_DIR was removed in M2.7 item 8 — config is now bind-mounted
# directly at AGENT_HOME. This check is intentionally absent.

# ---------------------------------------------------------------------------
# Mount checks (reasoning layer perspective)
# ---------------------------------------------------------------------------
# The reasoning layer inherits sandbox volumes via --volumes-from.
# This gives it access to the sandbox's CHANGES_DIR and .git (via shared
# filesystem). INPUT_DIR and OUTPUT_DIR are its own bind mounts.

section "mounts"
critical "INPUT_DIR exists (brief mount)"        test -d "$INPUT_DIR"
critical "INPUT_DIR is read-only"                _is_readonly "$INPUT_DIR"
critical "OUTPUT_DIR exists (output mount)"      test -d "$OUTPUT_DIR"
critical "OUTPUT_DIR is writable"                _is_writable "$OUTPUT_DIR"
critical "SANDBOX_DIR exists (volumes-from)"     test -d "$SANDBOX_DIR"

# ---------------------------------------------------------------------------
# Session state (read-only, written by capability layer)
# ---------------------------------------------------------------------------

section "session state (via shared .git)"
critical "sandbox/.git/SESSION_STATE exists"     test -f "$SANDBOX_DIR/.git/SESSION_STATE"

check_init_sha_readable() {
  local sha
  sha=$(session_state_read "$SANDBOX_DIR" "init_sha" 2>/dev/null) || return 1
  [[ -n "$sha" ]]
}
critical "SESSION_STATE.init_sha readable" check_init_sha_readable

check_session_ts() {
  local ts
  ts=$(session_state_read "$SANDBOX_DIR" "session_ts" 2>/dev/null) || return 1
  [[ -n "$ts" ]]
}
warn_check "SESSION_STATE.session_ts readable" check_session_ts

# ---------------------------------------------------------------------------
# Cross-container marker (written by dry_run_capability.sh in Phase 1)
# ---------------------------------------------------------------------------

section "cross-container communication"
_cap_marker="$SANDBOX_DIR/../workspace/session-diffs/.dryrun_capability_marker"
if test -f "$_cap_marker"; then
  _content=$(cat "$_cap_marker" 2>/dev/null)
  if [[ "$_content" == "CAPABILITY_LAYER_OK" ]]; then
    _pass "capability layer marker: readable from reasoning layer"
  else
    _warn "capability layer marker: unexpected content: $_content"
  fi
else
  _warn "capability layer marker: not found (Phase 1 may not have run)"
fi

# ---------------------------------------------------------------------------
# session-diffs round-trip (reasoning layer side)
# ---------------------------------------------------------------------------
# CHANGES_DIR is inherited from the sandbox via --volumes-from.
# Verify the resolved path matches the expected bind mount target.

section "session-diffs round-trip"

check_changes_dir_matches_mount_target() {
  local expected="/home/agentuser/workspace/session-diffs"
  [[ "$CHANGES_DIR" == "$expected" ]]
}
critical "CHANGES_DIR resolves to bind mount target" check_changes_dir_matches_mount_target

# Write a marker file and verify it's readable at the resolved path.
# If the path is doubled (bug), mkdir -p creates the wrong tree and the
# marker lands outside the bind mount — the subsequent read fails.
_marker="$CHANGES_DIR/.dryrun_seam_test"
if mkdir -p "$CHANGES_DIR" 2>/dev/null && echo "REASONING_OK" > "$_marker" 2>/dev/null; then
  _readback=$(cat "$_marker" 2>/dev/null) || _readback=""
  if [[ "$_readback" == "REASONING_OK" ]]; then
    _pass "reasoning layer round-trip: wrote and read back marker"
    rm -f "$_marker"
  else
    _fail "reasoning layer round-trip: marker empty or unreadable"
  fi
else
  _fail "reasoning layer round-trip: could not write to $CHANGES_DIR"
fi

# ---------------------------------------------------------------------------
# Input channel and brief
# ---------------------------------------------------------------------------

section "input channel"
warn_check "brief.md present in INPUT_DIR" test -f "$INPUT_DIR/brief.md"

printf "\n=== workspace/input contents ===\n"
ls -p "$INPUT_DIR" 2>/dev/null || echo "(empty)"

# ---------------------------------------------------------------------------
# stdin / TUI readiness
# ---------------------------------------------------------------------------

section "stdin / TUI readiness"
critical "stdin is not /dev/null" _stdin_not_devnull
warn_check "stdin is a character device (TTY expected for make start; pipe acceptable for make dry-run)" \
  bash -c 'target=$(readlink /proc/$$/fd/0 2>/dev/null); [[ "$target" == /dev/pts/* ]] || test -c /proc/$$/fd/0 2>/dev/null'

# ---------------------------------------------------------------------------
# Liveness write
# ---------------------------------------------------------------------------

printf "\n=== liveness write ===\n"
if echo "PASS" > "$OUTPUT_DIR/liveness.txt" 2>/dev/null; then
  _pass "liveness.txt written to workspace/output"
else
  _fail "liveness.txt written to workspace/output"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf "\n=== summary ===\n"
printf "critical failures: %d\n" "$CRITICAL_FAILS"
printf "warnings:          %d\n" "$WARN_FAILS"

if [[ $CRITICAL_FAILS -eq 0 && $WARN_FAILS -eq 0 ]]; then
  echo "All checks passed. Reasoning layer is healthy."
elif [[ $CRITICAL_FAILS -eq 0 ]]; then
  echo "Reasoning layer healthy. Review warnings before production use."
else
  echo "Reasoning layer is NOT healthy. Fix critical failures before running agents."
fi

[[ $CRITICAL_FAILS -eq 0 ]]
