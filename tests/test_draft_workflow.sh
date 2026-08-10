#!/usr/bin/env bash
# tests/test_draft_workflow.sh
# Tests for libs/draft_workflow.sh
#
# Covers:
#   draft_run   — creates branch, applies patches, .draft-state, guards
#   confirm_run — rebases, merges, deletes branch
#   reject_run  — returns to source, deletes branch
#
# Uses make_session_fixture for synthetic session exports; for
# author-rewrite and commit-message tests, which need make_real_session.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/draft.sh"
source "$REPO_ROOT/scripts/workflows/confirm.sh"
source "$REPO_ROOT/scripts/workflows/reject.sh"
source "$REPO_ROOT/scripts/guards.sh"
source "$TEST_DIR/libs/git_fixtures.sh"
source "$TEST_DIR/libs/session_fixtures.sh"

# =============================================================================
# _test_draft_run — backward-compat wrapper for old draft_run callers
#
# Replicates the old draft_run contract (create branch + apply patches +
# apply uncommitted) using the new decomposed functions.
# Signature matches old draft_run: PROJECT_DIR SOURCE_DIR SESSION_NAME
# BRANCH_FROM DIFFS BRANCH_SUMMARY
# =============================================================================
_test_draft_run() {
  local PROJECT_DIR="$1" SOURCE_DIR="$2" SESSION_NAME="$3"
  local BRANCH_FROM="$4" DIFFS="$5" BRANCH_SUMMARY="$6"

  local PATCHES_DIR="$SOURCE_DIR/patches"
  local PATCH_LIST
  PATCH_LIST=$(draft_collect_patches "$PATCHES_DIR" "$DIFFS" || true)
  local DIFF_COUNT
  DIFF_COUNT=$(echo "$PATCH_LIST" | grep -c . || true)
  if [[ "$DIFF_COUNT" -eq 0 ]]; then
    echo "Error: no .diff files found in $PATCHES_DIR" >&2
    return 1
  fi

  draft_run "$PROJECT_DIR" "$SOURCE_DIR" "$SESSION_NAME" \
    "$BRANCH_FROM" "$BRANCH_SUMMARY" "$DIFF_COUNT" || return 1

  local AUTHOR
  AUTHOR="$(git -C "$PROJECT_DIR" config user.name) <$(git -C "$PROJECT_DIR" config user.email)>"

  echo "$PATCH_LIST" | draft_apply_patches "$PROJECT_DIR" "$AUTHOR" false false || return 1
  draft_apply_uncommitted "$PROJECT_DIR" "$SOURCE_DIR" "$AUTHOR" false false || return 1
}

# current_branch DIR
_current_branch() {
  git -C "$1" rev-parse --abbrev-ref HEAD
}

# branch_exists DIR NAME
_branch_exists() {
  git -C "$1" show-ref --verify --quiet "refs/heads/$2" 2>/dev/null
}

# =============================================================================
# make_real_session — creates a session with real git-generated diffs
# for testing author rewrite and commit message format.
# =============================================================================
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
  local SESSION_NAME="${SESSION_TS}-${BRANCH}"
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION_NAME"
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
      | sed -e '$a\' \
      > "$SESSION_DIR/patches/${PADDING}-${COMMIT_SHA}.diff"
    PREV_SHA="$COMMIT_SHA"
    COMMIT_NUM=$((COMMIT_NUM + 1))
  done

  # Write all-changes.diff and uncommitted.diff
  git -C "$SANDBOX" diff --binary -M "${BASELINE_SHA}..HEAD" \
    > "$SESSION_DIR/all-changes.diff"
  > "$SESSION_DIR/uncommitted.diff"
}

# =============================================================================
# DRAFT tests
# =============================================================================

test_draft_creates_branch() {
  local P="$FIXTURE_DIR/draft_branch_p"
  local S="$FIXTURE_DIR/draft_branch_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local BRANCH
  BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)
  if [[ "$BRANCH" == draft/20260420-120000-test-branch-* ]]; then
    pass "draft creates working branch with correct name format"
  else
    fail "expected draft/* branch, got: $BRANCH"
  fi
}

test_draft_applies_diffs() {
  local P="$FIXTURE_DIR/draft_diffs_p"
  local S="$FIXTURE_DIR/draft_diffs_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  # initial + .draft-state + 2 diffs = 4
  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  if [[ "$COUNT" -eq 4 ]]; then
    pass "draft applies all diffs as commits"
  else
    fail "expected 4 commits, got $COUNT"
  fi
}

test_draft_branch_name_format() {
  local P="$FIXTURE_DIR/draft_name_p"
  local S="$FIXTURE_DIR/draft_name_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-feature-M2_3-agent"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local BRANCH
  BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)
  if [[ "$BRANCH" == draft/20260420-120000-feature-M2_3-agent-* ]]; then
    pass "draft branch name follows expected format"
  else
    fail "branch name wrong: got '$BRANCH'"
  fi
}

test_draft_branch_name_with_summary() {
  local P="$FIXTURE_DIR/draft_summary_p"
  local S="$FIXTURE_DIR/draft_summary_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "my-feature" >/dev/null 2>&1

  local BRANCH
  BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)
  if [[ "$BRANCH" == *"my-feature"* ]]; then
    pass "draft branch name uses BRANCH_SUMMARY"
  else
    fail "branch name missing summary: got '$BRANCH'"
  fi
}

test_draft_creates_draft_state_commit() {
  local P="$FIXTURE_DIR/draft_state_p"
  local S="$FIXTURE_DIR/draft_state_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)
  local FIRST_NEW
  FIRST_NEW=$(git -C "$P" rev-list main.."$DRAFT_BRANCH" --reverse | head -1)
  local MSG
  MSG=$(git -C "$P" log -1 --format=%s "$FIRST_NEW")

  if [[ "$MSG" == ".draft-state" ]]; then
    pass ".draft-state is the first new commit"
  else
    fail ".draft-state not first commit: got '$MSG'"
  fi

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

test_draft_state_has_correct_values() {
  local P="$FIXTURE_DIR/draft_vals_p"
  local S="$FIXTURE_DIR/draft_vals_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 3
  {
    echo "STATUS=SUCCESS"
    echo "TIMESTAMP=20260420-120000"
    echo "INIT_SHA=aaaaaaaaaaaaaaaaaaaa"
  } > "$EXPORT/.export-status"

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)
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

test_draft_rejects_same_name_collision() {
  local P="$FIXTURE_DIR/draft_collision_p"
  local S="$FIXTURE_DIR/draft_collision_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  git -C "$P" checkout main --quiet

  local OUT
  OUT=$(_test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" 2>&1) || true
  if [[ "$OUT" == *"draft branch already exists"* ]]; then
    pass "draft rejects same-name collision"
  else
    fail "did not reject collision: $OUT"
  fi
}

test_draft_rejects_when_on_draft_branch() {
  local P="$FIXTURE_DIR/draft_ondraft_p"
  local S="$FIXTURE_DIR/draft_ondraft_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local OUT
  OUT=$(_test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" 2>&1) || true
  if [[ "$OUT" == *"already on a draft branch"* ]]; then
    pass "draft rejects when already on a draft branch"
  else
    fail "did not reject on-draft: $OUT"
  fi
}

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
  if [[ "$COUNT" -eq 2 ]]; then
    pass "draft allows parallel draft branches"
  else
    fail "expected 2 draft branches, got $COUNT"
  fi
}

test_draft_branch_from() {
  local P="$FIXTURE_DIR/draft_from_p"
  local S="$FIXTURE_DIR/draft_from_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2

  echo "extra" > "$P/extra.txt"
  git -C "$P" add extra.txt
  git -C "$P" commit -m "extra commit" --quiet
  local FROM_HASH
  FROM_HASH=$(git -C "$P" rev-parse HEAD)

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "$FROM_HASH" "" "" >/dev/null 2>&1

  # initial + extra + .draft-state + 2 diffs = 5
  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  if [[ "$COUNT" -eq 5 ]]; then
    pass "draft BRANCH_FROM creates branch from specified commit"
  else
    fail "expected 5 commits, got $COUNT"
  fi
}

test_draft_diffs_range() {
  local P="$FIXTURE_DIR/draft_range_p"
  local S="$FIXTURE_DIR/draft_range_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 4

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "2..3" "" >/dev/null 2>&1

  # .draft-state + 2 diffs + initial = 4
  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  if [[ "$COUNT" -eq 4 ]]; then
    pass "draft DIFFS range applies only selected diffs"
  else
    fail "expected 4 commits, got $COUNT"
  fi
}

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
  > "$EXPORT/session/changes.diff"

  local OUT
  OUT=$(_test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" 2>&1) || true
  if [[ "$OUT" == *"no patches/"* || "$OUT" == *"no .diff files"* ]]; then
    pass "draft errors when no diffs found"
  else
    fail "did not error on missing diffs: $OUT"
  fi
}

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
  > "$EXPORT/uncommitted.diff"

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

test_draft_resets_author_to_operator() {
  local P="$FIXTURE_DIR/draft_author_p"
  local S="$FIXTURE_DIR/draft_author_s"
  make_committed_repo "$P"
  make_real_session "$P" "$S"
  local EXPORT="$S/.workspace/session-diffs/20260408-120000-main"

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local BAD
  BAD=$(git -C "$P" log main..HEAD --format='%ae' | grep -v "test@fixture" || true)
  if [[ -z "$BAD" ]]; then
    pass "draft resets all commit authors to operator identity"
  else
    fail "non-operator author found: $BAD"
  fi
}

test_draft_commit_messages() {
  local P="$FIXTURE_DIR/draft_msg_p"
  local S="$FIXTURE_DIR/draft_msg_s"
  make_committed_repo "$P"
  make_real_session "$P" "$S"
  local EXPORT="$S/.workspace/session-diffs/20260408-120000-main"

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  local FIRST_MSG
  FIRST_MSG=$(git -C "$P" log main..HEAD --reverse --format='%s' | head -1)
  if [[ "$FIRST_MSG" == ".draft-state" ]]; then
    pass "first commit is .draft-state"
  else
    fail "first commit should be .draft-state, got: $FIRST_MSG"
  fi

  local SECOND_MSG
  SECOND_MSG=$(git -C "$P" log main..HEAD --reverse --format='%s' | sed -n '2p')
  if [[ "$SECOND_MSG" == "Apply "* ]]; then
    pass "patch commits have generated messages"
  else
    fail "patch message should start with 'Apply', got: $SECOND_MSG"
  fi
}

# =============================================================================
# _ingest_export_metadata tests
# =============================================================================

# An explicit --branch-from skips .export-status validation entirely (the
# documented escape hatch for sources without a .export-status, e.g. legacy
# bundles). BASE_COMMIT resolves from the given ref.
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

# A draft command with no --branch-from must still error when .export-status
# is missing — the escape hatch requires an explicit fork point.
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

# INIT_SHA records the patch-generation point only (a warning signal, not the
# fork point). The exporter omits it when empty, so draft must tolerate its
# absence and default BASE_COMMIT to HEAD rather than erroring.
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

# When INIT_SHA is present in the source it feeds the divergence warning;
# verify the branch point still resolves (HEAD default) and does not error.
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
    if [[ "$BASE" == "HEAD" && -n "$INIT" ]]; then
      pass "INIT_SHA present: branch point resolves, divergence is warn-only"
    else
      fail "expected BASE=HEAD with INIT set; got BASE=$BASE INIT=$INIT"
    fi
  else
    fail "INIT_SHA present should not error"
  fi
}

# =============================================================================
# draft_resolve_commit_message tests
# =============================================================================

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

test_resolve_filename_subject_cleaned() {
  local TMP="$FIXTURE_DIR/resolve_subj"
  mkdir -p "$TMP"
  echo "dummy" > "$TMP/0001-abc1234-fix_widget_parsing.diff"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234-fix_widget_parsing.diff")
  if [[ "$MSG" == "fix widget parsing" ]]; then
    pass "draft_resolve_commit_message extracts subject from filename, cleans underscores"
  else
    fail "expected 'fix widget parsing', got '$MSG'"
  fi
}

test_resolve_filename_subject_trim_underscores() {
  local TMP="$FIXTURE_DIR/resolve_trim"
  mkdir -p "$TMP"
  # Subject with leading, trailing, and consecutive underscores
  echo "dummy" > "$TMP/0001-abc1234-__hello___world__.diff"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234-__hello___world__.diff")
  if [[ "$MSG" == "hello world" ]]; then
    pass "draft_resolve_commit_message trims and collapses underscores"
  else
    fail "expected 'hello world', got '$MSG'"
  fi
}

test_resolve_fallback_no_subject() {
  local TMP="$FIXTURE_DIR/resolve_fb"
  mkdir -p "$TMP"
  echo "dummy" > "$TMP/0001-abc1234.diff"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234.diff")
  if [[ "$MSG" == "Apply 0001-abc1234.diff" ]]; then
    pass "draft_resolve_commit_message falls back to 'Apply <basename>'"
  else
    fail "expected 'Apply 0001-abc1234.diff', got '$MSG'"
  fi
}

test_resolve_msg_file_preferred_over_filename() {
  local TMP="$FIXTURE_DIR/resolve_prefer"
  mkdir -p "$TMP"
  # Both .msg and filename subject exist — .msg should win
  echo "dummy" > "$TMP/0001-abc1234-some_subject.diff"
  echo "Message from .msg" > "$TMP/0001-abc1234-some_subject.msg"

  local MSG
  MSG=$(draft_resolve_commit_message "$TMP/0001-abc1234-some_subject.diff")
  if [[ "$MSG" == "Message from .msg" ]]; then
    pass "draft_resolve_commit_message prefers .msg over filename subject"
  else
    fail "expected 'Message from .msg', got '$MSG'"
  fi
}

test_draft_applies_uncommitted_diff() {
  local P="$FIXTURE_DIR/draft_uncomm_p"
  local S="$FIXTURE_DIR/draft_uncomm_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-uncommitted-test"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2 content

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1

  # Should have patches + uncommitted commits
  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$P" log main..HEAD --reverse --format='%s' | grep -v '^\.draft-state$' | wc -l | tr -d ' ')
  if [[ "$COMMIT_COUNT" -eq 3 ]]; then
    pass "draft_run applies patches then uncommitted.diff (3 commits: 2 patches + 1 uncommitted)"
  else
    fail "draft_run should create 3 commits, got $COMMIT_COUNT"
  fi

  # Verify uncommitted.txt was created
  if [[ -f "$P/uncommitted.txt" ]]; then
    pass "draft_run applies uncommitted.diff content (uncommitted.txt created)"
  else
    fail "draft_run should create uncommitted.txt from uncommitted.diff"
  fi
}

# =============================================================================
# CONFIRM tests
# =============================================================================

test_confirm_deletes_draft_branch() {
  local P="$FIXTURE_DIR/confirm_del_p"
  local S="$FIXTURE_DIR/confirm_del_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)

  confirm_run "$P" "$S" "" >/dev/null 2>&1

  if _branch_exists "$P" "$DRAFT_BRANCH"; then
    fail "confirm did not delete draft branch"
  else
    pass "confirm deletes draft branch"
  fi
}

test_confirm_merges_changes() {
  local P="$FIXTURE_DIR/confirm_merge_p"
  local S="$FIXTURE_DIR/confirm_merge_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  confirm_run "$P" "$S" "" >/dev/null 2>&1

  local COUNT
  COUNT=$(git -C "$P" rev-list --count main)
  if [[ "$COUNT" -ge 3 ]]; then
    pass "confirm merges changes into source branch"
  else
    fail "expected at least 3 commits on main, got $COUNT"
  fi
}

test_confirm_target_branch() {
  local P="$FIXTURE_DIR/confirm_target_p"
  local S="$FIXTURE_DIR/confirm_target_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  git -C "$P" checkout -b feature-branch --quiet
  git -C "$P" checkout main --quiet
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 2

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  confirm_run "$P" "$S" "feature-branch" >/dev/null 2>&1

  local CURR
  CURR=$(_current_branch "$P")
  if [[ "$CURR" == "feature-branch" ]]; then
    local COUNT
    COUNT=$(git -C "$P" rev-list --count feature-branch)
    if [[ "$COUNT" -ge 3 ]]; then
      pass "confirm TARGET merges to specified branch"
    else
      fail "commits not on target: expected >=3, got $COUNT"
    fi
  else
    fail "not on feature-branch after confirm: $CURR"
  fi
}

test_confirm_rejects_non_draft_branch() {
  local P="$FIXTURE_DIR/confirm_nondraft_p"
  make_committed_repo "$P"
  local S="$FIXTURE_DIR/confirm_nondraft_s"

  local OUT
  OUT=$(confirm_run "$P" "$S" "" 2>&1) || true
  if [[ "$OUT" == *"not on a draft branch"* ]]; then
    pass "confirm rejects when not on a draft branch"
  else
    fail "did not reject non-draft: $OUT"
  fi
}

test_confirm_conflict_recovery() {
  local P="$FIXTURE_DIR/confirm_conflict_p"
  local S="$FIXTURE_DIR/confirm_conflict_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)

  git -C "$P" checkout main --quiet
  echo "conflicting content" > "$P/file-1.txt"
  git -C "$P" add file-1.txt
  git -C "$P" commit -m "conflicting change" --quiet
  git -C "$P" checkout "$DRAFT_BRANCH" --quiet

  local OUT
  OUT=$(confirm_run "$P" "$S" "" 2>&1) || true

  git -C "$P" rebase --abort 2>/dev/null || true
  git -C "$P" checkout main --quiet 2>/dev/null || true
  git -C "$P" branch -D "$DRAFT_BRANCH" 2>/dev/null || true

  if [[ "$OUT" == *"Conflict rebasing"* ]]; then
    pass "confirm reports rebase conflict with recovery hints"
  else
    fail "did not report conflict: $OUT"
  fi
}

# =============================================================================
# REJECT tests
# =============================================================================

test_reject_returns_to_source() {
  local P="$FIXTURE_DIR/reject_src_p"
  local S="$FIXTURE_DIR/reject_src_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  reject_run "$P" "$S" >/dev/null 2>&1

  local CURR
  CURR=$(_current_branch "$P")
  if [[ "$CURR" == "main" ]]; then
    pass "reject returns to source branch"
  else
    fail "expected main, got: $CURR"
  fi
}

test_reject_deletes_draft_branch() {
  local P="$FIXTURE_DIR/reject_del_p"
  local S="$FIXTURE_DIR/reject_del_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_session_fixture "$EXPORT" 1

  _test_draft_run "$P" "$EXPORT" "$(basename "$EXPORT")" "" "" "" >/dev/null 2>&1
  local DRAFT_BRANCH
  DRAFT_BRANCH=$(git -C "$P" branch --list 'draft/*' | tr -d ' *' | head -1)

  reject_run "$P" "$S" >/dev/null 2>&1

  if _branch_exists "$P" "$DRAFT_BRANCH"; then
    fail "reject did not delete draft branch"
  else
    pass "reject deletes draft branch"
  fi
}

test_reject_rejects_non_draft() {
  local P="$FIXTURE_DIR/reject_nondraft_p"
  make_committed_repo "$P"
  local S="$FIXTURE_DIR/reject_nondraft_s"

  local OUT
  OUT=$(reject_run "$P" "$S" 2>&1) || true
  if [[ "$OUT" == *"not on a draft branch"* ]]; then
    pass "reject rejects when not on a draft branch"
  else
    fail "did not reject non-draft: $OUT"
  fi
}

# =============================================================================
# Run all
# =============================================================================
run_test test_draft_creates_branch
run_test test_draft_applies_diffs

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
run_test test_draft_strips_index_lines
run_test test_draft_resets_author_to_operator
run_test test_draft_commit_messages

run_test test_resolve_msg_file_used
run_test test_resolve_filename_subject_cleaned
run_test test_resolve_filename_subject_trim_underscores
run_test test_resolve_fallback_no_subject
run_test test_resolve_msg_file_preferred_over_filename

run_test test_confirm_deletes_draft_branch
run_test test_confirm_merges_changes
run_test test_confirm_target_branch
run_test test_confirm_rejects_non_draft_branch
run_test test_confirm_conflict_recovery

run_test test_reject_returns_to_source
run_test test_reject_deletes_draft_branch
run_test test_reject_rejects_non_draft

test_done
