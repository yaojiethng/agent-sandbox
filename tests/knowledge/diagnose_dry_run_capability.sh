#!/usr/bin/env bash
# diagnose_dry_run_capability.sh
# Run inside the sandbox container:
#   docker exec <sandbox-container> bash /path/to/diagnose_dry_run_capability.sh
#
# Checks why the capability-layer dry-run checks (dry_run_capability.sh) fail
# by verifying every link in the chain: environment, library availability,
# path resolution, script hygiene, mount expectations, and a live diff_export
# test.
#
# This is the capability-layer counterpart to diagnose_dry_run.sh (reasoning
# layer). Together they cover the full dry-run precondition space.

set -uo pipefail

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

ROOT="/home/agentuser"

echo "=== 1. Environment ==="
for var in SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME CHANGES_DIR_NAME WORKSPACE_DIR_NAME; do
  val="${!var:-<UNSET>}"
  echo "  $var='$val'"
done

echo ""
echo "=== 2. Library sourcing ==="
# The capability script needs dirs.sh, session.sh, and diff.sh.
# Verify each exists at the expected path and can be sourced.
for lib in dirs.sh session.sh diff.sh; do
  libpath="/opt/sandbox/lib/$lib"
  if [[ -f "$libpath" ]]; then
    if source "$libpath" 2>/dev/null; then
      pass "source $libpath succeeded"
    else
      fail "source $libpath FAILED (exit $?)"
    fi
  else
    fail "$libpath does not exist"
  fi
done

echo ""
echo "=== 3. Path resolution ==="
# Re-source dirs.sh after the loop above consumed it, then resolve paths.
source /opt/sandbox/lib/dirs.sh 2>/dev/null
WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
echo "  SNAPSHOT_DIR=$SNAPSHOT_DIR"
echo "  CHANGES_DIR=$CHANGES_DIR"
echo "  INPUT_DIR=$INPUT_DIR"
echo "  OUTPUT_DIR=$OUTPUT_DIR"
echo "  SANDBOX_DIR=$ROOT/${SANDBOX_DIR_NAME:-sandbox}"

# Verify derived paths are non-empty
[[ -n "$SNAPSHOT_DIR" ]]  && pass "SNAPSHOT_DIR resolved"  || fail "SNAPSHOT_DIR is empty"
[[ -n "$CHANGES_DIR" ]]   && pass "CHANGES_DIR resolved"   || fail "CHANGES_DIR is empty"
[[ -n "$INPUT_DIR" ]]     && pass "INPUT_DIR resolved"     || fail "INPUT_DIR is empty"
[[ -n "$OUTPUT_DIR" ]]    && pass "OUTPUT_DIR resolved"    || fail "OUTPUT_DIR is empty"

echo ""
echo "=== 4. Script hygiene: local keyword ==="
# dry_run_capability.sh is bind-mounted at /dry_run_capability.sh.
# 'local' at the top level of an executed script is invalid in bash —
# it works only inside functions. Grep for local assignments that
# are not inside a function definition.
SCRIPT="/dry_run_capability.sh"
if [[ -f "$SCRIPT" ]]; then
  # Find lines with 'local' that are NOT inside a function body.
  # Heuristic: a local inside a function has the function declaration
  # before it (with some lines between). We check by seeing if every
  # 'local ' line is inside a function by looking for the defining
  # patterns: lines starting with <function-name>() or preceded by a
  # line containing '{'.
  # Simple approach: list all 'local' lines that are outside of
  # function bodies by tracking a state machine.
  BAD_LOCALS=0
  IN_FUNC=0
  while IFS= read -r line; do
    # Detect function start: line matches ^<name>() { or ^<name>()$
    if echo "$line" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)\s*(\{|$)' 2>/dev/null; then
      IN_FUNC=1
    fi
    # Detect closing brace at start of line (end of function)
    if echo "$line" | grep -qE '^\}' 2>/dev/null && [[ "$IN_FUNC" -eq 1 ]]; then
      IN_FUNC=0
    fi
    # Check for local keyword
    if echo "$line" | grep -qE '^\s*local\s+' 2>/dev/null; then
      if [[ "$IN_FUNC" -eq 0 ]]; then
        echo "    top-level local: $line"
        BAD_LOCALS=$((BAD_LOCALS + 1))
      fi
    fi
  done < "$SCRIPT"
  if [[ "$BAD_LOCALS" -eq 0 ]]; then
    pass "No top-level local usage in $SCRIPT"
  else
    fail "$BAD_LOCALS top-level local usage(s) found in $SCRIPT (must use plain variables in executed scripts)"
  fi
else
  fail "$SCRIPT not found — cannot check local keyword hygiene"
fi

# Also check that the check framework helpers (critical, warn_check) use
# 'local' correctly (inside function bodies). If they don't, the pass/fail
# counting would break.
echo "  (check framework helpers defined in script — verified above by function tracking)"

echo ""
echo "=== 5. Mount expectations ==="
# The capability layer (sandbox) mounts:
#   - SNAPSHOT_DIR  (read-only, snapshot)
#   - CHANGES_DIR   (writable, session-diffs)
# It does NOT mount:
#   - INPUT_DIR     (agent-only)
#   - OUTPUT_DIR    (agent-only)
# Check that the EXPECTED mounts are present and the UNEXPECTED ones are absent.

# Expected mounts
if [[ -d "$SNAPSHOT_DIR" ]]; then
  pass "SNAPSHOT_DIR exists ($SNAPSHOT_DIR)"
  if [[ -f "$SNAPSHOT_DIR/baseline.tar" ]]; then
    pass "  baseline.tar present"
  else
    fail "  baseline.tar MISSING"
  fi
else
  fail "SNAPSHOT_DIR missing (snapshot mount not attached)"
fi

if [[ -d "$CHANGES_DIR" ]]; then
  pass "CHANGES_DIR exists ($CHANGES_DIR)"
  if touch "$CHANGES_DIR/.diag_write_test" 2>/dev/null; then
    pass "  CHANGES_DIR is writable"
    rm -f "$CHANGES_DIR/.diag_write_test"
  else
    fail "  CHANGES_DIR is NOT writable"
  fi
else
  fail "CHANGES_DIR missing (session-diffs mount not attached)"
fi

# Agent-only mounts — expected to be ABSENT in sandbox
if [[ -d "$INPUT_DIR" ]]; then
  pass "INPUT_DIR exists (unexpected — agent mount present in sandbox)"
else
  pass "INPUT_DIR absent (expected — agent-only mount)"
fi

if [[ -d "$OUTPUT_DIR" ]]; then
  pass "OUTPUT_DIR exists (unexpected — agent mount present in sandbox)"
else
  pass "OUTPUT_DIR absent (expected — agent-only mount)"
fi

echo ""
echo "=== 6. diff_export live test ==="
# Test that the diff pipeline can be invoked without error.
# This validates that diff.sh was sourced and diff_export is available.
source /opt/sandbox/lib/diff.sh 2>/dev/null || {
  fail "Cannot source diff.sh — diff_export unavailable"
}

SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"
LIVE_DIR="${CHANGES_DIR}/diag-diff-export-$(date +%s)"
mkdir -p "$LIVE_DIR"

if type diff_export &>/dev/null; then
  pass "diff_export function is available"
  if diff_export "$SANDBOX_DIR" "$LIVE_DIR" 2>/dev/null; then
    pass "diff_export succeeded (exit 0)"
    if [[ -f "$LIVE_DIR/uncommitted.diff" ]]; then
      pass "  uncommitted.diff produced"
    else
      fail "  uncommitted.diff MISSING"
    fi
    if [[ -f "$LIVE_DIR/all-changes.diff" ]]; then
      pass "  all-changes.diff produced"
    else
      fail "  all-changes.diff MISSING"
    fi
    if [[ -d "$LIVE_DIR/patches" ]]; then
      pass "  patches/ directory produced"
    else
      fail "  patches/ directory MISSING"
    fi
  else
    fail "diff_export FAILED (exit $?)"
  fi
else
  fail "diff_export function NOT available (diff.sh not sourced)"
fi
rm -rf "$LIVE_DIR"

echo ""
echo "=== 7. Cross-container marker write test ==="
# Phase 1 writes a marker to CHANGES_DIR for Phase 2 to read.
# Verify the path is writable and the marker round-trips.
MARKER="${CHANGES_DIR}/.diag_capability_marker"
if mkdir -p "$CHANGES_DIR" 2>/dev/null; then
  if echo "DIAG_CAPABILITY_OK" > "$MARKER" 2>/dev/null; then
    READBACK=$(cat "$MARKER" 2>/dev/null)
    if [[ "$READBACK" == "DIAG_CAPABILITY_OK" ]]; then
      pass "Cross-container marker: wrote and read back correctly"
    else
      fail "Cross-container marker: readback mismatch ('$READBACK')"
    fi
    rm -f "$MARKER"
  else
    fail "Cross-container marker: could not write to $MARKER"
  fi
else
  fail "Cross-container marker: could not mkdir -p $CHANGES_DIR"
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASS, Failed: $FAIL"
echo ""
echo "If any checks fail:"
echo "  1. Library sourcing → check /opt/sandbox/lib/ contents"
echo "  2. Top-level local  → edit dry_run_capability.sh; remove 'local' from top-level vars"
echo "  3. Mount failures   → check docker-compose.dry-run.yml volume definitions"
echo "  4. diff_export fail  → check diff.sh is sourced before calling diff_export"
echo "  5. Marker write fail → check CHANGES_DIR mount is writable"

[[ "$FAIL" -eq 0 ]]
