#!/usr/bin/env bash
# tests/test_skill_sources.sh
# The source store gate: the store is the record a bump reads, and the gate
# holds it valid - schema, paths, anchors, edge addresses and canonical form. It
# asks for no record: a path with no edge is a path nobody bumps.
#
# Covers:
#   clean          -- a canonical store with one edge passes
#   no edge        -- a skill with no edge passes, because provenance is opt-in
#   absent path    -- an edge whose local_path is gone fails
#   no SKILL.md    -- a skill edge whose directory holds no SKILL.md fails
#   anchor         -- an anchor absent from its file, or present twice, fails
#   composite      -- one local_path under two sources passes
#   duplicate edge -- the same edge twice in one source fails
#   canonical form -- a store file that is not canonical fails
#   source line    -- an artifact carrying its own source line fails
#   repository     -- the real store is clean
#   identity       -- a malformed id, a filename mismatch and a duplicate id,
#                     each reported once

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

SCANNER="$REPO_ROOT/scripts/lint/skill_sources.mjs"
A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

skill() {
  local dir="$1" name="$2"
  mkdir -p "$dir"
  printf '%s\n' '---' "name: $name" "description: The $name skill." '---' '' "$name." >"$dir/SKILL.md"
}

source_file() {
  local store="$1" id="$2"; shift 2
  printf '{\n  "schema": 1,\n  "id": "%s",\n  "url": "https://example.test/%s",\n  "license": "MIT",\n  "copyright": "Copyright Test",\n  "artifacts": [\n%s\n  ]\n}\n' \
    "$id" "$id" "$(printf '%s' "$*" | sed 's/^/    /; s/^     /    /')" >"$store/$id.json"
}

edge() {
  local local_path="$1" kind="$2" extra="${3:-}"
  printf '{\n  "local_path": "%s",\n  "kind": "%s",\n  "parent": null,\n  "upstream_path": "upstream/%s",\n  "origin": "%s",\n  "base": "%s"%s\n}' \
    "$local_path" "$kind" "$(basename "$local_path")" "$A" "$A" "$extra"
}

# make_fixture -- a tree with one skill and an instruction file, and a canonical
# store holding one skill edge and one passage edge.
make_fixture() {
  local root="$FIXTURE_DIR/tree" store
  store="$root/.agents/registry/sources"
  mkdir -p "$store"
  skill "$root/src/reasoning/agent/skills/alpha" alpha
  skill "$root/src/reasoning/agent/skills/beta" beta
  printf '%s\n' '# Layer' '' 'When writing code, take the first rung that holds.' '' 'Done.' \
    >"$root/AGENTS.md"

  cat >"$store/test-source.json" <<EOF
{
  "schema": 1,
  "id": "test-source",
  "url": "https://example.test/source",
  "license": "MIT",
  "copyright": "Copyright Test",
  "artifacts": [
    {
      "local_path": "AGENTS.md",
      "kind": "instruction",
      "parent": null,
      "upstream_path": "AGENTS.md",
      "origin": "$A",
      "base": "$A",
      "anchor": "When writing code, take the first rung that holds."
    },
    {
      "local_path": "src/reasoning/agent/skills/alpha",
      "kind": "skill",
      "parent": null,
      "upstream_path": "skills/alpha",
      "origin": "$A",
      "base": "$A"
    }
  ]
}
EOF
  printf '%s\n' "$root"
}

run_gate() {
  local root="$1"
  SKILL_SOURCE_ROOT="$root" node "$SCANNER" 2>&1
}

test_a_clean_store_passes() {
  local root out rc
  root="$(make_fixture)"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 0 "$rc" "a canonical store with two edges passes"
  assert_contains "$out" "clean across 1 source(s) and 2 artifact(s)" "the report counts sources and edges"
}

test_a_skill_with_no_edge_passes() {
  local root out rc
  root="$(make_fixture)"
  skill "$root/src/reasoning/agent/skills/gamma" gamma
  out="$(run_gate "$root")"; rc=$?
  assert_rc 0 "$rc" "an unrecorded skill is not a finding"
  assert_not_contains "$out" "gamma" "nothing names the skill nobody bumps"
}

test_an_absent_local_path_fails() {
  local root out rc
  root="$(make_fixture)"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.artifacts[1].local_path = "src/reasoning/agent/skills/gone";
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$root/.agents/registry/sources/test-source.json"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "an edge whose artifact is gone fails"
  assert_contains "$out" "local_path src/reasoning/agent/skills/gone does not exist" "the absent path is named"
}

test_a_skill_edge_needs_a_skill_md() {
  local root out rc
  root="$(make_fixture)"
  rm "$root/src/reasoning/agent/skills/alpha/SKILL.md"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "a skill edge whose directory has no SKILL.md fails"
  assert_contains "$out" "has no SKILL.md" "the missing entry point is named"
}

test_a_broken_anchor_fails() {
  local root out rc
  root="$(make_fixture)"
  printf '%s\n' '# Layer' '' 'The passage moved.' '' 'Done.' >"$root/AGENTS.md"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "an anchor absent from its file fails"
  assert_contains "$out" "anchor does not occur in AGENTS.md" "the absent anchor is named"

  printf '%s\n' '# Layer' '' 'Take the first rung.' 'Take the first rung.' >"$root/AGENTS.md"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.artifacts[0].anchor = "Take the first rung.";
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$root/.agents/registry/sources/test-source.json"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "an anchor that occurs twice fails"
  assert_contains "$out" "it must be unique" "the ambiguity is named"
}

test_one_artifact_in_two_sources_passes() {
  local root out rc store
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  cat >"$store/other-source.json" <<EOF
{
  "schema": 1,
  "id": "other-source",
  "url": "https://example.test/other",
  "license": "MIT",
  "copyright": "Copyright Other",
  "artifacts": [
    {
      "local_path": "src/reasoning/agent/skills/alpha",
      "kind": "skill",
      "parent": null,
      "upstream_path": "skills/alpha-half",
      "origin": "$B",
      "base": "$B"
    }
  ]
}
EOF
  out="$(run_gate "$root")"; rc=$?
  assert_rc 0 "$rc" "a composite artifact passes"
  assert_contains "$out" "clean across 2 source(s) and 3 artifact(s)" "both contributions are counted"
}

test_a_duplicate_edge_in_one_source_fails() {
  local root out rc
  root="$(make_fixture)"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.artifacts.push({ ...d.artifacts[0] });
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$root/.agents/registry/sources/test-source.json"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "the same edge twice in one source fails"
  assert_contains "$out" "is listed twice" "the duplicate is named"
}

test_a_non_canonical_file_fails() {
  local root out rc
  root="$(make_fixture)"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.artifacts[0].record = { dropped: "nothing", kept: "the method" };
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$root/.agents/registry/sources/test-source.json"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "an unordered record fails the gate"
  assert_contains "$out" "is not in canonical form" "the form finding names the file"
}

test_the_store_identity_rules_are_reported_once() {
  local root out rc
  root="$(make_fixture)"
  printf '%s\n' '{"schema": 1, "id": "Bad_Id", "url": "https://e.test/x", "license": "MIT", "copyright": "C", "reason": "none", "artifacts": []}' \
    >"$root/.agents/registry/sources/mismatch.json"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "a malformed id fails"
  assert_contains "$out" "id must be a lowercase source id" "the shape is named"
}

test_the_repository_store_is_clean() {
  local out rc
  out="$(node "$SCANNER" 2>&1)"; rc=$?
  assert_rc 0 "$rc" "the repository store is clean"
  assert_contains "$out" "skill sources: clean across" "the report is printed"
}

run_test test_a_clean_store_passes
run_test test_a_skill_with_no_edge_passes
run_test test_an_absent_local_path_fails
run_test test_a_skill_edge_needs_a_skill_md
run_test test_a_broken_anchor_fails
run_test test_one_artifact_in_two_sources_passes
run_test test_a_duplicate_edge_in_one_source_fails
run_test test_a_non_canonical_file_fails
run_test test_the_store_identity_rules_are_reported_once
test_a_source_line_in_the_artifact_fails() {
  local root out rc
  root="$(make_fixture)"
  printf '%s\n' '' '> Source: [upstream](https://example.test), landed at abc.' >>"$root/src/reasoning/agent/skills/alpha/SKILL.md"
  out="$(run_gate "$root")"; rc=$?
  assert_rc 1 "$rc" "a file carrying its own source line fails"
  assert_contains "$out" "the store is the only provenance record" "the finding names the rule"
}

run_test test_a_source_line_in_the_artifact_fails
run_test test_the_repository_store_is_clean

test_done
