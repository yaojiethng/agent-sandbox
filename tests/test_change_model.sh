#!/usr/bin/env bash
# tests/test_change_model.sh
# Tests for the change model gate: `scripts/check_change_model.sh` over a
# fixture model, and the real tree.
#
# Covers:
#   clean        -- a chart and table that agree are clean
#   missing row  -- an edge without a transition row is named
#   ghost row    -- a transition row without an edge is named
#   no actor     -- an unlabelled actor is named
#   bad lane     -- a lane outside agent/host is named
#   no test      -- a named test that does not exist is named
#   no mutation  -- a catalog id that does not exist is named
#   manual git   -- the operator-git row must be manual
#   redraft      -- the remediation row must name reject then draft
#   real tree    -- the committed model is clean

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO_ROOT/scripts/check_change_model.sh"
DOC="$FIXTURE_DIR/change_model.md"

write_doc() {
  local edges="$1" rows="$2"
  cat > "$DOC" <<EOF
# Fixture model

Delivery is copy or mount, full or flatten.

\`\`\`mermaid
stateDiagram-v2
${edges}
\`\`\`

## The transitions

| Id | Lane | Actor | Event | Guard | From | To | Mechanism | Manual | Subject | Invariant | Test | Mutation |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
${rows}

## End
EOF
}

BASE_EDGES='  [*] --> NotReady
  NotReady --> Ready: T01 prepare
  Ready --> Drafted: T04 draft
  Drafted --> Accepted: T06 confirm
  Drafted --> Drafted: T10 operator git
  Drafted --> Drafted: T11 reject and redraft'
BASE_ROWS='| `T01` | agent | agent | prepare | the head is not an ancestor | `not-ready` | `ready` | rebase | no | the prepare primitive | `PrepareResolvesEveryConflict` | none: model check | none: model-only |
| `T04` | host | operator | draft | a bundle is present | `ready` | `drafted` | `make draft` | no | `scripts/workflows/draft.sh` | `MergeableRequiresForkable` | `test_draft_forks_from_branch_point_not_head` | `252` |
| `T06` | host | operator | confirm | ready and at the queue head | `drafted` | `accepted` | `make confirm` | yes | `scripts/workflows/confirm.sh` | `AtomicAccept` | `test_confirm_script_entry_merges_draft` | `52` |
| `T10` | host | operator | operator git | the operator runs git | `drafted` | `drafted` | raw git | yes | none: operator action | `OperatorGitRederivesTheState` | none: operator action | none: operator action |
| `T11` | host | operator | reject and redraft | a broken draft | `drafted` | `drafted` | `make reject` then `make draft` | yes | `scripts/workflows/reject.sh` | `MistakeHasARemediation` | `test_reject_returns_to_source` | `259` |'

test_clean_fixture() {
  write_doc "$BASE_EDGES" "$BASE_ROWS"
  assert_run 0 "$GATE --doc=$DOC" "the fixture is clean" || return 1
  assert_contains "$RUN_OUT" "change model: clean across 5 transition(s)" "the clean summary names the transition count"
}

test_edge_without_row_is_named() {
  write_doc "$BASE_EDGES
  NotReady --> Rejected: T99 reject" "$BASE_ROWS"
  assert_run 1 "$GATE --doc=$DOC" "an edge without a row fails the gate"
  assert_contains "$RUN_OUT" "T99" "the finding names the edge"
}

test_row_without_edge_is_named() {
  write_doc "$BASE_EDGES" "$BASE_ROWS
| \`T99\` | host | operator | reject | a draft | \`drafted\` | \`rejected\` | \`make reject\` | yes | \`scripts/workflows/reject.sh\` | \`R\` | \`test_reject_returns_to_source\` | \`259\` |"
  assert_run 1 "$GATE --doc=$DOC" "a row without an edge fails the gate"
  assert_contains "$RUN_OUT" "T99" "the finding names the row"
}

test_unlabelled_actor_is_named() {
  write_doc "$BASE_EDGES" "${BASE_ROWS/| host | operator | draft |/| host | - | draft |}"
  assert_run 1 "$GATE --doc=$DOC" "an unlabelled actor fails the gate"
  assert_contains "$RUN_OUT" "T04: Actor is empty" "the finding names the actor"
}

test_bad_lane_is_named() {
  write_doc "$BASE_EDGES" "${BASE_ROWS/| host | operator | draft |/| operator | operator | draft |}"
  assert_run 1 "$GATE --doc=$DOC" "a lane outside agent/host fails the gate"
  assert_contains "$RUN_OUT" "T04: Lane is operator" "the finding names the lane"
}

test_missing_test_is_named() {
  write_doc "$BASE_EDGES" "${BASE_ROWS/test_draft_forks_from_branch_point_not_head/test_no_such_test}"
  assert_run 1 "$GATE --doc=$DOC" "a missing test function fails the gate"
  assert_contains "$RUN_OUT" "test_no_such_test" "the finding names the missing test"
}

test_missing_mutation_is_named() {
  write_doc "$BASE_EDGES" "${BASE_ROWS/| \`252\` |/| \`999999\` |}"
  assert_run 1 "$GATE --doc=$DOC" "a missing catalog row fails the gate"
  assert_contains "$RUN_OUT" "999999" "the finding names the missing mutation"
}

test_operator_git_must_be_manual() {
  write_doc "$BASE_EDGES" "${BASE_ROWS/| raw git | yes |/| raw git | no |}"
  assert_run 1 "$GATE --doc=$DOC" "the operator-git row must be manual"
  assert_contains "$RUN_OUT" "operator git is a manual host action" "the finding names the manual flag"
}

test_redraft_must_name_both_verbs() {
  write_doc "$BASE_EDGES" "${BASE_ROWS/| \`make reject\` then \`make draft\` |/| \`make reject\` |}"
  assert_run 1 "$GATE --doc=$DOC" "the remediation row must name reject then draft"
  assert_contains "$RUN_OUT" "does not name make reject then make draft" "the finding names the missing verb"
}

test_real_tree_is_clean() {
  assert_run 0 "$GATE" "the committed model is clean" || return 1
  assert_contains "$RUN_OUT" "change model: clean across" "the real summary is printed"
}

run_test test_clean_fixture
run_test test_edge_without_row_is_named
run_test test_row_without_edge_is_named
run_test test_unlabelled_actor_is_named
run_test test_bad_lane_is_named
run_test test_missing_test_is_named
run_test test_missing_mutation_is_named
run_test test_operator_git_must_be_manual
run_test test_redraft_must_name_both_verbs
run_test test_real_tree_is_clean

test_done "change model gate"
