#!/usr/bin/env bash
# diagnose_preflight.sh
# Run inside the sandbox container:
#   docker exec <sandbox-container> bash /path/to/diagnose_preflight.sh
#
# Checks why the pre-flight checks in sandbox-entrypoint.sh fail by testing
# every link in the chain: set -e safety, stderr capture, path resolution,
# SESSION_STATE, mount points, and a live simulation of the full check block.

set -uo pipefail

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

ROOT="/home/agentuser"
SANDBOX_DIR="$ROOT/sandbox"

echo "=== 1. Environment ==="
for var in SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME CHANGES_DIR_NAME WORKSPACE_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME AUTOSAVE_INTERVAL SESSION_TS; do
  val="${!var:-<UNSET>}"
  echo "  $var='$val'"
done

echo ""
echo "=== 2. Path resolution ==="
source /opt/sandbox/lib/dirs.sh 2>/dev/null
WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
echo "  SNAPSHOT_DIR=$SNAPSHOT_DIR"
echo "  CHANGES_DIR=$CHANGES_DIR"
echo "  INPUT_DIR=$INPUT_DIR"
echo "  OUTPUT_DIR=$OUTPUT_DIR"
echo "  SANDBOX_DIR=$SANDBOX_DIR"

# Check directories
[[ -d "$SNAPSHOT_DIR" ]] && pass "SNAPSHOT_DIR exists ($SNAPSHOT_DIR)" || fail "SNAPSHOT_DIR missing"
[[ -d "$CHANGES_DIR" ]] && pass "CHANGES_DIR exists ($CHANGES_DIR)" || fail "CHANGES_DIR missing"
[[ -d "$INPUT_DIR" ]]   && pass "INPUT_DIR exists ($INPUT_DIR)"     || pass "INPUT_DIR absent (expected: capability layer lacks this mount)"
[[ -d "$OUTPUT_DIR" ]]  && pass "OUTPUT_DIR exists ($OUTPUT_DIR)"   || pass "OUTPUT_DIR absent (expected: capability layer lacks this mount)"
[[ -f "$SNAPSHOT_DIR/baseline.tar" ]] && pass "baseline.tar present" || fail "baseline.tar missing"

echo ""
echo "=== 3. SESSION_STATE ==="
if [[ -f "$SANDBOX_DIR/.git/SESSION_STATE" ]]; then
  pass "SESSION_STATE file exists"
  source /opt/sandbox/lib/session.sh 2>/dev/null
  INIT_SHA=$(session_state_read "$SANDBOX_DIR" "init_sha")
  if [[ -n "$INIT_SHA" ]]; then
    if git -C "$SANDBOX_DIR" rev-parse --verify --quiet "$INIT_SHA" >/dev/null 2>&1; then
      pass "init_sha=$INIT_SHA is a valid commit"
    else
      fail "init_sha=$INIT_SHA is NOT a valid commit in the sandbox repo"
    fi
  else
    fail "init_sha is missing from SESSION_STATE"
  fi
  SESSION_TS_CHECK=$(session_state_read "$SANDBOX_DIR" "session_ts")
  [[ -n "$SESSION_TS_CHECK" ]] && pass "session_ts=$SESSION_TS_CHECK" || fail "session_ts missing"
else
  fail "SESSION_STATE file MISSING at $SANDBOX_DIR/.git/SESSION_STATE"
fi

echo ""
echo "=== 4. set -e safety (regression guard) ==="
# Verify that _preflight_crit does NOT kill the shell under set -e when
# the check command fails.  This was a regression: the old approach
# used _err=$("$@" 2>&1 >/dev/null) which propagates non-zero exit
# through command substitution, causing set -e to abort the entire
# entrypoint.  The fix uses if _err=$(cmd 2>&1 >/dev/null); then so
# that the if clause suppresses errexit.
#
# We run a subshell with set -e and call _preflight_crit with a failing
# command.  If the subshell survives, the guard works.

GUARD_RESULT=$(bash -e -c '
set -euo pipefail
_preflight_crit() {
  local msg="$1"; shift
  local _err
  if _err=$("$@" 2>&1 >/dev/null); then
    echo "PASS: $msg"
  else
    echo "FAIL: $msg${_err:+  --  ${_err%%$'\''\n'\''*}}" >&2
  fi
}
PREFLIGHT_FAILS=0
_preflight_crit "test -d /nonexistent" test -d /nonexistent
echo "SURVIVED"
' 2>&1) || true

if echo "$GUARD_RESULT" | grep -q "SURVIVED"; then
  pass "_preflight_crit does not kill shell under set -e"
else
  fail "_preflight_crit KILLS shell under set -e (regression)"
  echo "  Output was: $(echo "$GUARD_RESULT" | tr '\n' ' ')"
fi

echo ""
echo "=== 5. stderr capture ==="
# Verify that stderr from a failing command is captured and displayed.
OUT=$(bash -e -c '
set -euo pipefail
_preflight_crit() {
  local msg="$1"; shift
  local _err
  if _err=$("$@" 2>&1 >/dev/null); then
    :
  else
    echo "ERR:${_err}"
  fi
}
PREFLIGHT_FAILS=0
_preflight_crit "touch nonexistent" touch /nonexistent/.preflight_capture_test
' 2>&1) || true

if echo "$OUT" | grep -q "No such file or directory"; then
  pass "stderr captured and displayed"
else
  fail "stderr NOT captured (output: '$OUT')"
fi

echo ""
echo "=== 6. Live pre-flight simulation ==="

PREFLIGHT_FAILS=0

# Import the exact implementations from sandbox-entrypoint.sh
_preflight_crit() {
  local msg="$1"; shift
  local _err
  if _err=$("$@" 2>&1 >/dev/null); then
    echo "  PREFLIGHT PASS: $msg"
  else
    echo "  PREFLIGHT FAIL: $msg${_err:+  --  ${_err%%$'\n'*}}" >&2
    PREFLIGHT_FAILS=$(( PREFLIGHT_FAILS + 1 ))
  fi
}
_preflight_warn() {
  local msg="$1"; shift
  local _err
  if _err=$("$@" 2>&1 >/dev/null); then
    echo "  PREFLIGHT PASS: $msg"
  else
    echo "  PREFLIGHT WARN: $msg${_err:+  --  ${_err%%$'\n'*}}" >&2
  fi
}

echo "--- pre-flight checks ---"

# SESSION_STATE checks
_preflight_crit "SESSION_STATE has init_sha" \
  bash -c 's="$(cat /home/agentuser/sandbox/.git/SESSION_STATE 2>/dev/null)"; [[ "$s" == *init_sha=* ]]'
_preflight_crit "SESSION_STATE has session_ts" \
  bash -c 's="$(cat /home/agentuser/sandbox/.git/SESSION_STATE 2>/dev/null)"; [[ "$s" == *session_ts=* ]]'

# Mount checks (capability layer mounts only)
_preflight_crit "SNAPSHOT_DIR is readable (snapshot mount)"       test -f "$SNAPSHOT_DIR/baseline.tar"
_preflight_crit "CHANGES_DIR is writable (session-diffs mount)"   touch "$CHANGES_DIR/.preflight_write_test" && rm -f "$CHANGES_DIR/.preflight_write_test"

# WARN checks
_preflight_warn "Working tree is clean"    bash -c 'cd "$SANDBOX_DIR"; [[ -z "$(git status --short)" ]]'

SUMMARY=$([ "$PREFLIGHT_FAILS" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "$PREFLIGHT_FAILS FAILURE(S)")
echo "--- pre-flight: $SUMMARY ---"

if [[ "$PREFLIGHT_FAILS" -eq 0 ]]; then
  pass "All pre-flight checks pass"
else
  fail "$PREFLIGHT_FAILS pre-flight check(s) failed (expected: 0)"
fi

# Verify the two agent-container-only checks are NOT in the critical list
ENTRYPOINT_FILE="/home/agentuser/sandbox/libs/sandbox-entrypoint.sh"
if [[ -f "$ENTRYPOINT_FILE" ]]; then
  if grep -q 'PREFLIGHT FAIL: INPUT_DIR\|PREFLIGHT FAIL: OUTPUT_DIR' "$ENTRYPOINT_FILE"; then
    fail "sandbox-entrypoint.sh still contains INPUT_DIR/OUTPUT_DIR CRITICAL checks"
  else
    pass "INPUT_DIR/OUTPUT_DIR CRITICAL checks removed from sandbox-entrypoint.sh"
  fi
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASS, Failed: $FAIL"

echo ""
echo "If any checks fail:"
echo "  1. set -e safety failure -> _preflight_crit uses _err=\$(cmd) instead of if _err=\$(cmd); then"
echo "  2. stderr capture failure -> the 2>&1 >/dev/null redirection may be misordered"
echo "  3. SESSION_STATE failure  -> snapshot_init_git did not write it, or .git is missing"
echo "  4. Mount failures         -> check compose volume definitions for the sandbox service"

[[ "$FAIL" -eq 0 ]]
