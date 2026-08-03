#!/usr/bin/env bash
# diagnose_autosave.sh
# Run inside the sandbox container:
#   docker exec <sandbox-container> bash /path/to/diagnose_autosave.sh
#
# Checks why the autosave loop isn't producing output by verifying
# every link in the chain: env vars, path resolution, SESSION_STATE,
# and a live diff_export call.

set -uo pipefail

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

ROOT="/home/agentuser"

echo "=== 1. Environment ==="
for var in AUTOSAVE_INTERVAL SESSION_TS SANITIZED_HOST_BRANCH CHANGES_DIR_NAME WORKSPACE_DIR_NAME SANDBOX_DIR_NAME; do
  val="${!var:-<UNSET>}"
  echo "  $var='$val'"
done

# Validate AUTOSAVE_INTERVAL
if [[ -n "${AUTOSAVE_INTERVAL:-}" ]]; then
  if [[ "$AUTOSAVE_INTERVAL" =~ ^[0-9]+$ ]] && [[ "$AUTOSAVE_INTERVAL" -gt 0 ]]; then
    pass "AUTOSAVE_INTERVAL=$AUTOSAVE_INTERVAL (numeric, > 0)"
  elif [[ "$AUTOSAVE_INTERVAL" =~ ^[0-9]+$ ]] && [[ "$AUTOSAVE_INTERVAL" -eq 0 ]]; then
    fail "AUTOSAVE_INTERVAL=0 — autosave loop is DISABLED"
  else
    fail "AUTOSAVE_INTERVAL='$AUTOSAVE_INTERVAL' is not a positive integer"
  fi
else
  fail "AUTOSAVE_INTERVAL is UNSET — sandbox-entrypoint defaults to 60 (line 46), but compose env may not have passed it"
fi

echo ""
echo "=== 2. Path resolution ==="
source /opt/sandbox/lib/dirs.sh 2>/dev/null
WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
echo "CHANGES_DIR=$CHANGES_DIR"
echo "SANDBOX_DIR=$ROOT/${SANDBOX_DIR_NAME:-sandbox}"
echo "SNAPSHOT_DIR=$SNAPSHOT_DIR"

# Check the directories actually exist
[[ -d "$CHANGES_DIR" ]] && pass "CHANGES_DIR exists ($CHANGES_DIR)" || fail "CHANGES_DIR missing"
[[ -d "$ROOT/${SANDBOX_DIR_NAME:-sandbox}" ]] && pass "SANDBOX_DIR exists" || fail "SANDBOX_DIR missing"

echo ""
echo "=== 3. SESSION_STATE ==="
SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"
if [[ -f "$SANDBOX_DIR/.git/SESSION_STATE" ]]; then
  pass "SESSION_STATE file exists"
  cat "$SANDBOX_DIR/.git/SESSION_STATE"
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
echo "=== 4. Autosave process ==="
# Check if the autosave background subshell is alive by searching for sleep processes
# that are children of sandbox-entrypoint (PID 1)
AUTOSAVE_PROC=$(ps -eo pid,ppid,args 2>/dev/null | grep -E '[s]leep.*[0-9]+' | awk '{print $1, $NF}')
if [[ -n "$AUTOSAVE_PROC" ]]; then
  pass "Found sleep process(es) — autosave loop may be alive: $AUTOSAVE_PROC"
else
  fail "No sleep processes found — autosave loop is NOT running or has crashed"
fi

# Check if there are any diff_export processes or children of PID 1
PID1_CHILDREN=$(ps -eo pid,ppid,args 2>/dev/null | awk '$2==1 && $1!=1' | head -10)
echo "  Children of PID 1:"
echo "$PID1_CHILDREN" | sed 's/^/    /'

echo ""
echo "=== 5. Autosave path construction ==="
source /opt/sandbox/lib/routing.sh 2>/dev/null
AS_DIR=$(export_path "$CHANGES_DIR" "autosave" "${RUN_ID:-unknown}" 2>/dev/null) || AS_DIR="<ERROR>"
echo "Autosave target path: $AS_DIR"
echo "Session target path:  $(export_path "$CHANGES_DIR" "session" "${RUN_ID:-unknown}" 2>/dev/null || echo '<ERROR>')"

# Manually try to write to the autosave path
echo "" > "/tmp/autosave_writability_test" 2>/dev/null
TEST_AS_DIR="$AS_DIR"
if [[ "$TEST_AS_DIR" != "<ERROR>" ]]; then
  mkdir -p "$TEST_AS_DIR" 2>/dev/null && pass "Can mkdir -p autosave path ($TEST_AS_DIR)" || fail "Cannot mkdir -p autosave path"
  echo "test" > "$TEST_AS_DIR/.write_test" 2>/dev/null && { pass "Can write to autosave path"; rm -f "$TEST_AS_DIR/.write_test"; } || fail "Cannot write to autosave path"
else
  fail "Cannot construct autosave path (export_path failed)"
fi

echo ""
echo "=== 6. Existing autosave output ==="
# Check for ANY autosave output with this session's TS
if [[ -d "$CHANGES_DIR/autosave" ]]; then
  echo "Existing autosave entries:"
  ls -t "$CHANGES_DIR/autosave/" 2>/dev/null | head -5
  AS_COUNT=$(ls -U "$CHANGES_DIR/autosave/" 2>/dev/null | wc -l)
  echo "  Total autosave entries: $AS_COUNT"
  # Check if any match our session
  OUR_TS="${SESSION_TS:-unknown}"
  MATCHING=$(ls "$CHANGES_DIR/autosave/" 2>/dev/null | grep "$OUR_TS" | wc -l)
  if [[ "$MATCHING" -gt 0 ]]; then
    pass "Found $MATCHING autosave entries matching session TS '$OUR_TS'"
  else
    fail "No autosave entries match our session TS '$OUR_TS' (expected after ~$(( AUTOSAVE_INTERVAL / 60 ))m of runtime)"
    echo "  Most recent: $(ls -t "$CHANGES_DIR/autosave/" 2>/dev/null | head -1)"
  fi
else
  fail "autosave/ directory does NOT exist under $CHANGES_DIR"
fi

echo ""
echo "=== 7. Live diff_export test ==="
source /opt/sandbox/lib/diff.sh 2>/dev/null || source "$SANDBOX_DIR/libs/diff.sh" 2>/dev/null || { fail "Cannot source diff.sh"; }

# Create a test file
echo "diagnostic-$(date +%s)" > "$SANDBOX_DIR/.autosave-diagnostic.txt"
LIVE_DIR="${CHANGES_DIR}/autosave/diagnostic-$(date +%s)"
mkdir -p "$LIVE_DIR"
if diff_export "$SANDBOX_DIR" "$LIVE_DIR" 2>/dev/null; then
  pass "diff_export succeeded (exit 0)"
  if [[ -f "$LIVE_DIR/uncommitted.diff" && -s "$LIVE_DIR/uncommitted.diff" ]]; then
    pass "uncommitted.diff is non-empty"
  else
    fail "uncommitted.diff missing or empty"
  fi
else
  fail "diff_export FAILED (exit $?)"
fi
# Cleanup
rm -f "$SANDBOX_DIR/.autosave-diagnostic.txt"
rm -rf "$LIVE_DIR"

echo ""
echo "=== Summary ==="
echo "Passed: $PASS, Failed: $FAIL"
echo ""
echo "If AUTOSAVE_INTERVAL is correctly set and the path is writable but"
echo "autosave/ has no entries, the autosave subshell may have crashed."
echo "Check the sandbox container logs: docker logs <sandbox-container>"

[[ "$FAIL" -eq 0 ]]
