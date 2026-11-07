#!/usr/bin/env bash
# tests/test_skill_map.sh
# The generated skill-layer map: the four layers, pi's first-wins resolution,
# the collision gate, the shipped-layer link boundary and the warning report.
#
# Covers:
#   clean          -- four layers with distinct names and a project link into a
#                     shipped layer pass
#   collision      -- one name in two layers fails and names both
#   forbidden link -- an agent-sandbox link into the provider layer fails
#   broken link    -- a relative link with no target fails
#   no record      -- an agent-sandbox skill with no record file passes, because
#                     provenance is opt-in bump data and the gate does not ask for it
#   empty tree     -- four declared layers holding no skill fail
#   repository     -- the real tree is clean across four layers

set -uo pipefail

# TEST_DEADLINE: 120

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="$REPO_ROOT/scripts/skill_map.mjs"
LAYERS="$REPO_ROOT/scripts/skill_layers.mjs"

# layer_dir -- a layer's directory under a fixture root, read from the layer
# table so a moved layer moves the fixture with it.
layer_dir() {
  local root="$1" name="$2" source
  source="$(node "$LAYERS" --list | awk -F'\t' -v n="$name" '$1 == n { print $2 }')"
  printf '%s\n' "$root/$source"
}

# relative_to -- the relative path from one absolute path to another.
relative_to() {
  node -e 'process.stdout.write(require("node:path").relative(process.argv[1], process.argv[2]))' "$1" "$2"
}

write_skill() {
  local dir="$1" name="$2" description="$3" body="${4:-}"
  mkdir -p "$dir"
  cat >"$dir/SKILL.md" <<EOF
---
name: $name
description: $description
---

$body
EOF
}


# make_fixture -- one skill in each layer the table declares, plus a project
# skill that links into a shipped layer.
make_fixture() {
  local root="$FIXTURE_DIR/tree"
  local name source project agent
  while IFS=$'\t' read -r name source _; do
    write_skill "$root/$source/$name-skill" "$name-skill" "The $name layer skill."
  done < <(node "$LAYERS" --list)
  project="$(layer_dir "$root" project)/project-skill"
  agent="$(layer_dir "$root" agent-sandbox)/agent-sandbox-skill"
  write_skill "$project" project-skill "Project skill." \
    "See [the agent skill]($(relative_to "$project" "$agent/SKILL.md"))."
  printf '%s\n' "$root"
}

run_map() {
  local root="$1"
  node "$MAP" --root "$root" 2>&1
}

test_clean_fixture_passes() {
  local root out rc
  root="$(make_fixture)"
  out="$(run_map "$root")"; rc=$?
  assert_rc 0 "$rc" "four distinct layers pass"
  assert_contains "$out" "clean across 4 layer(s) and 4 skill(s)" "the clean report counts four layers and four skills"
  assert_contains "$out" "project-to-shipped link" "the allowed project link is reported"
}

test_a_collision_fails_and_names_both_layers() {
  local root out rc
  root="$(make_fixture)"
  write_skill "$(layer_dir "$root" provider)/project-skill" project-skill "A second project-skill."
  out="$(run_map "$root")"; rc=$?
  assert_rc 1 "$rc" "one name in two layers fails"
  assert_contains "$out" "collision: 'project-skill' is held by project" "the winner's layer is named"
  assert_contains "$out" "and provider (" "the loser's layer is named by the finding"
}

test_a_shipped_link_outside_its_layer_fails() {
  local root out rc agent provider
  root="$(make_fixture)"
  agent="$(layer_dir "$root" agent-sandbox)/agent-sandbox-skill"
  provider="$(layer_dir "$root" provider)/provider-skill/SKILL.md"
  printf "\nSee [the provider skill](%s).\n" "$(relative_to "$agent" "$provider")" >>"$agent/SKILL.md"
  out="$(run_map "$root")"; rc=$?
  assert_rc 1 "$rc" "an agent-sandbox link into the provider layer fails"
  assert_contains "$out" "forbidden link: agent-sandbox" "the finding names the source layer"
  assert_contains "$out" "leaves its layer root" "the finding names the boundary"
}

test_a_broken_link_fails() {
  local root out rc
  root="$(make_fixture)"
  printf '\n[missing](missing.md)\n' >>"$(layer_dir "$root" project)/project-skill/SKILL.md"
  out="$(run_map "$root")"; rc=$?
  assert_rc 1 "$rc" "a relative link with no target fails"
  assert_contains "$out" "does not resolve" "the finding names the missing target"
}

test_a_skill_with_no_record_passes() {
  local root out rc
  root="$(make_fixture)"
  out="$(run_map "$root")"; rc=$?
  assert_rc 0 "$rc" "a skill with no record file passes"
  assert_not_contains "$out" "MAINTENANCE" "nothing asks for a record file"
}

test_an_empty_tree_fails() {
  local root out rc name source
  root="$FIXTURE_DIR/empty"
  while IFS=$'\t' read -r name source _; do
    mkdir -p "$root/$source"
  done < <(node "$LAYERS" --list)
  out="$(run_map "$root")"; rc=$?
  assert_rc 1 "$rc" "four declared layers holding no skill fail"
  assert_contains "$out" "map: the declared layers hold no skill" "the empty map is named"
}

test_the_repository_map_is_clean() {
  local out rc
  out="$(node "$MAP" 2>&1)"; rc=$?
  assert_rc 0 "$rc" "the repository map passes"
  assert_contains "$out" "clean across 4 layer(s) and" "the repository has four layers"
  assert_not_contains "$out" "finding:" "the repository map has no hard finding"
}

run_test test_clean_fixture_passes
run_test test_a_collision_fails_and_names_both_layers
run_test test_a_shipped_link_outside_its_layer_fails
run_test test_a_broken_link_fails
run_test test_a_skill_with_no_record_passes
run_test test_an_empty_tree_fails
run_test test_the_repository_map_is_clean

test_done
