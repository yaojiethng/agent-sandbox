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
#   capability layer  — sandbox/.git present (baseline commit made)
#   provider config   — PROVIDER_CONFIG_DIR is writable (copy-in / copy-out path)
#   input channel     — brief.md and snapshot .gitignore present
#   stdin / TUI       — stdin is not /dev/null (regression guard for background-job entrypoint)

# Intentionally no set -e: all checks must run even when some fail.
# Intentionally no set -u: env vars are checked explicitly with guards.
set -o pipefail

ROOT="/home/agentuser"
source /libs/dirs.sh

INPUT_DIR="$ROOT/$INPUT_DIR_NAME"
OUTPUT_DIR="$ROOT/$OUTPUT_DIR_NAME"
SANDBOX_DIR="$ROOT/$SANDBOX_DIR_NAME"

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
