#!/usr/bin/env bash
# test_capability_layer.sh
# Functional test for the capability layer container (standalone, no compose).
#
# Tests the full startup → mutation → shutdown → diff sequence using a
# throwaway container to simulate the reasoning layer writing to sandbox/.
#
# Usage:
#   ./test_capability_layer.sh <repo-root> <sandbox-dir>
#
#   <repo-root>    absolute path to the agent-sandbox repo (build context)
#   <sandbox-dir>  absolute path to SANDBOX_DIR — must contain:
#                    Dockerfile.sandbox
#                    .snapshot/   (pre-built snapshot)
#                    .workspace/changes/  (created by this script if absent)
#
# Example:
#   ./test_capability_layer.sh ~/agent-sandbox ~/myproject-sandbox
#
# Requirements:
#   - Docker running
#   - A pre-built .snapshot/ inside SANDBOX_DIR
#
# Note: intentionally no set -euo pipefail — test scripts must handle failures
# explicitly so that failures produce diagnostic output rather than silent exit.

# -------------------------
# Args and config
# -------------------------
REPO_ROOT="$(cd "${1:?Usage: $0 <repo-root> <sandbox-dir>}" && pwd)"
SANDBOX_DIR="$(cd "${2:?Usage: $0 <repo-root> <sandbox-dir>}" && pwd)"

SNAPSHOT_DIR="$SANDBOX_DIR/.snapshot"
WORKSPACE_CHANGES_DIR="$SANDBOX_DIR/.workspace/changes"
DOCKERFILE="$SANDBOX_DIR/Dockerfile.sandbox"

IMAGE_NAME="${IMAGE_NAME:-agent-sandbox-sandbox-test}"
RUN_ID="$(dd if=/dev/urandom bs=4 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
CONTAINER_NAME="cap-layer-test-${RUN_ID}"
BUILD_LOG=""

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
  docker rm -v "$CONTAINER_NAME" &>/dev/null || true
  docker rmi "$IMAGE_NAME" &>/dev/null || true
  rm -f "$BUILD_LOG"
}
trap cleanup EXIT

# -------------------------
# Preflight
# -------------------------
echo "=== Capability Layer Functional Test ==="
echo "Repo root:    $REPO_ROOT"
echo "Sandbox dir:  $SANDBOX_DIR"
echo "Snapshot dir: $SNAPSHOT_DIR"
echo "Workspace:    $WORKSPACE_CHANGES_DIR"
echo "Dockerfile:   $DOCKERFILE"
echo ""

echo "--- Preflight ---"

check "Dockerfile.sandbox exists in sandbox dir" \
  test -f "$DOCKERFILE"

check "snapshot dir exists and is non-empty" \
  bash -c "[[ -d '$SNAPSHOT_DIR' && -n \"\$(ls -A '$SNAPSHOT_DIR')\" ]]"

check "docker is running" docker info

mkdir -p "$WORKSPACE_CHANGES_DIR"

# -------------------------
# Build
# -------------------------
echo ""
echo "--- Build ---"

echo "  Building $IMAGE_NAME from $REPO_ROOT..."
BUILD_LOG=$(mktemp)
DOCKER_BUILDKIT=1 docker build \
  --progress=plain \
  ${NO_CACHE:+--no-cache} \
  -f "$DOCKERFILE" \
  -t "$IMAGE_NAME" \
  "$REPO_ROOT" >"$BUILD_LOG" 2>&1
BUILD_EXIT=$?
if [[ $BUILD_EXIT -eq 0 ]]; then
  IMAGE_ID=$(docker inspect --format='{{.Id}}' "$IMAGE_NAME" 2>/dev/null | cut -c1-19)
  pass "docker build succeeded ($IMAGE_ID)"
else
  fail "docker build failed — aborting"
  echo ""
  echo "  Build output:"
  cat "$BUILD_LOG" | sed 's/^/    /'
  echo ""
  rm -f "$BUILD_LOG"
  exit 1
fi
rm -f "$BUILD_LOG"

check "sandbox-entrypoint.sh present in image" \
  docker run --rm --entrypoint test "$IMAGE_NAME" -f /usr/local/bin/sandbox-entrypoint.sh

check "libs/snapshot.sh present in image" \
  docker run --rm --entrypoint test "$IMAGE_NAME" -f /libs/snapshot.sh

check "libs/diff.sh present in image" \
  docker run --rm --entrypoint test "$IMAGE_NAME" -f /libs/diff.sh

check "libs/dirs.sh present in image" \
  docker run --rm --entrypoint test "$IMAGE_NAME" -f /libs/dirs.sh

# -------------------------
# Startup
# -------------------------
echo ""
echo "--- Startup ---"

echo "  Starting capability layer container..."
START_OUTPUT=$(docker run -d \
  --name "$CONTAINER_NAME" \
  --volume "$SNAPSHOT_DIR:/home/agentuser/.snapshot:ro" \
  --volume "$WORKSPACE_CHANGES_DIR:/home/agentuser/workspace/changes" \
  --env AUTOSAVE_INTERVAL=0 \
  "$IMAGE_NAME" 2>&1)
START_EXIT=$?
if [[ $START_EXIT -ne 0 ]]; then
  fail "docker run failed — aborting"
  echo ""
  echo "  docker run output:"
  echo "$START_OUTPUT" | sed 's/^/    /'
  echo ""
  exit 1
fi

# Wait for capability layer to report healthy — sandbox/.git exists,
# init is complete. Uses the HEALTHCHECK declared in Dockerfile.sandbox
# rather than a fixed sleep, so this is robust on slow machines.
echo "  Waiting for container to become healthy..."
HEALTH_TIMEOUT=60
HEALTH_ELAPSED=0
while true; do
  STATUS=$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null)
  if [[ "$STATUS" == "healthy" ]]; then
    break
  fi
  if [[ "$STATUS" == "unhealthy" ]]; then
    fail "container became unhealthy — aborting"
    echo ""
    echo "  Container logs:"
    docker logs "$CONTAINER_NAME" 2>&1 | sed 's/^/    /'
    echo ""
    exit 1
  fi
  if [[ $HEALTH_ELAPSED -ge $HEALTH_TIMEOUT ]]; then
    fail "container did not become healthy within ${HEALTH_TIMEOUT}s — aborting"
    echo ""
    echo "  Container logs:"
    docker logs "$CONTAINER_NAME" 2>&1 | sed 's/^/    /'
    echo ""
    exit 1
  fi
  sleep 2
  HEALTH_ELAPSED=$((HEALTH_ELAPSED + 2))
done

check "container is healthy after init" \
  bash -c "[[ \"\$(docker inspect -f '{{.State.Health.Status}}' '$CONTAINER_NAME')\" == 'healthy' ]]"

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
  test -f "$WORKSPACE_CHANGES_DIR/staged.diff"

check "staged.diff is non-empty" \
  bash -c "[[ -s '$WORKSPACE_CHANGES_DIR/staged.diff' ]]"

check "staged.diff contains the mutated file" \
  grep -q "capability_test.txt" "$WORKSPACE_CHANGES_DIR/staged.diff"

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
  git apply --check "$WORKSPACE_CHANGES_DIR/staged.diff"

rm -rf "$APPLY_DIR"

# -------------------------
# Failure cases
# -------------------------
echo ""
echo "--- Failure cases ---"

EMPTY_SNAPSHOT="$(mktemp -d)"
FAIL_CONTAINER="cap-layer-fail-${RUN_ID}"
FAIL_WORKSPACE="$(mktemp -d)"

docker run -d \
  --name "$FAIL_CONTAINER" \
  --volume "$EMPTY_SNAPSHOT:/home/agentuser/.snapshot:ro" \
  --volume "$FAIL_WORKSPACE:/home/agentuser/workspace/changes" \
  "$IMAGE_NAME" > /dev/null || true

sleep 2

check "container exits non-zero when .snapshot/ is empty (gate 2)" \
  bash -c "[[ \"\$(docker inspect -f '{{.State.ExitCode}}' '$FAIL_CONTAINER' 2>/dev/null)\" != '0' ]]"

docker rm -v "$FAIL_CONTAINER" &>/dev/null || true
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