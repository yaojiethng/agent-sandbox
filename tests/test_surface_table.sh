#!/usr/bin/env bash
# TEST_DEADLINE: 120
# tests/test_surface_table.sh
# Behavioural tests for src/build/surface_table.mjs -- the one writer of the
# generated destination table -- and the scripts/check_surface_table.sh gate it
# wraps.
#
# Covers the two rules the gate holds over docs/reference/*.md:
#
#   a block equal to the manifest              --  rc 0
#   a hand-edited block body                   --  rc 1; the file is named
#   a BEGIN marker with no END                 --  rc 1; the marker is named
#   an END marker with no BEGIN                --  rc 1; the marker is named
#   no reference document carries a block      --  rc 1; the folder is named
#   a table row restating source and target    --  rc 1; the line is named
#   a prose line naming both, outside a table  --  rc 0 (the sentence is not a
#                                                 mapping and stays readable)
#   a backticked path the tree does not hold   --  rc 1; the path is named
#   a `<placeholder>` path that resolves       --  rc 0
#   a `<placeholder>` path that does not       --  rc 1; the path is named
#   a reference folder with no .md file        --  rc 1 (fails closed)
#   a missing manifest                         --  rc 1 (fails closed)
#   `write` bringing a drifted block back      --  rc 0 afterwards; one path
#                                                 reported as rewritten
#   `write` on a clean tree                    --  rc 0; nothing rewritten
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the scan is
# pointed at them with SURFACE_TABLE_SCAN_ROOT, so the repository's own
# documents are never the subject.
#
# Run:   bash tests/test_surface_table.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_surface_table.sh"
MODULE="$REPO_ROOT/src/build/surface_table.mjs"
MANIFEST_REL="src/build/container-interface.json"

GATE_RC=0
GATE_OUT=""
run_gate() {
  GATE_RC=0
  GATE_OUT=$(SURFACE_TABLE_SCAN_ROOT="$1" bash "$GATE" 2>&1) || GATE_RC=$?
}

MODULE_RC=0
MODULE_OUT=""
run_module() {
  MODULE_RC=0
  MODULE_OUT=$(node "$MODULE" "$@" 2>&1) || MODULE_RC=$?
}

# write_manifest ROOT  --  a manifest holding three image rows and the provider
# directory the placeholder rule resolves against.
write_manifest() {
  local root="$1"
  local path="$root/$MANIFEST_REL"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
{
  "image": [
    { "provider": "pi", "source": "src/libs/", "destination": "/opt/sandbox/lib/" },
    { "provider": "pi", "source": "docs/reference/", "destination": "/opt/sandbox/docs/reference/" },
    { "provider": "pi", "source": "src/reasoning/agent/skills/", "destination": "/opt/workflow/agent/skills/" }
  ]
}
EOF
}

# write_reference ROOT NAME LINE...  --  one reference document holding the
# given lines, verbatim.
write_reference() {
  local root="$1" name="$2"
  shift 2
  local path="$root/docs/reference/$name"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

BLOCK_BEGIN='<!-- BEGIN GENERATED: surface-table -->'
BLOCK_END='<!-- END GENERATED: surface-table -->'

# write_tree ROOT  --  a manifest, a provider directory for the placeholder
# rule, and one reference document whose block the module writes.
write_tree() {
  local root="$1"
  write_manifest "$root"
  mkdir -p "$root/src/reasoning/agent-runtime/pi"
  write_reference "$root" model.md "Intro line." "" "$BLOCK_BEGIN" "$BLOCK_END"
  node "$MODULE" write --root "$root" >/dev/null
}

test_conforming_tree_passes() {
  local root="$FIXTURE_DIR/conforming"
  write_tree "$root"
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'a generated block equal to the manifest passes'
}

test_hand_edited_block_flagged() {
  local root="$FIXTURE_DIR/edited"
  write_tree "$root"
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const text = fs.readFileSync(file, "utf8");
    fs.writeFileSync(file, text.replace("`src/libs/`", "`src/lib/`"));
  ' "$root/docs/reference/model.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a hand-edited block fails'
  assert_contains "$GATE_OUT" 'the generated block differs from the manifest' 'the divergence is named'
  assert_contains "$GATE_OUT" 'docs/reference/model.md' 'the file is named'
}

test_unterminated_block_flagged() {
  local root="$FIXTURE_DIR/unterminated"
  write_tree "$root"
  write_reference "$root" model.md "$BLOCK_BEGIN" '| a | b |' '|---|---|'
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a BEGIN marker with no END fails'
  assert_contains "$GATE_OUT" 'has no matching' 'the missing marker is named'
}

test_end_without_begin_flagged() {
  local root="$FIXTURE_DIR/endonly"
  write_tree "$root"
  write_reference "$root" stray.md 'text' "$BLOCK_END"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an END marker with no BEGIN fails'
  assert_contains "$GATE_OUT" 'has no <!-- BEGIN GENERATED' 'the missing marker is named'
}

test_no_block_anywhere_flagged() {
  local root="$FIXTURE_DIR/noblock"
  write_manifest "$root"
  write_reference "$root" plain.md 'No block here.'
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a tree stating no block fails'
  assert_contains "$GATE_OUT" 'no reference document carries a' 'the folder is named'
}

test_table_row_restating_the_mapping_flagged() {
  local root="$FIXTURE_DIR/restated"
  write_tree "$root"
  write_reference "$root" model.md "$BLOCK_BEGIN" "$BLOCK_END" "" \
    '| Source | Destination |' \
    '|---|---|' \
    '| `src/libs/` | `/opt/sandbox/lib/` |'
  node "$MODULE" write --root "$root" >/dev/null
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a table row restating the mapping fails'
  assert_contains "$GATE_OUT" 'restates the mapping outside the generated block' 'the finding is named'
  local row_line
  row_line="$(grep -n 'src/libs/' "$root/docs/reference/model.md" | tail -1 | cut -d: -f1)"
  assert_contains "$GATE_OUT" "docs/reference/model.md:${row_line}:" 'the line is named'
}

test_prose_line_naming_both_passes() {
  local root="$FIXTURE_DIR/prose"
  write_tree "$root"
  write_reference "$root" model.md "$BLOCK_BEGIN" "$BLOCK_END" "" \
    'The libraries in `src/libs/` are sourced from the baked `/opt/sandbox/lib/` path.'
  node "$MODULE" write --root "$root" >/dev/null
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'a sentence naming both paths is not a mapping statement'
}

test_unresolved_path_flagged() {
  local root="$FIXTURE_DIR/unresolved"
  write_tree "$root"
  write_reference "$root" model.md "$BLOCK_BEGIN" "$BLOCK_END" "" \
    'The record sits at `src/reasoning/agent-runtime/<n>/config/settings.json`.'
  node "$MODULE" write --root "$root" >/dev/null
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a path the tree does not hold fails'
  assert_contains "$GATE_OUT" 'does not resolve in the tree' 'the finding is named'
  assert_contains "$GATE_OUT" 'src/reasoning/agent-runtime/<n>/config/settings.json' 'the path is named'
}

test_placeholder_path_resolves() {
  local root="$FIXTURE_DIR/placeholder"
  write_tree "$root"
  mkdir -p "$root/src/reasoning/agent-runtime/pi/config/agent"
  printf 'FROM scratch\n' > "$root/src/reasoning/agent-runtime/pi/provider.dockerfile"
  printf 'the provider layer\n' > "$root/src/reasoning/agent-runtime/pi/config/agent/AGENTS.md"
  write_reference "$root" model.md "$BLOCK_BEGIN" "$BLOCK_END" "" \
    'Each provider supplies an `AGENTS.md` at `src/reasoning/agent-runtime/<n>/config/agent/AGENTS.md`.'
  node "$MODULE" write --root "$root" >/dev/null
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'a `<placeholder>` segment resolves against the provider directory'
}

test_missing_reference_folder_fails_closed() {
  local root="$FIXTURE_DIR/noref"
  write_manifest "$root"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a tree with no reference folder fails closed'
  assert_contains "$GATE_OUT" 'docs/reference/ is missing' 'the missing folder is named'
}

test_missing_manifest_fails_closed() {
  local root="$FIXTURE_DIR/nomanifest"
  write_reference "$root" model.md "$BLOCK_BEGIN" "$BLOCK_END"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a tree with no manifest fails closed'
  assert_contains "$GATE_OUT" 'is missing or does not parse' 'the missing manifest is named'
}

test_write_repairs_a_drifted_block() {
  local root="$FIXTURE_DIR/repair"
  write_tree "$root"
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    fs.writeFileSync(file, fs.readFileSync(file, "utf8").replace("`src/libs/`", "`src/lib/`"));
  ' "$root/docs/reference/model.md"
  run_module write --root "$root"
  assert_rc 0 "$MODULE_RC" 'write succeeds'
  assert_contains "$MODULE_OUT" 'rewrote docs/reference/model.md' 'the rewritten file is named'
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'the block matches the manifest after the write'
}

test_write_on_a_clean_tree_reports_nothing() {
  local root="$FIXTURE_DIR/clean"
  write_tree "$root"
  run_module write --root "$root"
  assert_rc 0 "$MODULE_RC" 'write succeeds'
  assert_empty "$MODULE_OUT" 'nothing is rewritten when the block already matches'
}

run_test test_conforming_tree_passes
run_test test_hand_edited_block_flagged
run_test test_unterminated_block_flagged
run_test test_end_without_begin_flagged
run_test test_no_block_anywhere_flagged
run_test test_table_row_restating_the_mapping_flagged
run_test test_prose_line_naming_both_passes
run_test test_unresolved_path_flagged
run_test test_placeholder_path_resolves
run_test test_missing_reference_folder_fails_closed
run_test test_missing_manifest_fails_closed
run_test test_write_repairs_a_drifted_block
run_test test_write_on_a_clean_tree_reports_nothing

test_done
