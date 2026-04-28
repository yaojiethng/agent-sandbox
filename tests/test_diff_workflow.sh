#!/usr/bin/env bash
# tests/test_diff_workflow.sh
# Tests for libs/diff_workflow.sh
#
# Covers:
#   apply_run — resolves session, finds changes.diff via fallback,
#               applies diff, optional branch checkout, force mode

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/diff_workflow.sh"
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

# =============================================================================
# APPLY tests
# =============================================================================

test_apply_uses_latest_session() {
  local P="$FIXTURE_DIR/apply_latest_p"
  local S="$FIXTURE_DIR/apply_latest_s"
  local DIFFS_DIR="$S/.workspace/output/diffs"
  make_committed_repo "$P"
  mkdir -p "$DIFFS_DIR"
  make_diffs_session "20260401-120000-main" "$DIFFS_DIR"
  make_diffs_session "20260402-120000-main" "$DIFFS_DIR"

  apply_run "$P" "$S" "" "" "" false >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$P" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]]; then
    pass "apply uses lexicographically latest session in DIFFS_DIR"
  else
    fail "apply did not apply changes.diff: $STATUS"
  fi

  local COUNT
  COUNT=$(git -C "$P" rev-list --count HEAD)
  if [[ "$COUNT" -eq 1 ]]; then
    pass "apply does not create commits"
  else
    fail "apply created commits: expected 1, got $COUNT"
  fi
}

test_apply_uses_named_session() {
  local P="$FIXTURE_DIR/apply_named_p"
  local S="$FIXTURE_DIR/apply_named_s"
  local DIFFS_DIR="$S/.workspace/output/diffs"
  make_committed_repo "$P"
  mkdir -p "$DIFFS_DIR"
  make_diffs_session "session-a" "$DIFFS_DIR"
  mkdir -p "$DIFFS_DIR/session-b"
  cat > "$DIFFS_DIR/session-b/changes.diff" <<'EOF'
diff --git a/named-file.txt b/named-file.txt
new file mode 100644
--- /dev/null
+++ b/named-file.txt
@@ -0,0 +1 @@
+named session change
EOF

  apply_run "$P" "$S" "session-a" "" "" false >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$P" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]] && [[ "$STATUS" != *"named-file.txt"* ]]; then
    pass "apply uses named session when SESSION specified"
  else
    fail "apply did not use named session: $STATUS"
  fi
}

test_apply_uses_absolute_session_path() {
  local P="$FIXTURE_DIR/apply_abs_p"
  local S="$FIXTURE_DIR/apply_abs_s"
  make_committed_repo "$P"
  local CUSTOM_DIR="$FIXTURE_DIR/custom_session"
  mkdir -p "$CUSTOM_DIR"
  cat > "$CUSTOM_DIR/changes.diff" <<'EOF'
diff --git a/absolute-file.txt b/absolute-file.txt
new file mode 100644
--- /dev/null
+++ b/absolute-file.txt
@@ -0,0 +1 @@
+absolute path change
EOF

  apply_run "$P" "$S" "$CUSTOM_DIR" "" "" false >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$P" status --porcelain)
  if [[ "$STATUS" == *"absolute-file"* ]]; then
    pass "apply uses absolute session path"
  else
    fail "apply did not use absolute path: $STATUS"
  fi
}

test_apply_requires_changes_diff() {
  local P="$FIXTURE_DIR/apply_no_diff_p"
  local S="$FIXTURE_DIR/apply_no_diff_s"
  make_committed_repo "$P"
  local EMPTY_SESSION="$FIXTURE_DIR/empty_session"
  mkdir -p "$EMPTY_SESSION"

  local OUT
  OUT=$(apply_run "$P" "$S" "$EMPTY_SESSION" "" "" false 2>&1) || true
  if [[ "$OUT" == *"changes.diff not found"* ]]; then
    pass "apply fails when changes.diff is missing"
  else
    fail "apply did not fail on missing changes.diff: $OUT"
  fi
}

test_apply_no_sessions_error() {
  local P="$FIXTURE_DIR/apply_no_output_p"
  local S="$FIXTURE_DIR/apply_no_output_s"
  local DIFFS_DIR="$S/.workspace/output/diffs"
  make_committed_repo "$P"
  mkdir -p "$DIFFS_DIR"

  local OUT
  OUT=$(apply_run "$P" "$S" "" "" "" false 2>&1) || true
  if [[ "$OUT" == *"no session directories"* ]]; then
    pass "apply errors when no sessions found"
  else
    fail "apply did not error on empty directory: $OUT"
  fi
}

test_apply_empty_diff_applies_cleanly() {
  local P="$FIXTURE_DIR/apply_clean_p"
  local S="$FIXTURE_DIR/apply_clean_s"
  local DIFFS_DIR="$S/.workspace/output/diffs"
  make_committed_repo "$P"
  mkdir -p "$DIFFS_DIR"
  make_diffs_session "test-session" "$DIFFS_DIR"

  apply_run "$P" "$S" "test-session" "" "" false >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$P" status --porcelain)
  if [[ "$STATUS" == *"output-file"* ]]; then
    pass "apply applies changes.diff cleanly via relative SESSION"
  else
    fail "apply did not apply changes.diff: $STATUS"
  fi
}

test_apply_with_branch() {
  local P="$FIXTURE_DIR/apply_branch_p"
  local S="$FIXTURE_DIR/apply_branch_s"
  local DIFFS_DIR="$S/.workspace/output/diffs"
  make_committed_repo "$P"
  mkdir -p "$DIFFS_DIR"
  make_diffs_session "test-session" "$DIFFS_DIR"

  apply_run "$P" "$S" "test-session" "" "feature-apply" false >/dev/null 2>&1

  local CURR
  CURR=$(git -C "$P" rev-parse --abbrev-ref HEAD)
  if [[ "$CURR" == "feature-apply" ]]; then
    pass "apply creates and checks out specified branch"
  else
    fail "apply did not create branch: got $CURR"
  fi
}

test_apply_force_mode() {
  local P="$FIXTURE_DIR/apply_force_p"
  local S="$FIXTURE_DIR/apply_force_s"
  local DIFFS_DIR="$S/.workspace/output/diffs"
  make_committed_repo "$P"
  mkdir -p "$DIFFS_DIR"
  make_diffs_session "test-session" "$DIFFS_DIR"

  local OUT
  OUT=$(apply_run "$P" "$S" "test-session" "" "" true 2>&1) || true
  if [[ "$OUT" == *"Force mode"* ]]; then
    pass "apply --force applies with --reject"
  else
    fail "apply --force did not enable force mode: $OUT"
  fi
}

test_apply_diff_argument() {
  local P="$FIXTURE_DIR/apply_diff_arg_p"
  local S="$FIXTURE_DIR/apply_diff_arg_s"
  make_committed_repo "$P"
  local DIFF_FILE="$FIXTURE_DIR/standalone.diff"
  cat > "$DIFF_FILE" <<'EOF'
diff --git a/diff-arg-file.txt b/diff-arg-file.txt
new file mode 100644
--- /dev/null
+++ b/diff-arg-file.txt
@@ -0,0 +1 @@
+diff argument
EOF

  apply_run "$P" "$S" "" "$DIFF_FILE" "" false >/dev/null 2>&1

  if [[ -f "$P/diff-arg-file.txt" ]]; then
    pass "apply DIFF=<path> applies specific diff file"
  else
    fail "apply did not apply diff from --diff argument"
  fi
}

test_apply_diff_not_found() {
  local P="$FIXTURE_DIR/apply_diff_missing_p"
  local S="$FIXTURE_DIR/apply_diff_missing_s"
  make_committed_repo "$P"

  local OUT
  OUT=$(apply_run "$P" "$S" "" "/nonexistent/path/changes.diff" "" false 2>&1) || true
  if [[ "$OUT" == *"diff file not found"* ]]; then
    pass "apply DIFF=<path> fails when diff file does not exist"
  else
    fail "apply did not fail on missing diff: $OUT"
  fi
}

test_apply_strips_index_lines() {
  local P="$FIXTURE_DIR/apply_strip_p"
  local S="$FIXTURE_DIR/apply_strip_s"
  make_committed_repo "$P"
  local SESSION_DIR="$FIXTURE_DIR/apply_strip_session"
  mkdir -p "$SESSION_DIR"
  cat > "$SESSION_DIR/changes.diff" <<'EOF'
diff --git a/strip-test.txt b/strip-test.txt
new file mode 100644
index 0000000..8a963d6
--- /dev/null
+++ b/strip-test.txt
@@ -0,0 +1 @@
+stripped
EOF

  apply_run "$P" "$S" "$SESSION_DIR" "" "" false >/dev/null 2>&1

  if [[ -f "$P/strip-test.txt" ]]; then
    pass "apply strips index lines before applying"
  else
    fail "apply did not apply diff after stripping index lines"
  fi
}

test_apply_uses_autosave_changes_diff() {
  local P="$FIXTURE_DIR/apply_autosave_p"
  local S="$FIXTURE_DIR/apply_autosave_s"
  make_committed_repo "$P"
  local SESSION_DIR="$FIXTURE_DIR/apply_autosave_session"
  mkdir -p "$SESSION_DIR/autosave"
  cat > "$SESSION_DIR/autosave/changes.diff" <<'EOF'
diff --git a/autosave-file.txt b/autosave-file.txt
new file mode 100644
--- /dev/null
+++ b/autosave-file.txt
@@ -0,0 +1 @@
+autosave change
EOF

  apply_run "$P" "$S" "$SESSION_DIR" "" "" false >/dev/null 2>&1

  if [[ -f "$P/autosave-file.txt" ]]; then
    pass "apply falls back to autosave/changes.diff"
  else
    fail "apply did not fall back to autosave/changes.diff"
  fi
}

test_apply_uses_session_changes_diff_fallback() {
  local P="$FIXTURE_DIR/apply_session_fallback_p"
  local S="$FIXTURE_DIR/apply_session_fallback_s"
  make_committed_repo "$P"
  local SESSION_DIR="$FIXTURE_DIR/apply_session_fallback_session"
  mkdir -p "$SESSION_DIR/session"
  cat > "$SESSION_DIR/session/changes.diff" <<'EOF'
diff --git a/session-file.txt b/session-file.txt
new file mode 100644
--- /dev/null
+++ b/session-file.txt
@@ -0,0 +1 @@
+session change
EOF

  apply_run "$P" "$S" "$SESSION_DIR" "" "" false >/dev/null 2>&1

  if [[ -f "$P/session-file.txt" ]]; then
    pass "apply falls back to session/changes.diff"
  else
    fail "apply did not fall back to session/changes.diff"
  fi
}

test_apply_absolute_path_no_diffs_dir() {
  local P="$FIXTURE_DIR/apply_abs_nodiffs_p"
  local S="$FIXTURE_DIR/apply_abs_nodiffs_s"
  make_committed_repo "$P"
  local SESSION_DIR="$FIXTURE_DIR/abs_session_nodiffs"
  mkdir -p "$SESSION_DIR"
  cat > "$SESSION_DIR/changes.diff" <<'EOF'
diff --git a/no-diffs-dir-file.txt b/no-diffs-dir-file.txt
new file mode 100644
--- /dev/null
+++ b/no-diffs-dir-file.txt
@@ -0,0 +1 @@
+no diffs dir needed
EOF

  apply_run "$P" "$S" "$SESSION_DIR" "" "" false >/dev/null 2>&1

  if [[ -f "$P/no-diffs-dir-file.txt" ]]; then
    pass "apply --session=<absolute> works without DIFFS_DIR"
  else
    fail "apply --session=<absolute> requires DIFFS_DIR but should not"
  fi
}

test_apply_diff_no_diffs_dir() {
  local P="$FIXTURE_DIR/apply_diff_nodiffs_p"
  local S="$FIXTURE_DIR/apply_diff_nodiffs_s"
  make_committed_repo "$P"
  local DIFF_FILE="$FIXTURE_DIR/standalone_nodiffs.diff"
  cat > "$DIFF_FILE" <<'EOF'
diff --git a/diff-no-diffs-file.txt b/diff-no-diffs-file.txt
new file mode 100644
--- /dev/null
+++ b/diff-no-diffs-file.txt
@@ -0,0 +1 @@
+diff no diffs dir
EOF

  apply_run "$P" "$S" "" "$DIFF_FILE" "" false >/dev/null 2>&1

  if [[ -f "$P/diff-no-diffs-file.txt" ]]; then
    pass "apply --diff=<path> works without DIFFS_DIR"
  else
    fail "apply --diff=<path> requires DIFFS_DIR but should not"
  fi
}

test_apply_relative_session_under_diffs_dir() {
  local P="$FIXTURE_DIR/apply_relative_p"
  local S="$FIXTURE_DIR/apply_relative_s"
  local DIFFS_DIR="$S/.workspace/output/diffs"
  make_committed_repo "$P"
  mkdir -p "$DIFFS_DIR"
  make_diffs_session "20260401-test-session" "$DIFFS_DIR"

  apply_run "$P" "$S" "20260401-test-session" "" "" false >/dev/null 2>&1

  local STATUS
  STATUS=$(git -C "$P" status --porcelain)
  if [[ "$STATUS" == *"output-file.txt"* ]]; then
    pass "apply resolves relative SESSION under DIFFS_DIR"
  else
    fail "apply did not resolve relative SESSION: $STATUS"
  fi
}

test_apply_no_diffs_dir_error() {
  local P="$FIXTURE_DIR/apply_nodiffsdir_error_p"
  local S="$FIXTURE_DIR/apply_nodiffsdir_error_s"
  make_committed_repo "$P"

  local OUT
  OUT=$(apply_run "$P" "$S" "" "" "" false 2>&1) || true
  if [[ "$OUT" == *"diffs directory not found"* ]]; then
    pass "apply errors clearly when DIFFS_DIR does not exist (auto-resolve)"
  else
    fail "apply did not error on missing DIFFS_DIR: $OUT"
  fi
}

test_apply_changes_diff_tries_all_paths() {
  local P="$FIXTURE_DIR/apply_allpaths_error_p"
  local S="$FIXTURE_DIR/apply_allpaths_error_s"
  make_committed_repo "$P"
  local EMPTY_SESSION="$FIXTURE_DIR/allpaths_empty_session"
  mkdir -p "$EMPTY_SESSION"

  local OUT
  OUT=$(apply_run "$P" "$S" "$EMPTY_SESSION" "" "" false 2>&1) || true
  if [[ "$OUT" == *"changes.diff not found"* ]] && [[ "$OUT" == *"session/changes.diff"* ]] && [[ "$OUT" == *"autosave/changes.diff"* ]]; then
    pass "apply lists all tried paths when changes.diff not found"
  else
    fail "apply did not list all tried paths: $OUT"
  fi
}

# =============================================================================
# Run all
# =============================================================================
run_test test_apply_uses_latest_session
run_test test_apply_uses_named_session
run_test test_apply_uses_absolute_session_path
run_test test_apply_requires_changes_diff
run_test test_apply_no_sessions_error
run_test test_apply_empty_diff_applies_cleanly
run_test test_apply_with_branch
run_test test_apply_force_mode
run_test test_apply_diff_argument
run_test test_apply_diff_not_found
run_test test_apply_strips_index_lines
run_test test_apply_uses_autosave_changes_diff
run_test test_apply_uses_session_changes_diff_fallback
run_test test_apply_absolute_path_no_diffs_dir
run_test test_apply_diff_no_diffs_dir
run_test test_apply_relative_session_under_diffs_dir
run_test test_apply_no_diffs_dir_error
run_test test_apply_changes_diff_tries_all_paths

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
