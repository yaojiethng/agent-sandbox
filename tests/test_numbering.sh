#!/usr/bin/env bash
# Tests for the numbering check: contiguous units, ordered sections, resolvable
# references.
#
# Each case builds a small tree, runs the check from that root, and reads the
# verdict. A number is contiguous from 1 within its scope, so a gap is the
# defect the check exists to catch.
#
# Covers:
#   units    --  contiguous units pass, a gap fails, a repeat fails
#   sections --  a dotted series stays in order, a skip fails
#   refs     --  a qualified reference resolves, a missing unit fails
#   prose    --  a fenced block and an unnumbered list carry no units
#   archive  --  a closed archive tree is historical and is not checked

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

RULE="$REPO_ROOT/scripts/lint/numbering.mjs"

run_in() {
  local dir="$1"; shift
  ( cd "$dir" && node "$RULE" "$@" 2>&1 )
}

numbering_contiguous_units_pass() {
  local d; d="$(mktemp -d)"
  printf '# Report\n\n### F1 First\n\n### F2 Second\n\n### Q1 A question\n' > "$d/report.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "0" "contiguous units pass"
  assert_contains "$out" "1 with numbered units" "the report counts the population"
  rm -rf "$d"
}

numbering_unit_gap_fails() {
  local d; d="$(mktemp -d)"
  printf '# Report\n\n### F1 First\n\n### F3 Third\n' > "$d/report.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "1" "a gap fails"
  assert_contains "$out" "F3 is at position 2" "the finding names the unit and its position"
  rm -rf "$d"
}

numbering_unit_repeat_fails() {
  local d; d="$(mktemp -d)"
  printf '# Report\n\n### F1 First\n\n### F1 Again\n' > "$d/report.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "1" "a repeated number fails"
  assert_contains "$out" "F1 is at position 2" "the repeat is reported as a position"
  rm -rf "$d"
}

numbering_section_order_holds() {
  local d; d="$(mktemp -d)"
  printf '# Doc\n\n## 1 One\n\n### 1.1 A\n\n### 1.2 B\n\n## 2 Two\n' > "$d/doc.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "0" "an ordered section series passes"
  rm -rf "$d"
}

numbering_section_gap_fails() {
  local d; d="$(mktemp -d)"
  printf '# Doc\n\n## 1 One\n\n## 1 Again\n' > "$d/doc.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "1" "a section that repeats fails"
  assert_contains "$out" "1 follows 1" "the finding names the pair"
  rm -rf "$d"
}

numbering_reference_resolves() {
  local d; d="$(mktemp -d)"
  printf '# Report\n\n### F1 First\n\n### F2 Second\n\n### F3 Third\n' > "$d/20260101-01-report.md"
  printf '# Note\n\nsee `20260101-01-report.md`/F3 for the detail\n' > "$d/note.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "0" "a reference to an existing unit passes"
  rm -rf "$d"
}

numbering_dangling_reference_fails() {
  local d; d="$(mktemp -d)"
  printf '# Report\n\n### F1 First\n' > "$d/20260101-01-report.md"
  printf '# Note\n\nsee `20260101-01-report.md`/F4 for the detail\n' > "$d/note.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "1" "a reference to a missing unit fails"
  assert_contains "$out" "F4 names no unit" "the finding names the unit"
  rm -rf "$d"
}

numbering_prose_carries_no_units() {
  local d; d="$(mktemp -d)"
  printf '# Doc\n\n```text\nF9 in a fenced block is not a unit\n```\n\n- a bullet with no unit\n' > "$d/doc.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "0" "a fenced block and a plain list carry no units"
  assert_contains "$out" "0 with numbered units" "the population is empty"
  rm -rf "$d"
}

numbering_archive_is_not_checked() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/devlog/handovers/archive"
  printf '# Old\n\n### F1 One\n\n### F5 Five\n' > "$d/devlog/handovers/archive/20260101-01-old.md"
  local out rc
  out="$(run_in "$d")"; rc=$?
  assert_eq "$rc" "0" "a closed archive tree is historical"
  rm -rf "$d"
}

numbering_skill_defines_every_letter() {
  local skill="$REPO_ROOT/.agents/skills/numbering/SKILL.md"
  local l pat got
  for l in F Q D R; do
    pat='^\| `'"$l"'` '
    got="$(grep -E "$pat" "$skill")"
    assert_not_empty "$got" "the unit-letter table defines $l"
  done
}

numbering_skill_rules_cite_a_story() {
  local skill="$REPO_ROOT/.agents/skills/numbering/SKILL.md"
  local rows missing
  rows="$(awk '/^## The scheme per class/{f=1;next} /^## /{f=0} f && /^\| / && !/^\| Class/ && !/^\|---/' "$skill")"
  assert_not_empty "$rows" "the class table has rows"
  missing="$(printf '%s\n' "$rows" | grep -vE 'S[0-9]' || true)"
  assert_empty "$missing" "every class row cites a story"
}

numbering_skill_stories_are_served() {
  local skill="$REPO_ROOT/.agents/skills/numbering/SKILL.md"
  local ids cited id
  ids="$(grep -oE '^\| S[0-9]+ ' "$skill" | tr -d '| ' | sort -u)"
  assert_not_empty "$ids" "the story table has rows"
  cited="$(grep -oE 'S[0-9]+' "$skill" | sort | uniq -c | awk '$1 > 1 { print $2 }')"
  for id in $ids; do
    assert_contains "$cited" "$id" "story $id is served by at least one rule"
  done
}

run_test numbering_skill_defines_every_letter
run_test numbering_skill_rules_cite_a_story
run_test numbering_skill_stories_are_served

run_test numbering_contiguous_units_pass
run_test numbering_unit_gap_fails
run_test numbering_unit_repeat_fails
run_test numbering_section_order_holds
run_test numbering_section_gap_fails
run_test numbering_reference_resolves
run_test numbering_dangling_reference_fails
run_test numbering_prose_carries_no_units
run_test numbering_archive_is_not_checked

test_done
