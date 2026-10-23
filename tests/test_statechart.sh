#!/usr/bin/env bash
# Tests for the statechart gate: `scripts/check_statechart.sh` over a fixture
# chart and its `## States` table.
#
# The gate holds two statements of one state set together, so each case moves one
# statement and asserts the gate names the side that moved. The id and region
# columns are derived from the chart and compared; the gloss column is authored,
# so a gloss that differs from the chart label must stay clean.
#
# Covers:
#   clean      --  a table whose ids and regions match the chart is clean
#   declared   --  a state the chart declares and the table omits is named
#   ghost      --  a table row the chart does not declare is named
#   region     --  a region moved in the table alone is named
#   order      --  rows out of the chart's declaration order are named
#   gloss      --  an authored gloss that differs from the label is clean
#   missing    --  a document without `## States` refuses
#   write      --  `--write` adds the missing row and keeps the authored gloss

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO_ROOT/scripts/check_statechart.sh"

FIXTURE_ROOT_DIR="$FIXTURE_DIR/fixture"
DOC="$FIXTURE_ROOT_DIR/workflow_statechart.md"

# write_doc CHART_ROWS TABLE_ROWS  --  a fixture chart in one region, the table,
# and a following section so the scanner must stop at it.
write_doc() {
  local chart_rows="$1" table_rows="$2"
  mkdir -p "$FIXTURE_ROOT_DIR"
  {
    printf '# Fixture chart\n\n'
    printf '```mermaid\nstateDiagram-v2\n    state "Region one" as one {\n'
    printf '%s\n' "$chart_rows"
    printf '    }\n```\n\n## States\n\n| Id | Region | The state it names |\n|---|---|---|\n'
    printf '%s\n' "$table_rows"
    printf '\n## Commands\n\n`one` outside the table is not read here.\n'
  } > "$DOC"
}

CHART='        state "a_start -- begins" as a_start
        state "a_end -- ends" as a_end'
TABLE='| `a_start` | one | begins |
| `a_end` | one | ends |'

test_clean() {
  write_doc "$CHART" "$TABLE"
  assert_run 0 "$GATE --doc $DOC" "the fixture is clean" || return 1
  assert_contains "$RUN_OUT" "statechart: clean across 2 state(s)" "the clean summary is printed"
}

test_declared_state_is_named() {
  write_doc "$CHART
        state \"a_mid -- midway\" as a_mid" "$TABLE"
  assert_run 1 "$GATE --doc $DOC" "a state the table omits fails the gate"
  assert_contains "$RUN_OUT" "a_mid" "the finding names the state"
}

test_ghost_row_is_named() {
  write_doc "$CHART" "$TABLE
| \`a_ghost\` | one | a ghost |"
  assert_run 1 "$GATE --doc $DOC" "a row the chart does not declare fails the gate"
  assert_contains "$RUN_OUT" "a_ghost" "the finding names the row"
}

test_region_move_is_named() {
  write_doc "$CHART" '| `a_start` | two | begins |
| `a_end` | one | ends |'
  assert_run 1 "$GATE --doc $DOC" "a region moved in the table fails the gate"
  assert_contains "$RUN_OUT" "one" "the finding names the chart's region"
  assert_contains "$RUN_OUT" "two" "the finding names the table's region"
}

test_order_is_named() {
  write_doc "$CHART" '| `a_end` | one | ends |
| `a_start` | one | begins |'
  assert_run 1 "$GATE --doc $DOC" "rows out of order fail the gate"
  assert_contains "$RUN_OUT" "declaration order" "the finding names the order"
}

test_authored_gloss_is_clean() {
  write_doc "$CHART" '| `a_start` | one | the authored beginning |
| `a_end` | one | ends |'
  assert_run 0 "$GATE --doc $DOC" "an authored gloss is not compared" || return 1
  assert_contains "$RUN_OUT" "statechart: clean" "the clean summary is printed"
}

test_missing_section_refuses() {
  mkdir -p "$FIXTURE_ROOT_DIR"
  printf '# Fixture chart\n\n```mermaid\nstateDiagram-v2\n    state "a_start -- begins" as a_start\n```\n' > "$DOC"
  assert_run 1 "$GATE --doc $DOC" "a document without the section fails the gate"
  assert_contains "$RUN_OUT" "no \`## States\` section" "the refusal names the missing section"
}

test_write_adds_the_row_and_keeps_the_gloss() {
  write_doc "$CHART
        state \"a_mid -- midway\" as a_mid" '| `a_start` | one | the authored beginning |
| `a_end` | one | ends |'
  assert_run 0 "$GATE --doc $DOC --write" "the write completes" || return 1
  assert_run 0 "$GATE --doc $DOC" "the regenerated table is clean" || return 1
  assert_contains "$(cat "$DOC")" "| \`a_mid\` | one | midway |" "the new row is seeded from the label"
  assert_contains "$(cat "$DOC")" "| \`a_start\` | one | the authored beginning |" "the authored gloss is kept"
}

test_real_tree_is_clean() {
  assert_run 0 "$GATE" "the tree's chart is clean" || return 1
  assert_contains "$RUN_OUT" "statechart: clean across 40 state(s)" "the summary counts the states"
}

run_test test_clean
run_test test_declared_state_is_named
run_test test_ghost_row_is_named
run_test test_region_move_is_named
run_test test_order_is_named
run_test test_authored_gloss_is_clean
run_test test_missing_section_refuses
run_test test_write_adds_the_row_and_keeps_the_gloss
run_test test_real_tree_is_clean

test_done "statechart gate"
