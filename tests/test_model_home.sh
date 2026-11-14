#!/usr/bin/env bash
# Tests for the model home: `tests/model/` as the source the reference
# documents render, and the gates that read it.
#
# Covers:
#   drift        -- a model edited away from its rendered copy is named
#   write        -- `--write` restores the rendered copy from the home
#   shipped path -- a shipped reference carries no repository-only path

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_GATE="$REPO_ROOT/scripts/check_statechart.sh"
CM_GATE="$REPO_ROOT/scripts/check_change_model.sh"
WS_MODEL="$FIXTURE_DIR/ws-model"
CM_MODEL="$FIXTURE_DIR/cm-model"
WS_DOC="$FIXTURE_DIR/workflow_statechart.md"
CM_DOC="$FIXTURE_DIR/change_model.md"

copy_fixture() {
  mkdir -p "$WS_MODEL" "$CM_MODEL"
  cp "$REPO_ROOT/tests/model/workflow_statechart/chart.mmd" "$WS_MODEL/chart.mmd"
  cp "$REPO_ROOT/tests/model/workflow_statechart/discussion.mmd" "$WS_MODEL/discussion.mmd"
  cp "$REPO_ROOT/tests/model/change_model/chart.mmd" "$CM_MODEL/chart.mmd"
  cp "$REPO_ROOT/tests/model/change_model/transitions.md" "$CM_MODEL/transitions.md"
  cp "$REPO_ROOT/docs/reference/workflow_statechart.md" "$WS_DOC"
  cp "$REPO_ROOT/docs/reference/change_model.md" "$CM_DOC"
}

test_statechart_drift_is_named_and_write_restores() {
  copy_fixture
  printf '\n  %%%% drift\n' >> "$WS_MODEL/chart.mmd"
  assert_run 1 "$WS_GATE --doc=$WS_DOC --model=$WS_MODEL/chart.mmd" "a model edited away from its rendered copy fails"
  assert_contains "$RUN_OUT" "does not match" "the finding names the drift"
  assert_run 0 "$WS_GATE --doc=$WS_DOC --model=$WS_MODEL/chart.mmd --write" "--write restores the rendered chart"
  assert_run 0 "$WS_GATE --doc=$WS_DOC --model=$WS_MODEL/chart.mmd" "the restored chart is clean"
}

test_change_model_drift_is_named_and_write_restores() {
  copy_fixture
  printf '\n  %%%% drift\n' >> "$CM_MODEL/chart.mmd"
  assert_run 1 "$CM_GATE --doc=$CM_DOC --model-dir=$CM_MODEL" "a change model edited away from its rendered copy fails"
  assert_contains "$RUN_OUT" "does not match" "the finding names the drift"
  assert_run 0 "$CM_GATE --doc=$CM_DOC --model-dir=$CM_MODEL --write" "--write restores the rendered chart and table"
  assert_run 0 "$CM_GATE --doc=$CM_DOC --model-dir=$CM_MODEL" "the restored model is clean"
}

test_discussion_drift_is_named_and_write_restores() {
  copy_fixture
  printf '\n  %%%% drift\n' >> "$WS_MODEL/discussion.mmd"
  assert_run 1 "$WS_GATE --doc=$WS_DOC --model=$WS_MODEL/chart.mmd --discussion-model=$WS_MODEL/discussion.mmd" "a discussion chart edited away from its rendered copy fails"
  assert_contains "$RUN_OUT" "discussion.mmd" "the finding names the discussion model"
  assert_run 0 "$WS_GATE --doc=$WS_DOC --model=$WS_MODEL/chart.mmd --discussion-model=$WS_MODEL/discussion.mmd --write" "--write restores the discussion chart"
  assert_run 0 "$WS_GATE --doc=$WS_DOC --model=$WS_MODEL/chart.mmd --discussion-model=$WS_MODEL/discussion.mmd" "the restored discussion chart is clean"
}

test_references_carry_no_repository_only_path() {
  assert_run 1 "grep -q 'tests/model' \"$REPO_ROOT/docs/reference/change_model.md\"" "the change model reference carries no repository-only path"
  assert_run 1 "grep -q 'tests/model' \"$REPO_ROOT/docs/reference/workflow_statechart.md\"" "the workflow reference carries no repository-only path"
}

run_test test_statechart_drift_is_named_and_write_restores
run_test test_discussion_drift_is_named_and_write_restores
run_test test_change_model_drift_is_named_and_write_restores
run_test test_references_carry_no_repository_only_path

test_done "model home"
