#!/usr/bin/env bash
# tests/test_change_pipeline_delivery.sh
# The change pipeline's delivery matrix: the same agent change exports the same
# diff under copy and mount delivery, full and flatten history.
#
# The model says delivery is a parameter of the agent lane's entry, not a second
# pipeline. This test exercises the shared delivery primitive
# (`snapshot_deliver`) under the four entry labels, applies the same change, and
# compares the diff from the branch point. The copy/mount labels are the entry
# paths; the container-level volume-versus-worktree difference is the
# entrypoint tests' (`test_capability_entrypoint_mount.sh`, `test_seed_volume.sh`).
#
# Covers:
#   copy-full       -- full history keeps the source head as the branch point
#   copy-flatten    -- flatten starts a new root with the same tree
#   mount-full      -- full history keeps the source head as the branch point
#   mount-flatten   -- flatten starts a new root with the same tree
#   same diff       -- the four diffs from the branch point are byte-identical

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/capability/snapshot.sh"
source "$TEST_DIR/libs/git_fixtures.sh"

# run_matrix_case NAME FLATTEN
#   Builds a source repo, delivers it with the shared primitive, applies one
#   change, and writes the diff from the branch point. Globals set: MATRIX_DIFF.
run_matrix_case() {
  local NAME="$1"
  local FLATTEN="$2"
  local SRC="$FIXTURE_DIR/$NAME.src"
  local DST="$FIXTURE_DIR/$NAME.dst"
  local BASE INIT

  make_committed_repo "$SRC"
  BASE=$(git -C "$SRC" rev-parse HEAD)
  if ! snapshot_deliver "$SRC" "$DST" "$FLATTEN"; then
    fail "$NAME: delivery failed"
    return 1
  fi
  INIT=$(git -C "$DST" rev-parse HEAD)
  if [[ "$FLATTEN" == "true" ]]; then
    [[ "$INIT" != "$BASE" ]] || fail "$NAME: flatten kept the source head as the branch point"
  else
    [[ "$INIT" == "$BASE" ]] || fail "$NAME: full history moved the branch point"
  fi
  if ! git -C "$DST" merge-base --is-ancestor "$INIT" HEAD; then
    fail "$NAME: the branch point is not an ancestor of the change"
  fi
  git -C "$DST" config user.email "test@fixture"
  git -C "$DST" config user.name "Test Fixture"
  echo "agent change" > "$DST/agent.txt"
  git -C "$DST" add agent.txt
  git -C "$DST" commit -m "agent change" --quiet
  MATRIX_DIFF="$FIXTURE_DIR/$NAME.diff"
  git -C "$DST" diff --binary "$INIT" HEAD > "$MATRIX_DIFF"
  [[ -s "$MATRIX_DIFF" ]] || fail "$NAME: the diff from the branch point is empty"
}

# Given: a source repo and the four delivery entries
# When:  the same change is applied after each delivery
# Then:  every diff from the branch point is byte-identical
test_delivery_matrix_is_one_pipeline() {
  local copy_full copy_flat mount_full mount_flat

  run_matrix_case copy-full false
  copy_full="$MATRIX_DIFF"
  run_matrix_case copy-flatten true
  copy_flat="$MATRIX_DIFF"
  run_matrix_case mount-full false
  mount_full="$MATRIX_DIFF"
  run_matrix_case mount-flatten true
  mount_flat="$MATRIX_DIFF"

  cmp -s "$copy_full" "$copy_flat" || fail "copy full and copy flatten exported different diffs"
  cmp -s "$copy_full" "$mount_full" || fail "copy and mount full history exported different diffs"
  cmp -s "$copy_full" "$mount_flat" || fail "copy full and mount flatten exported different diffs"
  pass "the four delivery entries export the same diff from the branch point"
}

# Given: the change pipeline reference
# When:  the delivery matrix is read
# Then:  it names the parameter and the matrix
test_model_names_the_delivery_matrix() {
  local doc="$REPO_ROOT/docs/reference/change_pipeline.md"
  grep -q 'Delivery is a parameter of the agent lane' "$doc" || fail "the model does not name delivery as a parameter"
  grep -q 'test matrix runs the same transitions' "$doc" || fail "the model does not name the test matrix"
  pass "the model names the delivery parameter and the matrix"
}

run_test test_delivery_matrix_is_one_pipeline
run_test test_model_names_the_delivery_matrix

test_done "change pipeline delivery matrix"
