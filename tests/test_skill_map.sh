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
#   warning        -- an agent-sandbox skill without MAINTENANCE.md passes with
#                     a warning
#   repository     -- the real tree is clean across four layers

set -uo pipefail

# TEST_DEADLINE: 120

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="$REPO_ROOT/scripts/skill_map.mjs"

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

write_record() {
  local dir="$1"
  cat >"$dir/MAINTENANCE.md" <<'EOF'
# Maintenance record

## Source

Home-grown.

## Adapted

None.

## Name

The skill name.
EOF
}

# make_fixture -- one skill in each of the four layers, plus a project skill
# that links into a shipped layer.
make_fixture() {
  local root="$FIXTURE_DIR/tree"
  local project="$root/.agents/skills/project-skill"
  local provider="$root/src/reasoning/providers/pi/config/agent/skills/provider-skill"
  local agent="$root/src/reasoning/agent/skills/agent-skill"
  local workflow="$root/workflow/coding-agent/skills/workflow-skill"

  write_skill "$project" project-skill "Project skill." \
    "See [the agent skill](../../../src/reasoning/agent/skills/agent-skill/SKILL.md)."
  write_skill "$provider" provider-skill "Provider skill."
  write_skill "$agent" agent-skill "Agent skill."
  write_skill "$workflow" workflow-skill "Workflow skill."
  write_record "$agent"
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
  write_skill "$root/src/reasoning/providers/pi/config/agent/skills/project-skill" project-skill "A second project-skill."
  out="$(run_map "$root")"; rc=$?
  assert_rc 1 "$rc" "one name in two layers fails"
  assert_contains "$out" "collision: 'project-skill' is held by project" "the winner's layer is named"
  assert_contains "$out" "provider" "the loser's layer is named"
}

test_a_shipped_link_outside_its_layer_fails() {
  local root out rc
  root="$(make_fixture)"
  printf '\nSee [the provider skill](../../../providers/pi/config/agent/skills/provider-skill/SKILL.md).\n' \
    >>"$root/src/reasoning/agent/skills/agent-skill/SKILL.md"
  out="$(run_map "$root")"; rc=$?
  assert_rc 1 "$rc" "an agent-sandbox link into the provider layer fails"
  assert_contains "$out" "forbidden link: agent-sandbox" "the finding names the source layer"
  assert_contains "$out" "leaves its layer root" "the finding names the boundary"
}

test_a_broken_link_fails() {
  local root out rc
  root="$(make_fixture)"
  printf '\n[missing](missing.md)\n' >>"$root/.agents/skills/project-skill/SKILL.md"
  out="$(run_map "$root")"; rc=$?
  assert_rc 1 "$rc" "a relative link with no target fails"
  assert_contains "$out" "does not resolve" "the finding names the missing target"
}

test_a_missing_record_is_a_warning() {
  local root out rc
  root="$(make_fixture)"
  rm "$root/src/reasoning/agent/skills/agent-skill/MAINTENANCE.md"
  out="$(run_map "$root")"; rc=$?
  assert_rc 0 "$rc" "a missing agent-sandbox record is a warning, not a hard finding"
  assert_contains "$out" "warning: agent-sandbox: 'agent-skill' has no MAINTENANCE.md" "the warning names the skill"
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
run_test test_a_missing_record_is_a_warning
run_test test_the_repository_map_is_clean

test_done
