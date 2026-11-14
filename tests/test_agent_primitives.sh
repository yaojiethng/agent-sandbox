#!/usr/bin/env bash
# tests/test_agent_primitives.sh
# Tests for the branch-preparation gate: `scripts/check_agent_primitives.sh`
# over a fixture root and the real tree.
#
# Covers:
#   clean             -- the runbook present and no retired prompt is clean
#   missing runbook   -- a missing prepare runbook is named
#   returned prompt   -- a restored change prompt is named
#   returned scheduler-- a restored merge-queue prompt is named
#   live link         -- a live file naming a retired prompt is named
#   real tree         -- the committed tree is clean

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO_ROOT/scripts/check_agent_primitives.sh"

seed_fixture() {
  FIXTURE="$FIXTURE_DIR/root"
  mkdir -p "$FIXTURE/.agents/skills/git-discipline/references" \
    "$FIXTURE/workflow/coding-agent/prompts" "$FIXTURE/docs"
  printf '# Prepare\n' \
    > "$FIXTURE/.agents/skills/git-discipline/references/prepare.md"
  printf 'the operator runs make confirm\n' > "$FIXTURE/docs/live.md"
}

test_clean_fixture() {
  seed_fixture
  assert_run 0 "$GATE --root=$FIXTURE" "the fixture is clean" || return 1
  assert_contains "$RUN_OUT" "agent primitives: clean" "the clean summary is printed"
}

test_missing_runbook_is_named() {
  seed_fixture
  rm "$FIXTURE/.agents/skills/git-discipline/references/prepare.md"
  assert_run 1 "$GATE --root=$FIXTURE" "a missing runbook fails the gate"
  assert_contains "$RUN_OUT" "missing" "the finding names the missing runbook"
}

test_returned_prompt_is_named() {
  seed_fixture
  : > "$FIXTURE/workflow/coding-agent/prompts/prepare-rebase.md"
  assert_run 1 "$GATE --root=$FIXTURE" "a returned prompt fails the gate"
  assert_contains "$RUN_OUT" "prepare-rebase.md" "the finding names the prompt"
}

test_returned_scheduler_is_named() {
  seed_fixture
  : > "$FIXTURE/workflow/coding-agent/prompts/merge-queue.md"
  assert_run 1 "$GATE --root=$FIXTURE" "a returned scheduler fails the gate"
  assert_contains "$RUN_OUT" "merge-queue.md" "the finding names the scheduler"
}

test_live_link_is_named() {
  seed_fixture
  printf 'see prepare-rebase\n' > "$FIXTURE/docs/live.md"
  assert_run 1 "$GATE --root=$FIXTURE" "a live link fails the gate"
  assert_contains "$RUN_OUT" "docs/live.md" "the finding names the file"
}

test_real_tree_is_clean() {
  assert_run 0 "$GATE" "the committed tree is clean" || return 1
  assert_contains "$RUN_OUT" "agent primitives: clean" "the real summary is printed"
}

run_test test_clean_fixture
run_test test_missing_runbook_is_named
run_test test_returned_prompt_is_named
run_test test_returned_scheduler_is_named
run_test test_live_link_is_named
run_test test_real_tree_is_clean

test_done "agent primitives gate"
