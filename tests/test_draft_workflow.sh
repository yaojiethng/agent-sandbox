#!/usr/bin/env bash
# tests/test_draft_workflow.sh
# Tests for libs/draft_workflow.sh
# Pins cite: devlog/discussions/design_apply_draft_workflow.md (commit-subject format).

#
# Covers:
#   draft_run      --  creates branch, applies patches, .draft-state, guards
#   draft_collect_patches / draft_apply_patches / _run_draft_workflow
#   _ingest_export_metadata  --  --branch-from, INIT_SHA defaults
#   draft_resolve_commit_message  --  .msg file, filename subject, fallback
#
# Uses make_session_fixture for synthetic session exports; for
# author-rewrite and commit-message tests, which need make_real_session.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
export AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/draft.sh"
source "$REPO_ROOT/scripts/guards.sh"
source "$TEST_DIR/libs/git_fixtures.sh"
source "$TEST_DIR/libs/session_fixtures.sh"
source "$TEST_DIR/libs/draft_fixtures.sh"

make_real_session() {
  local SANDBOX_DIR="$2"
  local SESSION_TS="${3:-20260408-120000}"
  local BRANCH="${4:-main}"

  # Create sandbox with distinct identity (different from project repo)
  local SANDBOX="$SANDBOX_DIR/sandbox-work"
  rm -rf "$SANDBOX"
  mkdir -p "$SANDBOX"
  git -C "$SANDBOX" init --quiet
  git -C "$SANDBOX" config user.email "agent@sandbox"
  git -C "$SANDBOX" config user.name "Agent"
  echo "baseline" > "$SANDBOX/file.txt"
  git -C "$SANDBOX" add .
  git -C "$SANDBOX" commit -m "baseline" --quiet
  local BASELINE_SHA
  BASELINE_SHA=$(git -C "$SANDBOX" rev-parse HEAD)

  # Agent makes two commits
  echo "agent change 1" > "$SANDBOX/agent1.txt"
  git -C "$SANDBOX" add .
  git -C "$SANDBOX" commit -m "feat: first agent commit" --quiet

  echo "agent change 2" > "$SANDBOX/agent2.txt"
  git -C "$SANDBOX" add .
  git -C "$SANDBOX" commit -m "feat: second agent commit" --quiet

  # Prepare workspace directory
  mkdir -p "$SANDBOX_DIR/.workspace"

  # Write session directory
  local BUNDLE_NAME="${SESSION_TS}-${BRANCH}"
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$BUNDLE_NAME"
  rm -rf "$SESSION_DIR"
  mkdir -p "$SESSION_DIR/patches"

  # Write .export-status (consolidated metadata file)
  {
    echo "STATUS=SUCCESS"
    echo "TIMESTAMP=20260408-120000"
    echo "INIT_SHA=${BASELINE_SHA}"
  } > "$SESSION_DIR/.export-status"

  # Write numbered .diff files (index-stripped) from BASELINE_SHA..HEAD
  local COMMIT_NUM=1
  local PREV_SHA="$BASELINE_SHA"
  for COMMIT_SHA in $(git -C "$SANDBOX" rev-list "${BASELINE_SHA}..HEAD" --reverse); do
    local PADDING
    PADDING=$(printf "%04d" "$COMMIT_NUM")
    git -C "$SANDBOX" diff "${PREV_SHA}..${COMMIT_SHA}" \
      | strip_index_lines \
      | sed 's/[[:space:]]*$//' \
      | awk '{print} END{print ""}' \
      > "$SESSION_DIR/patches/${PADDING}-${COMMIT_SHA}.diff"
    PREV_SHA="$COMMIT_SHA"
    COMMIT_NUM=$((COMMIT_NUM + 1))
  done

  # Write all-changes.diff and uncommitted.diff
  git -C "$SANDBOX" diff --binary -M "${BASELINE_SHA}..HEAD" \
    > "$SESSION_DIR/all-changes.diff"
  : > "$SESSION_DIR/uncommitted.diff"
}

# Given: a session fixture and a clean project
# When:  the draft orchestration creates its branch
# Then:  the working branch is named draft/<session-ts>-<slug>-<hash>
# Asserts: the branch-name shape (the hash suffix is not pinned, see row 230)
test_draft_creates_branch() {
  make_draft_fixture draft_branch 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local BRANCH
  BRANCH=$(draft_branch "$P")
  if [[ "$BRANCH" == draft/20260420-120000-test-branch-* ]]; then
    pass "draft creates working branch with correct name format"
  else
    fail "expected draft/* branch, got: $BRANCH"
  fi
}

# Given: a fixture carrying two patches
# When:  the orchestration runs
# Then:  HEAD holds four commits - initial, .draft-state, and the two patches
# Asserts: the apply loop commits every collected patch
test_draft_applies_diffs() {
  make_draft_fixture draft_diffs 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  # initial + .draft-state + 2 diffs = 4
  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  assert_eq_num "$COUNT" "4" "draft applies all diffs as commits"
}

# Given: an export directory whose name carries the session timestamp and host branch
# When:  the branch is created
# Then:  the branch name embeds both
# Asserts: the folder-name parse is what feeds the branch name
test_draft_branch_name_format() {
  make_draft_fixture draft_name 1 20260420-120000-feature-M2_3-agent

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local BRANCH
  BRANCH=$(draft_branch "$P")
  if [[ "$BRANCH" == draft/20260420-120000-feature-M2_3-agent-* ]]; then
    pass "draft branch name follows expected format"
  else
    fail "branch name wrong: got '$BRANCH'"
  fi
}

# Given: --branch-summary naming a slug
# When:  the branch is created
# Then:  the slug replaces the host branch in the name
# Asserts: the summary override
test_draft_branch_name_with_summary() {
  make_draft_fixture draft_summary 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "my-feature" >/dev/null 2>&1

  local BRANCH
  BRANCH=$(draft_branch "$P")
  assert_contains "$BRANCH" "my-feature" "draft branch name uses BRANCH_SUMMARY"
}

# Given: a created draft branch
# When:  the first new commit is inspected
# Then:  it is .draft-state and carries every required field
# Asserts: the state record's field set
test_draft_creates_draft_state_commit() {
  make_draft_fixture draft_state 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")
  local FIRST_NEW
  FIRST_NEW=$(git -C "$P" rev-list main.."$DRAFT_BRANCH" --reverse | head -1)
  local MSG
  MSG=$(git -C "$P" log -1 --format=%s "$FIRST_NEW")

  assert_eq "$MSG" ".draft-state" ".draft-state is the first new commit"

  local CONTENT
  CONTENT=$(git -C "$P" show "${FIRST_NEW}:.draft-state")
  local ALL_FIELDS=true
  for field in source_branch from_hash author session_ts host_branch diff_count exported-at drafted-at; do
    if [[ "$CONTENT" != *"${field}:"* ]]; then
      ALL_FIELDS=false
      fail ".draft-state missing field: $field"
    fi
  done
  if [[ "$ALL_FIELDS" == true ]]; then
    pass ".draft-state contains all required fields"
  fi
}

# Given: the same created draft
# When:  the field values are read
# Then:  source_branch, session_ts, host_branch, diff_count, and exported-at match the fixture
# Asserts: the record's values, not only field presence
test_draft_state_has_correct_values() {
  make_draft_fixture draft_vals 3
  {
    echo "STATUS=SUCCESS"
    echo "TIMESTAMP=20260420-120000"
    echo "INIT_SHA=aaaaaaaaaaaaaaaaaaaa"
  } > "$EXPORT/.export-status"

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local DRAFT_BRANCH
  DRAFT_BRANCH=$(draft_branch "$P")
  local FIRST_NEW
  FIRST_NEW=$(git -C "$P" rev-list main.."$DRAFT_BRANCH" --reverse | head -1)
  local CONTENT
  CONTENT=$(git -C "$P" show "${FIRST_NEW}:.draft-state")

  [[ "$CONTENT" == *"source_branch: main"* ]] && pass "source_branch correct" || fail "source_branch wrong"
  [[ "$CONTENT" == *"session_ts: 20260420-120000"* ]] && pass "session_ts correct" || fail "session_ts wrong"
  [[ "$CONTENT" == *"host_branch: test-branch"* ]] && pass "host_branch correct" || fail "host_branch wrong"
  [[ "$CONTENT" == *"diff_count: 3"* ]] && pass "diff_count correct" || fail "diff_count wrong"
  [[ "$CONTENT" == *"exported-at: 20260420-120000"* ]] && pass "exported-at correct" || fail "exported-at wrong"
}

# Given: a branch with the target name already exists
# When:  the orchestration runs
# Then:  it refuses and names the collision
# Asserts: draft_guard_no_collision's message
test_draft_rejects_same_name_collision() {
  make_draft_fixture draft_collision 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  git -C "$P" checkout main --quiet

  local OUT
  OUT=$(_test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" 2>&1) || true
  assert_contains "$OUT" "draft branch already exists" "draft rejects same-name collision"
}

# Given: HEAD is already on a draft/* branch
# When:  the orchestration runs
# Then:  it refuses and points at confirm and reject
# Asserts: the on-draft guard and its remedy hint
test_draft_rejects_when_on_draft_branch() {
  make_draft_fixture draft_ondraft 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local OUT
  OUT=$(_test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" 2>&1) || true
  assert_contains "$OUT" "already on a draft branch" "draft rejects when already on a draft branch"
}

# Given: two exports drafted in sequence
# When:  the branch list is read
# Then:  two draft branches exist
# Asserts: the branch name carries enough identity that a second draft cannot collide
test_draft_allows_parallel_drafts() {
  local P="$FIXTURE_DIR/draft_parallel_p"
  local S="$FIXTURE_DIR/draft_parallel_s"
  local EXPORT1="$S/.workspace/session-diffs/20260420-120000-branch-a"
  local EXPORT2="$S/.workspace/session-diffs/20260420-130000-branch-b"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT1" 1
  make_session_fixture "$EXPORT2" 1

  _test_draft_run "$P" "$EXPORT1" "$(basename "$EXPORT1")" "" "" "" >/dev/null 2>&1
  git -C "$P" checkout main --quiet
  _test_draft_run "$P" "$EXPORT2" "$(basename "$EXPORT2")" "" "" "" >/dev/null 2>&1

  local COUNT
  COUNT=$(git -C "$P" branch --list 'draft/*' | wc -l)
  assert_eq_num "$COUNT" "2" "draft allows parallel draft branches"
}

# Given: an extra commit and --branch-from naming it
# When:  the draft runs
# Then:  the commit count is five
# Asserts: the flag is accepted - the fixture records the flag's value as the current HEAD, so the fork point is not distinguished (row 230)
test_draft_branch_from() {
  make_draft_fixture draft_from 2

  echo "extra" > "$P/extra.txt"
  git -C "$P" add extra.txt
  git -C "$P" commit -m "extra commit" --quiet
  local FROM_HASH
  FROM_HASH=$(git -C "$P" rev-parse HEAD)

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "$FROM_HASH" "" "" >/dev/null 2>&1

  # initial + extra + .draft-state + 2 diffs = 5
  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  assert_eq_num "$COUNT" "5" "draft BRANCH_FROM creates branch from specified commit"
}

# Given: four patches and --diffs=2..3
# When:  the draft runs
# Then:  only the two selected patches land
# Asserts: the range filter's upper and lower bounds
test_draft_diffs_range() {
  make_draft_fixture draft_range 4

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "2..3" "" >/dev/null 2>&1

  # .draft-state + 2 diffs + initial = 4
  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  assert_eq_num "$COUNT" "4" "draft DIFFS range applies only selected diffs"
}

# Given: an export with no patches and no uncommitted changes
# When:  the draft runs
# Then:  it errors
# Asserts: the missing-source refusal, reached in practice through the test-side replica (row 223)
test_draft_no_diffs_error() {
  local P="$FIXTURE_DIR/draft_nodiff_p"
  local S="$FIXTURE_DIR/draft_nodiff_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  mkdir -p "$EXPORT/session"
  {
    echo "STATUS=SUCCESS"
    echo "TIMESTAMP=20260420-120000"
    echo "INIT_SHA=aaaaaaaaaaaaaaaaaaaa"
  } > "$EXPORT/session/.export-status"
  : > "$EXPORT/session/changes.diff"

  local OUT
  OUT=$(_test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" 2>&1) || true
  if [[ "$OUT" == *"no patches/"* || "$OUT" == *"no .diff files"* ]]; then
    pass "draft errors when no diffs found"
  else
    fail "did not error on missing diffs: $OUT"
  fi
}

# Given: a patch whose target file already exists, so it cannot apply
# When:  the orchestration runs
# Then:  the operator is back on the source branch
# Asserts: the rollback's branch restore - the tree reset is not asserted (row 234)
test_draft_failure_returns_to_source_branch() {
  make_draft_fixture draft_rollback 1

  # Force the new-file patch to fail: file-1.txt already exists in the baseline,
  # so git apply cannot create it. This drives _run_draft_workflow through its
  # failure/rollback path.
  echo "conflict" > "$P/file-1.txt"
  git -C "$P" add file-1.txt
  git -C "$P" commit -m "conflict file" --quiet

  _run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" false >/dev/null 2>&1 || true

  local CURR
  CURR=$(_current_branch "$P")
  assert_eq "$CURR" "main" "failed draft returns operator to source branch"
}

# Given: the same apply failure
# When:  the branch list is read
# Then:  no draft/* branch remains
# Asserts: the rollback deletes the exact branch the run created
test_draft_failure_deletes_draft_branch() {
  make_draft_fixture draft_rollback_del 1

  echo "conflict" > "$P/file-1.txt"
  git -C "$P" add file-1.txt
  git -C "$P" commit -m "conflict file" --quiet

  _run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" false >/dev/null 2>&1 || true

  local LEFT
  LEFT=$(git -C "$P" branch --list 'draft/*')
  assert_empty "$LEFT" "failed draft deletes the draft branch it created"
}

# Given: a patch whose index line would break a plain git apply
# When:  the draft runs
# Then:  the file still lands
# Asserts: the index-line stripping inherited from diff.sh
test_draft_strips_index_lines() {
  local P="$FIXTURE_DIR/draft_strip_p"
  local S="$FIXTURE_DIR/draft_strip_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  mkdir -p "$EXPORT/patches"
  {
    echo "STATUS=SUCCESS"
    echo "TIMESTAMP=20260420-120000"
    echo "INIT_SHA=aaaaaaaaaaaaaaaaaaaa"
  } > "$EXPORT/.export-status"
  : > "$EXPORT/uncommitted.diff"

  cat > "$EXPORT/patches/0001-test.diff" <<'EOF'
diff --git a/stripped.txt b/stripped.txt
new file mode 100644
index 0000000..8a963d6
--- /dev/null
+++ b/stripped.txt
@@ -0,0 +1 @@
+stripped content
EOF

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  if [[ -f "$P/stripped.txt" ]]; then
    pass "draft strips index lines before applying"
  else
    fail "did not apply diff after stripping index lines"
  fi
}

# Given: session commits authored by the agent
# When:  the draft commits them
# Then:  every commit author is the operator's identity
# Asserts: the author rewrite, which is the reason the draft workflow exists
test_draft_resets_author_to_operator() {
  local P="$FIXTURE_DIR/draft_author_p"
  local S="$FIXTURE_DIR/draft_author_s"
  make_committed_repo "$P"
  make_real_session "$P" "$S"
  local EXPORT="$S/.workspace/session-diffs/20260408-120000-main"

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local BAD
  BAD=$(git -C "$P" log main..HEAD --format='%ae' | grep -v "test@fixture" || true)
  assert_empty "$BAD" "draft resets all commit authors to operator identity"
}

# Given: patch files carrying .msg subjects and filename subjects
# When:  the draft commits them
# Then:  each commit carries the message that resolution produces
# Asserts: the resolution order across the four shapes (see the resolve_* units below)
test_draft_commit_messages() {
  local P="$FIXTURE_DIR/draft_msg_p"
  local S="$FIXTURE_DIR/draft_msg_s"
  make_committed_repo "$P"
  make_real_session "$P" "$S"
  local EXPORT="$S/.workspace/session-diffs/20260408-120000-main"

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local FIRST_MSG
  FIRST_MSG=$(git -C "$P" log main..HEAD --reverse --format='%s' | head -1)
  assert_eq "$FIRST_MSG" ".draft-state" "first commit is .draft-state"

  local SECOND_MSG
  SECOND_MSG=$(git -C "$P" log main..HEAD --reverse --format='%s' | sed -n '2p')
  if [[ "$SECOND_MSG" == "Apply "* ]]; then
    pass "patch commits have generated messages"
  else
    fail "patch message should start with 'Apply', got: $SECOND_MSG"
  fi
}

# Given: no .export-status and an explicit --branch-from
# When:  metadata is ingested
# Then:  the call succeeds
# Asserts: the documented escape hatch for sources without metadata
test_branch_from_skips_missing_export_status() {
  local P="$FIXTURE_DIR/ingest_from_p"
  local S="$FIXTURE_DIR/ingest_from_s"
  make_committed_repo "$P"
  mkdir -p "$S"

  # Source dir with patches but NO .export-status
  local EXPORT="$S/export"
  mkdir -p "$EXPORT/patches"

  local BASE TIME INIT
  if _ingest_export_metadata "$EXPORT" "HEAD" "$P" BASE TIME INIT 2>/dev/null; then
    if [[ "$BASE" == "HEAD" ]]; then
      pass "--branch-from skips missing .export-status"
    else
      fail "expected BASE=HEAD, got: $BASE"
    fi
  else
    fail "--branch-from should skip missing .export-status validation"
  fi
}

# Given: no .export-status and no --branch-from
# When:  metadata is ingested
# Then:  the call errors
# Asserts: the refusal only - which of the two metadata checks refuses is not pinned (row 228)
test_no_branch_from_errors_without_export_status() {
  local P="$FIXTURE_DIR/ingest_nofrom_p"
  local S="$FIXTURE_DIR/ingest_nofrom_s"
  make_committed_repo "$P"
  mkdir -p "$S"

  local EXPORT="$S/export"
  mkdir -p "$EXPORT/patches"

  local BASE TIME INIT
  if _ingest_export_metadata "$EXPORT" "" "$P" BASE TIME INIT 2>/dev/null; then
    fail "missing .export-status with no --branch-from should error"
  else
    pass "missing .export-status with no --branch-from errors"
  fi
}

# Given: .export-status without INIT_SHA
# When:  metadata is ingested
# Then:  the base is HEAD and init is empty, without error
# Asserts: INIT_SHA's advisory role
test_missing_init_sha_defaults_to_head() {
  local P="$FIXTURE_DIR/ingest_nohash_p"
  local S="$FIXTURE_DIR/ingest_nohash_s"
  make_committed_repo "$P"
  mkdir -p "$S"

  local EXPORT="$S/export"
  mkdir -p "$EXPORT/patches"
  {
    echo "STATUS=SUCCESS"
    echo "TIMESTAMP=20260420-120000"
  } > "$EXPORT/.export-status"

  local BASE TIME INIT
  if _ingest_export_metadata "$EXPORT" "" "$P" BASE TIME INIT 2>/dev/null; then
    if [[ "$BASE" == "HEAD" ]] && [[ -z "$INIT" ]]; then
      pass "missing INIT_SHA defaults to HEAD without error"
    else
      fail "expected BASE=HEAD, empty INIT; got BASE=$BASE INIT=$INIT"
    fi
  else
    fail "missing INIT_SHA should default to HEAD, not error"
  fi
}

# Given: an INIT_SHA that differs from the resolved fork point
# When:  metadata is ingested
# Then:  the call succeeds with the base at HEAD
# Asserts: divergence is warn-only - the warning text itself is discarded here (row 227)
test_init_sha_warns_on_divergence_but_proceeds() {
  local P="$FIXTURE_DIR/ingest_hash_p"
  local S="$FIXTURE_DIR/ingest_hash_s"
  make_committed_repo "$P"
  mkdir -p "$S"

  local EXPORT="$S/export"
  mkdir -p "$EXPORT/patches"
  {
    echo "STATUS=SUCCESS"
    echo "TIMESTAMP=20260420-120000"
    echo "INIT_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  } > "$EXPORT/.export-status"

  local BASE TIME INIT
  # Warning goes to stderr; here we assert success + HEAD default.
  if _ingest_export_metadata "$EXPORT" "" "$P" BASE TIME INIT 2>/dev/null; then
    [[ -n "$TIME" ]] || fail "export metadata: TIME should be populated"
    if [[ "$BASE" == "HEAD" && -n "$INIT" ]]; then
      pass "INIT_SHA present: branch point resolves, divergence is warn-only"
    else
      fail "expected BASE=HEAD with INIT set; got BASE=$BASE INIT=$INIT"
    fi
  else
    fail "INIT_SHA present should not error"
  fi
}

# Given: a diff with a sibling non-empty .msg file
# When:  draft_resolve_commit_message runs
# Then:  the .msg body is the message
# Asserts: priority 1.
test_resolve_msg_file_used() {
  local TMP="$FIXTURE_DIR/resolve_msg"
  mkdir -p "$TMP"
  echo "dummy" > "$TMP/0001-abc1234.diff"
  printf "Original subject\n\nFull body paragraph.\n" > "$TMP/0001-abc1234.msg"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234.diff")
  if [[ "$MSG" == "Original subject"$'\n'""$'\n'"Full body paragraph." ]]; then
    pass "draft_resolve_commit_message reads .msg file with full body"
  else
    fail "draft_resolve_commit_message should return .msg content"
  fi
}

# Given: a diff named NNNN-<sha>-<subject>.diff with no .msg
# When:  draft_resolve_commit_message runs
# Then:  the subject is returned with underscores as spaces
# Asserts: priority 2.
test_resolve_filename_subject_cleaned() {
  local TMP="$FIXTURE_DIR/resolve_subj"
  mkdir -p "$TMP"
  echo "dummy" > "$TMP/0001-abc1234-fix_widget_parsing.diff"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234-fix_widget_parsing.diff")
  assert_eq "$MSG" "fix widget parsing" "draft_resolve_commit_message extracts subject from filename, cleans underscores"
}

# Given: a filename subject padded with leading, repeated, and trailing underscores
# When:  draft_resolve_commit_message runs
# Then:  the underscores are trimmed and collapsed
# Asserts: the subject cleanup loop.
test_resolve_filename_subject_trim_underscores() {
  local TMP="$FIXTURE_DIR/resolve_trim"
  mkdir -p "$TMP"
  # Subject with leading, trailing, and consecutive underscores
  echo "dummy" > "$TMP/0001-abc1234-__hello___world__.diff"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234-__hello___world__.diff")
  assert_eq "$MSG" "hello world" "draft_resolve_commit_message trims and collapses underscores"
}

# Given: a diff named NNNN-<sha>.diff with no subject portion
# When:  draft_resolve_commit_message runs
# Then:  the fallback 'Apply <basename>' is returned
# Asserts: priority 3.
test_resolve_fallback_no_subject() {
  local TMP="$FIXTURE_DIR/resolve_fb"
  mkdir -p "$TMP"
  echo "dummy" > "$TMP/0001-abc1234.diff"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234.diff")
  assert_eq "$MSG" "Apply 0001-abc1234.diff" "draft_resolve_commit_message falls back to 'Apply <basename>'"
}

# Given: a diff with both a subject in the filename and a non-empty .msg file
# When:  draft_resolve_commit_message runs
# Then:  the .msg body wins
# Asserts: the ordering of priorities (an empty .msg file is not covered; see finding 40).
test_resolve_msg_file_preferred_over_filename() {
  local TMP="$FIXTURE_DIR/resolve_prefer"
  mkdir -p "$TMP"
  # Both .msg and filename subject exist  --  .msg should win
  echo "dummy" > "$TMP/0001-abc1234-some_subject.diff"
  echo "Message from .msg" > "$TMP/0001-abc1234-some_subject.msg"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234-some_subject.diff")
  assert_eq "$MSG" "Message from .msg" "draft_resolve_commit_message prefers .msg over filename subject"
}

# Given: a fixture with patches and a non-empty uncommitted.diff
# When:  the draft runs
# Then:  the patches are committed and uncommitted.diff sits in the working tree only
# Asserts: the two-tier apply contract (committed patches, uncommitted review material)
test_draft_applies_uncommitted_diff() {
  local P="$FIXTURE_DIR/draft_uncomm_p"
  local S="$FIXTURE_DIR/draft_uncomm_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-uncommitted-test"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2 content

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  # Patches are committed; uncommitted.diff is applied to the working tree
  # only (draft_apply_uncommitted does not commit  --  see draft.sh contract).
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$P" log main..HEAD --reverse --format='%s' | grep -v '^\.draft-state$' | wc -l | tr -d ' ')
  assert_eq_num "$COMMIT_COUNT" "2" "draft_run commits the 2 patches (uncommitted.diff is not committed)"

  # Verify uncommitted.txt was created in the working tree and is not part of
  # HEAD (uncommitted.diff is applied, not committed).
  if [[ -f "$P/uncommitted.txt" ]] && ! git -C "$P" cat-file -e HEAD:uncommitted.txt 2>/dev/null; then
    pass "draft_run applies uncommitted.diff to the working tree (uncommitted.txt present, not committed)"
  else
    fail "draft_run should apply uncommitted.diff to the working tree only"
  fi
}

# Given: a dirty working tree
# When:  the draft runs
# Then:  it refuses
# Asserts: the fork-base invariant - force never bypasses it, though the force case itself is unpinned (row 241)
test_draft_fails_on_dirty_working_tree() {
  make_draft_fixture draft_dirty 1

  # Dirty the project tree with an unstaged change.
  echo "wip" >> "$P/file.txt"

  local OUT RC=0
  OUT=$(_test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" 2>&1) || RC=$?

  if [[ $RC -ne 0 \
     && "$OUT" == *"requires a clean working tree"* \
     && "$OUT" == *"Stash them"* ]]; then
    pass "draft fails on a dirty working tree (never bypassed)"
  else
    fail "expected dirty-tree refusal with stash hint, got rc=$RC out='$OUT'"
  fi
}

# Given: a corrupt .git/index, so git status cannot read the tree
# When:  the draft runs
# Then:  it refuses without the phantom stash hint
# Asserts: the unreadable-tree arm and its distinct guidance
test_draft_fails_on_unreadable_working_tree() {
  make_draft_fixture draft_unreadable 1

  # A corrupt index is not a dirty tree: the operator must not be told to stash
  # changes that do not exist. git status fails while HEAD still resolves.
  printf 'garbage' > "$P/.git/index"

  local OUT RC=0
  OUT=$(_test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" 2>&1) || RC=$?

  if [[ $RC -ne 0 \
     && "$OUT" == *"cannot read the working tree state"* \
     && "$OUT" != *"Stash them"* ]]; then
    pass "draft refuses an unreadable tree without a phantom stash hint"
  else
    fail "expected unreadable-tree refusal, got rc=$RC out='$OUT'"
  fi
}

# Given: a non-interactive draft with no bundle
# When:  the entry point resolves the source
# Then:  it errors and points at the picker
# Asserts: the no-auto-pick rule
test_draft_requires_bundle() {
  local OUT RC
  OUT=$(_resolve_draft_source "$FIXTURE_DIR" session "" 2>&1)
  RC=$?
  if [[ "$RC" -ne 0 ]] && [[ "$OUT" == *"INTERACTIVE=1"* ]]; then
    pass "a non-interactive draft with no bundle errors and points at the picker"
  else
    fail "no-bundle guard wrong: rc=$RC out=$OUT"
  fi
}

# =============================================================================
# Run all
# =============================================================================
run_test test_draft_creates_branch
run_test test_draft_requires_bundle
run_test test_draft_applies_diffs
run_test test_draft_applies_uncommitted_diff

run_test test_branch_from_skips_missing_export_status
run_test test_no_branch_from_errors_without_export_status
run_test test_missing_init_sha_defaults_to_head
run_test test_init_sha_warns_on_divergence_but_proceeds

run_test test_draft_branch_name_format
run_test test_draft_branch_name_with_summary
run_test test_draft_creates_draft_state_commit
run_test test_draft_state_has_correct_values
run_test test_draft_rejects_same_name_collision
run_test test_draft_rejects_when_on_draft_branch
run_test test_draft_allows_parallel_drafts
run_test test_draft_branch_from
run_test test_draft_diffs_range
run_test test_draft_no_diffs_error
run_test test_draft_fails_on_dirty_working_tree
run_test test_draft_fails_on_unreadable_working_tree
run_test test_draft_failure_returns_to_source_branch
run_test test_draft_failure_deletes_draft_branch
run_test test_draft_strips_index_lines
run_test test_draft_resets_author_to_operator
run_test test_draft_commit_messages

run_test test_resolve_msg_file_used
run_test test_resolve_filename_subject_cleaned
run_test test_resolve_filename_subject_trim_underscores
run_test test_resolve_fallback_no_subject
run_test test_resolve_msg_file_preferred_over_filename

test_done
