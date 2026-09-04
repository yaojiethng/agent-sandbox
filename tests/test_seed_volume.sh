#!/usr/bin/env bash
# tests/test_seed_volume.sh
# Helper-container seeder tests (src/capability/seed_volume.sh).
#
# Covers the ADR 2026-09-04 entry contract:
#   - guards fail closed: submodules, unborn HEAD, linked worktrees, tracked sentinel
#   - existence filter: unstaged deletions absent from the volume
#   - porcelain parity: staging state preserved; self-check detects induced divergence
#   - SESSION_STATE written by the seeder (init_sha = HEAD, session_id, session_ts)
#   - empty enumeration (everything tracked deleted, no untracked) skips the tar step
#
# The script is exercised both as a subprocess (full flow) and via sourced
# functions (verify_parity unit case). No docker involved: /src and /dest are
# local fixture directories.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"

SEED_SCRIPT="$REPO_ROOT/src/capability/seed_volume.sh"
LIBS_DIR="$REPO_ROOT/src/libs"

# run_seeder SRC DEST [extra env via caller]
# Runs the seeder as a subprocess against fixture dirs.
run_seeder() {
  local src="$1" dest="$2"
  SEED_SRC="$src" SEED_DEST="$dest" SEED_LIB_DIR="$LIBS_DIR" \
  SESSION_ID="testses" SESSION_TS="20260904-000000" HOST_HEAD_SHA="$(git -C "$src" rev-parse HEAD)" \
    bash "$SEED_SCRIPT" > /dev/null 2>&1
}

# make_rich_project DIR
# Committed repo exercising every parity dimension: staged + unstaged edits,
# staged new file, unstaged deletion, untracked file, negation patterns,
# symlink, exec bit, unicode name, ignored file.
make_rich_project() {
  local DIR="$1"
  make_committed_repo "$DIR"
  # committed.txt: staged edit (index differs from HEAD, worktree == index)
  echo "baseline line" > "$DIR/committed.txt"
  git -C "$DIR" add committed.txt
  git -C "$DIR" commit -q -m "add committed.txt"
  echo "staged edit" >> "$DIR/committed.txt"
  git -C "$DIR" add committed.txt
  # unstaged.txt: unstaged edit (worktree differs from index)
  # Pathspec-scoped commits: a plain `git commit` would sweep the previously
  # staged committed.txt edit into HEAD and destroy the fixture's staged state.
  echo "one" > "$DIR/unstaged.txt"
  git -C "$DIR" add unstaged.txt
  git -C "$DIR" commit -q -m "add unstaged.txt" -- unstaged.txt
  echo "two" >> "$DIR/unstaged.txt"
  # gone.txt: unstaged deletion
  echo "doomed" > "$DIR/gone.txt"
  git -C "$DIR" add gone.txt
  git -C "$DIR" commit -q -m "add gone.txt" -- gone.txt
  rm "$DIR/gone.txt"
  # staged new file (in index, not in HEAD)
  echo "staged new" > "$DIR/staged_new.txt"
  git -C "$DIR" add staged_new.txt
  # untracked + negation patterns + ignored content
  printf '*.log\n!keep.log\n' > "$DIR/.gitignore"
  echo "untracked data" > "$DIR/untracked.txt"
  mkdir -p "$DIR/nested dir"
  echo "unicode content" > "$DIR/nested dir/üñícode.txt"
  echo "dropped" > "$DIR/drop.log"
  echo "kept" > "$DIR/keep.log"
  # ignored file must not cross
  echo "secret data" > "$DIR/secret.env"
  printf 'secret.env\n' >> "$DIR/.gitignore"
  # symlink + exec bit
  ln -s committed.txt "$DIR/link.txt"
  echo "#!/bin/sh" > "$DIR/run.sh"
  chmod +x "$DIR/run.sh"
}

# -------------------------
# Guard tests (fail closed)
# -------------------------

test_seeder_rejects_submodule() {
  local proj="$FIXTURE_DIR/sub_project"
  make_committed_repo "$proj"
  local tree
  tree=$(git -C "$proj" hash-object -w -t tree /dev/null)
  git -C "$proj" update-index --add --cacheinfo "160000,$tree,sub" 2>/dev/null
  local dest="$FIXTURE_DIR/sub_dest"
  mkdir -p "$dest"
  if run_seeder "$proj" "$dest"; then
    fail "seeder: submodule repo rejected"
  else
    pass "seeder: submodule repo rejected"
  fi
}

test_seeder_rejects_unborn_head() {
  local proj="$FIXTURE_DIR/unborn_project"
  make_repo "$proj"
  local dest="$FIXTURE_DIR/unborn_dest"
  mkdir -p "$dest"
  if run_seeder "$proj" "$dest"; then
    fail "seeder: unborn HEAD rejected"
  else
    pass "seeder: unborn HEAD rejected"
  fi
}

test_seeder_rejects_linked_worktree() {
  local proj="$FIXTURE_DIR/wt_project"
  make_committed_repo "$proj"
  git -C "$proj" worktree add "$FIXTURE_DIR/wt_linked" --quiet 2>/dev/null
  local dest="$FIXTURE_DIR/wt_dest"
  mkdir -p "$dest"
  if run_seeder "$FIXTURE_DIR/wt_linked" "$dest"; then
    fail "seeder: linked worktree rejected"
  else
    pass "seeder: linked worktree rejected"
  fi
}

test_seeder_rejects_tracked_sentinel() {
  local proj="$FIXTURE_DIR/sentinel_project"
  make_committed_repo "$proj"
  mkdir -p "$proj/.agent-sandbox-seed/worktree"
  echo "stale payload" > "$proj/.agent-sandbox-seed/worktree/stale.txt"
  git -C "$proj" add .agent-sandbox-seed
  git -C "$proj" commit -q -m "accidental harness staging"
  local dest="$FIXTURE_DIR/sentinel_dest"
  mkdir -p "$dest"
  if run_seeder "$proj" "$dest"; then
    fail "seeder: tracked sentinel rejected"
  else
    pass "seeder: tracked sentinel rejected"
  fi
}

# -------------------------
# Happy path: porcelain parity
# -------------------------

test_seeder_parity_preserves_everything() {
  local proj="$FIXTURE_DIR/rich_project"
  local dest="$FIXTURE_DIR/rich_dest"
  make_rich_project "$proj"
  mkdir -p "$dest"
  if ! run_seeder "$proj" "$dest"; then
    fail "seeder: rich project seeds successfully"
    return 0
  fi
  pass "seeder: rich project seeds successfully"

  local status
  status=$(git -C "$dest" status --porcelain)

  # Staged edit stays staged (the porcelain guarantee: "M " not " M")
  echo "$status" | grep -q '^M  committed\.txt$' \
    && pass "parity: staged edit stays staged" \
    || fail "parity: staged edit should be 'M  committed.txt', got: $(echo "$status" | grep committed)"

  # Staged new file stays staged
  echo "$status" | grep -q '^A  staged_new\.txt$' \
    && pass "parity: staged new file stays staged" \
    || fail "parity: staged new file should be 'A  staged_new.txt'"

  # Unstaged edit stays unstaged
  echo "$status" | grep -q '^ M unstaged\.txt$' \
    && pass "parity: unstaged edit shows ' M'" \
    || fail "parity: unstaged edit should show ' M'"

  # Unstaged deletion visible
  echo "$status" | grep -q '^ D gone\.txt$' \
    && pass "parity: unstaged deletion shows ' D'" \
    || fail "parity: unstaged deletion should show ' D'"

  # Untracked file + unicode name present
  [[ -f "$dest/untracked.txt" && -f "$dest/nested dir/üñícode.txt" ]] \
    && pass "parity: untracked content crosses" \
    || fail "parity: untracked content missing from volume"

  # Negation: keep.log crosses, drop.log and ignored secret do not
  [[ -f "$dest/keep.log" && ! -f "$dest/drop.log" && ! -f "$dest/secret.env" ]] \
    && pass "parity: negation patterns honored, ignored content absent" \
    || fail "parity: ignore resolution wrong (keep.log/drop.log/secret.env)"

  # Symlink target + exec bit preserved
  [[ "$(readlink "$dest/link.txt")" == "committed.txt" ]] \
    && pass "parity: symlink target preserved" \
    || fail "parity: symlink target wrong: $(readlink "$dest/link.txt")"
  [[ -x "$dest/run.sh" ]] \
    && pass "parity: exec bit preserved" \
    || fail "parity: exec bit lost"

  # SESSION_STATE: init_sha = HEAD, identity keys present
  local head_sha
  head_sha=$(git -C "$proj" rev-parse HEAD)
  grep -q "^init_sha=$head_sha$" "$dest/.git/SESSION_STATE" \
    && pass "session state: init_sha equals HEAD" \
    || fail "session state: init_sha mismatch"
  grep -q "^session_id=testses$" "$dest/.git/SESSION_STATE" \
    && pass "session state: session_id written" \
    || fail "session state: session_id missing"

  # Direct parity assertion (what the seeder's self-check enforces)
  if diff <(git -C "$proj" status --porcelain=v1 -uall | sort) \
          <(git -C "$dest" status --porcelain=v1 -uall | sort) > /dev/null; then
    pass "parity: git status porcelain-identical between source and volume"
  else
    fail "parity: git status diverges between source and volume"
  fi
}

# -------------------------
# Self-check: induced divergence is detected
# -------------------------

test_seeder_parity_fail_detected() {
  local proj="$FIXTURE_DIR/corrupt_project"
  local dest="$FIXTURE_DIR/corrupt_dest"
  make_committed_repo "$proj"
  mkdir -p "$dest"
  run_seeder "$proj" "$dest" || { fail "seeder: clean project seeds"; return 0; }
  # Induce divergence after the seed: tamper with volume content
  echo "tampered" > "$dest/file.txt"
  # Subshell: the script sets -e for itself; the test shell must not inherit it.
  # shellcheck disable=SC1090  # path is a repo-relative variable by design
  if ( SEED_VOLUME_NO_MAIN=1 source "$SEED_SCRIPT"; verify_parity "$proj" "$dest" ) 2>/dev/null; then
    fail "self-check: induced divergence detected"
  else
    pass "self-check: induced divergence detected"
  fi
}

# -------------------------
# Empty enumeration: tracked file deleted, nothing untracked
# -------------------------

test_seeder_empty_enumeration() {
  local proj="$FIXTURE_DIR/empty_project"
  local dest="$FIXTURE_DIR/empty_dest"
  make_committed_repo "$proj"
  rm "$proj/file.txt"
  mkdir -p "$dest"
  if run_seeder "$proj" "$dest"; then
    pass "seeder: empty enumeration (deleted-only worktree) seeds"
  else
    fail "seeder: empty enumeration should skip the tar step and succeed"
    return 0
  fi
  if git -C "$dest" status --porcelain | grep -q '^ D file\.txt$'; then
    pass "parity: deletion visible in seeded volume"
  else
    fail "parity: deletion should show as ' D file.txt'"
  fi
}

# -------------------------
# Registration
# -------------------------

run_test test_seeder_rejects_submodule
run_test test_seeder_rejects_unborn_head
run_test test_seeder_rejects_linked_worktree
run_test test_seeder_rejects_tracked_sentinel
run_test test_seeder_parity_preserves_everything
run_test test_seeder_parity_fail_detected
run_test test_seeder_empty_enumeration

test_done
