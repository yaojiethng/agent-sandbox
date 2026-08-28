#!/usr/bin/env bash
# tests/test_apply_count.sh
# Pins the reachable file-count reporting of scripts/workflows/apply.sh:
# an applicable diff reports its header count exactly once
# ("Files changed: N", single line).
#
# Note: the zero-count branch is unreachable through public interfaces --
# `git apply` rejects a header-less/empty diff before the count runs
# ("No valid patches in input"). See roadmap "Empty uncommitted.diff"
# decision; if that decision makes empty diffs succeed, extend coverage here.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

export AGENT_SANDBOX_REPO="$REPO_ROOT"
source "$REPO_ROOT/scripts/workflows/apply.sh"

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

# =============================================================================
# Run
# =============================================================================

run_test test_apply_run_single_file_diff_reports_one
run_test test_apply_run_multi_file_diff_reports_exact_count

test_done test_apply_count.sh
