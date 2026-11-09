#!/usr/bin/env bash
# TEST_DEADLINE: 15
# tests/test_draft_workflow.sh
# Tests for libs/draft_workflow.sh
# Pins cite: devlog/discussions/archive/20260803-design-settled-apply_draft_workflow.md (commit-subject format).

#
# Covers:
#   main           --  script entry point, non-interactive and interactive paths
#   draft_run      --  creates branch, writes its record, applies patches, guards
#   draft_collect_patches / draft_apply_patches / _run_draft_workflow
#   _ingest_export_metadata  --  .branch-point default, explicit override, refusals (missing/malformed/non-commit)
#   draft_resolve_commit_message  --  non-empty .msg file, empty .msg, filename subject, fallback
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
  local PROJECT_DIR="$1"
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

  # Record the package fork point the draft now consumes. The project is
  # the host repository, so its HEAD is the commit the host can fork from;
  # the sandbox baseline is only the patch-generation point.
  local PROJECT_HEAD
  PROJECT_HEAD=$(git -C "$PROJECT_DIR" rev-parse HEAD)
  {
    echo "BUNDLE=${BUNDLE_NAME}"
    echo "BRANCH_POINT=${PROJECT_HEAD}"
    echo "BASELINE_MOVED=false"
    echo "RECORDED_INIT_SHA=${BASELINE_SHA}"
  } > "$SESSION_DIR/.branch-point"

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

# make_draft_script_fixture NAME PATCHES [BUNDLE]
#   Builds the fixture the draft script's own source resolution expects:
#   the bundle lives under CHANGES_DIR/session, where dirs_resolve and
#   resolve_source_for_draft look. Sets P, S, BUNDLE, and EXPORT in the
#   caller's scope so a `bash draft.sh ...` invocation can reach it.
make_draft_script_fixture() {
  local NAME="$1" PATCHES="${2:-0}"
  local B="${3:-20260420-120000-test-branch}"
  P="$FIXTURE_DIR/${NAME}_p"
  S="$FIXTURE_DIR/${NAME}_s"
  BUNDLE="$B"
  EXPORT="$S/.workspace/session-diffs/session/$BUNDLE"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" "$PATCHES" none "$(git -C "$P" rev-parse HEAD)"
}

# Given: a session fixture and a clean project
# When:  the draft orchestration creates its branch
# Then:  the working branch is named draft/<session-ts>-<slug>-<hash>
# Asserts: the branch-name shape
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
# Then:  HEAD holds three commits - initial and the two patches
# Asserts: the apply loop commits every collected patch, with no metadata commit
test_draft_applies_diffs() {
  make_draft_fixture draft_diffs 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  # initial + 2 diffs = 3
  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  assert_eq_num "$COUNT" "3" "draft applies all diffs as commits"
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
# When:  its record and first new commit are read
# Then:  the source and fork point are recorded, and no .draft-state commit exists
# Asserts: the branch-local record and the absence of the old metadata commit
test_draft_writes_branch_record() {
  make_draft_fixture draft_record 2
  local POINT
  POINT=$(git -C "$P" rev-parse HEAD)

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local DRAFT_BRANCH SOURCE FORK FIRST_MSG
  DRAFT_BRANCH=$(draft_branch "$P")
  SOURCE=$(git -C "$P" config --local --get "branch.${DRAFT_BRANCH}.agent-sandbox-source" 2>/dev/null || true)
  FORK=$(git -C "$P" config --local --get "branch.${DRAFT_BRANCH}.agent-sandbox-fork" 2>/dev/null || true)
  FIRST_MSG=$(git -C "$P" log main.."$DRAFT_BRANCH" --reverse --format='%s' | head -1)

  if [[ "$SOURCE" == "main" && "$FORK" == "$POINT" && "$FIRST_MSG" == Apply\ * ]] \
     && ! git -C "$P" cat-file -e "${DRAFT_BRANCH}:.draft-state" 2>/dev/null; then
    pass "draft writes the branch record and adds no .draft-state commit"
  else
    fail "record wrong: source='$SOURCE' fork='$FORK' first='$FIRST_MSG'"
  fi
}

# Given: a repo whose draft branch cannot be created
# When:  draft_create_and_init_branch runs
# Then:  the record keys are cleared
# Asserts: the branch-creation failure cleanup
test_draft_branch_creation_failure_clears_record() {
  local P="$FIXTURE_DIR/draft_createfail_p"
  make_committed_repo "$P"
  local BASE
  BASE=$(git -C "$P" rev-parse HEAD)

  if draft_create_and_init_branch "$P" "draft/bad..name" "$BASE" "main" 2>/dev/null; then
    fail "draft branch creation should fail for an invalid ref"
  elif git -C "$P" config --local --get branch.draft/bad..name.agent-sandbox-source >/dev/null 2>&1; then
    fail "failed branch creation left the draft record behind"
  else
    pass "failed branch creation clears the draft record"
  fi
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

# Given: two exports with distinct session identities drafted in sequence
# When:  the branch list is read
# Then:  two draft branches exist
# Asserts: exact branch-ref identity; a different name may coexist
test_draft_allows_distinct_branch_identities() {
  local P="$FIXTURE_DIR/draft_parallel_p"
  local S="$FIXTURE_DIR/draft_parallel_s"
  local EXPORT1="$S/.workspace/session-diffs/20260420-120000-branch-a"
  local EXPORT2="$S/.workspace/session-diffs/20260420-130000-branch-b"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT1" 1 none "$(git -C "$P" rev-parse HEAD)"
  make_session_fixture "$EXPORT2" 1 none "$(git -C "$P" rev-parse HEAD)"

  _test_draft_run "$P" "$EXPORT1" "$(basename "$EXPORT1")" "" "" "" >/dev/null 2>&1
  git -C "$P" checkout main --quiet
  _test_draft_run "$P" "$EXPORT2" "$(basename "$EXPORT2")" "" "" "" >/dev/null 2>&1

  local COUNT
  COUNT=$(git -C "$P" branch --list 'draft/*' | wc -l)
  assert_eq_num "$COUNT" "2" "distinct draft branch identities coexist"
}

# Given: an extra commit and --branch-from naming it
# When:  the draft runs
# Then:  the commit count is five
# Asserts: the flag is accepted and the commit count follows from it
test_draft_branch_from() {
  make_draft_fixture draft_from 2

  echo "extra" > "$P/extra.txt"
  git -C "$P" add extra.txt
  git -C "$P" commit -m "extra commit" --quiet
  local FROM_HASH
  FROM_HASH=$(git -C "$P" rev-parse HEAD)

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "$FROM_HASH" "" "" >/dev/null 2>&1

  # initial + extra + 2 diffs = 4
  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  assert_eq_num "$COUNT" "4" "draft BRANCH_FROM creates branch from specified commit"
}

# Given: four patches and --diffs=2..3
# When:  the draft runs
# Then:  only the two selected patches land
# Asserts: the range filter's upper and lower bounds
test_draft_diffs_range() {
  make_draft_fixture draft_range 4

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "2..3" "" >/dev/null 2>&1

  # 2 diffs + initial = 3
  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  assert_eq_num "$COUNT" "3" "draft DIFFS range applies only selected diffs"
}

# Given: an export directory whose name carries no <ts>-<branch> shape
# When:  the draft runs through the production orchestration
# Then:  the raw folder name becomes the branch identity segment
# Asserts: the folder name is not validated; the identity falls back to the raw name
#          and the slug segment is left empty.
test_draft_unparseable_export_name_still_drafts() {
  local P="$FIXTURE_DIR/draft_unparsed_p"
  local S="$FIXTURE_DIR/draft_unparsed_s"
  local EXPORT="$S/.workspace/session-diffs/session/weird"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 1 none "$(git -C "$P" rev-parse HEAD)"

  local RC=0
  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1 || RC=$?

  local BRANCH
  BRANCH=$(draft_branch "$P")
  if [[ $RC -eq 0 && "$BRANCH" == draft/weird--* ]]; then
    pass "an unparseable export name drafts with the raw name as identity (empty slug)"
  else
    fail "unparseable export name: rc=$RC branch='$BRANCH'"
  fi
}

# Given: an export with no patches and no uncommitted changes
# When:  the draft runs through the production orchestration
# Then:  it errors
# Asserts: the missing-source refusal.
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

  local HEAD_SHA
  HEAD_SHA=$(git -C "$P" rev-parse HEAD)
  _run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "$HEAD_SHA" "" "" false >/dev/null 2>&1 || true

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

  local HEAD_SHA
  HEAD_SHA=$(git -C "$P" rev-parse HEAD)
  _run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "$HEAD_SHA" "" "" false >/dev/null 2>&1 || true

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
  {
    echo "BUNDLE=$(basename "$EXPORT")"
    echo "BRANCH_POINT=$(git -C "$P" rev-parse HEAD)"
    echo "BASELINE_MOVED=false"
    echo "RECORDED_INIT_SHA=$(git -C "$P" rev-parse HEAD)"
  } > "$EXPORT/.branch-point"
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

  local FIRST_MSG SECOND_MSG
  FIRST_MSG=$(git -C "$P" log main..HEAD --reverse --format='%s' | head -1)
  SECOND_MSG=$(git -C "$P" log main..HEAD --reverse --format='%s' | sed -n '2p')
  if [[ "$FIRST_MSG" == Apply\ * && "$SECOND_MSG" == Apply\ * ]]; then
    pass "patch commits have generated messages"
  else
    fail "patch messages should start with 'Apply', got: '$FIRST_MSG' / '$SECOND_MSG'"
  fi
}

# =============================================================================
# _ingest_case  --  one driver for the metadata-resolution table
# =============================================================================

# _ingest_case NAME BRANCH_FROM STATUS_BODY POINT_BODY EXPECT_RC EXPECT_SUBSTR \
#   [EXPECT_BASE] [EXPECT_ERR_EMPTY]
#
# Builds a repo and an export directory, writes each metadata body when it is
# non-empty, runs _ingest_export_metadata, and asserts the exit code, a message
# substring, the printed base, and optionally that stderr carried no warning.
_ingest_case() {
  local NAME="$1" BRANCH_FROM="$2" STATUS_BODY="$3" POINT_BODY="$4"
  local EXPECT_RC="$5" EXPECT_SUBSTR="$6" EXPECT_BASE="${7:-}"
  local EXPECT_ERR_EMPTY="${8:-}"
  local P="$FIXTURE_DIR/${NAME}_p"
  local S="$FIXTURE_DIR/${NAME}_s"
  local EXPORT="$S/export"
  local ERR_FILE="$FIXTURE_DIR/${NAME}.err"

  [[ -d "$P/.git" ]] || make_committed_repo "$P"
  mkdir -p "$EXPORT/patches"
  [[ -n "$STATUS_BODY" ]] && printf '%s\n' "$STATUS_BODY" > "$EXPORT/.export-status"
  [[ -n "$POINT_BODY" ]] && printf '%s\n' "$POINT_BODY" > "$EXPORT/.branch-point"

  local OUT RC=0 ERR=""
  OUT=$(_ingest_export_metadata "$EXPORT" "$BRANCH_FROM" "$P" 2>"$ERR_FILE") || RC=$?
  ERR=$(cat "$ERR_FILE")
  local COMBINED="${OUT}${ERR}"

  if [[ "$RC" -ne "$EXPECT_RC" ]]; then
    fail "$NAME: expected rc=$EXPECT_RC, got rc=$RC out='$COMBINED'"
    return
  fi
  if [[ -n "$EXPECT_SUBSTR" && "$COMBINED" != *"$EXPECT_SUBSTR"* ]]; then
    fail "$NAME: expected message '$EXPECT_SUBSTR', got '$COMBINED'"
    return
  fi
  if [[ -n "$EXPECT_BASE" && "$OUT" != "$EXPECT_BASE" ]]; then
    fail "$NAME: expected base '$EXPECT_BASE', got '$OUT'"
    return
  fi
  if [[ "$EXPECT_ERR_EMPTY" == "empty" && -n "$ERR" ]]; then
    fail "$NAME: expected no warning, got '$ERR'"
    return
  fi
  pass "$NAME"
}

# Given: no .export-status and an explicit --branch-from
# When:  metadata is ingested
# Then:  the call succeeds
# Asserts: the documented escape hatch for sources without metadata
test_branch_from_skips_missing_export_status() {
  _ingest_case branch_from_skips_missing_export "HEAD" "" "" 0 "" "HEAD"
}

# Given: --branch-from is a well-formed 40-hex id that is not a commit object
# When:  metadata is ingested
# Then:  the call refuses
# Asserts: the strong commit check; `rev-parse --verify` would accept the hex.
test_branch_from_rejects_non_commit_hex() {
  _ingest_case branch_from_badhex "0000000000000000000000000000000000000000" \
    "STATUS=SUCCESS" "" 1 "does not resolve to a valid commit"
}

# Given: no .export-status and no --branch-from
# When:  metadata is ingested
# Then:  the call errors
# Asserts: the missing-file refusal, distinct from a missing fork point
test_no_branch_from_errors_without_export_status() {
  _ingest_case no_branch_from "" "" "" 1 ".export-status not found"
}

# Given: .export-status but no .branch-point and no --branch-from
# When:  metadata is ingested
# Then:  the call refuses and names BRANCH_FROM
# Asserts: the package is the only default fork point
test_missing_branch_point_refused() {
  _ingest_case missing_branch_point "" "STATUS=SUCCESS
TIMESTAMP=20260420-120000" "" 1 ".branch-point has no BRANCH_POINT"
}

# Given: .branch-point without a BRANCH_POINT key
# When:  metadata is ingested without --branch-from
# Then:  the call refuses
# Asserts: a malformed package record is not treated as absent-and-defaulted
test_branch_point_missing_key_refused() {
  _ingest_case branch_point_missing_key "" "STATUS=SUCCESS
TIMESTAMP=20260420-120000" "BUNDLE=test" 1 ".branch-point has no BRANCH_POINT"
}

# Given: .branch-point with a BRANCH_POINT that is not a commit
# When:  metadata is ingested without --branch-from
# Then:  the call refuses
# Asserts: the package fork point is validated like any other base
test_branch_point_non_commit_refused() {
  _ingest_case branch_point_non_commit "" "STATUS=SUCCESS
TIMESTAMP=20260420-120000" "BUNDLE=test
BRANCH_POINT=not-a-commit" 1 "does not resolve to a valid commit"
}

# Given: .branch-point at an ancestor and .export-status INIT_SHA at HEAD
# When:  metadata is ingested without --branch-from
# Then:  the package branch point wins and no divergence warning prints
# Asserts: INIT_SHA is not the fork point
test_branch_point_wins_over_init_sha() {
  local P="$FIXTURE_DIR/branch_point_wins_p"
  make_committed_repo "$P"
  echo "extra" > "$P/extra.txt"
  git -C "$P" add extra.txt
  git -C "$P" commit -m "extra commit" --quiet
  local HEAD_SHA POINT
  HEAD_SHA=$(git -C "$P" rev-parse HEAD)
  POINT=$(git -C "$P" rev-parse HEAD~1)

  _ingest_case branch_point_wins "" "STATUS=SUCCESS
TIMESTAMP=20260420-120000
INIT_SHA=${HEAD_SHA}" "BUNDLE=test
BRANCH_POINT=${POINT}" 0 "" "$POINT" empty
}

# Given: a valid .branch-point and an explicit --branch-from at a different commit
# When:  metadata is ingested
# Then:  the explicit base wins and the override is named
# Asserts: the operator override remains authoritative
test_explicit_branch_from_overrides_branch_point() {
  local P="$FIXTURE_DIR/branch_from_override_p"
  make_committed_repo "$P"
  echo "extra" > "$P/extra.txt"
  git -C "$P" add extra.txt
  git -C "$P" commit -m "extra commit" --quiet
  local HEAD_SHA POINT
  HEAD_SHA=$(git -C "$P" rev-parse HEAD)
  POINT=$(git -C "$P" rev-parse HEAD~1)

  _ingest_case branch_from_override "$HEAD_SHA" "STATUS=SUCCESS
TIMESTAMP=20260420-120000" "BUNDLE=test
BRANCH_POINT=${POINT}" 0 "overrides the package branch point" "$HEAD_SHA"
}

# Given: a malformed .branch-point and a valid explicit --branch-from
# When:  metadata is ingested
# Then:  the explicit value is attempted and the package point is reported ignored
# Asserts: malformed package metadata does not outrank the operator
test_explicit_branch_from_survives_malformed_branch_point() {
  local P="$FIXTURE_DIR/branch_from_bad_p"
  make_committed_repo "$P"
  local HEAD_SHA
  HEAD_SHA=$(git -C "$P" rev-parse HEAD)

  _ingest_case branch_from_bad "$HEAD_SHA" "STATUS=SUCCESS
TIMESTAMP=20260420-120000" "BUNDLE=test
BRANCH_POINT=not-a-commit" 0 "does not resolve; using BRANCH_FROM" "$HEAD_SHA"
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

# Given: a diff with an empty .msg sibling and a subject in its filename
# When:  draft_resolve_commit_message runs
# Then:  the empty .msg is skipped and the filename subject is returned
# Asserts: the non-empty gate on the .msg priority.
test_resolve_empty_msg_falls_through_to_filename() {
  local TMP="$FIXTURE_DIR/resolve_empty_msg"
  mkdir -p "$TMP"
  echo "dummy" > "$TMP/0001-abc1234-fix_widget.diff"
  : > "$TMP/0001-abc1234-fix_widget.msg"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234-fix_widget.diff")
  assert_eq "$MSG" "fix widget" "draft_resolve_commit_message skips an empty .msg and uses the filename subject"
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
  make_session_fixture "$EXPORT" 2 content "$(git -C "$P" rev-parse HEAD)"

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  # Patches are committed; uncommitted.diff is applied to the working tree
  # only (draft_apply_uncommitted does not commit  --  see draft.sh contract).
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$P" log main..HEAD --reverse --format='%s' | wc -l | tr -d ' ')
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
# Asserts: the dirty-tree refusal and its stash hint, under no force
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

# Given: a session export reachable through the script's own source resolution
# When:  draft.sh runs as a script with explicit flags
# Then:  it creates the draft branch and commits every patch
# Asserts: main's non-interactive path - argument parse, channel default, orchestration
test_draft_script_entry_creates_branch() {
  make_draft_script_fixture draft_script_entry 2

  local OUT RC=0
  OUT=$(bash "$AGENT_SANDBOX_REPO/scripts/workflows/draft.sh" \
    --project="$P" --sandbox="$S" --bundle="$BUNDLE" 2>&1) || RC=$?

  local BRANCH COUNT
  BRANCH=$(draft_branch "$P")
  COUNT=$(git -C "$P" rev-list --count HEAD 2>/dev/null || echo 0)
  if [[ $RC -eq 0 && -n "$BRANCH" && "$COUNT" == "3" ]]; then
    pass "draft.sh entry point creates the draft branch and applies both patches"
  else
    fail "draft.sh entry point broken: rc=$RC branch='$BRANCH' count='$COUNT' out='$OUT'"
  fi
}

# Given: an interactive draft with both channel and bundle named
# When:  the script runs with the confirmation answered yes
# Then:  the draft branch is created and the equivalent command is named
# Asserts: the both-given interactive path - preview, confirm, in-process run
test_draft_interactive_channel_and_bundle() {
  make_draft_script_fixture draft_interactive 2

  local OUT RC=0
  OUT=$(printf 'y\n' | bash "$AGENT_SANDBOX_REPO/scripts/workflows/draft.sh" \
    --project="$P" --sandbox="$S" --channel=session --bundle="$BUNDLE" --interactive 2>&1) || RC=$?

  local BRANCH
  BRANCH=$(draft_branch "$P")
  if [[ $RC -eq 0 && -n "$BRANCH" \
     && "$OUT" == *"Running: make draft FROM=session BUNDLE=$BUNDLE"* ]]; then
    pass "interactive draft with channel and bundle drafts through the in-process path"
  else
    fail "interactive draft broken: rc=$RC branch='$BRANCH' out='$OUT'"
  fi
}

# Given: an .export-status present but without TIMESTAMP
# When:  metadata is ingested with no explicit --branch-from
# Then:  the call succeeds
# Asserts: TIMESTAMP is not read by the fork-point resolution
test_ingest_ignores_missing_timestamp() {
  local P="$FIXTURE_DIR/ingest_nots_p"
  make_committed_repo "$P"
  local POINT
  POINT=$(git -C "$P" rev-parse HEAD)

  _ingest_case ingest_nots "" "STATUS=SUCCESS" "BUNDLE=test
BRANCH_POINT=${POINT}" 0 "" "$POINT" empty
}

# Given: a valid .export-status and a --branch-from naming no commit
# When:  metadata is ingested
# Then:  the refusal names the unresolved base and the flag remedy
# Asserts: the base-resolves check
test_unresolvable_branch_from_errors() {
  _ingest_case unresolvable_from "no-such-ref-123" "STATUS=SUCCESS
TIMESTAMP=20260420-120000" "" 1 "does not resolve to a valid commit"
}

# Given: a session export and a --branch-from that is an ancestor of HEAD
# When:  the orchestration runs
# Then:  the draft branch forks from the named ancestor, not from HEAD
# Asserts: the fork point and the six-character hash suffix in the branch name
test_draft_forks_from_named_base() {
  make_draft_fixture draft_fork 1

  echo "extra" > "$P/extra.txt"
  git -C "$P" add extra.txt
  git -C "$P" commit -m "extra commit" --quiet
  local EXTRA FORK
  EXTRA=$(git -C "$P" rev-parse HEAD)
  FORK=$(git -C "$P" rev-parse HEAD~1)

  _run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "$FORK" "" "" false >/dev/null 2>&1

  local BRANCH FORK_RECORD EXTRA_ANCESTOR=false
  BRANCH=$(draft_branch "$P")
  FORK_RECORD=$(git -C "$P" config --local --get "branch.${BRANCH}.agent-sandbox-fork" 2>/dev/null || true)
  git -C "$P" merge-base --is-ancestor "$EXTRA" "$BRANCH" 2>/dev/null && EXTRA_ANCESTOR=true

  if [[ -n "$BRANCH" && "$FORK_RECORD" == "$FORK" && "$EXTRA_ANCESTOR" == false \
     && "$BRANCH" =~ -[0-9a-f]{6}$ ]]; then
    pass "draft forks from the named base and names a six-character hash suffix"
  else
    fail "fork point wrong: branch='$BRANCH' extra_ancestor=$EXTRA_ANCESTOR record='$FORK_RECORD'"
  fi
}

# Given: a session export whose .branch-point names an ancestor and HEAD is ahead
# When:  the orchestration runs without --branch-from
# Then:  the draft forks at .branch-point, not at HEAD
# Asserts: the package branch point is the default and drives the recorded fork point
test_draft_forks_from_branch_point_not_head() {
  make_draft_fixture draft_branchpoint 1

  echo "extra" > "$P/extra.txt"
  git -C "$P" add extra.txt
  git -C "$P" commit -m "extra commit" --quiet
  local EXTRA POINT
  EXTRA=$(git -C "$P" rev-parse HEAD)
  POINT=$(git -C "$P" rev-parse HEAD~1)
  {
    echo "BUNDLE=$(basename "$EXPORT")"
    echo "BRANCH_POINT=${POINT}"
    echo "BASELINE_MOVED=false"
    echo "RECORDED_INIT_SHA=${POINT}"
  } > "$EXPORT/.branch-point"

  _run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" false >/dev/null 2>&1

  local BRANCH FORK_RECORD EXTRA_ANCESTOR=false
  BRANCH=$(draft_branch "$P")
  FORK_RECORD=$(git -C "$P" config --local --get "branch.${BRANCH}.agent-sandbox-fork" 2>/dev/null || true)
  git -C "$P" merge-base --is-ancestor "$EXTRA" "$BRANCH" 2>/dev/null && EXTRA_ANCESTOR=true

  if [[ -n "$BRANCH" && "$FORK_RECORD" == "$POINT" && "$EXTRA_ANCESTOR" == false \
     && "$BRANCH" == *-"${POINT:0:6}" ]]; then
    pass "draft forks at .branch-point, not at HEAD"
  else
    fail "branch-point default wrong: branch='$BRANCH' extra_ancestor=$EXTRA_ANCESTOR record='$FORK_RECORD'"
  fi
}

# Given: a patches directory and a range missing an endpoint
# When:  draft_collect_patches runs
# Then:  it refuses with the expected-format message
# Asserts: the invalid-range refusal
test_collect_patches_invalid_range_errors() {
  make_draft_fixture collect_bad_range 1

  local OUT RC=0
  OUT=$(draft_collect_patches "$EXPORT/patches" "..5" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"invalid DIFFS range format"* ]]; then
    pass "draft_collect_patches refuses a range with a missing endpoint"
  else
    fail "invalid-range refusal wrong: rc=$RC out='$OUT'"
  fi
}

# Given: a patches directory whose only patch is outside the range
# When:  draft_collect_patches runs
# Then:  it refuses with the no-diffs-in-range message
# Asserts: the empty-range refusal
test_collect_patches_empty_range_errors() {
  make_draft_fixture collect_empty_range 1

  local OUT RC=0
  OUT=$(draft_collect_patches "$EXPORT/patches" "9..9" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"no diffs in range 9..9 found"* ]]; then
    pass "draft_collect_patches refuses a range that matches no patch"
  else
    fail "empty-range refusal wrong: rc=$RC out='$OUT'"
  fi
}

# Given: a source directory that does not exist
# When:  draft_run runs
# Then:  it refuses and names the missing source
# Asserts: the source-directory guard
test_draft_run_missing_source_errors() {
  make_draft_fixture draft_run_nosrc 1
  local BASE
  BASE=$(git -C "$P" rev-parse HEAD)

  local OUT RC=0
  OUT=$(draft_run "$P" "$FIXTURE_DIR/no_such_source" "$(basename "$EXPORT")" "$BASE" "" "1" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"source not found"* ]]; then
    pass "draft_run refuses a source directory that does not exist"
  else
    fail "source guard wrong: rc=$RC out='$OUT'"
  fi
}

# Given: a source directory without a patches directory and a nonzero count
# When:  draft_run runs
# Then:  it refuses and names the missing patches directory
# Asserts: the patches-or-zero-count guard
test_draft_run_missing_patches_errors() {
  local P="$FIXTURE_DIR/draft_run_nopatches_p"
  local SRC="$FIXTURE_DIR/draft_run_nopatches_src"
  make_committed_repo "$P"
  mkdir -p "$SRC"
  local BASE
  BASE=$(git -C "$P" rev-parse HEAD)

  local OUT RC=0
  OUT=$(draft_run "$P" "$SRC" "20260420-120000-test-branch" "$BASE" "" "1" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"no patches/ in"* ]]; then
    pass "draft_run refuses a nonzero count without a patches directory"
  else
    fail "patches guard wrong: rc=$RC out='$OUT'"
  fi
}

# Given: a valid source and an empty patch count
# When:  draft_run runs
# Then:  it aborts on the required count parameter
# Asserts: the required-count guard
test_draft_run_requires_diff_count() {
  make_draft_fixture draft_run_count 1
  local BASE
  BASE=$(git -C "$P" rev-parse HEAD)

  local OUT RC=0
  OUT=$(draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "$BASE" "" "" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"DIFF_COUNT"* ]]; then
    pass "draft_run aborts when the patch count parameter is empty"
  else
    fail "required-count guard wrong: rc=$RC out='$OUT'"
  fi
}

# Given: a dirty working tree and FORCE=true
# When:  the orchestration runs
# Then:  the clean-tree guard still refuses and no draft branch is created
# Asserts: force never bypasses the draft clean-tree guard
test_draft_force_does_not_bypass_clean_tree() {
  make_draft_fixture draft_force_dirty 1
  echo "wip" >> "$P/file.txt"

  local OUT RC=0
  OUT=$(_run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" true 2>&1) || RC=$?

  local LEFT
  LEFT=$(git -C "$P" branch --list 'draft/*')
  if [[ $RC -ne 0 && "$OUT" == *"requires a clean working tree"* && -z "$LEFT" ]]; then
    pass "force does not bypass the draft clean-tree guard"
  else
    fail "force bypassed the clean-tree guard: rc=$RC draft='$LEFT' out='$OUT'"
  fi
}

# Given: patches that apply and an uncommitted.diff that cannot
# When:  the orchestration runs
# Then:  it rolls back to the source branch and deletes the draft branch
# Asserts: the rollback on an uncommitted-apply failure
test_draft_uncommitted_failure_rolls_back() {
  make_draft_fixture draft_uc_rollback 1

  cat > "$EXPORT/uncommitted.diff" <<'EOF'
diff --git a/file-1.txt b/file-1.txt
new file mode 100644
--- /dev/null
+++ b/file-1.txt
@@ -0,0 +1 @@
+conflicting
EOF

  local PRE
  PRE=$(git -C "$P" rev-list --count main)

  local RC=0
  _run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" false >/dev/null 2>&1 || RC=$?

  local CURR LEFT POST
  CURR=$(_current_branch "$P")
  LEFT=$(git -C "$P" branch --list 'draft/*')
  POST=$(git -C "$P" rev-list --count main)
  if [[ $RC -ne 0 && "$CURR" == "main" && -z "$LEFT" \
     && "$POST" == "$PRE" && ! -f "$P/file-1.txt" ]]; then
    pass "an uncommitted-apply failure rolls back to the fork point and deletes the draft"
  else
    fail "uncommitted rollback broken: rc=$RC branch='$CURR' draft='$LEFT' count='$PRE->$POST'"
  fi
}

# Given: a recorded source branch that no longer exists
# When:  _draft_rollback runs
# Then:  it detaches at the recorded fork point and deletes the draft
# Asserts: the rollback target is the record's fork, not the draft tip or source.
test_draft_rollback_detaches_at_fork_when_source_missing() {
  local P="$FIXTURE_DIR/draft_rollback_missing_source_p"
  make_committed_repo "$P"
  local BASE
  BASE=$(git -C "$P" rev-parse HEAD)
  git -C "$P" checkout -b "draft/missing-source" --quiet
  echo "partial" > "$P/partial.txt"
  git -C "$P" add partial.txt
  git -C "$P" commit -m "partial draft" --quiet
  draft_record_write "$P" "draft/missing-source" "gone" "$BASE"

  local RC=0
  _draft_rollback "$P" "gone" "draft/missing-source" >/dev/null 2>&1 || RC=$?

  local HEAD_SHA="" EXISTS=no
  HEAD_SHA=$(git -C "$P" rev-parse HEAD 2>/dev/null || true)
  git -C "$P" show-ref --verify --quiet "refs/heads/draft/missing-source" && EXISTS=yes
  if [[ $RC -eq 0 && "$HEAD_SHA" == "$BASE" && "$EXISTS" == no ]]; then
    pass "rollback detaches at the recorded fork when the source branch is gone"
  else
    fail "missing-source rollback wrong: rc=$RC head='$HEAD_SHA' base='$BASE' draft=$EXISTS"
  fi
}

# Given: a record on a branch outside draft/*
# When:  _draft_rollback runs
# Then:  the branch is not deleted
# Asserts: the destructive delete guard is scoped to draft branches.
test_draft_rollback_keeps_non_draft_branch() {
  local P="$FIXTURE_DIR/draft_rollback_nondraft_p"
  make_committed_repo "$P"
  local BASE
  BASE=$(git -C "$P" rev-parse HEAD)
  git -C "$P" checkout -b "sidelined" --quiet
  draft_record_write "$P" "sidelined" "main" "$BASE"

  local RC=0
  _draft_rollback "$P" "main" "sidelined" >/dev/null 2>&1 || RC=$?

  local EXISTS=no
  git -C "$P" show-ref --verify --quiet "refs/heads/sidelined" && EXISTS=yes
  if [[ $RC -eq 0 && "$EXISTS" == yes ]]; then
    pass "rollback keeps a branch outside draft/*"
  else
    fail "rollback deleted a non-draft branch: rc=$RC exists=$EXISTS"
  fi
}

# Given: an export with no patches and a non-empty uncommitted.diff
# When:  the production orchestration runs
# Then:  the draft branch is created and uncommitted.diff lands in the tree
# Asserts: the uncommitted-only source path
test_draft_uncommitted_only_source() {
  local P="$FIXTURE_DIR/draft_uc_only_p"
  local S="$FIXTURE_DIR/draft_uc_only_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-uc-only"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 0 content "$(git -C "$P" rev-parse HEAD)"

  local RC=0
  _run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" false >/dev/null 2>&1 || RC=$?

  local BRANCH
  BRANCH=$(draft_branch "$P")
  if [[ $RC -eq 0 && -n "$BRANCH" && -f "$P/uncommitted.txt" ]]; then
    pass "a source with only uncommitted.diff drafts without a patch count"
  else
    fail "uncommitted-only path broken: rc=$RC branch='$BRANCH'"
  fi
}

# Given: a source with patches and no uncommitted.diff
# When:  the production orchestration runs
# Then:  the run completes applying only the patches
# Asserts: the absence branch of the uncommitted presence check
test_draft_patches_without_uncommitted() {
  make_draft_fixture draft_no_uc 1

  local OUT RC=0
  OUT=$(_run_draft_workflow "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" false 2>&1) || RC=$?

  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  if [[ $RC -eq 0 && "$COUNT" == "2" && "$OUT" != *"failed to apply uncommitted.diff"* ]]; then
    pass "a source without uncommitted.diff applies only the patches"
  else
    fail "absence of uncommitted.diff not handled: rc=$RC count=$COUNT out='$OUT'"
  fi
}

# Given: a conflicting patch applied through the draft apply loop
# When:  the loop runs with FORCE
# Then:  the conflict is tolerated and the commit lands
# Asserts: draft_apply_patches forwards FORCE to apply_and_commit
test_draft_apply_patches_forwards_force() {
  local P="$FIXTURE_DIR/draft_force_forward_p"
  make_committed_repo "$P"
  local AUTHOR
  AUTHOR="$(git -C "$P" config user.name) <$(git -C "$P" config user.email)>"

  echo "changed" > "$P/file.txt"
  git -C "$P" diff > "$FIXTURE_DIR/draft_force_forward.diff"
  git -C "$P" checkout -- file.txt
  echo "other" > "$P/file.txt"
  git -C "$P" add file.txt
  git -C "$P" commit -m "other" --quiet

  local RC=0
  echo "$FIXTURE_DIR/draft_force_forward.diff" | draft_apply_patches "$P" "$AUTHOR" true >/dev/null 2>&1 || RC=$?

  local MSG
  MSG=$(git -C "$P" log -1 --format=%s)
  if [[ $RC -eq 0 && "$MSG" == "Apply draft_force_forward.diff" ]]; then
    pass "draft_apply_patches forwards force so a conflicting patch still commits"
  else
    fail "force forwarding broken: rc=$RC msg='$MSG'"
  fi
}

# =============================================================================
# Run all
# =============================================================================
run_test test_draft_creates_branch
run_test test_draft_requires_bundle
run_test test_draft_script_entry_creates_branch
run_test test_draft_interactive_channel_and_bundle
run_test test_draft_applies_diffs
run_test test_draft_applies_uncommitted_diff

run_test test_branch_from_skips_missing_export_status
run_test test_branch_from_rejects_non_commit_hex
run_test test_no_branch_from_errors_without_export_status
run_test test_ingest_ignores_missing_timestamp
run_test test_unresolvable_branch_from_errors
run_test test_missing_branch_point_refused
run_test test_branch_point_missing_key_refused
run_test test_branch_point_non_commit_refused
run_test test_branch_point_wins_over_init_sha
run_test test_explicit_branch_from_overrides_branch_point
run_test test_explicit_branch_from_survives_malformed_branch_point

run_test test_draft_branch_name_format
run_test test_draft_branch_name_with_summary
run_test test_draft_writes_branch_record
run_test test_draft_branch_creation_failure_clears_record
run_test test_draft_rejects_same_name_collision
run_test test_draft_rejects_when_on_draft_branch
run_test test_draft_allows_distinct_branch_identities
run_test test_draft_branch_from
run_test test_draft_forks_from_named_base
run_test test_draft_forks_from_branch_point_not_head
run_test test_draft_diffs_range
run_test test_draft_unparseable_export_name_still_drafts
run_test test_collect_patches_invalid_range_errors
run_test test_collect_patches_empty_range_errors
run_test test_draft_no_diffs_error
run_test test_draft_run_missing_source_errors
run_test test_draft_run_missing_patches_errors
run_test test_draft_run_requires_diff_count
run_test test_draft_fails_on_dirty_working_tree
run_test test_draft_force_does_not_bypass_clean_tree
run_test test_draft_fails_on_unreadable_working_tree
run_test test_draft_failure_returns_to_source_branch
run_test test_draft_failure_deletes_draft_branch
run_test test_draft_uncommitted_failure_rolls_back
run_test test_draft_rollback_detaches_at_fork_when_source_missing
run_test test_draft_rollback_keeps_non_draft_branch
run_test test_draft_uncommitted_only_source
run_test test_draft_patches_without_uncommitted
run_test test_draft_apply_patches_forwards_force
run_test test_draft_strips_index_lines
run_test test_draft_resets_author_to_operator
run_test test_draft_commit_messages

run_test test_resolve_msg_file_used
run_test test_resolve_empty_msg_falls_through_to_filename
run_test test_resolve_filename_subject_cleaned
run_test test_resolve_filename_subject_trim_underscores
run_test test_resolve_fallback_no_subject
run_test test_resolve_msg_file_preferred_over_filename

# Given: a project whose source branch is an ancestor of the draft tip
# When:  the confirm hint prints
# Then:  it names the rebase and fast-forward route
# Asserts: the hint matches what `make confirm` can actually do
test_draft_hint_routes_to_fast_forward_when_ancestor() {
  make_draft_fixture draft_ffroute 1
  local SRC POINT
  SRC=$(git -C "$P" rev-parse --abbrev-ref HEAD)
  POINT=$(git -C "$P" rev-parse HEAD)

  local OUT
  OUT=$(draft_print_confirm_hint "$P" "$SRC" "$POINT" 2>&1)

  local OK=true
  [[ "$OUT" == *"Branch point: ${POINT:0:7}"* ]] || OK=false
  [[ "$OUT" == *"git rebase -i"* ]] || OK=false
  [[ "$OUT" == *"make confirm TARGET_BRANCH=$SRC"* ]] || OK=false
  [[ "$OUT" != *"NEW=1"* ]] || OK=false

  if [[ "$OK" == true ]]; then
    pass "draft names the fast-forward route when the source branch is an ancestor"
  else
    fail "hint did not route to fast-forward: $OUT"
  fi
}

# Given: a project whose source branch tip is not an ancestor of the draft tip
# When:  the confirm hint prints
# Then:  it names the soft-reset route and never the fast-forward one
# Asserts: the state a container-side rebase leaves the host in
test_draft_hint_routes_to_soft_reset_when_not_fast_forwardable() {
  make_draft_fixture draft_softreset 1

  # A parentless fork of the same tree: the state a rewritten history leaves
  # behind, and not an ancestor of HEAD.
  local TREE
  TREE=$(git -C "$P" rev-parse "HEAD^{tree}")
  local FORKED
  FORKED=$(git -C "$P" commit-tree "$TREE" -m "rewritten history")
  local SRC="rewritten-source"
  git -C "$P" branch -f "$SRC" "$FORKED"

  local POINT
  POINT=$(git -C "$P" rev-parse HEAD)

  local OUT
  OUT=$(draft_print_confirm_hint "$P" "$SRC" "$POINT" 2>&1)

  local OK=true
  [[ "$OUT" == *"Branch point: ${POINT:0:7}"* ]] || OK=false
  [[ "$OUT" == *"cannot fast-forward"* ]] || OK=false
  [[ "$OUT" == *"NEW=1"* ]] || OK=false
  [[ "$OUT" != *"git rebase -i"* ]] || OK=false
  # The untouched-branch fact is what no other host step prints.
  [[ "$OUT" == *"untouched"* ]] || OK=false

  if [[ "$OK" == true ]]; then
    pass "draft names the soft-reset route when the source branch cannot fast-forward"
  else
    fail "hint did not route to soft-reset: $OUT"
  fi
}
run_test test_draft_hint_routes_to_fast_forward_when_ancestor
run_test test_draft_hint_routes_to_soft_reset_when_not_fast_forwardable

test_done
