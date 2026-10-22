#!/usr/bin/env bash
# TEST_DEADLINE: 40
# tests/test_norm_ownership.sh
# Behavioural tests for scripts/check_norm_ownership.sh -- the norm ledger gate.
#
# The ledger holds every prose line of the two source documents to an observer and a
# mark, and the skill its text cites as the line's source of truth. Rule and judgement
# are read off the observer, so no row states them. The grouping map holds the
# judgement lines that cite no skill.
#
#   a conforming tree                            --  rc 0; the summary carries a sourced count
#   a new prose line                             --  rc 1; the line is named unclassified
#   a norm with no observer                       --  rc 0; it counts as a judgement
#   a description carrying an observer            --  rc 1; the mark is named
#   a reviewer no prompt dispatches              --  rc 1; the observer is named
#   a reviewer a prompt dispatches               --  rc 0
#   a cited skill no root holds                  --  rc 1; the source of truth is named
#   a hand-edited source-of-truth column         --  rc 1; the derivation is named
#   a line citing two skills                     --  rc 1; the ambiguity is named
#   a group whose note names no skill            --  rc 1; the group is named
#   --generate derives the source of truth       --  the row carries skill:<name>
#   --regroup derives a sourced group            --  the map stores no row for it
#   a stored row for a sourced line               --  rc 1; the derivation is named as its home
#
# The fixtures sit under $FIXTURE_DIR and the scan is pointed at them with
# NORM_OWNERSHIP_SCAN_ROOT, so the repository's own documents are never the
# subject. The manifest fixture declares the skill and prompt roots the gate
# resolves through src/build/container-interface.mjs.
#
# Run:   bash tests/test_norm_ownership.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_norm_ownership.sh"
PROSE=".agents/skills/docs/SKILL.md"
CONVENTIONS="docs/development/prompt-authoring-conventions.md"
LEDGER="scripts/lint/norm-ownership.tsv"
JUDGEMENTS="scripts/lint/norm-judgements.tsv"

# build_fixture  --  a tree the gate can read: the manifest with one skill root
# and one prompt root, the two source documents, one dispatched skill, one
# undispatched skill, and the lint umbrella the gate resolves a `gate:` observer
# against.
build_fixture() {
  local root="$FIXTURE_DIR"
  mkdir -p "$root/src/build" "$root/.agents/skills/docs" "$root/docs/development" \
    "$root/skills/doc-maintenance" "$root/skills/principle-x" \
    "$root/prompts" "$root/scripts/lint"

  cat > "$root/src/build/container-interface.json" <<'EOF'
{
  "cells": [
    { "sources": ["skills/"], "runtime_path": "/opt/workflow/agent/skills/" },
    { "sources": ["prompts/"], "runtime_path": "/opt/workflow/agent/prompts/" }
  ]
}
EOF

  cat > "$root/skills/doc-maintenance/SKILL.md" <<'EOF'
# Doc maintenance
EOF
  cat > "$root/skills/principle-x/SKILL.md" <<'EOF'
# Principle X
EOF
  cat > "$root/prompts/document.md" <<'EOF'
# Document

Dispatch `doc-maintenance` when the artifact lands.
EOF
  cat > "$root/scripts/lint.sh" <<'EOF'
#!/usr/bin/env bash
GATES=(check_norm_ownership.sh)
EOF
  printf '# Lint rule\n' > "$root/scripts/lint/linking.mjs"

  cat > "$root/$PROSE" <<'EOF'
# docs

A writer keeps the sentence that changes a decision.

A writer applies `skills/principle-x/SKILL.md` before drafting.

A writer states the fact the reader needs.

The gate reads the reference.
EOF
  cat > "$root/$CONVENTIONS" <<'EOF'
# Authoring conventions

A prompt opens with frontmatter and a body.

A prompt states its subject once.
EOF
}

# classify TEXT MARK OBSERVER  --  set the mark and observer of the ledger row
# whose text is TEXT. The text is matched as a prefix so a long line is easy to
# name in a test.
classify() {
  local text="$1" mark="$2" obs="$3"
  awk -F'\t' -v text="$text" -v mark="$mark" -v obs="$obs" 'BEGIN { OFS = "\t" }
    $0 ~ /^#/ || $0 == "" { print; next }
    index($6, text) == 1 { $3 = mark; $4 = obs }
    { print }
  ' "$FIXTURE_DIR/$LEDGER" > "$FIXTURE_DIR/$LEDGER.tmp"
  mv "$FIXTURE_DIR/$LEDGER.tmp" "$FIXTURE_DIR/$LEDGER"
}

# set_source_of_truth TEXT SOURCE  --  overwrite a row's derived source of truth, standing in for a hand
# edit the gate must reject.
set_source_of_truth() {
  local text="$1" source="$2"
  awk -F'\t' -v text="$text" -v source="$source" 'BEGIN { OFS = "\t" }
    $0 ~ /^#/ || $0 == "" { print; next }
    index($6, text) == 1 { $5 = source }
    { print }
  ' "$FIXTURE_DIR/$LEDGER" > "$FIXTURE_DIR/$LEDGER.tmp"
  mv "$FIXTURE_DIR/$LEDGER.tmp" "$FIXTURE_DIR/$LEDGER"
}

# map_row TEXT GROUP NOTE  --  append a grouping row for the line whose text
# begins with TEXT.
map_row() {
  local text="$1" group="$2" note="$3" hash
  hash="$(awk -F'\t' -v text="$text" '$0 !~ /^#/ && index($6, text) == 1 { print $1; exit }' "$FIXTURE_DIR/$LEDGER")"
  printf '%s\t%s\t%s\n' "$hash" "$group" "$note" >> "$FIXTURE_DIR/$JUDGEMENTS"
}

# classify_fixture  --  build the fixture, generate its ledger, and classify the
# four lines so the tree is conforming. The judgement lines cite principle-x and
# carry no source of truth, so each takes a grouping row.
# regenerate  --  derive the source-of-truth column after a mark changed. `--generate`
# preserves a recorded mark and observer by hash, and derives the source of truth from the
# text, so it runs once to create the rows and again once they are classified.
regenerate() {
  ( cd "$FIXTURE_DIR" && NORM_OWNERSHIP_SCAN_ROOT="$FIXTURE_DIR" bash "$GATE" --generate >/dev/null )
}

classify_fixture() {
  build_fixture
  regenerate
  classify "A writer keeps the sentence" norm none
  classify "A writer applies \`skills/principle-x/SKILL.md\`" norm none
  classify "A writer states the fact" norm none
  classify "The gate reads the reference" norm gate:check_norm_ownership.sh
  classify "A prompt opens with frontmatter" description none
  classify "A prompt states its subject once" norm none
  regenerate
  printf '# Judgement grouping map.\n' > "$FIXTURE_DIR/$JUDGEMENTS"
  map_row "A writer keeps the sentence" j-delete-test -
  map_row "A writer states the fact" j-local-fact -
  map_row "A prompt states its subject once" j-one-subject -
}

# run_gate ARGS...  --  run the gate against the fixture, capturing output and
# exit code in OUT and RC.
run_gate() {
  OUT="$( cd "$FIXTURE_DIR" && NORM_OWNERSHIP_SCAN_ROOT="$FIXTURE_DIR" bash "$GATE" "$@" 2>&1 )"
  RC=$?
}

test_conforming_tree_passes() {
  classify_fixture
  run_gate --check
  assert_rc 0 "$RC" "conforming tree passes"
  assert_contains "$OUT" "sourced" "the summary reports the sourced count"
}

test_new_line_is_unclassified() {
  classify_fixture
  printf 'A writer never repeats the same sentence.\n' >> "$FIXTURE_DIR/$PROSE"
  run_gate --check
  assert_rc 1 "$RC" "a new line fails the gate"
  assert_contains "$OUT" "unclassified line" "the unclassified line is named"
}

test_norm_without_observer_is_a_judgement() {
  classify_fixture
  classify "The gate reads the reference" norm none
  map_row "The gate reads the reference" j-local-fact -
  run_gate --check
  assert_rc 0 "$RC" "a norm with no observer is not an inconsistency"
  assert_contains "$OUT" "judgement" "the line counts as a judgement once it is grouped"
}

test_description_with_observer_fails() {
  classify_fixture
  classify "A prompt opens with frontmatter" description gate:check_norm_ownership.sh
  run_gate --check
  assert_rc 1 "$RC" "a description carrying an observer fails the gate"
  assert_contains "$OUT" "marks a description with an observer" "the mark is named"
}

test_review_observer_must_be_dispatched() {
  classify_fixture
  classify "The gate reads the reference" norm review:principle-x
  run_gate --check
  assert_rc 1 "$RC" "a skill no prompt dispatches cannot observe a rule"
  assert_contains "$OUT" "observer 'review:principle-x' that does not run" "the observer is named"
}

test_review_observer_dispatched_passes() {
  classify_fixture
  classify "The gate reads the reference" norm review:doc-maintenance
  run_gate --check
  assert_rc 0 "$RC" "a dispatched skill observes a rule"
}

test_cited_skill_must_exist() {
  classify_fixture
  printf 'A writer applies `skills/ghost/SKILL.md` before drafting.\n' >> "$FIXTURE_DIR/$PROSE"
  run_gate --generate
  classify "A writer applies \`skills/ghost/SKILL.md\`" norm none
  regenerate
  run_gate --check
  assert_rc 1 "$RC" "a cited skill no root holds fails the gate"
  assert_contains "$OUT" "which no declared skill root holds" "the source of truth is named"
}

test_hand_edited_source_of_truth_is_rejected() {
  classify_fixture
  set_source_of_truth "A writer keeps the sentence" skill:principle-x
  run_gate --check
  assert_rc 1 "$RC" "a hand-edited source of truth fails the gate"
  assert_contains "$OUT" "do not hand-edit" "the derivation is named"
}

test_two_cited_skills_are_ambiguous() {
  classify_fixture
  printf 'A writer reads `skills/doc-maintenance/SKILL.md` and `skills/principle-x/SKILL.md`.\n' >> "$FIXTURE_DIR/$PROSE"
  run_gate --generate
  classify "A writer reads \`skills/doc-maintenance" norm none
  regenerate
  run_gate --check
  assert_rc 1 "$RC" "a line citing two skills fails the gate"
  assert_contains "$OUT" "cites more than one skill" "the ambiguity is named"
}

test_group_note_must_resolve() {
  classify_fixture
  sed -i 's/\(.*\)\tj-local-fact\t-$/\1\tj-local-fact\tskill:ghost/' "$FIXTURE_DIR/$JUDGEMENTS"
  run_gate --groups
  assert_rc 1 "$RC" "a group source of truth no root holds fails the gate"
  assert_contains "$OUT" "no declared skill root holds" "the group is named"
}

test_generate_derives_the_source_of_truth() {
  classify_fixture
  local row
  row="$(awk -F'\t' '$0 !~ /^#/ && index($6, "A writer applies") == 1 { print $5 }' "$FIXTURE_DIR/$LEDGER")"
  assert_eq "$row" "skill:principle-x" "--generate derives the source of truth from the citation"
}

test_regroup_derives_a_sourced_group_and_stores_no_row() {
  classify_fixture
  ( cd "$FIXTURE_DIR" && NORM_OWNERSHIP_SCAN_ROOT="$FIXTURE_DIR" bash "$GATE" --regroup >/dev/null )
  local stored derived
  stored="$(awk -F'\t' '$2 ~ /^j-source-of-truth-/ { print $2 }' "$FIXTURE_DIR/$JUDGEMENTS" | paste -sd, -)"
  assert_eq "$stored" "" "--regroup stores no row for a sourced line"
  run_gate --groups
  derived="$(printf '%s\n' "$OUT" | awk -F'\t' '$1 ~ /^j-source-of-truth-/ { print $1 }' | sort -u | paste -sd, -)"
  assert_eq "$derived" "j-source-of-truth-principle-x" "--groups derives a sourced line's group at read time"
}

test_a_stored_sourced_row_fails() {
  classify_fixture
  ( cd "$FIXTURE_DIR" && NORM_OWNERSHIP_SCAN_ROOT="$FIXTURE_DIR" bash "$GATE" --regroup >/dev/null )
  local hash
  hash="$(awk -F'\t' '$0 !~ /^#/ && $5 != "none" { print $1 }' "$FIXTURE_DIR/$LEDGER")"
  printf '%s\tj-source-of-truth-principle-x\tskill:principle-x\n' "$hash" >> "$FIXTURE_DIR/$JUDGEMENTS"
  run_gate --check
  assert_ne 0 "$RC" "a stored row for a sourced line fails the check"
  assert_contains "$OUT" "its group is derived and no map row holds it" "the finding says why the row cannot exist"
}

test_row_source_is_checked() {
  classify_fixture
  awk -F'\t' 'BEGIN { OFS = "\t" }
    $0 ~ /^#/ || $0 == "" { print; next }
    index($6, "A writer states the fact") == 1 { $2 = "docs/development/prompt-authoring-conventions.md" }
    { print }
  ' "$FIXTURE_DIR/$LEDGER" > "$FIXTURE_DIR/$LEDGER.tmp"
  mv "$FIXTURE_DIR/$LEDGER.tmp" "$FIXTURE_DIR/$LEDGER"
  run_gate --check
  assert_rc 1 "$RC" "a row whose source column is wrong fails the gate"
  assert_contains "$OUT" "orphaned row" "the wrong source is named"
}

test_observer_name_matches_whole() {
  classify_fixture
  classify "The gate reads the reference" norm review:doc
  run_gate --check
  assert_rc 1 "$RC" "a fragment of a skill name is not a dispatch of it"
  assert_contains "$OUT" "observer 'review:doc' that does not run" "the fragment is named"
}

test_class_one_group_needs_a_source_of_truth() {
  classify_fixture
  sed -i 's/\tj-local-fact\t-/\tj-dup\t-/; s/\tj-one-subject\t-/\tj-dup\t-/' "$FIXTURE_DIR/$JUDGEMENTS"
  run_gate --groups
  assert_rc 1 "$RC" "a judgement two documents state needs a source of truth"
  assert_contains "$OUT" "so it needs a source of truth" "the group is named"
}

test_regroup_drops_a_gone_row() {
  classify_fixture
  printf 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\tj-gone\t-\n' >> "$FIXTURE_DIR/$JUDGEMENTS"
  ( cd "$FIXTURE_DIR" && NORM_OWNERSHIP_SCAN_ROOT="$FIXTURE_DIR" bash "$GATE" --regroup >/dev/null )
  local gone
  gone="$(grep -c 'j-gone' "$FIXTURE_DIR/$JUDGEMENTS" || true)"
  assert_eq "$gone" "0" "--regroup drops a row whose line is gone"
}

run_test test_conforming_tree_passes
run_test test_new_line_is_unclassified
run_test test_norm_without_observer_is_a_judgement
run_test test_description_with_observer_fails
run_test test_review_observer_must_be_dispatched
run_test test_review_observer_dispatched_passes
run_test test_cited_skill_must_exist
run_test test_hand_edited_source_of_truth_is_rejected
run_test test_two_cited_skills_are_ambiguous
run_test test_group_note_must_resolve
run_test test_generate_derives_the_source_of_truth
run_test test_regroup_derives_a_sourced_group_and_stores_no_row
run_test test_a_stored_sourced_row_fails
run_test test_row_source_is_checked
run_test test_observer_name_matches_whole
run_test test_class_one_group_needs_a_source_of_truth
run_test test_regroup_drops_a_gone_row

test_done "$(basename "${BASH_SOURCE[0]}")"
