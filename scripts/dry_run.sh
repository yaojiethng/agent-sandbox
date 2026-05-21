#!/usr/bin/env bash
# dry_run.sh
# Diagnostic checks run inside the reasoning layer container during a dry-run.
# Bind-mounted at /dry_run.sh via the dry-run compose overlay.
#
# Exit codes:
#   0 — all CRITICAL checks passed (warnings may exist)
#   1 — one or more CRITICAL checks failed
#
# Check severity:
#   CRITICAL — infrastructure is broken; the run would fail or produce wrong results
#   WARN     — something is missing or unexpected; worth reviewing before production use
#
# Checks:
#   identity          — user and uid
#   environment       — required env vars (AGENT_HOME, PROVIDER_NAME, PROVIDER_CONFIG_DIR)
#   mounts            — input (exists + read-only), output (exists + writable), sandbox (exists + writable)
#   capability layer  — sandbox/.git present (baseline commit made), SESSION_STATE valid
#   provider config   — PROVIDER_CONFIG_DIR is writable (copy-in / copy-out path)
#   input channel     — brief.md and snapshot .gitignore present
#   stdin / TUI       — stdin is not /dev/null (regression guard for background-job entrypoint)

# Intentionally no set -e: all checks must run even when some fail.
# Intentionally no set -u: env vars are checked explicitly with guards.
set -o pipefail

ROOT="/home/agentuser"
source /opt/sandbox/lib/dirs.sh
source /opt/sandbox/lib/session.sh

WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"

# ---------------------------------------------------------------------------
# Check framework
# ---------------------------------------------------------------------------

CRITICAL_FAILS=0
WARN_FAILS=0

_pass() { printf "  PASS  %s\n" "$1"; }
_fail() { printf "  FAIL  %s\n" "$1${2:+  ($2)}"; CRITICAL_FAILS=$(( CRITICAL_FAILS + 1 )); }
_warn() { printf "  WARN  %s\n" "$1${2:+  ($2)}"; WARN_FAILS=$(( WARN_FAILS + 1 )); }

# critical NAME CMD [ARGS...] — PASS or FAIL based on CMD exit code
critical() {
  local name="$1"; shift
  if "$@" 2>/dev/null; then _pass "$name"; else _fail "$name"; fi
}

# warn_check NAME CMD [ARGS...] — PASS or WARN based on CMD exit code
warn_check() {
  local name="$1"; shift
  if "$@" 2>/dev/null; then _pass "$name"; else _warn "$name"; fi
}

section() { printf "\n=== %s ===\n" "$1"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Returns 0 (success) if the directory is writable, 1 if not.
_is_writable() {
  local dir="$1" testfile="$1/.dryrun_write_test"
  if touch "$testfile" 2>/dev/null; then rm -f "$testfile" 2>/dev/null; return 0; fi
  return 1
}

# Returns 0 (success) if the directory is read-only, 1 if writable.
_is_readonly() {
  _is_writable "$1" && return 1 || return 0
}

# Returns 0 (success) if stdin is NOT /dev/null.
# Uses inode comparison: robust across symlinks and bind mounts.
_stdin_not_devnull() {
  local stdin_ino null_ino
  stdin_ino=$(stat -L /proc/$$/fd/0 2>/dev/null | awk '/Inode/{print $2}') || return 0
  null_ino=$(stat /dev/null 2>/dev/null | awk '/Inode/{print $2}') || return 0
  [[ "$stdin_ino" != "$null_ino" ]]
}

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

section "identity"
id
warn_check "running as non-root" bash -c '[[ "$(id -u)" -ne 0 ]]'

section "environment variables"
critical "AGENT_HOME is set"          bash -c '[[ -n "${AGENT_HOME:-}" ]]'
critical "PROVIDER_NAME is set"       bash -c '[[ -n "${PROVIDER_NAME:-}" ]]'
critical "PROVIDER_CONFIG_DIR is set" bash -c '[[ -n "${PROVIDER_CONFIG_DIR:-}" ]]'

section "mounts"
critical "workspace/input exists"      test -d "$INPUT_DIR"
critical "workspace/input is read-only" _is_readonly "$INPUT_DIR"
critical "workspace/output exists"     test -d "$OUTPUT_DIR"
critical "workspace/output is writable" _is_writable "$OUTPUT_DIR"
critical "sandbox exists"              test -d "$SANDBOX_DIR"
critical "sandbox is writable"         _is_writable "$SANDBOX_DIR"

section "capability layer"
critical "sandbox/.git present (baseline commit ready)" test -d "$SANDBOX_DIR/.git"

# SESSION_STATE is written by the sandbox entrypoint (snapshot_init_git).
# Missing file means the capability layer completed init without writing it
# (e.g. stale volume from before the feature was added), or init never finished.
critical "sandbox/.git/SESSION_STATE exists" test -f "$SANDBOX_DIR/.git/SESSION_STATE"

# init_sha is required by package_diff --all and write_all_changes_diff.
# Without it, diff packaging cannot find the session baseline.
# Validated in two steps: (1) readable and non-empty, (2) corresponds to a
# real commit in the sandbox repo (catches truncated or corrupted values).
check_init_sha_readable() {
  local sha
  sha=$(session_state_read "$SANDBOX_DIR" "init_sha" 2>/dev/null) || return 1
  [[ -n "$sha" ]]
}
critical "SESSION_STATE.init_sha readable" check_init_sha_readable

check_init_sha_valid() {
  local sha
  sha=$(session_state_read "$SANDBOX_DIR" "init_sha" 2>/dev/null) || return 1
  [[ -z "$sha" ]] && return 1
  git -C "$SANDBOX_DIR" rev-parse --verify --quiet "$sha" >/dev/null 2>&1
}
critical "SESSION_STATE.init_sha is a valid commit" check_init_sha_valid

# session_ts is used by package_branch for output path naming.
# Packaging falls back to env var if missing, so this is a warning.
check_session_ts() {
  local ts
  ts=$(session_state_read "$SANDBOX_DIR" "session_ts" 2>/dev/null) || return 1
  [[ -n "$ts" ]]
}
warn_check "SESSION_STATE.session_ts readable" check_session_ts

section "provider config"
critical "PROVIDER_CONFIG_DIR is writable" \
  bash -c '[[ -n "${PROVIDER_CONFIG_DIR:-}" ]] && touch "${PROVIDER_CONFIG_DIR}/.dryrun_write_test" 2>/dev/null && rm -f "${PROVIDER_CONFIG_DIR}/.dryrun_write_test" 2>/dev/null'
warn_check "PROVIDER_CONFIG_DIR not empty (prior session state or onboarding templates present)" \
  bash -c '[[ -n "${PROVIDER_CONFIG_DIR:-}" ]] && [[ -n "$(ls -A "${PROVIDER_CONFIG_DIR}" 2>/dev/null)" ]]'

section "input channel"
warn_check ".gitignore present in sandbox (snapshot quality check)" test -f "$SANDBOX_DIR/.gitignore"
warn_check "brief.md present in workspace/input"                    test -f "$INPUT_DIR/brief.md"

printf "\n=== workspace/input contents ===\n"
ls -p "$INPUT_DIR" 2>/dev/null || echo "(empty)"

section "stdin / TUI readiness"
critical "stdin is not /dev/null" _stdin_not_devnull
warn_check "stdin is a character device (TTY expected for make start; pipe acceptable for make dry-run)" \
  bash -c 'target=$(readlink /proc/$$/fd/0 2>/dev/null); [[ "$target" == /dev/pts/* ]] || test -c /proc/$$/fd/0 2>/dev/null'

# Write the liveness marker (verifies output mount end-to-end)
printf "\n=== liveness write ===\n"
if echo "PASS" > "$OUTPUT_DIR/liveness.txt" 2>/dev/null; then
  _pass "liveness.txt written to workspace/output"
else
  _fail "liveness.txt written to workspace/output"
fi

# ---------------------------------------------------------------------------
# session-diffs round-trip test
# ---------------------------------------------------------------------------
# Verifies that the CHANGES_DIR path resolution is consistent between:
#   - host side:  dirs_resolve on SANDBOX_DIR (defaults)
#   - container:  dirs_resolve on /home/agentuser (WORKSPACE_DIR_NAME=workspace)
#
# The compose bind mount maps:
#   source: ${CHANGES_DIR}  (host:  $SANDBOX_DIR/.workspace/session-diffs)
#   target: /home/agentuser/workspace/session-diffs  (container)
#
# If CHANGES_DIR_NAME is set to a subpath containing '/', dirs.sh prepends
# WORKSPACE_DIR_NAME, producing a doubled prefix. The marker write below
# detects this by verifying the resolved path matches the bind mount target.

section "session-diffs round-trip"

check_changes_dir_matches_mount_target() {
  local expected="/home/agentuser/workspace/session-diffs"
  [[ "$CHANGES_DIR" == "$expected" ]]
}
critical "CHANGES_DIR resolves to bind mount target (/home/agentuser/workspace/session-diffs)" \
  check_changes_dir_matches_mount_target

# Write a marker file and verify it's readable at the resolved path.
# If the path is doubled (bug), mkdir -p creates the wrong tree and the
# marker lands outside the bind mount — the subsequent read fails.
_marker="$CHANGES_DIR/.dryrun_seam_test"
if mkdir -p "$CHANGES_DIR" 2>/dev/null && echo "SEAM_OK" > "$_marker" 2>/dev/null; then
  local _readback
  _readback=$(cat "$_marker" 2>/dev/null) || _readback=""
  if [[ "$_readback" == "SEAM_OK" ]]; then
    _pass "session-diffs round-trip: wrote and read back marker at $CHANGES_DIR"
    rm -f "$_marker"
  else
    _fail "session-diffs round-trip: marker file empty or unreadable"
  fi
else
  _fail "session-diffs round-trip: could not write marker to $CHANGES_DIR"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf "\n=== summary ===\n"
printf "critical failures: %d\n" "$CRITICAL_FAILS"
printf "warnings:          %d\n" "$WARN_FAILS"

if [[ $CRITICAL_FAILS -eq 0 && $WARN_FAILS -eq 0 ]]; then
  echo "All checks passed. Infrastructure is ready."
elif [[ $CRITICAL_FAILS -eq 0 ]]; then
  echo "Infrastructure ready. Review warnings before production use."
else
  echo "Infrastructure is NOT ready. Fix critical failures before running agents."
fi

[[ $CRITICAL_FAILS -eq 0 ]]
