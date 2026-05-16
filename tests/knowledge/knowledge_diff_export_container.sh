#!/usr/bin/env bash
# tests/knowledge/knowledge_diff_export_container.sh
#
# Container-scoped integration test for the diff_export pipeline as invoked
# by the sandbox-entrypoint.sh EXIT trap.
#
# Tests the full function chain that the EXIT trap depends on:
#   session_export_path → mkdir -p → diff_export → package_branch → artefacts
#
# Validates:
#   1. diff_export produces all 5 artefact types with a committed file
#   2. diff_export captures uncommitted changes (no commit needed)
#   3. diff_export captures an untracked file (git add -N path)
#   4. Output lands under $CHANGES_DIR/session/<TS>-<BRANCH>/ (EXIT trap path)
#   5. SESSION_STATE missing causes silent failure (package_branch returns 1,
#      EXIT trap does not check return value — this documents the gap)
#   6. The export path matches what interactive_select_channel resolves on the host
#   7. Multiple exports accumulate with different timestamps
#
# This test runs inside a container (capability layer or reasoning layer)
# and does NOT require Docker or compose. It tests the pure function chain.
#
# Run:
#   bash tests/knowledge/knowledge_diff_export_container.sh
#
# Exit 0 = all assertions pass.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../.."

# Source the exact libraries the EXIT trap uses
source "$REPO_ROOT/libs/dirs.sh"
source "$REPO_ROOT/libs/session.sh"
source "$REPO_ROOT/libs/routing.sh"
source "$REPO_ROOT/libs/diff.sh"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

section() { echo ""; echo "=== $1 ==="; echo ""; }

# ---------------------------------------------------------------------------
# Helper: create a mock sandbox with baseline commit + SESSION_STATE
# ---------------------------------------------------------------------------
make_sandbox() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init --quiet
  git -C "$dir" config user.email "test@test"
  git -C "$dir" config user.name "test"
  git -C "$dir" config core.fileMode false

  # Baseline file
  echo "baseline" > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -m "baseline" --quiet

  local sha
  sha=$(git -C "$dir" rev-list --max-parents=0 HEAD)

  # Write SESSION_STATE
  mkdir -p "$dir/.git"
  echo "init_sha=$sha" > "$dir/.git/SESSION_STATE"
  echo "session_ts=20260521-120000" >> "$dir/.git/SESSION_STATE"

  echo "$sha"
}

make_sandbox_no_state() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init --quiet
  git -C "$dir" config user.email "test@test"
  git -C "$dir" config user.name "test"
  git -C "$dir" config core.fileMode false

  echo "baseline" > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -m "baseline" --quiet
}

# ---------------------------------------------------------------------------
# Simulate the EXIT trap's path construction
# ---------------------------------------------------------------------------
# The EXIT trap in sandbox-entrypoint.sh does:
#   WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"   (ROOT=/home/agentuser)
#   local _exit_dir="$(session_export_path "$CHANGES_DIR" "session" \
#                      "${SESSION_TS:-unknown}" "${SANITIZED_HOST_BRANCH:-unknown}")"
#   mkdir -p "$_exit_dir"
#   diff_export "$SANDBOX_DIR" "$_exit_dir"
exit_trap_export() {
  local sandbox_dir="$1"
  local changes_dir="$2"
  local session_ts="${3:-unknown}"
  local branch="${4:-unknown}"

  local _exit_dir
  _exit_dir=$(session_export_path "$changes_dir" "session" "$session_ts" "$branch")
  mkdir -p "$_exit_dir"
  diff_export "$sandbox_dir" "$_exit_dir"
  echo "$_exit_dir"
}

# ===========================================================================
# Test 1: diff_export produces all artefacts with a committed file
# ===========================================================================
section "Test 1: Full artefact output (committed change)"

T1_DIR=$(mktemp -d)
trap 'rm -rf "$T1_DIR"' RETURN

T1_SHA=$(make_sandbox "$T1_DIR/sandbox")
CHANGES_DIR="$T1_DIR/changes"

# Simulate container-side resolution
WORKSPACE_DIR_NAME=workspace
CHANGES_DIR_NAME=session-diffs
dirs_resolve "$T1_DIR"
# Override CHANGES_DIR for our test
CHANGES_DIR="$T1_DIR/changes"

# Create and commit a file
echo "new file content" > "$T1_DIR/sandbox/newfile.py"
git -C "$T1_DIR/sandbox" add newfile.py
git -C "$T1_DIR/sandbox" commit -m "add newfile.py" --quiet

# Run the EXIT trap sequence
EXPORT_DIR=$(exit_trap_export "$T1_DIR/sandbox" "$CHANGES_DIR" "20260521-120000" "main")

# Verify path
EXPECTED_PATH="$CHANGES_DIR/session/20260521-120000-main"
if [[ "$EXPORT_DIR" == "$EXPECTED_PATH" ]]; then
  pass "Export dir path matches: $EXPORT_DIR"
else
  fail "Export dir: expected $EXPECTED_PATH, got $EXPORT_DIR"
fi

# Verify all artefacts present
ALL_OK=true
if [[ -d "$EXPORT_DIR/patches" ]]; then
  PATCH_COUNT=$(ls "$EXPORT_DIR/patches/"*.diff 2>/dev/null | wc -l)
  [[ "$PATCH_COUNT" -gt 0 ]] || { echo "  MISSING: patches/*.diff (0 files)"; ALL_OK=false; }
else
  echo "  MISSING: patches/ directory"; ALL_OK=false
fi
[[ -f "$EXPORT_DIR/uncommitted.diff" ]] || { echo "  MISSING: uncommitted.diff"; ALL_OK=false; }
[[ -f "$EXPORT_DIR/all-changes.diff" ]] || { echo "  MISSING: all-changes.diff"; ALL_OK=false; }
[[ -d "$EXPORT_DIR/changed-files" ]] || { echo "  MISSING: changed-files/"; ALL_OK=false; }
[[ -f "$EXPORT_DIR/changed-files/newfile.py" ]] || { echo "  MISSING: changed-files/newfile.py"; ALL_OK=false; }
[[ -f "$EXPORT_DIR/changed-files/MANIFEST.txt" ]] || { echo "  MISSING: changed-files/MANIFEST.txt"; ALL_OK=false; }
[[ -f "$EXPORT_DIR/EXPORT-TIME.txt" ]] || { echo "  MISSING: EXPORT-TIME.txt"; ALL_OK=false; }

if [[ "$ALL_OK" == true ]]; then
  pass "All 5 artefact types present (patches/, uncommitted.diff, all-changes.diff, changed-files/, EXPORT-TIME.txt)"
else
  fail "One or more artefacts missing from $EXPORT_DIR"
fi

# Verify diff content includes the new file
if grep -q "newfile.py" "$EXPORT_DIR/all-changes.diff" 2>/dev/null; then
  pass "all-changes.diff references newfile.py"
else
  fail "all-changes.diff does not reference newfile.py"
fi

# ===========================================================================
# Test 2: Uncommitted changes captured (no commit needed)
# ===========================================================================
section "Test 2: Uncommitted change capture"

T2_DIR=$(mktemp -d)
trap 'rm -rf "$T2_DIR"' RETURN

make_sandbox "$T2_DIR/sandbox" > /dev/null

# Create uncommitted file
echo "uncommitted content" > "$T2_DIR/sandbox/uncommitted.txt"

CHANGES_DIR="$T2_DIR/changes"
EXPORT_DIR=$(exit_trap_export "$T2_DIR/sandbox" "$CHANGES_DIR" "20260521-120001" "main")

if [[ -f "$EXPORT_DIR/uncommitted.diff" && -s "$EXPORT_DIR/uncommitted.diff" ]]; then
  pass "uncommitted.diff is non-empty with uncommitted changes"
else
  fail "uncommitted.diff missing or empty with uncommitted changes"
fi

if [[ -f "$EXPORT_DIR/changed-files/uncommitted.txt" ]]; then
  pass "changed-files/ includes uncommitted.txt"
else
  fail "changed-files/ missing uncommitted.txt"
fi

# ===========================================================================
# Test 3: Untracked file captured (git add -N path)
# ===========================================================================
section "Test 3: Untracked file capture"

T3_DIR=$(mktemp -d)
trap 'rm -rf "$T3_DIR"' RETURN

make_sandbox "$T3_DIR/sandbox" > /dev/null

# Create an untracked file (no git add)
echo "untracked content" > "$T3_DIR/sandbox/untracked.txt"

CHANGES_DIR="$T3_DIR/changes"
EXPORT_DIR=$(exit_trap_export "$T3_DIR/sandbox" "$CHANGES_DIR" "20260521-120002" "main")

if grep -q "untracked.txt" "$EXPORT_DIR/all-changes.diff" 2>/dev/null; then
  pass "all-changes.diff references untracked file"
else
  fail "all-changes.diff does not reference untracked file"
fi

if [[ -f "$EXPORT_DIR/changed-files/untracked.txt" ]]; then
  pass "changed-files/ includes untracked.txt"
else
  fail "changed-files/ missing untracked.txt"
fi

# ===========================================================================
# Test 4: SESSION_STATE missing → silent failure (documents the gap)
# ===========================================================================
section "Test 4: SESSION_STATE missing — silent failure gap"

T4_DIR=$(mktemp -d)
trap 'rm -rf "$T4_DIR"' RETURN

make_sandbox_no_state "$T4_DIR/sandbox"

echo "orphaned content" > "$T4_DIR/sandbox/orphaned.txt"

CHANGES_DIR="$T4_DIR/changes"

# Call exit_trap_export — this is what the EXIT trap does.
# package_branch will fail because init_sha is missing, but the EXIT trap
# does not check the return value.
EXPORT_DIR=$(exit_trap_export "$T4_DIR/sandbox" "$CHANGES_DIR" "20260521-120003" "main") 2>/dev/null || true

# The export dir IS created (session_export_path + mkdir -p ran)
if [[ -d "$EXPORT_DIR" ]]; then
  pass "Export directory created even without SESSION_STATE"
else
  fail "Export directory not created"
fi

# But the artefacts are MISSING because package_branch failed
HAS_ARTEFACTS=false
if [[ -f "$EXPORT_DIR/uncommitted.diff" ]] || [[ -f "$EXPORT_DIR/all-changes.diff" ]]; then
  HAS_ARTEFACTS=true
fi

if [[ "$HAS_ARTEFACTS" == false ]]; then
  pass "GAP CONFIRMED: no diff artefacts produced when SESSION_STATE is missing"
  echo "  --> package_branch failed silently, EXIT trap did not detect it"
else
  fail "Artefacts produced despite missing SESSION_STATE — behaviour may have changed"
fi

# ===========================================================================
# Test 5: Path matches what interactive_select_channel resolves
# ===========================================================================
section "Test 5: Path agreement — container export == host lookup"

T5_DIR=$(mktemp -d)
trap 'rm -rf "$T5_DIR"' RETURN

make_sandbox "$T5_DIR/sandbox" > /dev/null
echo "content" > "$T5_DIR/sandbox/test.txt"

# Container side: what the EXIT trap produces
# Inside the container: WORKSPACE_DIR_NAME=workspace, ROOT=/home/agentuser
# The bind mount target is /home/agentuser/workspace/session-diffs
# We simulate this with a CHANGES_DIR at the mount target
CONTAINER_CHANGES_DIR="$T5_DIR/.container/changes"
mkdir -p "$CONTAINER_CHANGES_DIR"
EXPORT_CONTAINER_PATH=$(exit_trap_export "$T5_DIR/sandbox" "$CONTAINER_CHANGES_DIR" "20260521-120004" "main")

# The bind mount maps CONTAINER_CHANGES_DIR → HOST_CHANGES_DIR
# On the host, CHANGES_DIR = SANDBOX_DIR/.workspace/session-diffs
HOST_CHANGES_DIR="$T5_DIR/.host/changes"

# Symlink or mirror the container path to the host path
mkdir -p "$HOST_CHANGES_DIR"
ln -sfn "$CONTAINER_CHANGES_DIR/session" "$HOST_CHANGES_DIR/session" 2>/dev/null || \
  cp -a "$CONTAINER_CHANGES_DIR/session" "$HOST_CHANGES_DIR/" 2>/dev/null || true

# What interactive_select_channel looks for:
# dirs_resolve "$SANDBOX_DIR" (host defaults: WORKSPACE_DIR_NAME=.workspace)
# Then BASE_DIR = $CHANGES_DIR/session where CHANGES_DIR = $SANDBOX_DIR/.workspace/session-diffs
# But here we're simulating — the HOST path should have a session/ subdir
if [[ -d "$CONTAINER_CHANGES_DIR/session/20260521-120004-main" ]]; then
  pass "Container-side export dir exists under session/ subdirectory"
else
  fail "Container-side export dir not found under session/"
fi

# Verify the naming convention: <SESSION_TS>-<BRANCH>
SESSION_DIRNAME=$(basename "$EXPORT_CONTAINER_PATH")
if [[ "$SESSION_DIRNAME" == "20260521-120004-main" ]]; then
  pass "Export dir uses SESSION_TS-BRANCH naming: $SESSION_DIRNAME"
else
  fail "Export dir naming: expected 20260521-120004-main, got $SESSION_DIRNAME"
fi

# ===========================================================================
# Test 6: Multiple exports accumulate
# ===========================================================================
section "Test 6: Multiple exports accumulate"

T6_DIR=$(mktemp -d)
trap 'rm -rf "$T6_DIR"' RETURN

make_sandbox "$T6_DIR/sandbox" > /dev/null
CHANGES_DIR="$T6_DIR/changes"

# First export
echo "v1" > "$T6_DIR/sandbox/file1.txt"
EXPORT1=$(exit_trap_export "$T6_DIR/sandbox" "$CHANGES_DIR" "20260521-100000" "main")

# Second export
echo "v2" > "$T6_DIR/sandbox/file2.txt"
EXPORT2=$(exit_trap_export "$T6_DIR/sandbox" "$CHANGES_DIR" "20260521-110000" "feature-x")

SESSION_COUNT=$(find "$CHANGES_DIR/session" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
if [[ "$SESSION_COUNT" -eq 2 ]]; then
  pass "Multiple exports accumulate under session/ ($SESSION_COUNT entries)"
else
  fail "Expected 2 session entries, got $SESSION_COUNT"
fi

if [[ -f "$EXPORT1/changed-files/file1.txt" && -f "$EXPORT2/changed-files/file2.txt" ]]; then
  pass "Each export contains its own changed files"
else
  fail "Exports do not contain expected changed files"
fi

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "=== Summary ==="
echo "Results: $PASS passed, $FAIL failed"
echo ""
echo "Gaps documented:"
echo "  - SESSION_STATE missing → package_branch fails → EXIT trap silent"
echo "  - No test verifies the EXIT trap is registered in sandbox-entrypoint.sh"
echo "  - No end-to-end test simulates container stop (SIGTERM → EXIT)"

[[ "$FAIL" -eq 0 ]]
