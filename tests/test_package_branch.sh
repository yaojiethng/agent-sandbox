#!/usr/bin/env bash
# Tests for libs/package_branch.sh  --  dispatcher produces unified output format
#
# Expected output layout (under OUTPUT_DIR/):
#   patches/0001-<sha>.diff
#   patches/0001-<sha>.msg
#   patches/0002-<sha>.diff
#   patches/0002-<sha>.msg
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

# Given: a sandbox with SESSION_STATE and two commits
# When:  package_branch runs
# Then:  patches/ holds 0001- and 0002-, uncommitted.diff and all-changes.diff exist, changed-files/ holds both copies plus a non-empty MANIFEST.txt, and .export-status is non-empty
# Asserts: the six artefact types land; the .msg siblings are absent from this list (finding 82)
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

# Given: three commits after the baseline
# When:  package_branch runs
# Then:  exactly three diffs, prefixed 0001-, 0002-, 0003-
# Asserts: the per-commit numbering and zero padding
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

# Given: two commits after the baseline
# When:  package_branch runs
# Then:  each patch has a non-empty sibling .msg holding that commit's message
# Asserts: the host-consumed .msg artefact, which the bundle layout documents but no unit covered.
test_dispatcher_writes_msg_per_patch() {
  local DIR="$FIXTURE_DIR/pb_msg"
  local OUT="$FIXTURE_DIR/pb_msg_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "alpha.txt" "alpha content"
  commit_file "$DIR" "beta.txt" "beta content"

  package_branch "$DIR" "$OUT"

  local MSG_COUNT MISSING ALL_OK=true
  MSG_COUNT=$(ls "$OUT/patches/"*.msg 2>/dev/null | wc -l)
  MISSING=0
  local PATCH
  for PATCH in "$OUT/patches/"*.diff; do
    [[ -s "${PATCH%.diff}.msg" ]] || MISSING=$((MISSING + 1))
  done
  [[ "$MSG_COUNT" -eq 2 && "$MISSING" -eq 0 ]] || ALL_OK=false
  grep -q "add alpha.txt" "$OUT/patches/0001-"*.msg 2>/dev/null || ALL_OK=false

  if [[ "$ALL_OK" == true ]]; then
    pass "package_branch writes one non-empty .msg per patch with the commit message"
  else
    fail "package_branch .msg artefacts wrong: count=$MSG_COUNT missing=$MISSING"
  fi
}

# Given: one commit, then a second run after a further commit
# When:  package_branch runs twice
# Then:  the patch count is 1, then 2
# Asserts: a second run replaces the first for patches/ only; stale copies elsewhere are not checked (finding 83)
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

# Given: two changed files packaged once, then the second change dropped
# When:  package_branch runs again with a smaller change set
# Then:  changed-files/ no longer holds the dropped file's stale copy
# Asserts: the dispatcher's OUTPUT_DIR wipe owns the changed-files/ directory.
test_dispatcher_overwrite_clears_stale_changed_files() {
  local DIR="$FIXTURE_DIR/pb_stale"
  local OUT="$FIXTURE_DIR/pb_stale_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"
  commit_file "$DIR" "b.txt"

  package_branch "$DIR" "$OUT"
  if [[ ! -f "$OUT/changed-files/b.txt" ]]; then
    fail "setup: first run did not copy b.txt into changed-files/"
    return
  fi

  git -C "$DIR" reset --hard HEAD~1 --quiet
  package_branch "$DIR" "$OUT"

  if [[ -f "$OUT/changed-files/a.txt" && ! -e "$OUT/changed-files/b.txt" ]]; then
    pass "a second package_branch run drops the stale changed-files copy"
  else
    fail "stale changed-files copy survived the second run"
  fi
}

# Given: a committed change whose working tree is modified further
# When:  package_branch runs
# Then:  stderr carries the preflight divergence warning
# Asserts: the dispatcher wires the advisory preflight into its run.
test_dispatcher_runs_preflight_check() {
  local DIR="$FIXTURE_DIR/pb_preflight"
  local OUT="$FIXTURE_DIR/pb_preflight_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  commit_file "$DIR" "a.txt"
  echo "dirty working tree" >> "$DIR/a.txt"

  local ERR="$FIXTURE_DIR/pb_preflight.err"
  package_branch "$DIR" "$OUT" 2>"$ERR"

  if grep -q "uncommitted modifications" "$ERR" 2>/dev/null; then
    pass "package_branch runs the preflight and reports the divergence warning"
  else
    fail "package_branch did not run the preflight check"
  fi
}

# Given: a commit whose subject carries whitespace
# When:  package_branch runs
# Then:  the patch filename replaces the whitespace with underscores
# Asserts: the subject sanitisation that keeps the filename a single path token.
test_dispatcher_sanitises_commit_subject_filename() {
  local DIR="$FIXTURE_DIR/pb_subject"
  local OUT="$FIXTURE_DIR/pb_subject_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"
  echo "content" > "$DIR/a.txt"
  git -C "$DIR" add a.txt
  git -C "$DIR" commit -m "feat: add spaced subject" --quiet

  package_branch "$DIR" "$OUT"

  local PATCH BASE
  PATCH=$(ls "$OUT/patches/"*.diff 2>/dev/null | head -1)
  BASE=$(basename "$PATCH")
  if [[ -n "$PATCH" && "$BASE" != *" "* && "$BASE" == *"add_spaced_subject"* ]]; then
    pass "package_branch sanitises the commit subject into the patch filename"
  else
    fail "patch filename not sanitised: '$BASE'"
  fi
}

# Given: a committed modification to file.txt
# When:  the produced patch is applied to a fresh repo holding the baseline
# Then:  git apply --ignore-whitespace succeeds
# Asserts: the stripped patch applies, so its context matches the baseline
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

# Given: a commit adding a file whose content is the unique string unique-content
# When:  package_branch runs
# Then:  the patch text contains that string
# Asserts: the patch carries the change body, not only the header
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

# Given: a text commit and a binary commit
# When:  package_branch runs
# Then:  the text patch has zero index lines and the binary patch has one
# Asserts: the binary arm of strip_index_lines, where the index line is required by the binary patch format
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

# Given: a committed binary modification
# When:  the patch is applied to a fresh repo after strip_index_lines
# Then:  git apply succeeds
# Asserts: the binary round trip, which needs --binary in the per-commit diff (bite B8)
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

# Given: an untracked file in the sandbox
# When:  package_branch runs
# Then:  changed-files/ holds a copy of it
# Asserts: untracked files reach the changed-files tree
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

# Given: a sandbox whose HEAD is the baseline
# When:  package_branch runs
# Then:  zero patch files
# Asserts: the empty-commit-range early return
test_dispatcher_no_commits() {
  local DIR="$FIXTURE_DIR/pb_none"
  local OUT="$FIXTURE_DIR/pb_none_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR"

  package_branch "$DIR" "$OUT"

  local PATCH_COUNT
  PATCH_COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)
  assert_eq_num "$PATCH_COUNT" "0" "package_branch produces no diffs when no commits"
}

# Given: empty SANDBOX_DIR and OUTPUT_DIR
# When:  package_branch runs
# Then:  rc is non-zero
# Asserts: the required-argument guard
test_dispatcher_missing_args() {
  if package_branch "" "" 2>/dev/null; then
    fail "package_branch should fail with missing args"
  else
    pass "package_branch fails with missing args"
  fi
}

# Given: a committed repo with no SESSION_STATE
# When:  package_branch runs
# Then:  rc is non-zero, and neither patches/ nor the two repository diffs are written
# Asserts: a baseline-resolution failure aborts before any artefact
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

# Given: a sandbox with state and one commit
# When:  package_branch runs
# Then:  .export-status holds STATUS=SUCCESS, a TIMESTAMP and the resolved INIT_SHA, and no HEAD line
# Asserts: the status-field split between package_branch and diff_export, pinned after the field list was wrong three times
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

  # package_branch does not stamp HEAD; diff_export does, because only the
  # export path knows the commit it captured. Docs that bundle the two writers
  # into one field list have been wrong three times, so pin the distinction.
  if grep -q '^HEAD=' "$ES"; then
    fail "package_branch should not stamp HEAD (diff_export owns that field)"
  else
    pass "package_branch leaves HEAD to the diff_export caller"
  fi
}

# =============================================================================
# _package_preflight_check  --  warning-branch coverage
# =============================================================================

# Given: PACKAGE_BYPASS_PREFLIGHT=true and a nonexistent sandbox dir
# When:  the preflight runs
# Then:  rc 0 and no output
# Asserts: silence on the bypass path; it does not prove the return precedes git (bite B4 survives, row 8)
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

# Given: a repo with no changes since the baseline
# When:  the preflight runs
# Then:  rc 0 and no output
# Asserts: the clean-tree case is silent
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

# Given: a committed change plus a dirty working tree
# When:  the preflight runs
# Then:  the uncommitted-modification warning and the bypass hint appear, rc 0
# Asserts: the advisory stays non-blocking while naming the remedy
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

# Given: a committed change reverted in the working tree
# When:  the preflight runs
# Then:  the identical-content advisory appears
# Asserts: the worktree comparison; the unit's own comment records that the code comment says HEAD while the code reads the worktree (row 12)
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

# Given: a rename committed with rename detection off
# When:  the preflight runs
# Then:  no warning names the deleted old path
# Asserts: the deleted-file skip; the skip is result-redundant because both checks already come out quiet (bite B6)
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
run_test test_dispatcher_writes_msg_per_patch
run_test test_dispatcher_sanitises_commit_subject_filename
run_test test_dispatcher_overwrites_output
run_test test_dispatcher_overwrite_clears_stale_changed_files
run_test test_dispatcher_runs_preflight_check
run_test test_dispatcher_diff_is_applicable
run_test test_dispatcher_diff_contains_content
run_test test_dispatcher_strips_text_index_keeps_binary_index
run_test test_dispatcher_binary_patch_applies_to_fresh_repo
run_test test_dispatcher_includes_untracked_in_changed_files
run_test test_dispatcher_no_commits
# Given: a repository whose .git/index is garbage
# When:  package_branch runs
# Then:  rc is non-zero and no .export-status is written
# Asserts: the refuse-state guard catches an unreadable object store
test_dispatcher_refuses_unreadable_object_store() {
  # A truncated blob is an unreadable object store the index probe passes:
  # `git status --porcelain` returns 0 while the per-commit diff would return
  # 128, so the run would proceed and degrade to a partial-artifact SUCCESS.
  # The guard's `git fsck --no-dangling` probe must refuse it.
  local DIR="$FIXTURE_DIR/pb_blob"
  local OUT="$FIXTURE_DIR/pb_blob_out"
  mkdir -p "$OUT"
  make_committed_repo "$DIR"
  write_session_state "$DIR"

  local blob
  blob="$(git -C "$DIR" rev-parse HEAD:file.txt)"
  local d="${blob:0:2}" f="${blob:2}"
  local obj="$DIR/.git/objects/$d/$f"
  # Loose objects are read-only (0444); make it writable so the truncation
  # actually lands, then rewrite it short so git fsck reports it corrupt.
  chmod u+w "$obj"
  printf 'truncated' > "$obj"

  if package_branch "$DIR" "$OUT" 2>/dev/null; then
    fail "package_branch should refuse a repository whose object store is unreadable"
  else
    pass "package_branch refuses an unreadable object store"
  fi
  if [[ -f "$OUT/.export-status" ]]; then
    fail "package_branch wrote export metadata for a refused object store"
  else
    pass "package_branch writes no metadata when the object store is unreadable"
  fi
}

# Asserts: the refuse-state guard for the index case
test_dispatcher_refuses_unreadable_repository() {
  # A corrupt index degrades every git command below to empty output while this
  # function still reports success, so the caller would stamp a SUCCESS bundle
  # over the last good one. The save decision routes its undeterminable case
  # into this function, so it must refuse the state.
  local DIR="$FIXTURE_DIR/pb_corrupt"
  local OUT="$FIXTURE_DIR/pb_corrupt_out"
  mkdir -p "$OUT"
  make_committed_repo "$DIR"
  write_session_state "$DIR"
  printf 'garbage' > "$DIR/.git/index"

  if package_branch "$DIR" "$OUT" 2>/dev/null; then
    fail "package_branch should refuse a repository whose index is unreadable"
  else
    pass "package_branch refuses an unreadable repository"
  fi
  if [[ -f "$OUT/.export-status" ]]; then
    fail "package_branch wrote export metadata for a refused repository"
  else
    pass "package_branch writes no metadata when it refuses"
  fi
}

# Given: an explicit baseline two commits back
# When:  package_branch runs
# Then:  two patches and INIT_SHA equal to that baseline
# Asserts: the explicit baseline wins; the cat-file validation of it is untested (finding 85)
test_baseline_explicit_override() {
  local DIR="$FIXTURE_DIR/pb_base_arg"
  local OUT="$FIXTURE_DIR/pb_base_arg_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR" >/dev/null
  commit_file "$DIR" "a.txt"
  local BASE
  BASE=$(git -C "$DIR" rev-parse HEAD)
  commit_file "$DIR" "b.txt"
  commit_file "$DIR" "c.txt"

  package_branch "$DIR" "$OUT" false "$BASE"

  local COUNT RECORDED
  COUNT=$(ls "$OUT/patches/"*.diff 2>/dev/null | wc -l)
  RECORDED=$(export_status_read "$OUT" INIT_SHA)
  if [[ "$COUNT" -eq 2 && "$RECORDED" == "$BASE" ]]; then
    pass "package_branch honours an explicit baseline: 2 patches and INIT_SHA=$BASE"
  else
    fail "explicit baseline wrong: count=$COUNT recorded=$RECORDED expected=$BASE"
  fi
}

# Given: a recorded init_sha orphaned by a reset
# When:  package_branch_baseline runs
# Then:  the resolved baseline is the merge-base of init_sha and HEAD
# Asserts: the branch-point fallback (bite B1)
test_baseline_defaults_to_branch_point() {
  local DIR="$FIXTURE_DIR/pb_base_default"
  make_sandbox_fixture "$DIR" >/dev/null
  local BASE
  BASE=$(git -C "$DIR" rev-parse HEAD)

  commit_file "$DIR" "old.txt" "old"
  local ORPHAN
  ORPHAN=$(git -C "$DIR" rev-parse HEAD)

  # Simulate a session whose recorded init_sha a rewrite orphaned.
  : > "$DIR/.git/SESSION_STATE"
  echo "init_sha=$ORPHAN" >> "$DIR/.git/SESSION_STATE"
  echo "session_ts=20260501-120000" >> "$DIR/.git/SESSION_STATE"

  git -C "$DIR" reset --hard "$BASE" --quiet
  commit_file "$DIR" "new.txt" "new"

  local RESOLVED
  RESOLVED=$(package_branch_baseline "$DIR" "")
  if [[ "$RESOLVED" == "$BASE" ]]; then
    pass "package_branch defaults to the branch point after the recorded init_sha is orphaned"
  else
    fail "expected merge-base $BASE, got $RESOLVED"
  fi
}

# Given: an explicit baseline that resolves to no commit
# When:  package_branch_baseline runs
# Then:  rc 1 with the unresolved-baseline diagnostic
# Asserts: the explicit-baseline validation, which the valid-override unit cannot exercise.
test_baseline_rejects_unresolvable_explicit() {
  local DIR="$FIXTURE_DIR/pb_bad_base"
  make_sandbox_with_state "$DIR" >/dev/null

  local OUT RC=0
  OUT=$(package_branch_baseline "$DIR" "not-a-real-sha" 2>&1) || RC=$?

  if [[ $RC -eq 1 && "$OUT" == *"does not resolve to a commit"* ]]; then
    pass "package_branch_baseline rejects an explicit baseline that resolves to no commit"
  else
    fail "explicit-baseline validation broken: rc=$RC out='$OUT'"
  fi
}

run_test test_dispatcher_missing_args
run_test test_dispatcher_missing_session_state
run_test test_dispatcher_refuses_unreadable_repository
run_test test_dispatcher_refuses_unreadable_object_store
run_test test_dispatcher_export_status_contents
run_test test_preflight_bypass_returns_before_any_git
run_test test_preflight_clean_tree_is_silent
run_test test_preflight_flags_uncommitted_modifications
run_test test_preflight_flags_cancelled_out_modification
run_test test_preflight_skips_deleted_files_without_warning
run_test test_baseline_explicit_override
run_test test_baseline_rejects_unresolvable_explicit
run_test test_baseline_defaults_to_branch_point

# ===================================================================
# The bundle summary names a git ref  --  shape is enforced at entry
# ===================================================================

# Given: a summary holding spaces and a capital
# When:  package_branch_validate_summary runs
# Then:  rc 1, and the message names the snake_case rule
test_summary_rejects_spaces_and_capitals() {
  local OUT RC=0
  OUT=$(package_branch_validate_summary "Rebased plan series: M3.1" 2>&1) || RC=$?

  if [[ $RC -eq 1 && "$OUT" == *"lowercase snake_case"* ]]; then
    pass "package_branch_validate_summary rejects spaces and capitals"
  else
    fail "spaces/capitals accepted: rc=$RC out=$OUT"
  fi
}

# Given: a 49-character summary, one over the limit
# When:  package_branch_validate_summary runs
# Then:  rc 1, and the message states the bound and the length it saw
test_summary_rejects_overlong() {
  local LONG
  LONG=$(printf "a%.0s" $(seq 1 49))
  local OUT RC=0
  OUT=$(package_branch_validate_summary "$LONG" 2>&1) || RC=$?

  if [[ $RC -eq 1 && "$OUT" == *"3 to 48 characters"* && "$OUT" == *"got 49"* ]]; then
    pass "package_branch_validate_summary rejects a 49-character summary"
  else
    fail "overlong accepted: rc=$RC out=$OUT"
  fi
}

# Given: a well-formed snake_case summary inside the length bound
# When:  package_branch_validate_summary runs
# Then:  rc 0 and no output
test_summary_accepts_valid_slug() {
  local OUT RC=0
  OUT=$(package_branch_validate_summary "add_format_patch_support" 2>&1) || RC=$?

  if [[ $RC -eq 0 && -z "$OUT" ]]; then
    pass "package_branch_validate_summary accepts a valid snake_case slug"
  else
    fail "valid slug rejected: rc=$RC out=$OUT"
  fi
}

# Given: a summary that would break the draft branch name
# When:  the value is checked, then built into the ref draft.sh constructs
# Then:  the validator refuses it, and git confirms the reason
test_summary_refusal_matches_git_ref_rules() {
  local BAD="Rebased plan series: M3.1 split"
  local RC=0
  package_branch_validate_summary "$BAD" >/dev/null 2>&1 || RC=$?

  local REPO="$FIXTURE_DIR/pb_ref_check"
  mkdir -p "$REPO"
  git init -q "$REPO"
  local GITRC=0
  git -C "$REPO" branch "draft/$BAD" >/dev/null 2>&1 || GITRC=$?

  if [[ $RC -eq 1 && $GITRC -ne 0 ]]; then
    pass "the refusals agree with git: the value breaks a ref and the validator rejects it"
  else
    fail "divergence: validator_rc=$RC git_rc=$GITRC for $BAD"
  fi
}

# ===================================================================
# The export reports a moved branch point, and records it
# ===================================================================

# Given: a sandbox whose recorded init_sha a rewrite orphaned
# When:  package_branch runs
# Then:  the movement block is printed above the draft command, and
#        .branch-point records the resolved point and BASELINE_MOVED=true
test_moved_baseline_is_reported_and_recorded() {
  local DIR="$FIXTURE_DIR/pb_moved"
  local OUT="$FIXTURE_DIR/pb_moved_out"
  mkdir -p "$OUT"
  make_sandbox_fixture "$DIR" >/dev/null
  local BASE
  BASE=$(git -C "$DIR" rev-parse HEAD)

  commit_file "$DIR" "old.txt" "old"
  local ORPHAN
  ORPHAN=$(git -C "$DIR" rev-parse HEAD)

  : > "$DIR/.git/SESSION_STATE"
  echo "init_sha=$ORPHAN" >> "$DIR/.git/SESSION_STATE"
  echo "session_ts=20260501-120000" >> "$DIR/.git/SESSION_STATE"

  git -C "$DIR" reset --hard "$BASE" --quiet
  commit_file "$DIR" "new.txt" "new"

  local LOG RC=0
  LOG=$(package_branch "$DIR" "$OUT" false "" 2>&1) || RC=$?

  local OK=true
  [[ $RC -eq 0 ]] || OK=false
  [[ "$LOG" == *"Branch point moved"* ]] || OK=false
  # The movement block must precede the command, so the two read together.
  local MOVED_AT="${LOG%%To draft this bundle*}"
  [[ "$MOVED_AT" == *"Branch point moved"* ]] || OK=false
  [[ "$LOG" == *"NEW=1"* ]] || OK=false
  [[ -f "$OUT/.branch-point" ]] || OK=false
  grep -q "^BASELINE_MOVED=true$" "$OUT/.branch-point" || OK=false
  grep -q "^BRANCH_POINT=${BASE}$" "$OUT/.branch-point" || OK=false
  grep -q "^RECORDED_INIT_SHA=${ORPHAN}$" "$OUT/.branch-point" || OK=false

  if [[ "$OK" == true ]]; then
    pass "a moved branch point is reported above the draft command and recorded in .branch-point"
  else
    fail "movement reporting incomplete: rc=$RC log=$LOG"
  fi
}

# Given: a sandbox whose recorded init_sha is still an ancestor
# When:  package_branch runs
# Then:  no movement block, and .branch-point records BASELINE_MOVED=false
test_unmoved_baseline_records_no_movement() {
  local DIR="$FIXTURE_DIR/pb_unmoved"
  local OUT="$FIXTURE_DIR/pb_unmoved_out"
  mkdir -p "$OUT"
  make_sandbox_with_state "$DIR" >/dev/null
  commit_file "$DIR" "a.txt"

  local LOG
  LOG=$(package_branch "$DIR" "$OUT" false "" 2>&1)

  local OK=true
  [[ "$LOG" != *"Branch point moved"* ]] || OK=false
  grep -q "^BASELINE_MOVED=false$" "$OUT/.branch-point" || OK=false

  if [[ "$OK" == true ]]; then
    pass "a linear history records BASELINE_MOVED=false and prints no movement block"
  else
    fail "false movement reported: log=$LOG"
  fi
}

run_test test_summary_rejects_spaces_and_capitals
run_test test_summary_rejects_overlong
run_test test_summary_accepts_valid_slug
run_test test_summary_refusal_matches_git_ref_rules
run_test test_moved_baseline_is_reported_and_recorded
run_test test_unmoved_baseline_records_no_movement

test_done

