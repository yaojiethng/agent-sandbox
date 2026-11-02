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
#   repository     -- every agent-layer skill carries a record that resolves
#   nested skill   -- pi does not discover a nested SKILL.md under a parent that
#                     already has one
#   grouped skill  -- a skill under a directory with no SKILL.md is discovered
#   empty layer    -- a tree with no skill directory fails instead of passing
#   store identity -- a malformed id, a filename mismatch and a duplicate id,
#                     each reported once
#   store rules    -- an unknown field, a local_path that is gone and a file
#                     that is not canonical each fail the gate
#   duplicate path -- one local_path under two sources fails the gate

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
  assert_rc 0 "$rc" "two records naming one source pass"
  assert_contains "$out" "clean across 2 skill record(s) and 1 source(s)" "the report counts records and sources"
}

test_a_missing_record_fails() {
  local root out rc
  root="$(make_fixture)"
  rm "$root/src/reasoning/agent/skills/beta/MAINTENANCE.md"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "a skill without a record fails"
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
  assert_rc 0 "$rc" "a home-grown record passes"
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
  assert_rc 1 "$rc" "a record naming an unknown source fails"
  assert_contains "$out" "names source missing-source, which is not in the store" "the unknown source is named"
}

test_a_tree_skill_without_a_record_fails() {
  local root out rc
  root="$(make_fixture)"
  mkdir -p "$root/src/reasoning/agent/skills/gamma"
  printf '%s\n' '---' 'name: gamma' 'description: A skill with no record.' '---' '' 'Gamma.' \
    >"$root/src/reasoning/agent/skills/gamma/SKILL.md"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "a skill with no record fails even when the store is clean"
  assert_contains "$out" "skill gamma has no MAINTENANCE.md record" "the tree-wide finding names the skill"
}

test_the_repository_records_are_clean() {
  local out rc
  out="$(node "$SCANNER" 2>&1)"; rc=$?
  assert_rc 0 "$rc" "the repository records pass"
  assert_contains "$out" "clean across" "the live tree reports a clean run"
  assert_not_contains "$out" "finding:" "the live tree reports no finding"
  assert_contains "$out" "skill record(s)" "the report counts records rather than naming a size"
}

test_a_grouped_skill_is_discovered() {
  local root out rc
  root="$(make_fixture)"
  mkdir -p "$root/src/reasoning/agent/skills/group/gamma"
  printf '%s\n' '---' 'name: gamma' 'description: A grouped skill.' '---' '' 'Gamma.' \
    >"$root/src/reasoning/agent/skills/group/gamma/SKILL.md"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "a skill grouped under a non-skill directory is scanned"
  assert_contains "$out" "skill gamma has no MAINTENANCE.md record" "the grouped skill's missing record is named"
}

test_an_empty_skill_layer_fails() {
  local root="$FIXTURE_DIR/empty" out rc
  mkdir -p "$root/.agents/registry/sources"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "a tree with no skill directory fails"
  assert_contains "$out" "the agent skill layer holds no skill directory" "the empty layer is named"
}

test_the_store_identity_rules_are_reported_once() {
  local root out rc store
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  printf '%s\n' '{"schema":1,"id":"Bad_Id","url":"https://example.test/a","license":"MIT","copyright":"C","reason":"r","artifacts":[]}' \
    >"$store/Bad_Id.json"
  printf '%s\n' '{"schema":1,"id":"other-id","url":"https://example.test/b","license":"MIT","copyright":"C","reason":"r","artifacts":[]}' \
    >"$store/mismatched.json"
  cp "$store/test-source.json" "$store/copied-source.json"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "a store with bad ids fails"
  assert_contains "$out" "Bad_Id.json: id must be a lowercase source id" "a malformed id is named"
  assert_contains "$out" "mismatched.json: id other-id does not match the filename mismatched" "a filename mismatch is named"
  assert_contains "$out" "id test-source is already used by" "a duplicate id is named"
  local counted
  counted="$(printf '%s\n' "$out" | grep -c 'id must be a lowercase source id')"
  if [[ "$counted" == "1" ]]; then
    pass "a malformed id is reported once, not once per validator"
  else
    fail "the malformed id was reported $counted times"
  fi
}

test_a_nested_skill_is_not_discovered() {
  local root out rc
  root="$FIXTURE_DIR/loader"
  mkdir -p "$root/code-review/nested-child"
  printf '%s\n' '---' 'name: code-review' 'description: The parent skill.' '---' '' 'Parent.' \
    >"$root/code-review/SKILL.md"
  printf '%s\n' '---' 'name: nested-child' 'description: The nested child.' '---' '' 'Child.' \
    >"$root/code-review/nested-child/SKILL.md"
  out="$(node "$LOADER" "$root" 2>&1)"; rc=$?
  assert_rc 0 "$rc" "the loader probe runs"
  assert_contains "$out" "code-review" "the parent skill is discovered"
  assert_not_contains "$out" "nested-child" "a nested SKILL.md is not discovered under a skill root"
}

test_the_store_rules_fail_the_gate() {
  local root out rc store
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  cat >"$store/test-source.json" <<'EOF'
{
  "schema": 1,
  "id": "test-source",
  "url": "https://example.test/source",
  "license": "MIT",
  "copyright": "Copyright Test",
  "status": "live",
  "artifacts": [
    {
      "local_path": "src/reasoning/agent/skills/absent",
      "kind": "skill",
      "parent": null,
      "upstream_path": "skills/absent",
      "origin": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "base": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ]
}
EOF
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "a store the validator rejects fails the gate"
  assert_contains "$out" "unknown field status" "an unknown field is named"
  assert_contains "$out" "local_path src/reasoning/agent/skills/absent does not exist" "the absent path is named"
  assert_contains "$out" "is not in canonical form" "the hand-written file is named"
}

test_a_duplicate_local_path_fails_the_gate() {
  local root out rc store
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  # The same path in two sources. other-source sorts first, so test-source
  # reports the collision.
  for id in other-source test-source; do
    cat >"$store/$id.json" <<EOF
{
  "schema": 1,
  "id": "$id",
  "url": "https://example.test/$id",
  "license": "MIT",
  "copyright": "Copyright Test",
  "artifacts": [
    {
      "local_path": "src/reasoning/agent/skills/alpha",
      "kind": "skill",
      "parent": null,
      "upstream_path": "skills/alpha",
      "origin": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "base": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ]
}
EOF
  done
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "one path under two sources fails the gate"
  assert_contains "$out" "local_path src/reasoning/agent/skills/alpha is already used by source other-source" \
    "the collision is named"
}

run_test test_clean_fixture_passes
run_test test_a_missing_record_fails
run_test test_a_home_grown_record_is_accepted
run_test test_a_record_naming_an_unknown_source_fails
run_test test_a_tree_skill_without_a_record_fails
run_test test_the_repository_records_are_clean
run_test test_a_grouped_skill_is_discovered
run_test test_an_empty_skill_layer_fails
run_test test_the_store_identity_rules_are_reported_once
run_test test_a_nested_skill_is_not_discovered
run_test test_the_store_rules_fail_the_gate
run_test test_a_duplicate_local_path_fails_the_gate

test_done
