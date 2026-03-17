#!/usr/bin/env bash
# test_capability_layer.sh
# Functional test for the capability layer container (standalone, no compose).
#
# Tests the full startup → mutation → shutdown → diff sequence using a
# throwaway container to simulate the reasoning layer writing to sandbox/.
#
# Usage:
#   ./test_capability_layer.sh <repo-root> <snapshot-dir>
#
#   <repo-root>     absolute path to the agent-sandbox repo
#   <snapshot-dir>  absolute path to a pre-built .snapshot/ directory
#
# Example:
#   ./test_capability_layer.sh ~/agent-sandbox ~/agent-sandbox-sandbox/.snapshot
#
# Requirements:
#   - Docker running
#   - Dockerfile.sandbox built (or pass IMAGE_NAME to use an existing image)
#   - A pre-built .snapshot/ directory (run snapshot pipeline stage 1 first,
#     or copy an existing one)

set -euo pipefail

# -------------------------
# Args and config
# -------------------------
REPO_ROOT="${1:?Usage: $0 <repo-root> <snapshot-dir>}"
SNAPSHOT_DIR="${2:?Usage: $0 <repo-root> <snapshot-dir>}"

IMAGE_NAME="${IMAGE_NAME:-agent-sandbox-sandbox-test}"
CONTAINER_NAME="capability-layer-test-$$"
WORKSPACE_DIR="$(mktemp -d)"

PASS=0
FAIL=0

# -------------------------
# Helpers
# -------------------------
pass() { echo "  PASS: $1"; ((PASS++)) || true; }
fail() { echo "  FAIL: $1"; ((FAIL++)) || true; }

check() {
  local desc="$1"
  shift
  if "$@" &>/dev/null; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

cleanup() {
  echo ""
  echo "Cleaning up..."
  docker stop "$CONTAINER_NAME" &>/dev/null || true
  docker rm "$CONTAINER_NAME" &>/dev/null || true
  rm -rf "$WORKSPACE_DIR"
}
trap cleanup EXIT

# -------------------------
# Preflight
# -------------------------
echo "=== Capability Layer Functional Test ==="
echo "Repo root:    $REPO_ROOT"
echo "Snapshot dir: $SNAPSHOT_DIR"
echo "Workspace:    $WORKSPACE_DIR"
echo ""

echo "--- Preflight ---"

check "snapshot dir exists and is non-empty" \
  bash -c "[[ -d '$SNAPSHOT_DIR' && -n \"\$(ls -A '$SNAPSHOT_DIR')\" ]]"

check "docker is running" docker info

# -------------------------
# Build
# -------------------------
echo ""
echo "--- Build ---"

echo "  Building $IMAGE_NAME from $REPO_ROOT..."
if docker build -q -f "$REPO_ROOT/Dockerfile.sandbox" -t "$IMAGE_NAME" "$REPO_ROOT" &>/dev/null; then
  pass "docker build succeeded"
else
  fail "docker build failed — aborting"
  exit 1
fi

check "sandbox-entrypoint.sh present in image" \
  docker run --rm "$IMAGE_NAME" test -f /usr/local/bin/sandbox-entrypoint.sh

check "libs/snapshot.sh present in image" \
  docker run --rm "$IMAGE_NAME" test -f /libs/snapshot.sh

check "libs/diff.sh present in image" \
  docker run --rm "$IMAGE_NAME" test -f /libs/diff.sh

# -------------------------
# Startup
# -------------------------
echo ""
echo "--- Startup ---"

mkdir -p "$WORKSPACE_DIR/changes"

echo "  Starting capability layer container..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --volume "$SNAPSHOT_DIR:/home/agentuser/.snapshot:ro" \
  --volume "$WORKSPACE_DIR:/home/agentuser/.workspace" \
  --env AUTOSAVE_INTERVAL=0 \
  "$IMAGE_NAME" > /dev/null

# Give the entrypoint time to complete init before checking
sleep 3

check "container is running after init" \
  bash -c "[[ \"\$(docker inspect -f '{{.State.Running}}' '$CONTAINER_NAME')\" == 'true' ]]"

check "sandbox is non-empty (copy succeeded)" \
  bash -c "[[ \$(docker run --rm --volumes-from '$CONTAINER_NAME' ubuntu:24.04 find /home/agentuser/sandbox -type f | wc -l) -gt 0 ]]"

BASELINE_LOG=$(docker logs "$CONTAINER_NAME" 2>&1)

check "baseline SHA logged to stderr" \
  bash -c "echo '$BASELINE_LOG' | grep -q 'Baseline:'"

check "file count logged to stderr" \
  bash -c "echo '$BASELINE_LOG' | grep -q 'Copied.*file(s) into sandbox'"

# -------------------------
# Mutation via throwaway container (simulates reasoning layer)
# -------------------------
echo ""
echo "--- Mutation (simulated reasoning layer) ---"

docker run --rm \
  --volumes-from "$CONTAINER_NAME" \
  ubuntu:24.04 \
  bash -c "echo 'capability layer test' >> /home/agentuser/sandbox/capability_test.txt" \
  &>/dev/null

check "throwaway container can write to sandbox volume" \
  bash -c "[[ \$(docker run --rm --volumes-from '$CONTAINER_NAME' ubuntu:24.04 \
    cat /home/agentuser/sandbox/capability_test.txt) == 'capability layer test' ]]"

# -------------------------
# Shutdown and diff pipeline
# -------------------------
echo ""
echo "--- Shutdown and diff pipeline ---"

docker stop "$CONTAINER_NAME" > /dev/null

check "container exits with code 0" \
  bash -c "[[ \"\$(docker inspect -f '{{.State.ExitCode}}' '$CONTAINER_NAME')\" == '0' ]]"

check "staged.diff written to workspace" \
  test -f "$WORKSPACE_DIR/changes/staged.diff"

check "staged.diff is non-empty" \
  bash -c "[[ -s '$WORKSPACE_DIR/changes/staged.diff' ]]"

check "staged.diff contains the mutated file" \
  grep -q "capability_test.txt" "$WORKSPACE_DIR/changes/staged.diff"

# -------------------------
# Diff integrity
# -------------------------
echo ""
echo "--- Diff integrity ---"

# Apply the diff to a temp clone of the snapshot to verify it's well-formed.
APPLY_DIR="$(mktemp -d)"
cp -a "$SNAPSHOT_DIR/." "$APPLY_DIR/"
cd "$APPLY_DIR"
git init -q
git config user.email "test@test"
git config user.name "test"
git add -A
git commit -q -m "baseline"

check "staged.diff applies cleanly to snapshot" \
  git apply --check "$WORKSPACE_DIR/changes/staged.diff"

rm -rf "$APPLY_DIR"

# -------------------------
# Failure cases
# -------------------------
echo ""
echo "--- Failure cases ---"

EMPTY_SNAPSHOT="$(mktemp -d)"
FAIL_CONTAINER="capability-layer-fail-$$"
FAIL_WORKSPACE="$(mktemp -d)"
mkdir -p "$FAIL_WORKSPACE/changes"

docker run -d \
  --name "$FAIL_CONTAINER" \
  --volume "$EMPTY_SNAPSHOT:/home/agentuser/.snapshot:ro" \
  --volume "$FAIL_WORKSPACE:/home/agentuser/.workspace" \
  "$IMAGE_NAME" > /dev/null || true

sleep 2

check "container exits non-zero when .snapshot/ is empty (gate 2)" \
  bash -c "[[ \"\$(docker inspect -f '{{.State.ExitCode}}' '$FAIL_CONTAINER' 2>/dev/null)\" != '0' ]]"

docker rm "$FAIL_CONTAINER" &>/dev/null || true
rm -rf "$EMPTY_SNAPSHOT" "$FAIL_WORKSPACE"

# -------------------------
# Summary
# -------------------------
echo ""
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "All checks passed."
  exit 0
else
  echo "Some checks failed. Review output above."
  exit 1
fi
