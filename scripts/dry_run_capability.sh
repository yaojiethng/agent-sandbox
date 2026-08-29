#!/usr/bin/env bash
# dry_run_capability.sh
# Bearer self-check run inside the sandbox (capability layer) container during a dry-run.
# Bind-mounted at /dry_run_capability.sh via the dry-run compose overlay.
#
# Responsibility (bearer): assert the capability container is complete/ready per
# the readiness model (design devlog/discussions/20260828-design-settled-dry_run_phase_split.md),
# then write a per-container diagnostics record to the output mount for
# orchestration to validate (correct-container check). Checks are listed in
# L1..L6 layer order. Checks that the container preflight guarantees on every
# start (baked-lib presence, mount presence, SESSION_STATE presence) are NOT
# re-asserted here -- this probe owns the readiness DEPTH (L3 validity, L4 data
# plane, L5 cross-component) plus the L2 ro/rw semantics preflight deliberately
# leaves out.
#
# Exit codes:
#   0  --  all CRITICAL checks passed (warnings may exist)
#   1  --  one or more CRITICAL checks failed

# Intentionally no set -e: all checks must run even when some fail.
# Intentionally no set -u: env vars are checked explicitly with guards.
set -o pipefail

ROOT="/home/agentuser"
source /opt/sandbox/lib/session_state.sh
source /opt/sandbox/lib/diff_export.sh
source /opt/sandbox/lib/routing.sh

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
# Check framework (layer-aware)
# ---------------------------------------------------------------------------

CRITICAL_FAILS=0
WARN_FAILS=0
declare -A LAYER_CRIT=()   # layer -> count of critical fails in this layer
declare -A LAYER_WARN=()   # layer -> count of warns in this layer
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

# Write the per-container diagnostics record. Orchestration consumes this
# (not stdout) for the correct-container check.
#   container = identity echo-back (expected value injected via compose env)
#   layer.L<N> = PASS|FAIL (FAIL if any critical in that layer)
#   status     = overall PASS|FAIL
_write_record() {
  local record="${OUTPUT_DIR}/dryrun.capability.record"
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
# L1 - Image
# ---------------------------------------------------------------------------
# Deliberately omitted: baked-library/image-file presence is guaranteed by the
# container preflight on every start (dedup). L1 readiness here is implicit in
# this probe successfully sourcing the container libs above.

# ---------------------------------------------------------------------------
# L2 - Link-up (workspace channels, ro/rw semantics)
# ---------------------------------------------------------------------------

section "L2 link-up"
warn_check "INPUT_DIR readable"  test -d "$INPUT_DIR"
warn_check "OUTPUT_DIR writable" _is_writable "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# L3 - State/identity (validity depth; presence is CP-owned)
# ---------------------------------------------------------------------------

section "L3 state"
check_init_sha_valid() {
  local sha
  sha=$(session_state_read "$SANDBOX_DIR" "init_sha" 2>/dev/null) || return 1
  [[ -z "$sha" ]] && return 1
  git -C "$SANDBOX_DIR" rev-parse --verify --quiet "$sha" >/dev/null 2>&1
}
critical "SESSION_STATE.init_sha is a valid commit" check_init_sha_valid

# ---------------------------------------------------------------------------
# L4 - Data plane
# ---------------------------------------------------------------------------

section "L4 data plane"
# Verify the diff pipeline can be invoked without error.
# Uses a temp directory so no artifacts pollute the session.
_diff_test_dir=$(mktemp -d) || {
  _fail "diff_export: could not create temp directory"
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

warn_check "diff_export: .export-status exists after successful export" \
  test -f "$_diff_test_dir/.export-status"
warn_check "diff_export: .export-status reports SUCCESS" \
  bash -c 'test -f "$1" && grep -q "^STATUS=SUCCESS$" "$1"' _ "$_diff_test_dir/.export-status"
rm -rf "$_diff_test_dir"

section "L4 autosave"
warn_check "CHANGES_DIR/autosave/ exists" test -d "${CHANGES_DIR}/autosave"
warn_check "export_path: resolves with available env vars" \
  bash -c 'p=$(export_path "$1" session "${2:-}" 2>/dev/null); [[ -n "$p" ]]' \
  _ "$CHANGES_DIR" "${SESSION_ID:-}"
warn_check "wait_git_lockfile: returns 0 when no lockfile present" \
  wait_git_lockfile "$SANDBOX_DIR"

# ---------------------------------------------------------------------------
# L5 - Cross-component (capability half of the marker round-trip)
# ---------------------------------------------------------------------------

section "L5 cross-component"
# Write a capability-layer marker to CHANGES_DIR. The reasoning layer
# (dry_run_reasoning.sh) reads this to verify cross-container communication.
_cap_marker="$CHANGES_DIR/.dryrun_capability_marker"
if mkdir -p "$CHANGES_DIR" 2>/dev/null && echo "CAPABILITY_LAYER_OK" > "$_cap_marker" 2>/dev/null; then
  _readback=$(cat "$_cap_marker" 2>/dev/null) || _readback=""
  if [[ "$_readback" == "CAPABILITY_LAYER_OK" ]]; then
    _pass "capability layer marker: wrote and read back at $CHANGES_DIR"
  else
    _fail "capability layer marker: file empty or unreadable"
    rm -f "$_cap_marker"
  fi
else
  _fail "capability layer marker: could not write to $CHANGES_DIR"
fi

# ---------------------------------------------------------------------------
# L6 - Runtime
# ---------------------------------------------------------------------------
# Capability-side runtime concerns (TTY/stdin, liveness write) live on the
# reasoning container; nothing capability-specific to assert here.

# ---------------------------------------------------------------------------
# Summary + diagnostics record
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

_write_record

[[ $CRITICAL_FAILS -eq 0 ]]