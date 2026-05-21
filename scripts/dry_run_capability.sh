#!/usr/bin/env bash
# dry_run_capability.sh
# Diagnostic checks run inside the sandbox (capability layer) container during a dry-run.
# Bind-mounted at /dry_run_capability.sh via the dry-run compose overlay.
#
# These are investigation-level checks — deeper than the pre-flight checks
# in sandbox-entrypoint.sh. Pre-flight covers critical invariants for every
# start; this covers round-trip validation, file existence in the image,
# and cross-container communication.
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
source /opt/sandbox/lib/diff.sh

# Paths are passed as absolute env vars from the compose template.
# Fallback to dirs.sh only if unset (testing without compose).
SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"
SNAPSHOT_DIR="${SNAPSHOT_DIR:-}"
CHANGES_DIR="${CHANGES_DIR:-}"
INPUT_DIR="${INPUT_DIR:-}"
OUTPUT_DIR="${OUTPUT_DIR:-}"

if [[ -z "$SNAPSHOT_DIR" || -z "$CHANGES_DIR" || -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
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

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

section "image file existence"
critical "/opt/sandbox/bin/sandbox-entrypoint.sh present" test -f /opt/sandbox/bin/sandbox-entrypoint.sh
critical "/opt/sandbox/lib/snapshot.sh present"           test -f /opt/sandbox/lib/snapshot.sh
critical "/opt/sandbox/lib/diff.sh present"               test -f /opt/sandbox/lib/diff.sh
critical "/opt/sandbox/lib/dirs.sh present"               test -f /opt/sandbox/lib/dirs.sh
critical "/opt/sandbox/lib/routing.sh present"             test -f /opt/sandbox/lib/routing.sh
critical "/opt/sandbox/lib/session.sh present"             test -f /opt/sandbox/lib/session.sh

section "session state"
# After pre-flight has already validated init_sha and session_ts,
# this confirms the full key set at the investigation level.
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

check_session_ts() {
  local ts
  ts=$(session_state_read "$SANDBOX_DIR" "session_ts" 2>/dev/null) || return 1
  [[ -n "$ts" ]]
}
warn_check "SESSION_STATE.session_ts readable" check_session_ts

section "mounts"
critical "CHANGES_DIR writable (session-diffs mount)" _is_writable "$CHANGES_DIR"
critical "SNAPSHOT_DIR readable (snapshot mount)"     test -d "$SNAPSHOT_DIR"
warn_check "INPUT_DIR readable (brief mount)"           test -d "$INPUT_DIR"
warn_check "OUTPUT_DIR writable (output mount)"         _is_writable "$OUTPUT_DIR"

section "diff pipeline"
# Verify the diff pipeline can be invoked without error.
# Uses a temp directory so no artifacts pollute the session.
_diff_test_dir=$(mktemp -d) || {
  _fail "diff pipeline: could not create temp directory"
}
if diff_export "$SANDBOX_DIR" "$_diff_test_dir" 2>/dev/null; then
  _pass "diff_export: completed without error"
  _diff_files=$(find "$_diff_test_dir" -name "*.diff" -type f 2>/dev/null | wc -l)
  if [[ "$_diff_files" -gt 0 ]]; then
    _pass "diff_export: produced $_diff_files diff file(s)"
  else
    _warn "diff_export: no .diff files produced (baseline may be empty)"
  fi
else
  _fail "diff_export: command failed"
fi
rm -rf "$_diff_test_dir"

section "session-diffs round-trip"
# Write a capability-layer marker to CHANGES_DIR. The reasoning layer
# (dry_run_reasoning.sh) will later read this to verify cross-container communication.
_cap_marker="$CHANGES_DIR/.dryrun_capability_marker"
if mkdir -p "$CHANGES_DIR" 2>/dev/null && echo "CAPABILITY_LAYER_OK" > "$_cap_marker" 2>/dev/null; then
  _readback=$(cat "$_cap_marker" 2>/dev/null) || _readback=""
  if [[ "$_readback" == "CAPABILITY_LAYER_OK" ]]; then
    _pass "capability layer marker: wrote and read back at $CHANGES_DIR"
    # Leave marker for reasoning layer — cleaned up by host-side phase
  else
    _fail "capability layer marker: file empty or unreadable"
    rm -f "$_cap_marker"
  fi
else
  _fail "capability layer marker: could not write to $CHANGES_DIR"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf "\n=== summary ===\n"
printf "critical failures: %d\n" "$CRITICAL_FAILS"
printf "warnings:          %d\n" "$WARN_FAILS"

if [[ $CRITICAL_FAILS -eq 0 && $WARN_FAILS -eq 0 ]]; then
  echo "All checks passed. Capability layer is healthy."
elif [[ $CRITICAL_FAILS -eq 0 ]]; then
  echo "Capability layer healthy. Review warnings before production use."
else
  echo "Capability layer is NOT healthy. Fix critical failures before running agents."
fi

[[ $CRITICAL_FAILS -eq 0 ]]
