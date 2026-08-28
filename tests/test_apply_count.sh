#!/usr/bin/env bash
# tests/test_apply_count.sh
# Pins the reachable file-count reporting of scripts/workflows/apply.sh:
# an applicable diff reports its header count exactly once
# ("Files changed: N", single line).
#
# Also pins the decided empty-diff behavior (roadmap "Empty
# uncommitted.diff"): empty uncommitted.diff skips with a warning, empty
# bundle members land as message-bearing empty commits with a warning.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

export AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/apply.sh"
source "$REPO_ROOT/scripts/workflows/draft.sh"

# _make_repo <dir> -- minimal git repo with one commit (validate_project_dir
# requires at least one commit).
_make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@t.local
  git -C "$dir" config user.name t
  echo base > "$dir/file.txt"
  git -C "$dir" add -A
  git -C "$dir" commit -qm init
}

test_apply_run_single_file_diff_reports_one() {
  local repo="$FIXTURE_DIR/repo_one"
  _make_repo "$repo"

  local diff_file="$FIXTURE_DIR/one.diff"
  cat > "$diff_file" <<'EOF'
diff --git a/file.txt b/file.txt
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-base
+changed
EOF

  local OUT RC=0
  OUT=$(apply_run "$repo" "$diff_file" "" false </dev/null) || RC=$?

  local count_lines zero_line
  count_lines=$(grep -c "Files changed:" <<<"$OUT")
  zero_line=$(grep "Files changed:" <<<"$OUT")

  if [[ $RC -eq 0 && "$count_lines" == "1" && "$zero_line" == "Done. Files changed: 1" ]]; then
    pass "single-file diff reports exactly one 'Files changed: 1'"
  else
    fail "expected single 'Done. Files changed: 1' rc=0, got rc=$RC ($count_lines x): '$zero_line'"
  fi
}

test_apply_run_multi_file_diff_reports_exact_count() {
  local repo="$FIXTURE_DIR/repo_two"
  _make_repo "$repo"
  # Second tracked file (modifications, not creations -- this git build
  # rejects /dev/null-source hunks lacking index metadata).
  echo second > "$repo/second.txt"
  git -C "$repo" add -A
  git -C "$repo" -c user.email=t@t.local -c user.name=t commit -qm second

  local diff_file="$FIXTURE_DIR/two.diff"
  cat > "$diff_file" <<'EOF'
diff --git a/file.txt b/file.txt
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-base
+changed
diff --git a/second.txt b/second.txt
--- a/second.txt
+++ b/second.txt
@@ -1 +1 @@
-second
+updated
EOF

  local OUT RC=0
  OUT=$(apply_run "$repo" "$diff_file" "" false </dev/null) || RC=$?

  local count_lines zero_line
  count_lines=$(grep -c "Files changed:" <<<"$OUT")
  zero_line=$(grep "Files changed:" <<<"$OUT")

  if [[ $RC -eq 0 && "$count_lines" == "1" && "$zero_line" == "Done. Files changed: 2" ]]; then
    pass "two-file diff reports exactly one 'Files changed: 2'"
  else
    fail "expected single 'Done. Files changed: 2' rc=0, got rc=$RC ($count_lines x): '$zero_line'"
  fi
}

test_apply_run_empty_diff_skips_with_warning() {
  local repo="$FIXTURE_DIR/repo_empty_apply"
  _make_repo "$repo"
  local base_commit
  base_commit=$(git -C "$repo" rev-parse HEAD)

  local diff_file="$FIXTURE_DIR/empty.diff"
  : > "$diff_file"

  local ERR RC=0
  ERR=$(apply_run "$repo" "$diff_file" "" false </dev/null 2>&1 >/dev/null) || RC=$?

  if [[ $RC -eq 0 \
     && "$ERR" == *"is empty; nothing to apply"* \
     && $(git -C "$repo" rev-parse HEAD) == "$base_commit" ]]; then
    pass "empty diff: apply_run skips with warning, tree and HEAD unchanged"
  else
    fail "expected rc=0 + skip warning + unchanged HEAD, got rc=$RC err='$ERR'"
  fi
}

test_apply_and_commit_empty_diff_lands_message_bearing_empty_commit() {
  local repo="$FIXTURE_DIR/repo_empty_member"
  _make_repo "$repo"
  local base_commit
  base_commit=$(git -C "$repo" rev-parse HEAD)

  local diff_file="$FIXTURE_DIR/empty_member.diff"
  : > "$diff_file"

  local ERR RC=0
  ERR=$(apply_and_commit "$repo" "$diff_file" "feat: message survives" "T <t@t.local>" false </dev/null 2>&1 >/dev/null) || RC=$?

  local new_msg new_author is_empty=no
  new_msg=$(git -C "$repo" log -1 --format=%s)
  new_author=$(git -C "$repo" log -1 --format='%an <%ae>')
  # Empty commit: tree identical to its sole parent.
  [[ $(git -C "$repo" rev-parse 'HEAD^{tree}') == $(git -C "$repo" rev-parse 'HEAD~1^{tree}') ]] && is_empty=yes

  if [[ $RC -eq 0 \
     && "$ERR" == *"creating an empty commit for its message"* \
     && "$new_msg" == "feat: message survives" \
     && "$new_author" == "T <t@t.local>" \
     && "$is_empty" == yes ]]; then
    pass "empty member: message-bearing empty commit created with author preserved"
  else
    fail "expected empty commit w/ message+author, got rc=$RC msg='$new_msg' author='$new_author' empty=$is_empty err='$ERR'"
  fi
}

test_draft_apply_uncommitted_empty_diff_skips_with_warning() {
  local repo="$FIXTURE_DIR/repo_empty_uncommitted"
  _make_repo "$repo"
  local src_dir="$FIXTURE_DIR/src_empty_uc"
  mkdir -p "$src_dir"
  : > "$src_dir/uncommitted.diff"
  local base_commit
  base_commit=$(git -C "$repo" rev-parse HEAD)

  local OUT RC=0
  OUT=$(draft_apply_uncommitted "$repo" "$src_dir" "t <t@t.local>" false </dev/null 2>&1) || RC=$?

  if [[ $RC -eq 0 \
     && "$OUT" == *"contains no changes; skipping"* \
     && $(git -C "$repo" rev-parse HEAD) == "$base_commit" ]]; then
    pass "empty uncommitted.diff: skipped with warning, rc=0"
  else
    fail "expected rc=0 + skip warning, got rc=$RC out='$OUT'"
  fi
}

# =============================================================================
# Run
# =============================================================================

run_test test_apply_run_single_file_diff_reports_one
run_test test_apply_run_multi_file_diff_reports_exact_count
run_test test_apply_run_empty_diff_skips_with_warning
run_test test_apply_and_commit_empty_diff_lands_message_bearing_empty_commit
run_test test_draft_apply_uncommitted_empty_diff_skips_with_warning

test_done test_apply_count.sh
