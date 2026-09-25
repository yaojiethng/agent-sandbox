#!/usr/bin/env bash
# src/libs/dry_run_harness.sh
# Shared check framework for the dry-run probe scripts (dry_run_capability.sh
# and dry_run_reasoning.sh). Sourced by both; defines the probe bootstrap, the
# layer-aware pass/fail/warn counting, the section headers, and the
# per-container diagnostics record writer.
#
# Intentionally no set -e/set -u: all checks must run even when some fail,
# and env vars are checked explicitly with guards.

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

# ---------------------------------------------------------------------------
# Probe bootstrap
# ---------------------------------------------------------------------------

# dry_run_bootstrap
#   Resolves the four paths both probes share (SANDBOX_DIR, CHANGES_DIR,
#   INPUT_DIR, OUTPUT_DIR) and sources session_state.sh. Each probe locates
#   this file by its conventional lib path and then calls this function, so
#   the preamble the two probes share lives here once instead of in two copies
#   that drift.
#
#   The path defaults are container conventions. The dirs_resolve fallback
#   serves a probe run without the compose-injected path vars (test fixtures).
dry_run_bootstrap() {
  ROOT="${ROOT:-/home/agentuser}"
  # shellcheck source=/dev/null
  source "$LIBS_DIR/session_state.sh"
  SANDBOX_DIR="${SANDBOX_DIR:-$ROOT/${SANDBOX_DIR_NAME:-sandbox}}"
  CHANGES_DIR="${CHANGES_DIR:-}"
  INPUT_DIR="${INPUT_DIR:-}"
  OUTPUT_DIR="${OUTPUT_DIR:-}"
  if [[ -z "$CHANGES_DIR" || -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
    # shellcheck source=/dev/null
    source "$LIBS_DIR/dirs.sh"
    WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
  fi
}

# dry_run_write_record RECORD_FILE LAYERS [EXTRA_FIELDS...]
#   Writes the per-container diagnostics record consumed by orchestration
#   (not stdout) for the correct-container check. LAYERS is the ordered
#   list of readiness layers; each renders PASS unless its layer saw a
#   critical failure. EXTRA_FIELDS are emitted verbatim after the layers
#   (name=value lines, e.g. sandbox_init metrics).
dry_run_write_record() {
  local record="$1"
  shift
  local layers="$1"
  shift
  local overall="PASS"
  [[ "$CRITICAL_FAILS" -eq 0 ]] || overall="FAIL"
  {
    printf 'container=%s\n' "${DRY_RUN_IDENTITY:-unknown}"
    for layer in $layers; do
      local st="PASS"
      [[ "${LAYER_CRIT[$layer]:-0}" -eq 0 ]] || st="FAIL"
      printf 'layer.%s=%s\n' "$layer" "$st"
    done
    for field in "$@"; do printf '%s\n' "$field"; done
    printf 'status=%s\n' "$overall"
  } > "$record" 2>/dev/null || {
    printf "  WARN  could not write diagnostics record to %s\n" "$record" >&2
  }
}

# dry_run_summary
#   Prints the closing summary block and returns 0 only when no critical
#   check failed. Call as the final statement of a probe script.
dry_run_summary() {
  printf "\n=== summary ===\n"
  printf "critical failures: %d\n" "$CRITICAL_FAILS"
  printf "warnings:          %d\n" "$WARN_FAILS"

  if [[ $CRITICAL_FAILS -eq 0 && $WARN_FAILS -eq 0 ]]; then
    echo "All checks passed. Layer is healthy."
  elif [[ $CRITICAL_FAILS -eq 0 ]]; then
    echo "Layer healthy. Review warnings before production use."
  else
    echo "Layer is NOT healthy. Fix critical failures before running agents."
  fi
  return $(( CRITICAL_FAILS > 0 ? 1 : 0 ))
}