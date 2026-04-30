#!/usr/bin/env bash
# tests/test_diff_workflow.sh
# Tests for libs/diff_workflow.sh
#
# Covers:
#   apply_run — applies a diff file directly, strips index lines,
#               optional branch checkout, force mode, missing file

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/diff_workflow.sh"
source "$SCRIPT_DIR/libs/git_fixtures.sh"

source "$SCRIPT_DIR/libs/test_common.sh"

FIXTURE_DIR="$(mktemp -d /tmp/XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# =============================================================================
# APPLY tests
# =============================================================================

test_apply_run_applies_file_directly() {
  local P="$FIXTURE_DIR/apply_direct_p"
  local DIFF_FILE="$FIXTURE_DIR/apply_direct.diff"
  make_committed_repo "$P"

  cat > "$DIFF_FILE" <<'EOF'
diff --git a/direct-file.txt b/direct-file.txt
new file mode 100644
--- /dev/null
+++ b/direct-file.txt
@@ -0,0 +1 @@
+direct change
EOF

  apply_run "$P" "$DIFF_FILE" "" false >/dev/null 2>&1

  if [[ -f "$P/direct-file.txt" ]]; then
    pass "apply_run applies diff file directly"
  else
    fail "apply_run did not apply diff file"
  fi

  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  if [[ "$COUNT" -eq 1 ]]; then
    pass "apply_run does not create commits"
  else
    fail "apply_run created commits: expected 1, got $COUNT"
  fi
}

test_apply_run_missing_file_fails() {
  local P="$FIXTURE_DIR/apply_missing_p"
  make_committed_repo "$P"

  local OUT
  OUT=$(apply_run "$P" "/nonexistent/diff.diff" "" false 2>&1) || true
  if [[ "$OUT" == *"diff file not found"* ]]; then
    pass "apply_run fails when diff file does not exist"
  else
    fail "apply_run did not fail on missing file: $OUT"
  fi
}

test_apply_run_no_file_arg_fails() {
  local P="$FIXTURE_DIR/apply_nofile_p"
  make_committed_repo "$P"

  local OUT
  OUT=$(apply_run "$P" "" "" false 2>&1) || true
  if [[ "$OUT" == *"no diff file specified"* ]]; then
    pass "apply_run fails when no diff file specified"
  else
    fail "apply_run did not fail on empty file arg: $OUT"
  fi
}

test_apply_run_strips_index_lines() {
  local P="$FIXTURE_DIR/apply_strip_p"
  local DIFF_FILE="$FIXTURE_DIR/apply_strip.diff"
  make_committed_repo "$P"

  cat > "$DIFF_FILE" <<'EOF'
diff --git a/stripped.txt b/stripped.txt
new file mode 100644
index 0000000..8a963d6
--- /dev/null
+++ b/stripped.txt
@@ -0,0 +1 @@
+stripped content
EOF

  apply_run "$P" "$DIFF_FILE" "" false >/dev/null 2>&1

  if [[ -f "$P/stripped.txt" ]]; then
    pass "apply_run strips index lines before applying"
  else
    fail "apply_run did not apply diff after stripping index lines"
  fi
}

test_apply_run_creates_branch() {
  local P="$FIXTURE_DIR/apply_branch_p"
  local DIFF_FILE="$FIXTURE_DIR/apply_branch.diff"
  make_committed_repo "$P"

  cat > "$DIFF_FILE" <<'EOF'
diff --git a/branch-file.txt b/branch-file.txt
new file mode 100644
--- /dev/null
+++ b/branch-file.txt
@@ -0,0 +1 @@
+branch change
EOF

  apply_run "$P" "$DIFF_FILE" "feature-apply" false >/dev/null 2>&1

  local CURR
  CURR=$(git -C "$P" rev-parse --abbrev-ref HEAD)
  if [[ "$CURR" == "feature-apply" ]]; then
    pass "apply_run creates and checks out specified branch"
  else
    fail "apply_run did not create branch: got $CURR"
  fi
}

test_apply_run_force_mode() {
  local P="$FIXTURE_DIR/apply_force_p"
  local DIFF_FILE="$FIXTURE_DIR/apply_force.diff"
  make_committed_repo "$P"

  cat > "$DIFF_FILE" <<'EOF'
diff --git a/force-file.txt b/force-file.txt
new file mode 100644
--- /dev/null
+++ b/force-file.txt
@@ -0,0 +1 @@
+force change
EOF

  local OUT
  OUT=$(apply_run "$P" "$DIFF_FILE" "" true 2>&1) || true
  if [[ "$OUT" == *"Force mode"* ]]; then
    pass "apply_run --force applies with --reject"
  else
    fail "apply_run --force did not enable force mode: $OUT"
  fi
}

test_apply_run_counts_changed_files() {
  local P="$FIXTURE_DIR/apply_count_p"
  local DIFF_FILE="$FIXTURE_DIR/apply_count.diff"
  make_committed_repo "$P"

  cat > "$DIFF_FILE" <<'EOF'
diff --git a/file-a.txt b/file-a.txt
new file mode 100644
--- /dev/null
+++ b/file-a.txt
@@ -0,0 +1 @@
+a
diff --git a/file-b.txt b/file-b.txt
new file mode 100644
--- /dev/null
+++ b/file-b.txt
@@ -0,0 +1 @@
+b
EOF

  local OUT
  OUT=$(apply_run "$P" "$DIFF_FILE" "" false 2>&1) || true
  if [[ "$OUT" == *"Files changed: 2"* ]]; then
    pass "apply_run counts changed files correctly"
  else
    fail "apply_run did not count files correctly: $OUT"
  fi
}

test_apply_run_existing_branch() {
  local P="$FIXTURE_DIR/apply_exist_p"
  local DIFF_FILE="$FIXTURE_DIR/apply_exist.diff"
  make_committed_repo "$P"
  git -C "$P" checkout -b existing-branch --quiet
  git -C "$P" checkout main --quiet

  cat > "$DIFF_FILE" <<'EOF'
diff --git a/exist-file.txt b/exist-file.txt
new file mode 100644
--- /dev/null
+++ b/exist-file.txt
@@ -0,0 +1 @@
+exist
EOF

  apply_run "$P" "$DIFF_FILE" "existing-branch" false >/dev/null 2>&1

  local CURR
  CURR=$(git -C "$P" rev-parse --abbrev-ref HEAD)
  if [[ "$CURR" == "existing-branch" ]]; then
    pass "apply_run checks out existing branch"
  else
    fail "apply_run did not checkout existing branch: got $CURR"
  fi
}

# =============================================================================
# Run all
# =============================================================================
run_test test_apply_run_applies_file_directly
run_test test_apply_run_missing_file_fails
run_test test_apply_run_no_file_arg_fails
run_test test_apply_run_strips_index_lines
run_test test_apply_run_creates_branch
run_test test_apply_run_force_mode
run_test test_apply_run_counts_changed_files
run_test test_apply_run_existing_branch

test_done
