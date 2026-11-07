#!/usr/bin/env bash
# tests/knowledge/knowledge_skill_layer_resolution.sh
#
# Knowledge test: pi's first-wins skill resolution across the four layers.
#
# The four layers, highest precedence first, are:
#   project       .agents/skills
#   provider      src/reasoning/agent-runtime/pi/config/agent/skills
#   agent-sandbox src/reasoning/agent/skills
#   workflow      workflow/coding-agent/skills
#
# A name in all four layers is loaded from the project layer; the other three
# are reported as collisions. This is the runtime rule the generated layer map
# relies on, observed through pi's own `loadSkills`.
#
# Not run by make test. Run manually:
#   bash tests/knowledge/knowledge_skill_layer_resolution.sh
#
# Reference:
#  - src/build/container-interface.json (the skill surfaces)
#  - docs/reference/agent_workflow.md (Skills and Prompts Layer Model)
#  - docs/adr/skill_layer_resolution.md (the four-layer decision)

set -uo pipefail

TEST_KNOWLEDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_KNOWLEDGE_DIR/../libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$TEST_KNOWLEDGE_DIR/../.." && pwd)"
PROBE="$REPO_ROOT/tests/skill_layer_loader.mjs"

write_skill() {
  local dir="$1" name="$2"
  mkdir -p "$dir"
  cat >"$dir/SKILL.md" <<EOF
---
name: $name
description: The $name probe.
---

$name
EOF
}

# make_fixture -- one same-named skill in each layer the table declares.
make_fixture() {
  local root="$FIXTURE_DIR/tree"
  local name source
  while IFS=$'\t' read -r name source _; do
    write_skill "$root/$source/probe-skill" probe-skill
  done < <(node "$REPO_ROOT/scripts/skill_layers.mjs" --list)
  printf '%s\n' "$root"
}

test_project_wins_and_the_other_layers_are_shadowed() {
  echo ""
  echo "--- Project wins the name collision ---"

  local root out
  root="$(make_fixture)"
  out="$(node "$PROBE" "$root" 2>&1)"
  assert_contains "$out" "winner project probe-skill" "the project layer is the winner"
  assert_contains "$out" "loser provider probe-skill" "the provider layer is shadowed"
  assert_contains "$out" "loser agent-sandbox probe-skill" "the agent-sandbox layer is shadowed"
  assert_contains "$out" "loser workflow probe-skill" "the workflow layer is shadowed"
}

test_the_loaded_set_holds_one_skill() {
  echo ""
  echo "--- One loaded skill survives the collision ---"

  local root out
  root="$(make_fixture)"
  out="$(node "$PROBE" "$root" 2>&1)"
  local winners
  winners="$(printf '%s\n' "$out" | grep -c '^winner ' || true)"
  if [[ "$winners" == "1" ]]; then
    pass "exactly one skill is loaded"
  else
    fail "expected one loaded skill, got $winners"
  fi
}

run_test test_project_wins_and_the_other_layers_are_shadowed
run_test test_the_loaded_set_holds_one_skill

test_done
