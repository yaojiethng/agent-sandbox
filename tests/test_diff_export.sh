#!/usr/bin/env bash
# tests/test_diff_export.sh
# Tests for src/libs/diff_export.sh — the diff export orchestrator.
#
# Covers:
#   diff_export  — packages session artefacts via package_branch + export time

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/libs/test_common.sh"
source "$SCRIPT_DIR/libs/git_fixtures.sh"

test_diff_export_creates_export_time_file() {
  local DIR
  DIR=$(mktemp -d /tmp/XXXXXX)
  make_sandbox_fixture "$DIR"
  local OUTDIR="$DIR/export_out"
  mkdir -p "$OUTDIR"

  source "$REPO_ROOT/src/libs/diff_export.sh"
  diff_export "$DIR" "$OUTDIR" 2>/dev/null || true

  if [[ -f "$OUTDIR/EXPORT-TIME.txt" ]]; then
    pass "diff_export creates EXPORT-TIME.txt"
  else
    fail "diff_export did not create EXPORT-TIME.txt"
  fi
  rm -rf "$DIR"
}

test_diff_export_produces_all_changes() {
  local DIR
  DIR=$(mktemp -d /tmp/XXXXXX)
  make_sandbox_fixture "$DIR"
  local OUTDIR="$DIR/export_out"
  mkdir -p "$OUTDIR"

  source "$REPO_ROOT/src/libs/diff_export.sh"
  diff_export "$DIR" "$OUTDIR" 2>/dev/null || true

  if [[ -f "$OUTDIR/all-changes.diff" ]]; then
    pass "diff_export produces all-changes.diff"
  else
    fail "diff_export did not produce all-changes.diff"
  fi
  rm -rf "$DIR"
}

test_diff_export_requires_args() {
  if diff_export "" "" 2>/dev/null; then
    fail "diff_export should fail with empty args"
  else
    pass "diff_export fails with empty args"
  fi
}

run_test test_diff_export_creates_export_time_file
run_test test_diff_export_produces_all_changes
run_test test_diff_export_requires_args
