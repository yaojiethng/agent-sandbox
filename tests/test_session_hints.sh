#!/usr/bin/env bash
# tests/test_session_hints.sh
# Unit tests for src/libs/session_hints.sh -- the session-end hint pair.
#
# Covers:
#   session_end_hints  --  resume hint always; draft hint only for a draftable
#                          export, and never an abort on an unresolvable sandbox.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/session_hints.sh"

# Given: an empty sandbox-dir argument
# When:  session_end_hints runs
# Then:  it returns 0 and prints only the resume hint
# Asserts: an unresolvable sandbox degrades to resume-only, not a library abort.
test_session_end_hints_empty_sandbox_is_resume_only() {
  local out rc=0
  out="$(session_end_hints "" "sid123" 2>&1)" || rc=$?
  assert_rc 0 "$rc" "session_end_hints: empty sandbox dir does not abort"
  assert_contains "$out" "make resume SESSION_ID=sid123" "session_end_hints: resume hint printed"
  if [[ "$out" == *"make draft"* ]]; then
    fail "session_end_hints: empty sandbox dir must not print the draft hint"
  else
    pass "session_end_hints: empty sandbox dir prints no draft hint"
  fi
}

# Given: a sandbox holding a draftable export for the session
# When:  session_end_hints runs
# Then:  it prints both the resume hint and the draft hint
# Asserts: the draftable path names the export bundle.
test_session_end_hints_draftable_export_prints_pair() {
  local sd="$FIXTURE_DIR/sandbox"
  local exp="$sd/.workspace/session-diffs/session/20260101-000000-sidabc"
  mkdir -p "$exp/patches"
  local out
  out="$(session_end_hints "$sd" "sidabc")"
  assert_contains "$out" "make resume SESSION_ID=sidabc" "session_end_hints: resume hint printed"
  assert_contains "$out" "make draft BUNDLE=20260101-000000-sidabc" "session_end_hints: draft hint names the export"
}

# Given: a sandbox with no export for the session
# When:  session_end_hints runs
# Then:  it prints only the resume hint
# Asserts: the draftability gate suppresses a hint with no bundle behind it.
test_session_end_hints_no_export_is_resume_only() {
  local sd="$FIXTURE_DIR/sandbox_empty"
  mkdir -p "$sd"
  local out
  out="$(session_end_hints "$sd" "nope")"
  assert_contains "$out" "make resume SESSION_ID=nope" "session_end_hints: resume hint printed"
  if [[ "$out" == *"make draft"* ]]; then
    fail "session_end_hints: no export must not print the draft hint"
  else
    pass "session_end_hints: no export prints no draft hint"
  fi
}

run_test test_session_end_hints_empty_sandbox_is_resume_only
run_test test_session_end_hints_draftable_export_prints_pair
run_test test_session_end_hints_no_export_is_resume_only

test_done test_session_hints
