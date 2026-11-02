#!/usr/bin/env bash
# tests/test_skill_sources.sh
# The workflow skill record gate: every agent-layer skill carries a record, a
# forked record names a source in the per-source store, and a home-grown record
# says so. The gate carries no hash and no catalog.
#
# Covers:
#   clean          -- two records naming one source pass
#   missing record -- a skill without MAINTENANCE.md fails
#   home-grown     -- a record that states home-grown is accepted
#   unknown source -- a record naming a missing source fails
#   tree skill     -- a skill with no record fails even when the store is clean
#   repository     -- the live tree is clean across eight records and three sources
#   nested skill   -- pi does not discover a nested SKILL.md under a parent that
#                     already has one

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

SCANNER="$REPO_ROOT/scripts/lint/skill_sources.mjs"
LOADER="$REPO_ROOT/tests/skill_source_loader.mjs"

# make_fixture -- two skill records naming one source in the store.
make_fixture() {
  local root="$FIXTURE_DIR/tree" store
  store="$root/.agents/registry/sources"
  mkdir -p "$root/src/reasoning/agent/skills/alpha" \
    "$root/src/reasoning/agent/skills/beta" "$store"

  printf '%s\n' '---' 'name: alpha' 'description: The alpha skill.' '---' '' 'Alpha.' \
    >"$root/src/reasoning/agent/skills/alpha/SKILL.md"
  printf '%s\n' '---' 'name: beta' 'description: The beta skill.' '---' '' 'Beta.' \
    >"$root/src/reasoning/agent/skills/beta/SKILL.md"

  cat >"$root/src/reasoning/agent/skills/alpha/MAINTENANCE.md" <<'EOF'
# Maintenance record

## Source

Source: `test-source`; see [`NOTICE`](../NOTICE).

## Adapted

Kept.

## Name

alpha
EOF
  cat >"$root/src/reasoning/agent/skills/beta/MAINTENANCE.md" <<'EOF'
# Maintenance record

## Source

Source: `test-source`; see [`NOTICE`](../NOTICE).

## Adapted

Kept.

## Name

beta
EOF

  cat >"$store/test-source.json" <<'EOF'
{
  "schema": 1,
  "id": "test-source",
  "url": "https://example.test/source",
  "license": "MIT",
  "copyright": "Copyright Test",
  "reason": "The fixture has no forked artifact.",
  "artifacts": []
}
EOF
  printf '%s\n' "$root"
}

run_gate() {
  local root="$1"
  SKILL_SOURCE_ROOT="$root" node "$SCANNER" 2>&1
}

test_clean_fixture_passes() {
  local root out rc
  root="$(make_fixture)"
  out="$(run_gate "$root")"; rc=$?
  assert_rc "$rc" 0 "two records naming one source pass"
  assert_contains "$out" "clean across 2 skill record(s) and 1 source(s)" "the report counts records and sources"
}

test_a_missing_record_fails() {
  local root out rc
  root="$(make_fixture)"
  rm "$root/src/reasoning/agent/skills/beta/MAINTENANCE.md"
  out="$(run_gate "$root")"; rc=$?
  assert_rc "$rc" 1 "a skill without a record fails"
  assert_contains "$out" "skill beta has no MAINTENANCE.md record" "the missing record is named"
}

test_a_home_grown_record_is_accepted() {
  local root out rc
  root="$(make_fixture)"
  mkdir -p "$root/src/reasoning/agent/skills/gamma"
  printf '%s\n' '---' 'name: gamma' 'description: A home-grown skill.' '---' '' 'Gamma.' \
    >"$root/src/reasoning/agent/skills/gamma/SKILL.md"
  cat >"$root/src/reasoning/agent/skills/gamma/MAINTENANCE.md" <<'EOF'
# Maintenance record

## Source

Source: home-grown. No upstream.

## Adapted

Home-grown.

## Name

gamma
EOF
  out="$(run_gate "$root")"; rc=$?
  assert_rc "$rc" 0 "a home-grown record passes"
  assert_contains "$out" "clean across 3 skill record(s) and 1 source(s)" "the home-grown skill is not in the source count"
}

test_a_record_naming_an_unknown_source_fails() {
  local root out rc
  root="$(make_fixture)"
  mkdir -p "$root/src/reasoning/agent/skills/gamma"
  printf '%s\n' '---' 'name: gamma' 'description: A skill with an unknown source.' '---' '' 'Gamma.' \
    >"$root/src/reasoning/agent/skills/gamma/SKILL.md"
  cat >"$root/src/reasoning/agent/skills/gamma/MAINTENANCE.md" <<'EOF'
# Maintenance record

## Source

Source: `missing-source`; see the store.

## Adapted

Kept.

## Name

gamma
EOF
  out="$(run_gate "$root")"; rc=$?
  assert_rc "$rc" 1 "a record naming an unknown source fails"
  assert_contains "$out" "names source missing-source, which is not in the store" "the unknown source is named"
}

test_a_tree_skill_without_a_record_fails() {
  local root out rc
  root="$(make_fixture)"
  mkdir -p "$root/src/reasoning/agent/skills/gamma"
  printf '%s\n' '---' 'name: gamma' 'description: A skill with no record.' '---' '' 'Gamma.' \
    >"$root/src/reasoning/agent/skills/gamma/SKILL.md"
  out="$(run_gate "$root")"; rc=$?
  assert_rc "$rc" 1 "a skill with no record fails even when the store is clean"
  assert_contains "$out" "skill gamma has no MAINTENANCE.md record" "the tree-wide finding names the skill"
}

test_the_repository_records_are_clean() {
  local out rc
  out="$(node "$SCANNER" 2>&1)"; rc=$?
  assert_rc "$rc" 0 "the repository records pass"
  assert_contains "$out" "clean across 11 skill record(s) and 3 source(s)" "the live tree holds eleven records and three sources"
}

test_a_nested_skill_is_not_discovered() {
  local root out rc
  root="$FIXTURE_DIR/loader"
  mkdir -p "$root/code-review/improve-codebase-architecture"
  printf '%s\n' '---' 'name: code-review' 'description: The parent skill.' '---' '' 'Parent.' \
    >"$root/code-review/SKILL.md"
  printf '%s\n' '---' 'name: improve-codebase-architecture' 'description: The nested child.' '---' '' 'Child.' \
    >"$root/code-review/improve-codebase-architecture/SKILL.md"
  out="$(node "$LOADER" "$root" 2>&1)"; rc=$?
  assert_rc "$rc" 0 "the loader probe runs"
  assert_contains "$out" "code-review" "the parent skill is discovered"
  assert_not_contains "$out" "improve-codebase-architecture" "a nested SKILL.md is not discovered under a skill root"
}

run_test test_clean_fixture_passes
run_test test_a_missing_record_fails
run_test test_a_home_grown_record_is_accepted
run_test test_a_record_naming_an_unknown_source_fails
run_test test_a_tree_skill_without_a_record_fails
run_test test_the_repository_records_are_clean
run_test test_a_nested_skill_is_not_discovered

test_done
