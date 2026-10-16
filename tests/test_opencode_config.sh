#!/usr/bin/env bash
# tests/test_opencode_config.sh  --  OpenCode config generation
#
# Decision (out of scope): Prompts as OpenCode commands need an agent and a
# model mapping the runner seam owns, so they are deliberately not emitted.
#
# Run:
#   bash tests/test_opencode_config.sh
#
# Exit code: 0 if all tests pass, 1 if any fail.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

GEN="$REPO_ROOT/src/build/opencode-config.mjs"

test_generator_prints_valid_json() {
  local out rc
  out="$(node "$GEN" 2>&1)" ; rc=$?
  assert_rc 0 "$rc" "generator exits 0"
  # Validate JSON and inspect shape.
  local skills_count
  skills_count="$(printf '%s' "$out" | jq -r '.skills | length')"
  assert_not_empty "$skills_count" "skills count readable"
}

test_skills_one_entry_per_skills_cell() {
  local manifest="$REPO_ROOT/src/build/container-interface.json"
  local expected_cells_plus_extra
  expected_cells_plus_extra="$(jq '[.cells[].sources[] | select(endswith("skills/"))] | length' "$manifest")"
  expected_cells_plus_extra=$((expected_cells_plus_extra + 1))
  local actual
  actual="$(node "$GEN" | jq -r '.skills | length')"
  assert_eq_num "$actual" "$expected_cells_plus_extra" "skills count equals skills cells plus .agents/skills"
  # Each declared skills-cell source must appear as an absolute path entry.
  local src entry ok
  ok=0
  while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    entry="$REPO_ROOT/$src"
    if ! node "$GEN" | jq -e --arg p "$entry" '.skills | index($p) != null' >/dev/null; then
      echo "  not ok: missing skill path $entry"
      ok=1
    fi
  done < <(jq -r '.cells[].sources[] | select(endswith("skills/"))' "$manifest")
  if [[ "$ok" -eq 0 ]]; then
    pass "every declared skills cell appears in skills"
  else
    fail "every declared skills cell appears in skills"
  fi
}

test_instructions_named() {
  local out
  out="$(node "$GEN")"
  assert_contains "$out" '"'"$REPO_ROOT/AGENTS.md"'"' "root AGENTS.md in instructions"
  assert_contains "$out" '"'"$REPO_ROOT/src/reasoning/providers/pi/config/agent/AGENTS.md"'"' "pi AGENTS.md in instructions"
}

test_added_skills_cell_changes_output() {
  local tmp_root tmp_manifest base_out new_out
  tmp_root="$(get_fixture_dir)"
  mkdir -p "$tmp_root/src/build"
  cp "$REPO_ROOT/src/build/container-interface.json" "$tmp_root/src/build/container-interface.json"
  tmp_manifest="$tmp_root/src/build/container-interface.json"
  # Add a skills cell to a copy of the manifest.
  jq '.cells += [{"sources":["src/extra/skills/"],"runtime_path":"/opt/workflow/agent/extra/","loader":"x"}]' \
    "$tmp_manifest" > "$tmp_manifest.new" && mv "$tmp_manifest.new" "$tmp_manifest"
  base_out="$(node "$GEN")"
  new_out="$(node "$GEN" --root "$tmp_root")"
  if [[ "$base_out" == "$new_out" ]]; then
    fail "adding a skills cell changes the output"
  else
    pass "adding a skills cell changes the output"
  fi
}

run_test test_generator_prints_valid_json
run_test test_skills_one_entry_per_skills_cell
run_test test_instructions_named
run_test test_added_skills_cell_changes_output

test_done
