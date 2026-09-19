#!/usr/bin/env bash
# tests/test_session_save_guard.sh
# Unit tests for the session save / autosave no-op guard in diff_export.sh.
#
# Covers:
#   session_save_needed  --  the skip decision (dirty tree always saves; clean
#                            tree saves only when HEAD moved past the baseline)
#   _save_baseline       --  resolves the comparison point (last .export-status
#                            HEAD, else init_sha)
#   _write_export_status --  stamps HEAD into .export-status so the next save
#                            has a level-2 baseline
#
# The rule under test: a save runs iff the working tree is dirty (any
# uncommitted/untracked change) OR HEAD differs from BASELINE. It is skipped
# only when the tree is completely clean AND HEAD equals BASELINE.

set -uo pipefail
unset WORKSPACE_DIR_NAME SANDBOX_DIR_NAME CHANGES_DIR_NAME INPUT_DIR_NAME OUTPUT_DIR_NAME

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/git_fixtures.sh"

# source the module under test (git_fixtures is independent)
source "${REPO_ROOT}/src/libs/diff_export.sh"

# -- session_save_needed -----------------------------------------------------

test_dirty_tree_always_saves() {
  local fix
  fix=$(mktemp -d) || { fail "mktemp failed"; return; }
  make_committed_repo "$fix"
  write_session_state "$fix"
  local baseline
  baseline=$(get_init_sha "$fix")

  echo "uncommitted" >> "$fix/file.txt"
  if session_save_needed "$fix" "$baseline"; then
    pass "dirty tree saves (one uncommitted change)"
  else
    fail "dirty tree should always save"
  fi

  echo "more" >> "$fix/file.txt"
  if session_save_needed "$fix" "$baseline"; then
    pass "dirty tree saves regardless of change count (two changes)"
  else
    fail "two uncommitted changes must still save"
  fi

  touch "$fix/untracked.txt"
  if session_save_needed "$fix" "$baseline"; then
    pass "untracked file alone forces a save"
  else
    fail "untracked file must force a save"
  fi

  rm -rf "$fix"
}

test_clean_tree_at_baseline_skips() {
  local fix
  fix=$(mktemp -d) || { fail "mktemp failed"; return; }
  make_committed_repo "$fix"
  write_session_state "$fix"
  local baseline
  baseline=$(get_init_sha "$fix")   # HEAD == init_sha, tree clean

  if session_save_needed "$fix" "$baseline"; then
    fail "clean tree at baseline must skip (rc 1)"
  else
    pass "clean tree at baseline skips"
  fi
  rm -rf "$fix"
}

test_clean_tree_past_baseline_saves() {
  local fix
  fix=$(mktemp -d) || { fail "mktemp failed"; return; }
  make_committed_repo "$fix"
  write_session_state "$fix"
  local baseline
  baseline=$(get_init_sha "$fix")

  commit_change "$fix" "second commit"
  # now clean but HEAD != init_sha -- must save (captures the new commit once)
  if session_save_needed "$fix" "$baseline"; then
    pass "clean tree with commits past baseline saves"
  else
    fail "clean tree past baseline must save"
  fi

  # at HEAD (== the new commit) it skips again -- level 2: nothing new
  local new_head
  new_head=$(git -C "$fix" rev-parse HEAD)
  if session_save_needed "$fix" "$new_head"; then
    fail "clean tree back at last-saved HEAD must skip"
  else
    pass "clean tree at last-saved HEAD skips (level 2)"
  fi
  rm -rf "$fix"
}

# -- _save_baseline ----------------------------------------------------------

test_baseline_falls_back_to_init_sha() {
  local fix
  fix=$(mktemp -d) || { fail "mktemp failed"; return; }
  make_committed_repo "$fix"
  write_session_state "$fix"
  local expect
  expect=$(get_init_sha "$fix")

  local out
  out=$(_save_baseline "$fix" "$fix/nonexistent-dir")
  assert_eq "$out" "$expect" "_save_baseline falls back to init_sha when no prior export"
  rm -rf "$fix"
}

test_baseline_reads_last_export_head() {
  local fix
  fix=$(mktemp -d) || { fail "mktemp failed"; return; }
  make_committed_repo "$fix"
  write_session_state "$fix"

  local exp_dir="$fix/prior"
  mkdir -p "$exp_dir"
  # a previous successful export recorded a HEAD that is not init_sha
  _write_export_status "$exp_dir" "SUCCESS" "20260622-120000" "0" "$(get_init_sha "$fix")" "deadbeefcafe"

  local out
  out=$(_save_baseline "$fix" "$exp_dir")
  assert_eq "$out" "deadbeefcafe" "_save_baseline uses last saved HEAD over init_sha"
  rm -rf "$fix"
}

test_baseline_ignores_failed_export() {
  local fix
  fix=$(mktemp -d) || { fail "mktemp failed"; return; }
  make_committed_repo "$fix"
  write_session_state "$fix"
  local expect
  expect=$(get_init_sha "$fix")

  local exp_dir="$fix/prior"
  mkdir -p "$exp_dir"
  _write_export_status "$exp_dir" "FAIL" "20260622-120000" "1" "$(get_init_sha "$fix")" "deadbeefcafe"

  local out
  out=$(_save_baseline "$fix" "$exp_dir")
  assert_eq "$out" "$expect" "_save_baseline falls back to init_sha when prior export FAILed"
  rm -rf "$fix"
}

# -- _write_export_status stamps HEAD ----------------------------------------

test_export_status_stamps_head() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }
  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" "init1234" "head5678"
  local _content
  _content=$(cat "$_tmpdir/.export-status")
  rm -rf "$_tmpdir"
  assert_contains "$_content" "HEAD=head5678" "_write_export_status stamps HEAD given as 6th arg"
  assert_contains "$_content" "INIT_SHA=init1234" "_write_export_status keeps INIT_SHA"
}

test_export_status_no_head_when_empty() {
  local _tmpdir
  _tmpdir=$(mktemp -d) || { fail "mktemp failed"; return; }
  _write_export_status "$_tmpdir" "SUCCESS" "20260622-120000" "0" "init1234"
  local _content
  _content=$(cat "$_tmpdir/.export-status")
  rm -rf "$_tmpdir"
  if [[ "$_content" == *"HEAD="* ]]; then
    fail "_write_export_status should omit empty HEAD"
  else
    pass "_write_export_status omits HEAD when absent"
  fi
}

# -- run ---------------------------------------------------------------------

run_test test_dirty_tree_always_saves
run_test test_clean_tree_at_baseline_skips
run_test test_clean_tree_past_baseline_saves
run_test test_baseline_falls_back_to_init_sha
run_test test_baseline_reads_last_export_head
run_test test_baseline_ignores_failed_export
run_test test_export_status_stamps_head
run_test test_export_status_no_head_when_empty

test_done