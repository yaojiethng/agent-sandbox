#!/usr/bin/env bash
# tests/test_draft_workflow.sh
# Tests for libs/draft_workflow.sh
#
# Covers:
#   draft_run   — creates branch, applies patches, .draft-state, guards
#   confirm_run — rebases, merges, deletes branch
#   reject_run  — returns to source, deletes branch
#
# Uses synthetic diffs (make_export_with_diffs) for all cases except
# author-rewrite and commit-message tests, which need make_real_session.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/draft_workflow.sh"
source "$SCRIPT_DIR/libs/git_fixtures.sh"
source "$SCRIPT_DIR/libs/session_fixtures.sh"

PASS=0
FAIL=0
FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_test() {
  echo "[ $1 ]"
  $1 || true
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
  mkdir -p "$SESSION_DIR/session/patches"

  # Write EXPORT-TIME.txt
  echo "20260408-120000" > "$SESSION_DIR/session/EXPORT-TIME.txt"

  # Write numbered .diff files (index-stripped) from BASELINE_SHA..HEAD
  local COMMIT_NUM=1
  local PREV_SHA="$BASELINE_SHA"
  for COMMIT_SHA in $(git -C "$SANDBOX" rev-list "${BASELINE_SHA}..HEAD" --reverse); do
    local PADDING
    PADDING=$(printf "%04d" "$COMMIT_NUM")
    git -C "$SANDBOX" diff "${PREV_SHA}..${COMMIT_SHA}" \
      | grep -v '^index ' \
      | sed 's/[[:space:]]*$//' \
      | sed -e '$a\' \
      > "$SESSION_DIR/session/patches/${PADDING}-${COMMIT_SHA}.diff"
    PREV_SHA="$COMMIT_SHA"
    COMMIT_NUM=$((COMMIT_NUM + 1))
  done

  # Write staged.diff and changes.diff
  git -C "$SANDBOX" diff --binary -M "${BASELINE_SHA}..HEAD" \
    > "$SESSION_DIR/session/staged.diff"
  > "$SESSION_DIR/session/changes.diff"
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
  make_export_with_diffs "$EXPORT" 2

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1

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
  make_export_with_diffs "$EXPORT" 2

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1

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
  make_export_with_diffs "$EXPORT" 1

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1

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
  make_export_with_diffs "$EXPORT" 1

  draft_run "$P" "$S" "$EXPORT" "" "" "my-feature" >/dev/null 2>&1

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
  make_export_with_diffs "$EXPORT" 2

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1

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
  make_export_with_diffs "$EXPORT" 3

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1

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
  make_export_with_diffs "$EXPORT" 1

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1
  git -C "$P" checkout main --quiet

  local OUT
  OUT=$(draft_run "$P" "$S" "$EXPORT" "" "" "" 2>&1) || true
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
  make_export_with_diffs "$EXPORT" 1

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1

  local OUT
  OUT=$(draft_run "$P" "$S" "$EXPORT" "" "" "" 2>&1) || true
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
  make_export_with_diffs "$EXPORT1" 1
  make_export_with_diffs "$EXPORT2" 1

  draft_run "$P" "$S" "$EXPORT1" "" "" "" >/dev/null 2>&1
  git -C "$P" checkout main --quiet
  draft_run "$P" "$S" "$EXPORT2" "" "" "" >/dev/null 2>&1

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
  make_export_with_diffs "$EXPORT" 2

  echo "extra" > "$P/extra.txt"
  git -C "$P" add extra.txt
  git -C "$P" commit -m "extra commit" --quiet
  local FROM_HASH
  FROM_HASH=$(git -C "$P" rev-parse HEAD)

  draft_run "$P" "$S" "$EXPORT" "$FROM_HASH" "" "" >/dev/null 2>&1

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
  make_export_with_diffs "$EXPORT" 4

  draft_run "$P" "$S" "$EXPORT" "" "2..3" "" >/dev/null 2>&1

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
  echo "20260420-120000" > "$EXPORT/session/EXPORT-TIME.txt"
  > "$EXPORT/session/changes.diff"

  local OUT
  OUT=$(draft_run "$P" "$S" "$EXPORT" "" "" "" 2>&1) || true
  if [[ "$OUT" == *"no patches/ directory"* || "$OUT" == *"no .diff files"* ]]; then
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
  mkdir -p "$EXPORT/session/patches"
  echo "20260420-120000" > "$EXPORT/session/EXPORT-TIME.txt"
  > "$EXPORT/session/changes.diff"

  cat > "$EXPORT/session/patches/0001-test.diff" <<'EOF'
diff --git a/stripped.txt b/stripped.txt
new file mode 100644
index 0000000..8a963d6
--- /dev/null
+++ b/stripped.txt
@@ -0,0 +1 @@
+stripped content
EOF

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1

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

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1

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

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1

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
# CONFIRM tests
# =============================================================================

test_confirm_deletes_draft_branch() {
  local P="$FIXTURE_DIR/confirm_del_p"
  local S="$FIXTURE_DIR/confirm_del_s"
  local EXPORT="$S/.workspace/session-diffs/20260420-120000-test-branch"
  make_committed_repo "$P"
  mkdir -p "$S/.workspace"
  make_export_with_diffs "$EXPORT" 2

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1
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
  make_export_with_diffs "$EXPORT" 2

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1
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
  make_export_with_diffs "$EXPORT" 2

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1
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
  make_export_with_diffs "$EXPORT" 1

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1
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
  make_export_with_diffs "$EXPORT" 1

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1
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
  make_export_with_diffs "$EXPORT" 1

  draft_run "$P" "$S" "$EXPORT" "" "" "" >/dev/null 2>&1
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

run_test test_confirm_deletes_draft_branch
run_test test_confirm_merges_changes
run_test test_confirm_target_branch
run_test test_confirm_rejects_non_draft_branch
run_test test_confirm_conflict_recovery

run_test test_reject_returns_to_source
run_test test_reject_deletes_draft_branch
run_test test_reject_rejects_non_draft

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
