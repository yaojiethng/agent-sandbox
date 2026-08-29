#!/usr/bin/env bash
# dry_run_reasoning.sh
# Bearer self-check run inside the reasoning layer (agent) container during a dry-run.
# Bind-mounted at /dry_run_reasoning.sh via the dry-run compose overlay.
#
# Responsibility (bearer): assert the reasoning container is complete/ready per
# the readiness model (design devlog/discussions/20260828-design-settled-dry_run_phase_split.md),
# then write a per-container diagnostics record to the output mount for
# orchestration to validate (correct-container check). Checks are listed in
# L1..L6 layer order. The reasoning container reads the capability layer's state
# via the shared volume (volumes-from) and verifies cross-container link-up.
#
# Exit codes:
#   0 - all CRITICAL checks passed (warnings may exist)
#   1 - one or more CRITICAL checks failed

# Intentionally no set -e: all checks must run even when some fail.
# Intentionally no set -u: env vars are checked explicitly with guards.
set -o pipefail

ROOT="/home/agentuser"
source /opt/sandbox/lib/session_state.sh

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
# Check framework (layer-aware)
# ---------------------------------------------------------------------------

CRITICAL_FAILS=0
WARN_FAILS=0
declare -A LAYER_CRIT=()
declare -A LAYER_WARN=()
CURRENT_LAYER=""

_pass() { printf "  PASS  %s\n" "$1"; }
_fail() { printf "  FAIL  %s\n" "$1${2:+  ($2)}"; CRITICAL_FAILS=$(( CRITICAL_FAILS + 1 )); LAYER_CRIT[$CURRENT_LAYER]=$(( ${LAYER_CRIT[$CURRENT_LAYER]:-0} + 1 )); }
_warn() { printf "  WARN  %s\n" "$1${2:+  ($2)}"; WARN_FAILS=$(( WARN_FAILS + 1 )); LAYER_WARN[$CURRENT_LAYER]=$(( ${LAYER_WARN[$CURRENT_LAYER]:-0} + 1 )); }

critical() {
  local name="$1"; shift
  if "$@" 2>/dev/null; then _pass "$name"; else _fail "$name"; fi
}

warn_check() {
  local name="$1"; shift
  if "$@" 2>/dev/null; then _pass "$name"; else _warn "$name"; fi
}

section() { printf "\n=== %s ===\n" "$1"; CURRENT_LAYER="${1%% *}"; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_is_writable() {
  local testfile="$1/.dryrun_write_test"
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

# Write the per-container diagnostics record. Orchestration consumes this
# (not stdout) for the correct-container check.
_write_record() {
  local record="${OUTPUT_DIR}/dryrun.reasoning.record"
  local overall="PASS"
  [[ "$CRITICAL_FAILS" -eq 0 ]] || overall="FAIL"
  {
    printf 'container=%s\n' "${DRY_RUN_IDENTITY:-unknown}"
    for layer in L1 L2 L3 L4 L5 L6; do
      local st="PASS"
      [[ "${LAYER_CRIT[$layer]:-0}" -eq 0 ]] || st="FAIL"
      printf 'layer.%s=%s\n' "$layer" "$st"
    done
    printf 'status=%s\n' "$overall"
  } > "$record" 2>/dev/null || {
    printf "  WARN  could not write diagnostics record to %s\n" "$record" >&2
  }
}

# ---------------------------------------------------------------------------
# L1 - Image / L2 - Link-up
# ---------------------------------------------------------------------------
# Baked-image presence is CP-owned (dedup). Here the reasoning container asserts
# its compose-injected environment and workspace mounts are wired.

section "L2 link-up (environment + workspace)"
critical "AGENT_HOME is set"          bash -c '[[ -n "${AGENT_HOME:-}" ]]'
critical "PROVIDER_NAME is set"       bash -c '[[ -n "${PROVIDER_NAME:-}" ]]'
critical "INPUT_DIR exists (input mount)"        test -d "$INPUT_DIR"
critical "INPUT_DIR is read-only"                _is_readonly "$INPUT_DIR"
critical "OUTPUT_DIR exists (output mount)"      test -d "$OUTPUT_DIR"
critical "OUTPUT_DIR is writable"                _is_writable "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# L3 - State (via shared .git, written by capability layer)
# ---------------------------------------------------------------------------

section "L3 state (via shared .git)"
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
# L5 - Cross-component
# ---------------------------------------------------------------------------

section "L5 cross-component"
critical "SANDBOX_DIR exists (volumes-from)"     test -d "$SANDBOX_DIR"

# Capability-layer marker written in Phase 1 (dry_run_capability.sh) must be
# visible from the reasoning layer via the shared volume.
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

section "L5 session-diffs round-trip"
check_changes_dir_matches_mount_target() {
  local expected="/home/agentuser/workspace/session-diffs"
  [[ "$CHANGES_DIR" == "$expected" ]]
}
critical "CHANGES_DIR resolves to bind mount target" check_changes_dir_matches_mount_target

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
# L6 - Runtime / terminal
# ---------------------------------------------------------------------------

section "L6 runtime"
warn_check "running as non-root" bash -c '[[ "$(id -u)" -ne 0 ]]'

section "L6 stdin / TTY readiness"
critical "stdin is not /dev/null" _stdin_not_devnull
warn_check "stdin is a character device (TTY expected for make start; pipe acceptable for make dry-run)" \
  bash -c 'target=$(readlink /proc/$$/fd/0 2>/dev/null); [[ "$target" == /dev/pts/* ]] || test -c /proc/$$/fd/0 2>/dev/null'

section "L6 liveness"
printf "\n=== liveness write ===\n"
if echo "PASS" > "$OUTPUT_DIR/liveness.txt" 2>/dev/null; then
  _pass "liveness.txt written to workspace/output"
else
  _fail "liveness.txt written to workspace/output"
fi

# ---------------------------------------------------------------------------
# Summary + diagnostics record
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

_write_record

[[ $CRITICAL_FAILS -eq 0 ]]