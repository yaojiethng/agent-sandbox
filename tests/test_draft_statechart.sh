#!/usr/bin/env bash
# tests/test_draft_statechart.sh
# Tests for the draft branch statechart gate:
# `scripts/check_draft_statechart.sh` over a fixture model, and the real tree.
#
# Covers:
#   clean       -- a chart and table that agree are clean
#   missing row -- an edge without a transition row is named
#   ghost row   -- a transition row without an edge is named
#   no test     -- a product invariant without a real test function is named
#   no mutation -- a product invariant without a catalog row is named
#   ambiguous   -- two same-event transitions with no guard are named
#   real tree   -- the committed model is clean

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO_ROOT/scripts/check_draft_statechart.sh"
DOC="$FIXTURE_DIR/draft_statechart.md"

write_doc() {
  local edges="$1" rows="$2"
  cat > "$DOC" <<EOF
# Fixture chart

\`\`\`mermaid
stateDiagram-v2
${edges}
\`\`\`

## Transitions

| Id | From | Event | Guard | To | Subject | Invariant | Precondition | Postcondition | Tests | Mutation |
|---|---|---|---|---|---|---|---|---|---|---|
${rows}
EOF
}

write_doc_charts() {
  local charts="$1" rows="$2"
  cat > "$DOC" <<EOF
# Fixture chart

${charts}

## Transitions

| Id | From | Event | Guard | To | Subject | Invariant | Precondition | Postcondition | Tests | Mutation |
|---|---|---|---|---|---|---|---|---|---|---|
${rows}
EOF
}

BASE_EDGES='  [*] --> s0: X00 start
  s0 --> s1: X01 export'
BASE_ROWS='| `X00` | `[*]` | start | - | `s0` | none: initial | none: initial | none | none | none: initial | none: initial |
| `X01` | `s0` | export | - | `s1` | `scripts/workflows/apply.sh` | `R` | clean tree | package written | `test_dispatcher_creates_all_artefacts` | 1 |'

test_clean_fixture() {
  write_doc "$BASE_EDGES" "$BASE_ROWS"
  assert_run 0 "$GATE --doc=$DOC" "the fixture is clean" || return 1
  assert_contains "$RUN_OUT" "draft statechart: clean across 2 transition(s)" "the clean summary names the transition count"
}

# Given: a value flag in the space-separated form
# When:  the gate parses its arguments
# Then:  it refuses instead of silently scanning the default document
test_space_separated_doc_is_rejected() {
  write_doc "$BASE_EDGES" "$BASE_ROWS"
  assert_run 1 "$GATE --doc $DOC" "a space-separated --doc is rejected"
  assert_contains "$RUN_OUT" "--doc=PATH" "the refusal names the equal-separated form"
}

test_edge_without_row_is_named() {
  write_doc "$BASE_EDGES
  s1 --> s2: X02 finish" "$BASE_ROWS"
  assert_run 1 "$GATE --doc=$DOC" "an edge without a row fails the gate"
  assert_contains "$RUN_OUT" "X02" "the finding names the edge"
}

test_row_without_edge_is_named() {
  write_doc "$BASE_EDGES" "$BASE_ROWS
| \`X02\` | \`s1\` | finish | - | \`s2\` | \`scripts/workflows/draft.sh\` | \`R\` | ready | done | \`test_dispatcher_creates_all_artefacts\` | 1 |"
  assert_run 1 "$GATE --doc=$DOC" "a row without an edge fails the gate"
  assert_contains "$RUN_OUT" "X02" "the finding names the row"
}

test_product_invariant_needs_a_real_test() {
  write_doc "$BASE_EDGES" "${BASE_ROWS/test_dispatcher_creates_all_artefacts/test_no_such_test}"
  assert_run 1 "$GATE --doc=$DOC" "a missing test function fails the gate"
  assert_contains "$RUN_OUT" "test_no_such_test" "the finding names the missing test"
}

test_product_invariant_needs_a_catalog_row() {
  write_doc "$BASE_EDGES" "${BASE_ROWS/| 1 |/| 999999 |}"
  assert_run 1 "$GATE --doc=$DOC" "a missing mutation row fails the gate"
  assert_contains "$RUN_OUT" "999999" "the finding names the missing mutation"
}

test_ambiguous_event_is_named() {
  write_doc "$BASE_EDGES
  s0 --> s2: X02 export" "$BASE_ROWS
| \`X02\` | \`s0\` | export | - | \`s2\` | \`scripts/workflows/draft.sh\` | \`R\` | clean tree | package written | \`test_dispatcher_creates_all_artefacts\` | 1 |"
  assert_run 1 "$GATE --doc=$DOC" "two same-event transitions without guards fail the gate"
  assert_contains "$RUN_OUT" "share the event" "the finding names the ambiguity"
}

# Given: an edge with no transition id
# When:  the gate scans the chart
# Then:  the edge is named instead of skipped
test_edge_without_id_is_named() {
  write_doc "$BASE_EDGES
  s1 --> s2: finish" "$BASE_ROWS"
  assert_run 1 "$GATE --doc=$DOC" "an edge without an id fails the gate"
  assert_contains "$RUN_OUT" "no transition id" "the finding names the missing id"
}

# Given: an edge with no label at all
# When:  the gate scans the chart
# Then:  the missing label is a finding, not an empty label that passes
test_edge_without_label_is_named() {
  write_doc "$BASE_EDGES
  s1 --> s2" "$BASE_ROWS"
  assert_run 1 "$GATE --doc=$DOC" "an edge without a label fails the gate"
  assert_contains "$RUN_OUT" "no transition label" "the finding names the missing label"
}

# Given: an edge with an empty label
# When:  the gate scans the chart
# Then:  the empty label is a finding
test_empty_label_is_named() {
  write_doc "$BASE_EDGES
  s1 --> s2:" "$BASE_ROWS"
  assert_run 1 "$GATE --doc=$DOC" "an empty label fails the gate"
  assert_contains "$RUN_OUT" "no transition label" "the finding names the empty label"
}

# Given: an edge in a Mermaid arrow form the scanner does not accept
# When:  the gate scans the chart
# Then:  the malformed edge is named instead of silently skipped
test_noncanonical_arrow_is_named() {
  write_doc "$BASE_EDGES
  s1 -->|done| s2: X02 finish" "$BASE_ROWS"
  assert_run 1 "$GATE --doc=$DOC" "a non-canonical arrow fails the gate"
  assert_contains "$RUN_OUT" "canonical form" "the finding names the canonical-form violation"
}

# Given: two transition prefixes in one Mermaid block
# When:  the gate groups transitions by chart
# Then:  the mixed block is named
test_mixed_prefix_block_is_named() {
  write_doc "$BASE_EDGES
  s1 --> s2: Y02 finish" "$BASE_ROWS"
  assert_run 1 "$GATE --doc=$DOC" "a block with two prefixes fails the gate"
  assert_contains "$RUN_OUT" "mixes transition prefixes" "the finding names the mixed block"
}

# Given: one transition prefix in two Mermaid blocks
# When:  the gate groups transitions by chart
# Then:  the split prefix is named
test_prefix_in_two_blocks_is_named() {
  write_doc_charts "\`\`\`mermaid
stateDiagram-v2
${BASE_EDGES}
\`\`\`

\`\`\`mermaid
stateDiagram-v2
  s1 --> s2: X02 finish
\`\`\`" "$BASE_ROWS"
  assert_run 1 "$GATE --doc=$DOC" "one prefix in two blocks fails the gate"
  assert_contains "$RUN_OUT" "appears in chart blocks" "the finding names the split prefix"
}

# Given: a product transition whose mutation row mutates another subject
# When:  the gate cross-checks the catalog subject
# Then:  the mismatched subject is named
test_mutation_subject_must_match() {
  local rows="${BASE_ROWS/scripts\/workflows\/apply.sh/scripts\/workflows\/draft.sh}"
  write_doc "$BASE_EDGES" "$rows"
  assert_run 1 "$GATE --doc=$DOC" "a mutation row in another subject fails the gate"
  assert_contains "$RUN_OUT" "mutates scripts/workflows/apply.sh" "the finding names the mutation subject"
}

# Given: a product transition with no subject
# When:  the gate reads the row
# Then:  the missing subject is named
test_product_invariant_needs_a_subject() {
  local rows="${BASE_ROWS/scripts\/workflows\/apply.sh/-}"
  write_doc "$BASE_EDGES" "$rows"
  assert_run 1 "$GATE --doc=$DOC" "a product transition without a subject fails the gate"
  assert_contains "$RUN_OUT" "names an invariant and no subject" "the finding names the missing subject"
}

test_real_tree_is_clean() {
  assert_run 0 "$GATE" "the committed model is clean" || return 1
  assert_contains "$RUN_OUT" "draft statechart: clean across" "the real summary is printed"
}

run_test test_clean_fixture
run_test test_space_separated_doc_is_rejected
run_test test_edge_without_row_is_named
run_test test_row_without_edge_is_named
run_test test_product_invariant_needs_a_real_test
run_test test_product_invariant_needs_a_catalog_row
run_test test_ambiguous_event_is_named
run_test test_edge_without_id_is_named
run_test test_edge_without_label_is_named
run_test test_empty_label_is_named
run_test test_noncanonical_arrow_is_named
run_test test_mixed_prefix_block_is_named
run_test test_prefix_in_two_blocks_is_named
run_test test_mutation_subject_must_match
run_test test_product_invariant_needs_a_subject
run_test test_real_tree_is_clean

test_done "draft statechart gate"
