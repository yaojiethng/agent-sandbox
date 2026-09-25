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

# Given: a diff that touches one file
# When:  apply_run runs
# Then:  the report carries exactly one "Files changed: 1" line
# Asserts: single emission - the hazard the count's `|| true` and `:-0` pair guards
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

# Given: a diff that touches two files
# When:  apply_run runs
# Then:  the report carries exactly one "Files changed: 2" line
# Asserts: the count's value as well as its multiplicity
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

# Given: a zero-byte diff
# When:  apply_run runs
# Then:  rc 0, the skip warning, and HEAD unmoved
# Asserts: the empty-diff rule - the count line on this path is not asserted
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

# Given: a member diff that is empty but has a commit message
# When:  apply_and_commit runs
# Then:  an empty commit lands carrying that message, and working-tree noise is not swept in
# Asserts: the empty-member rule in the decided empty-diff behavior.
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

# Given: a repo dirtied after the diff was taken
# When:  apply_run runs with FORCE=false
# Then:  it refuses and names the stash hint
# Asserts: the clean-tree gate and its operator guidance
test_apply_run_clean_tree_guard_blocks_unstaged_changes() {
  local repo="$FIXTURE_DIR/repo_clean_guard"
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

  # Dirty the tree: an unstaged edit that conflicts with the diff target.
  echo "working-tree-edit" >> "$repo/file.txt"

  local ERR RC=0
  ERR=$(apply_run "$repo" "$diff_file" "" false </dev/null 2>&1) || RC=$?

  if [[ $RC -ne 0 \
     && "$ERR" == *"requires a clean working tree"* \
     && "$ERR" == *"Stash them (git stash) or commit them first"* ]]; then
    pass "apply blocks on a dirty tree without --force"
  else
    fail "expected clean-tree refusal, got rc=$RC err='$ERR'"
  fi
}

# Given: a repo with an untracked stray file, and a diff that still applies
# When:  apply_run runs with FORCE=true
# Then:  rc 0 with the tolerance warning, and no Error line on the path it continues
# Asserts: a continued path warns rather than refuses (two assertions)
test_apply_run_force_tolerates_dirty_tree_with_warning() {
  local repo="$FIXTURE_DIR/repo_force_dirty"
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

  # Dirty the tree with an unrelated unstaged change to a different file so the
  # patch itself still applies cleanly.
  echo "stray" > "$repo/stray.txt"
  git -C "$repo" add stray.txt

  local WARN RC=0
  WARN=$(apply_run "$repo" "$diff_file" "" true </dev/null 2>&1 >/dev/null) || RC=$?

  if [[ $RC -eq 0 && "$WARN" == *"tolerates a dirty working tree"* ]]; then
    pass "apply --force tolerates dirty tree and warns"
  else
    fail "expected force tolerance + warning, got rc=$RC warn='$WARN'"
  fi

  # A path that continues must not also emit an error: the operator sees a
  # warning, not a refusal it then ignores.
  if [[ "$WARN" != *"Error:"* ]]; then
    pass "apply --force reports a warning, never an error, on the path it continues"
  else
    fail "apply --force printed an error on a path it continues: '$WARN'"
  fi
}

# Given: an empty uncommitted.diff in the source directory
# When:  draft_apply_uncommitted runs
# Then:  rc 0, the skip warning, and HEAD unmoved
# Asserts: draft's empty-member rule (a draft.sh unit, kept with the apply count family)
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

# Given: a corrupt .git/index, so git status cannot read the tree while HEAD resolves
# When:  apply_run runs
# Then:  it refuses without the stash hint
# Asserts: the unreadable-tree arm and its distinct guidance - a dirty tree and an unreadable tree are different states
test_apply_run_unreadable_tree_refuses_without_stash_hint() {
  local repo="$FIXTURE_DIR/repo_unreadable"
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

  # A corrupt index is not a dirty tree: git status fails while HEAD resolves.
  # The operator must not be told to stash changes that do not exist.
  printf 'garbage' > "$repo/.git/index"

  local ERR RC=0
  ERR=$(apply_run "$repo" "$diff_file" "" false </dev/null 2>&1) || RC=$?

  if [[ $RC -ne 0 \
     && "$ERR" == *"cannot read the working tree state"* \
     && "$ERR" != *"Stash them"* ]]; then
    pass "apply refuses an unreadable tree without a phantom stash hint"
  else
    fail "expected unreadable-tree refusal, got rc=$RC err='$ERR'"
  fi
}

# =============================================================================
# Run
# =============================================================================

run_test test_apply_run_single_file_diff_reports_one
run_test test_apply_run_multi_file_diff_reports_exact_count
run_test test_apply_run_empty_diff_skips_with_warning
run_test test_apply_run_clean_tree_guard_blocks_unstaged_changes
run_test test_apply_run_force_tolerates_dirty_tree_with_warning
run_test test_apply_run_unreadable_tree_refuses_without_stash_hint
run_test test_apply_and_commit_empty_diff_lands_message_bearing_empty_commit
run_test test_draft_apply_uncommitted_empty_diff_skips_with_warning

test_done test_apply_count.sh
