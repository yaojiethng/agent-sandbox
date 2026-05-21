#!/usr/bin/env bash
# diagnose_dry_run_reasoning.sh
# Run inside the agent container:
#   docker exec <agent-container> bash /path/to/diagnose_dry_run_reasoning.sh
#
# Checks why the reasoning-layer dry-run checks (dry_run_reasoning.sh) fail
# by verifying every link in the chain: environment, library availability,
# path resolution, script hygiene, mount expectations, SESSION_STATE
# access, cross-container marker read, and session-diffs round-trip.
#
# This is the reasoning-layer counterpart to diagnose_dry_run_capability.sh
# (capability layer). Together they cover the full dry-run precondition space.

set -uo pipefail

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

ROOT="/home/agentuser"

echo "=== 1. Environment ==="
for var in AGENT_HOME PROVIDER_NAME PROVIDER_CONFIG_DIR SNAPSHOT_DIR_NAME SANDBOX_DIR_NAME CHANGES_DIR_NAME WORKSPACE_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME; do
  val="${!var:-<UNSET>}"
  echo "  $var='$val'"
done

echo ""
echo "=== 2. Library sourcing ==="
for lib in dirs.sh session.sh; do
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
source /opt/sandbox/lib/dirs.sh 2>/dev/null
WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
echo "  SNAPSHOT_DIR=$SNAPSHOT_DIR"
echo "  CHANGES_DIR=$CHANGES_DIR"
echo "  INPUT_DIR=$INPUT_DIR"
echo "  OUTPUT_DIR=$OUTPUT_DIR"
echo "  SANDBOX_DIR=$ROOT/${SANDBOX_DIR_NAME:-sandbox}"

[[ -n "$SNAPSHOT_DIR" ]]  && pass "SNAPSHOT_DIR resolved"  || fail "SNAPSHOT_DIR is empty"
[[ -n "$CHANGES_DIR" ]]   && pass "CHANGES_DIR resolved"   || fail "CHANGES_DIR is empty"
[[ -n "$INPUT_DIR" ]]     && pass "INPUT_DIR resolved"     || fail "INPUT_DIR is empty"
[[ -n "$OUTPUT_DIR" ]]    && pass "OUTPUT_DIR resolved"    || fail "OUTPUT_DIR is empty"

echo ""
echo "=== 4. Script hygiene: local keyword ==="
SCRIPT="/dry_run_reasoning.sh"
if [[ -f "$SCRIPT" ]]; then
  BAD_LOCALS=0
  IN_FUNC=0
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)\s*(\{|$)' 2>/dev/null; then
      IN_FUNC=1
    fi
    if echo "$line" | grep -qE '^\}' 2>/dev/null && [[ "$IN_FUNC" -eq 1 ]]; then
      IN_FUNC=0
    fi
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
    fail "$BAD_LOCALS top-level local usage(s) found in $SCRIPT"
  fi
else
  fail "$SCRIPT not found — cannot check local keyword hygiene"
fi

echo ""
echo "=== 5. Mount expectations ==="
# The reasoning layer (agent) mounts:
#   - INPUT_DIR    (read-only, brief mount)
#   - OUTPUT_DIR   (writable, output mount)
#   - SANDBOX_DIR  (via --volumes-from, shared filesystem with sandbox)
# It also has access to SNAPSHOT_DIR and CHANGES_DIR via volumes-from.

# Agent-specific mounts
if [[ -d "$INPUT_DIR" ]]; then
  pass "INPUT_DIR exists ($INPUT_DIR)"
  # Check read-only: try to create a file
  if touch "$INPUT_DIR/.diag_write_test" 2>/dev/null; then
    fail "  INPUT_DIR is WRITABLE (expected read-only)"
    rm -f "$INPUT_DIR/.diag_write_test" 2>/dev/null || true
  else
    pass "  INPUT_DIR is read-only (expected)"
  fi
else
  fail "INPUT_DIR missing (brief mount not attached)"
fi

if [[ -d "$OUTPUT_DIR" ]]; then
  pass "OUTPUT_DIR exists ($OUTPUT_DIR)"
  if touch "$OUTPUT_DIR/.diag_write_test" 2>/dev/null; then
    pass "  OUTPUT_DIR is writable"
    rm -f "$OUTPUT_DIR/.diag_write_test"
  else
    fail "  OUTPUT_DIR is NOT writable"
  fi
else
  fail "OUTPUT_DIR missing (output mount not attached)"
fi

# Via volumes-from
SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"
if [[ -d "$SANDBOX_DIR" ]]; then
  pass "SANDBOX_DIR exists via volumes-from ($SANDBOX_DIR)"
  if [[ -d "$SANDBOX_DIR/.git" ]]; then
    pass "  sandbox .git is accessible"
  else
    fail "  sandbox .git NOT accessible"
  fi
else
  fail "SANDBOX_DIR missing (volumes-from not attached)"
fi

echo ""
echo "=== 6. SESSION_STATE read ==="
# SESSION_STATE is written by the sandbox to its .git/SESSION_STATE.
# The reasoning layer accesses it via shared .git (volumes-from).
SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"
STATE_FILE="$SANDBOX_DIR/.git/SESSION_STATE"
if [[ -f "$STATE_FILE" ]]; then
  pass "SESSION_STATE file exists at $STATE_FILE"
  source /opt/sandbox/lib/session.sh 2>/dev/null
  INIT_SHA=$(session_state_read "$SANDBOX_DIR" "init_sha" 2>/dev/null)
  if [[ -n "$INIT_SHA" ]]; then
    if git -C "$SANDBOX_DIR" rev-parse --verify --quiet "$INIT_SHA" >/dev/null 2>&1; then
      pass "  init_sha=$INIT_SHA is a valid commit"
    else
      fail "  init_sha=$INIT_SHA is NOT a valid commit in the sandbox repo"
    fi
  else
    fail "  init_sha is missing from SESSION_STATE"
  fi
  TS=$(session_state_read "$SANDBOX_DIR" "session_ts" 2>/dev/null)
  [[ -n "$TS" ]] && pass "  session_ts=$TS" || fail "  session_ts missing"
else
  fail "SESSION_STATE file MISSING at $STATE_FILE"
fi

echo ""
echo "=== 7. Cross-container marker read test ==="
# Phase 1 writes a marker to CHANGES_DIR. Phase 2 reads it.
# The agent accesses CHANGES_DIR via volumes-from, so the path should
# be /home/agentuser/workspace/session-diffs (same as sandbox).
MARKER="${CHANGES_DIR}/.dryrun_capability_marker"
if [[ -f "$MARKER" ]]; then
  CONTENT=$(cat "$MARKER" 2>/dev/null)
  if [[ "$CONTENT" == "CAPABILITY_LAYER_OK" ]]; then
    pass "Cross-container marker: readable with correct content"
  else
    fail "Cross-container marker: unexpected content ('$CONTENT')"
  fi
else
  # The marker may not exist if Phase 1 hasn't run yet.
  # Check if CHANGES_DIR at least exists and is writable.
  if [[ -d "$CHANGES_DIR" ]]; then
    pass "CHANGES_DIR exists — marker absent (expected if Phase 1 hasn't run)"
  else
    fail "CHANGES_DIR does NOT exist — volumes-from may be broken"
  fi
fi

echo ""
echo "=== 8. Session-diffs round-trip ==="
# Verify the agent can write to and read from CHANGES_DIR.
# This validates that CHANGES_DIR resolves to the bind mount target.
MARKER="${CHANGES_DIR}/.diag_seam_test"
if mkdir -p "$CHANGES_DIR" 2>/dev/null && echo "DIAG_OK" > "$MARKER" 2>/dev/null; then
  READBACK=$(cat "$MARKER" 2>/dev/null)
  if [[ "$READBACK" == "DIAG_OK" ]]; then
    pass "Round-trip: wrote and read back marker at $CHANGES_DIR"
  else
    fail "Round-trip: readback mismatch ('$READBACK')"
  fi
  rm -f "$MARKER"
else
  fail "Round-trip: could not write to $CHANGES_DIR"
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASS, Failed: $FAIL"
echo ""
echo "If any checks fail:"
echo "  1. Library sourcing → check /opt/sandbox/lib/ contents"
echo "  2. Top-level local  → edit dry_run_reasoning.sh; remove 'local' from top-level vars"
echo "  3. Mount failures   → check docker-compose.dry-run.yml volume definitions"
echo "  4. SESSION_STATE    → check sandbox init wrote init_sha and session_ts"
echo "  5. Round-trip fail  → check CHANGES_DIR path matches volumes-from target"

[[ "$FAIL" -eq 0 ]]
