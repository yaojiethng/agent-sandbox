#!/usr/bin/env bash
# TEST_DEADLINE: 30
# tests/test_change_pipeline_generic_files.sh
# The change-pipeline bundle states its operation over generic files: it names
# no project convention, and its audit carries no local record path or citation
# parser. The record set is the caller's input.
#
# Covers:
#   the repository bundle                   -- no convention name, no local audit path
#   a convention name in a bundle file      -- named as an offender
#   a local path in the audit               -- named as an offender
#
# Run:   bash tests/test_change_pipeline_generic_files.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# shellcheck source=libs/test_common.sh
source "$TEST_DIR/libs/test_common.sh"
test_setup

BUNDLE=(
  "workflow/coding-agent/skills/git-discipline/SKILL.md"
  "workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/SKILL.md"
  "workflow/coding-agent/skills/recovery/SKILL.md"
  "workflow/coding-agent/prompts/record-correction.md"
)
AUDIT="workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/scripts/audit.sh"

# offenders ROOT -- print each bundle or audit file that names a convention or
# carries a local record path or the old citation finding.
offenders() {
  local root="$1" f out=""
  for f in "${BUNDLE[@]}"; do
    if grep -qE 'work-log|task-list|decision-records|^## Project conventions$' "$root/$f"; then
      out+="$f"$'\n'
    fi
  done
  if grep -qE 'devlog|roadmap|citation does not resolve' "$root/$AUDIT"; then
    out+="$AUDIT"$'\n'
  fi
  printf '%s' "$out"
}

copy_tree() {
  local dir="$1" f
  for f in "${BUNDLE[@]}" "$AUDIT"; do
    mkdir -p "$dir/$(dirname "$f")"
    cp "$REPO_ROOT/$f" "$dir/$f"
  done
}

test_the_repository_bundle_is_generic() {
  assert_empty "$(offenders "$REPO_ROOT")" "the bundle names no convention and the audit no local path"
}

test_a_convention_name_is_named() {
  local dir="$FIXTURE_DIR/bundle"
  copy_tree "$dir" || fail "fixture"
  printf '\n`work-log`\n' >>"$dir/${BUNDLE[2]}"
  assert_contains "$(offenders "$dir")" "${BUNDLE[2]}" "a convention name is named"
}

test_an_audit_local_path_is_named() {
  local dir="$FIXTURE_DIR/audit"
  copy_tree "$dir" || fail "fixture"
  printf '\ndevlog/roadmap.md\n' >>"$dir/$AUDIT"
  assert_contains "$(offenders "$dir")" "$AUDIT" "a local audit path is named"
}

run_test test_the_repository_bundle_is_generic
run_test test_a_convention_name_is_named
run_test test_an_audit_local_path_is_named

test_done change_pipeline_generic_files
