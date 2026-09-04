#!/usr/bin/env bash
# Tests for libs/package_branch.sh  --  dispatcher produces unified output format
#
# Expected output layout (under OUTPUT_DIR/):
#   patches/0001-<sha>.diff
#   patches/0002-<sha>.diff
#   ...
#   uncommitted.diff
#   all-changes.diff
#   changed-files/MANIFEST.txt
#   changed-files/<path>/<file>
#   .export-status

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/package_branch.sh"

# -------------------------------------------------------------------
# Helper: create a sandbox with a specific init SHA as session_ts
# Compared to make_sandbox_fixture, this overwrites session_ts with the
# actual commit SHA rather than using a fixed timestamp.
make_sandbox_with_state() {
  local DIR="$1"
  make_sandbox_fixture "$DIR" > /dev/null
  local SHA
  SHA=$(get_init_sha "$DIR")
  write_session_state "$DIR" "$SHA"
  echo "$SHA"
}

# -------------------------------------------------------------------
# Helper: create one or more commits in the sandbox
# -------------------------------------------------------------------
commit_file() {
  local DIR="$1"
  local FILE="$2"
  local CONTENT="${3:-file content}"
  mkdir -p "$(dirname "$DIR/$FILE")"
  echo "$CONTENT" > "$DIR/$FILE"
  git -C "$DIR" add "$FILE"
  git -C "$DIR" commit -m "add $FILE" --quiet
}

# -------------------------------------------------------------------
# Helper: add a binary file to a sandbox (1500 bytes of known pattern)
# -------------------------------------------------------------------
commit_binary() {
  local DIR="$1"
  local FILE="$2"
  mkdir -p "$(dirname "$DIR/$FILE")"
  printf '\x00\x01\x02%.0s' $(seq 1 500) > "$DIR/$FILE"
  git -C "$DIR" add "$FILE"
  git -C "$DIR" commit -m "add binary $FILE" --quiet
}

# ===================================================================
# package_branch produces the unified output layout
# ===================================================================

test_dispatcher_creates_all_artefacts() {
  local DIR="$FIXTURE_DIR/pb_allartefacts"
  local OUT="$FIXTURE_DIR/pb_allartefacts_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"
  commit_file "$DIR" "b.txt"

  package_branch "$DIR" "$OUT"

  local ALL_OK=true
  local HAS_P1=false HAS_P2=false
  ls "$OUT/patches/0001-"*.diff >/dev/null 2>&1 && HAS_P1=true
  ls "$OUT/patches/0002-"*.diff >/dev/null 2>&1 && HAS_P2=true
  [[ -d "$OUT/patches" && "$HAS_P1" == true && "$HAS_P2" == true ]] || ALL_OK=false
  [[ -f "$OUT/uncommitted.diff" ]] || ALL_OK=false
  [[ -f "$OUT/all-changes.diff" ]] || ALL_OK=false
  [[ -d "$OUT/changed-files" && -f "$OUT/changed-files/a.txt" && -f "$OUT/changed-files/b.txt" ]] || ALL_OK=false
  [[ -f "$OUT/changed-files/MANIFEST.txt" && -s "$OUT/changed-files/MANIFEST.txt" ]] || ALL_OK=false
  [[ -f "$OUT/.export-status" && -s "$OUT/.export-status" ]] || ALL_OK=false

  if [[ "$ALL_OK" == true ]]; then
    pass "package_branch creates all 6 artefact types (patches/, uncommitted.diff, all-changes.diff, changed-files/, MANIFEST.txt, .export-status)"
  else
    fail "package_branch missing one or more artefact types"
  fi
}

test_dispatcher_diffs_numbered() {
  local DIR="$FIXTURE_DIR/pb_numbered"
  local OUT="$FIXTURE_DIR/pb_numbered_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"
  commit_file "$DIR" "b.txt"
  commit_file "$DIR" "c.txt"

  package_branch "$DIR" "$OUT"

  local COUNT
  COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)

  if [[ "$COUNT" -eq 3 ]] && ls "$OUT/patches/0001-"*.diff >/dev/null 2>&1 \
     && ls "$OUT/patches/0002-"*.diff >/dev/null 2>&1 \
     && ls "$OUT/patches/0003-"*.diff >/dev/null 2>&1; then
    pass "package_branch produces 3 numbered diffs with 0001-, 0002-, 0003- prefix"
  else
    fail "package_branch should produce 3 numbered diffs with correct prefix, got $COUNT"
  fi
}

test_dispatcher_overwrites_output() {
  local DIR="$FIXTURE_DIR/pb_overwrite"
  local OUT="$FIXTURE_DIR/pb_overwrite_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"

  package_branch "$DIR" "$OUT"

  local FIRST_COUNT
  FIRST_COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)

  commit_file "$DIR" "b.txt"
  package_branch "$DIR" "$OUT"

  local SECOND_COUNT
  SECOND_COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)

  if [[ "$SECOND_COUNT" -eq 2 ]] && [[ "$FIRST_COUNT" -eq 1 ]]; then
    pass "package_branch overwrites: 1 diff first run, 2 diffs second run"
  else
    fail "package_branch should overwrite output, got $FIRST_COUNT then $SECOND_COUNT"
  fi
}

test_dispatcher_diff_is_applicable() {
  local DIR="$FIXTURE_DIR/pb_apply"
  local OUT="$FIXTURE_DIR/pb_apply_out"
  local TARGET="$FIXTURE_DIR/pb_apply_target"
  mkdir -p "$OUT" "$TARGET"
  make_sandbox_with_state "$DIR"

  # Modify the committed baseline file (file.txt) and commit the change
  echo "modified content" > "$DIR/file.txt"
  git -C "$DIR" add file.txt
  git -C "$DIR" commit -m "modify file.txt" --quiet

  package_branch "$DIR" "$OUT"

  # Init target repo with same baseline file, then apply the modification patch
  git -C "$TARGET" init --quiet
  git -C "$TARGET" config user.email "t@t"
  git -C "$TARGET" config user.name "t"
  echo "baseline" > "$TARGET/file.txt"
  git -C "$TARGET" add file.txt
  git -C "$TARGET" commit -m "baseline" --quiet

  if git -C "$TARGET" apply --ignore-whitespace < <(strip_index_lines < "$OUT/patches/0001-"*.diff) 2>/dev/null; then
    pass "diff produced by package_branch applies via git apply"
  else
    fail "diff produced by package_branch does not apply via git apply"
  fi
}

test_dispatcher_diff_contains_content() {
  local DIR="$FIXTURE_DIR/pb_content"
  local OUT="$FIXTURE_DIR/pb_content_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt" "unique-content"

  package_branch "$DIR" "$OUT"

  if grep -q "unique-content" "$OUT/patches/"*.diff 2>/dev/null; then
    pass "diff contains expected file content"
  else
    fail "diff should contain expected file content"
  fi
}

test_dispatcher_strips_text_index_keeps_binary_index() {
  local DIR="$FIXTURE_DIR/pb_index"
  local OUT="$FIXTURE_DIR/pb_index_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"
  commit_binary "$DIR" "data.bin"

  package_branch "$DIR" "$OUT"

  # Text diff should NOT have index line
  local TEXT_HAS_INDEX
  TEXT_HAS_INDEX=$(grep -c '^index ' "$OUT/patches/0001-"*.diff 2>/dev/null || true)

  # Binary diff should HAVE index line (for GIT binary patch)
  local BINARY_HAS_INDEX
  BINARY_HAS_INDEX=$(grep -c '^index ' "$OUT/patches/0002-"*.diff 2>/dev/null || true)

  if [[ "$TEXT_HAS_INDEX" -eq 0 ]] && [[ "$BINARY_HAS_INDEX" -eq 1 ]]; then
    pass "package_branch strips index from text diffs, keeps index for binary diffs"
  else
    fail "package_branch: text index=$TEXT_HAS_INDEX (want 0), binary index=$BINARY_HAS_INDEX (want 1)"
  fi
}

test_dispatcher_binary_patch_applies_to_fresh_repo() {
  local DIR="$FIXTURE_DIR/pb_binaryapply"
  local OUT="$FIXTURE_DIR/pb_binaryapply_out"
  local TARGET="$FIXTURE_DIR/pb_binaryapply_target"
  mkdir -p "$OUT" "$TARGET"
  make_sandbox_with_state "$DIR"

  # Create a binary baseline (file.txt is the committed baseline), then modify it
  printf '\x00\x01\x02%.0s' $(seq 1 500) > "$DIR/file.txt"
  git -C "$DIR" add file.txt
  git -C "$DIR" commit -m "baseline binary" --quiet

  # Modify the binary to a different pattern and commit
  printf '\xff\xfe\xfd%.0s' $(seq 1 500) > "$DIR/file.txt"
  git -C "$DIR" add file.txt
  git -C "$DIR" commit -m "modify binary" --quiet

  package_branch "$DIR" "$OUT"

  # Init target repo with same initial binary content
  git -C "$TARGET" init --quiet
  git -C "$TARGET" config user.email "t@t"
  git -C "$TARGET" config user.name "t"
  printf '\x00\x01\x02%.0s' $(seq 1 500) > "$TARGET/file.txt"
  git -C "$TARGET" add file.txt
  git -C "$TARGET" commit -m "init" --quiet

  # Apply using strip_index_lines (as draft_run now does)
  if git -C "$TARGET" apply --ignore-whitespace < <(strip_index_lines < "$OUT/patches/0002-"*.diff) 2>/dev/null; then
    pass "binary diff from package_branch applies to fresh repo via strip_index_lines"
  else
    fail "binary diff from package_branch should apply to fresh repo"
  fi
}

test_dispatcher_includes_untracked_in_changed_files() {
  local DIR="$FIXTURE_DIR/pb_untracked"
  local OUT="$FIXTURE_DIR/pb_untracked_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  echo "untracked content" > "$DIR/untracked.txt"

  package_branch "$DIR" "$OUT"

  if [[ -f "$OUT/changed-files/untracked.txt" ]]; then
    pass "package_branch includes untracked file in changed-files/"
  else
    fail "package_branch should include untracked file in changed-files/"
  fi
}

test_dispatcher_no_commits() {
  local DIR="$FIXTURE_DIR/pb_none"
  local OUT="$FIXTURE_DIR/pb_none_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"

  package_branch "$DIR" "$OUT"

  local PATCH_COUNT
  PATCH_COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)
  if [[ "$PATCH_COUNT" -eq 0 ]]; then
    pass "package_branch produces no diffs when no commits"
  else
    fail "package_branch should produce 0 diffs when no commits, got $PATCH_COUNT"
  fi
}

test_dispatcher_missing_args() {
  if package_branch "" "" 2>/dev/null; then
    fail "package_branch should fail with missing args"
  else
    pass "package_branch fails with missing args"
  fi
}

test_dispatcher_missing_session_state() {
  local DIR="$FIXTURE_DIR/pb_nostate"
  local OUT="$FIXTURE_DIR/pb_nostate_out"
  mkdir -p "$OUT"
  make_committed_repo "$DIR"
  # Intentionally do NOT write SESSION_STATE

  if package_branch "$DIR" "$OUT" 2>/dev/null; then
    fail "package_branch should fail when SESSION_STATE is missing"
  else
    pass "package_branch fails when SESSION_STATE is missing"
  fi

  # Verify no artefacts were written (OUTPUT_DIR may have been created
  # by package_branch's mkdir -p, but patches/ and diff files should be absent)
  local HAS_PATCHES=false HAS_DIFFS=false
  [[ -d "$OUT/patches" ]] && HAS_PATCHES=true
  [[ -f "$OUT/uncommitted.diff" || -f "$OUT/all-changes.diff" ]] && HAS_DIFFS=true
  if [[ "$HAS_PATCHES" == false && "$HAS_DIFFS" == false ]]; then
    pass "package_branch produces no artefacts when SESSION_STATE is missing"
  else
    fail "package_branch should produce no artefacts when SESSION_STATE is missing"
  fi
}

test_dispatcher_export_status_contents() {
  local DIR="$FIXTURE_DIR/pb_es_content"
  local OUT="$FIXTURE_DIR/pb_es_content_out"
  mkdir -p "$OUT"
  local INIT_SHA
  INIT_SHA=$(make_sandbox_with_state "$DIR")
  commit_file "$DIR" "a.txt"

  package_branch "$DIR" "$OUT"

  local ES="$OUT/.export-status"
  local ALL_OK=true
  grep -q '^STATUS=SUCCESS$' "$ES" || ALL_OK=false
  grep -q '^TIMESTAMP=' "$ES" || ALL_OK=false
  grep -q "^INIT_SHA=${INIT_SHA}$" "$ES" || ALL_OK=false

  if [[ "$ALL_OK" == true ]]; then
    pass "package_branch writes .export-status with STATUS, TIMESTAMP, INIT_SHA"
  else
    fail "package_branch .export-status missing expected fields"
  fi
}

# =============================================================================
# _package_preflight_check  --  warning-branch coverage
# =============================================================================

test_preflight_bypass_returns_before_any_git() {
  # Bypass must short-circuit BEFORE touching git: a nonexistent dir proves it.
  local OUT RC=0
  OUT=$(PACKAGE_BYPASS_PREFLIGHT=true \
    _package_preflight_check "$FIXTURE_DIR/does-not-exist" "deadbeef" 2>&1 </dev/null) || RC=$?
  if [[ $RC -eq 0 && -z "$OUT" ]]; then
    pass "preflight: PACKAGE_BYPASS_PREFLIGHT=true short-circuits before git access"
  else
    fail "bypass should be silent rc0, got rc=$RC out='$OUT'"
  fi
}

test_preflight_clean_tree_is_silent() {
  local P="$FIXTURE_DIR/pf_clean"
  make_committed_repo "$P"
  local INIT; INIT=$(git -C "$P" rev-parse HEAD)

  local OUT RC=0
  OUT=$(_package_preflight_check "$P" "$INIT" 2>&1 </dev/null) || RC=$?
  if [[ $RC -eq 0 && -z "$OUT" ]]; then
    pass "preflight: no changes since baseline -> silent success"
  else
    fail "clean tree should be silent, rc=$RC out='$OUT'"
  fi
}

test_preflight_flags_uncommitted_modifications() {
  local P="$FIXTURE_DIR/pf_dirty"
  make_committed_repo "$P"
  local INIT; INIT=$(git -C "$P" rev-parse HEAD)
  echo committed-change > "$P/file.txt"
  git -C "$P" commit -qam c2
  echo dirty-working-tree >> "$P/file.txt"

  local OUT RC=0
  OUT=$(_package_preflight_check "$P" "$INIT" 2>&1 </dev/null) || RC=$?
  if [[ $RC -eq 0 && "$OUT" == *"uncommitted modifications"* \
     && "$OUT" == *"flagged potential patch divergence"* ]]
  then
    pass "preflight: dirty working tree flagged with bypass hint, still rc0 (advisory)"
  else
    fail "dirty-tree flagging broken: rc=$RC out='$OUT'"
  fi
}

test_preflight_flags_cancelled_out_modification() {
  # Reachable path into the 'identical content' advisory: a committed change
  # whose working tree was reverted back to baseline content (uncommitted).
  # The file appears in the INIT..HEAD diff, yet `git diff --quiet $INIT -- f`
  # (INIT tree vs WORKING TREE  --  note: the code comment claims HEAD, it is
  # actually the worktree) finds them identical -> flagged.
  local P="$FIXTURE_DIR/pf_cancel"
  make_committed_repo "$P"
  local BASE_CONTENT; BASE_CONTENT=$(cat "$P/file.txt")
  echo changed > "$P/file.txt"
  git -C "$P" commit -qam c2
  printf '%s\n' "$BASE_CONTENT" > "$P/file.txt"
  local INIT; INIT=$(git -C "$P" rev-parse HEAD~1)

  local OUT RC=0
  OUT=$(_package_preflight_check "$P" "$INIT" 2>&1 </dev/null) || RC=$?
  if [[ $RC -eq 0 && "$OUT" == *"identical content at"* ]]; then
    pass "preflight: committed-then-worktree-reverted change hits identical-content advisory"
  else
    fail "cancelled-modification branch broken: rc=$RC out='$OUT'"
  fi
}

test_preflight_skips_deleted_files_without_warning() {
  # With rename detection disabled the diff lists BOTH rename sides; the old
  # name is gone from HEAD and must be skipped silently (no uncommitted/
  # identical-content warnings for it).
  local P="$FIXTURE_DIR/pf_renamed"
  make_committed_repo "$P"
  git -C "$P" config diff.renames false
  git -C "$P" mv file.txt renamed.txt
  git -C "$P" commit -qm rename
  local INIT; INIT=$(git -C "$P" rev-parse HEAD~1)

  local OUT RC=0
  OUT=$(_package_preflight_check "$P" "$INIT" 2>&1 </dev/null) || RC=$?
  if [[ $RC -eq 0 && "$OUT" != *"file.txt"* ]]
  then
    pass "preflight: deleted side of a rename skipped without warnings"
  else
    fail "deleted-file skip broken: rc=$RC out='$OUT'"
  fi
}

# =============================================================================
# Run
# =============================================================================
run_test test_dispatcher_creates_all_artefacts
run_test test_dispatcher_diffs_numbered
run_test test_dispatcher_overwrites_output
run_test test_dispatcher_diff_is_applicable
run_test test_dispatcher_diff_contains_content
run_test test_dispatcher_strips_text_index_keeps_binary_index
run_test test_dispatcher_binary_patch_applies_to_fresh_repo
run_test test_dispatcher_includes_untracked_in_changed_files
run_test test_dispatcher_no_commits
run_test test_dispatcher_missing_args
run_test test_dispatcher_missing_session_state
run_test test_dispatcher_export_status_contents
run_test test_preflight_bypass_returns_before_any_git
run_test test_preflight_clean_tree_is_silent
run_test test_preflight_flags_uncommitted_modifications
run_test test_preflight_flags_cancelled_out_modification
run_test test_preflight_skips_deleted_files_without_warning

test_done
