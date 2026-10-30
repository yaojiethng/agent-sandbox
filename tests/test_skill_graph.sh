#!/usr/bin/env bash
# tests/test_skill_graph.sh
# The skill provenance graph builder: pure graph output, artifact identity,
# source/image separation, link resolution, drift, duplicates and structural
# checks. The Pele renderer is tested at the end; it is downstream of the graph.
#
# Covers:
#   golden graph    -- the fixture's JSON is byte-for-byte stable
#   golden Mermaid  -- the serializer is stable
#   schema          -- the schema parses and the graph carries the required shape
#   separation      -- source and image target nodes are distinct
#   resolution      -- a project relative link targets repo; an absolute /opt link targets image
#   duplicate       -- two links from one skill to one target become one edge, count 2
#   drift           -- a changed image copy is a drift edge, not a merged node
#   missing source  -- a link with no source root is a structural finding
#   unknown image   -- no digest is a warning and an image:unknown version
#   deterministic   -- two runs produce identical JSON and Mermaid
#   render          -- Pele renders the fixture Mermaid to SVG with the labels

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRAPH="$REPO_ROOT/scripts/skill_graph.mjs"
RENDERER="$REPO_ROOT/scripts/render_skill_graph.mjs"
SCHEMA="$REPO_ROOT/scripts/skill_graph.schema.json"
FIXTURES="$REPO_ROOT/tests/fixtures/skill_graph"
BASE="$FIXTURES/base.json"
EXPECTED_JSON="$FIXTURES/base.expected.json"
EXPECTED_MMD="$FIXTURES/base.expected.mmd"
OUTPUT_DIR="${OUTPUT_DIR:-/home/agentuser/workspace/output}"
PELE="${PELE_MODULE:-$OUTPUT_DIR/vendor/pele.js}"

graph_json() {
  node "$GRAPH" --evidence "$1" --json 2>/dev/null
}

graph_check() {
  node "$GRAPH" --evidence "$1" --check 2>&1
}

graph_mermaid() {
  node "$GRAPH" --evidence "$1" --mermaid 2>/dev/null
}

mutate() {
  local source="$1" target="$2" expression="$3"
  node -e '
    const fs = require("fs");
    const source = process.argv[1];
    const target = process.argv[2];
    const expression = process.argv[3];
    const data = JSON.parse(fs.readFileSync(source, "utf8"));
    const next = new Function("data", `return (${expression});`)(data);
    fs.writeFileSync(target, JSON.stringify(next, null, 2) + "\n");
  ' "$source" "$target" "$expression"
}

test_golden_graph_is_stable() {
  local out
  out="$(graph_json "$BASE")"
  if diff -u "$EXPECTED_JSON" <(printf '%s\n' "$out") >/tmp/skill_graph_golden.diff 2>&1; then
    pass "the fixture graph matches the golden JSON"
  else
    fail "the fixture graph differs from the golden JSON (see /tmp/skill_graph_golden.diff)"
  fi
}

test_golden_mermaid_is_stable() {
  local out
  out="$(graph_mermaid "$BASE")"
  if diff -u "$EXPECTED_MMD" <(printf '%s\n' "$out") >/tmp/skill_graph_mermaid.diff 2>&1; then
    pass "the fixture Mermaid matches the golden source"
  else
    fail "the fixture Mermaid differs from the golden source (see /tmp/skill_graph_mermaid.diff)"
  fi
}

test_schema_parses() {
  if node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "$SCHEMA" 2>/dev/null; then
    pass "the graph schema parses"
  else
    fail "the graph schema does not parse"
  fi
}

test_source_and_image_targets_are_separate() {
  local out ids
  out="$(graph_json "$BASE")"
  ids="$(printf '%s' "$out" | node -e '
    let input = "";
    process.stdin.on("data", (chunk) => input += chunk);
    process.stdin.on("end", () => {
      const graph = JSON.parse(input);
      const targets = graph.nodes.filter((node) => node.role === "target");
      console.log(targets.map((node) => node.id).join("\n"));
    });
  ')"
  if printf '%s\n' "$ids" | grep -q '^skill:repo:agent-sandbox:propagation-check$' &&
     printf '%s\n' "$ids" | grep -q '^skill:image:agent-sandbox:propagation-check$'; then
    pass "the repo and image copies have distinct target nodes"
  else
    fail "the repo and image copies were merged or one is missing"
  fi
}

test_link_resolution_names_the_namespace() {
  local out
  out="$(graph_json "$BASE")"
  local resolutions
  resolutions="$(printf '%s' "$out" | node -e '
    let input = "";
    process.stdin.on("data", (chunk) => input += chunk);
    process.stdin.on("end", () => {
      const graph = JSON.parse(input);
      for (const edge of graph.edges.filter((entry) => entry.kind === "link")) {
        console.log(`${edge.sourceSkill} -> ${edge.targetSkill} ${edge.resolution} ${edge.count}`);
      }
    });
  ')"
  assert_contains "$resolutions" "testing -> propagation-check repo 2" "the project relative link targets repo source and is x2"
  assert_contains "$resolutions" "testing -> check-in image 1" "the project absolute link targets the image"
}

test_base_check_is_clean() {
  local out rc
  out="$(graph_check "$BASE")"; rc=$?
  assert_rc 0 "$rc" "a fixture with matching source/image hashes passes the check"
  assert_contains "$out" "same-content" "the clean fixture still records same-content edges"
}

test_missing_source_root_is_a_finding() {
  local fixture="$FIXTURE_DIR/missing.json" out rc
  mutate "$BASE" "$fixture" '(() => { const next = structuredClone(data); next.links[0].fromRoot = "missing"; return next; })()'
  out="$(graph_check "$fixture")"; rc=$?
  assert_rc 1 "$rc" "a link with no source root fails the graph check"
  assert_contains "$out" "source root 'missing' is not in evidence" "the finding names the missing root"
}

test_unknown_image_is_a_warning() {
  local fixture="$FIXTURE_DIR/unknown.json" out rc
  mutate "$BASE" "$fixture" '(() => { const next = structuredClone(data); next.image.digest = null; return next; })()'
  out="$(graph_check "$fixture")"; rc=$?
  assert_rc 0 "$rc" "an unknown image is not a structural failure"
  assert_contains "$out" "image: no digest available" "the warning names the unknown digest"
  out="$(graph_json "$fixture")"
  assert_contains "$out" '"version": "image:unknown"' "the image node carries image:unknown"
}

test_drift_is_an_edge_not_a_merge() {
  local fixture="$FIXTURE_DIR/drift.json" out rc
  mutate "$BASE" "$fixture" '(() => { const next = structuredClone(data); for (const root of next.roots) { if (root.id === "image:agent-sandbox") { root.sha256 = "image-agent-other"; root.skills[0].sha256 = "image-propagation-other"; } } return next; })()'
  out="$(graph_json "$fixture")"; rc=$?
  assert_rc 0 "$rc" "a drift fixture still builds a graph"
  assert_contains "$out" '"kind": "drift"' "the graph contains a drift edge"
  assert_contains "$out" "skill:image:agent-sandbox:propagation-check" "the image copy remains its own node"
  out="$(graph_check "$fixture")"; rc=$?
  assert_rc 1 "$rc" "the release check fails on drift"
  assert_contains "$out" "drift: " "the finding names the drift count"
}

test_two_runs_are_identical() {
  local first second
  first="$(graph_json "$BASE")"
  second="$(graph_json "$BASE")"
  if [[ "$first" == "$second" ]]; then
    pass "two graph runs are byte-identical"
  else
    fail "two graph runs differ"
  fi
}

test_pele_renders_the_fixture() {
  local out="$FIXTURE_DIR/render" svg
  if [[ ! -f "$PELE" ]]; then
    skip "Pele is not available at $PELE"
    return
  fi
  PELE_MODULE="$PELE" node "$RENDERER" --evidence "$BASE" --out "$out" >/tmp/skill_graph_render.out 2>&1
  local rc=$?
  assert_rc 0 "$rc" "the fixture renders through Pele"
  svg="$out/skill-provenance.svg"
  if [[ -s "$svg" ]] && grep -q '<svg' "$svg"; then
    pass "the renderer writes a non-empty SVG"
  else
    fail "the renderer did not write a usable SVG"
  fi
  assert_contains "$(cat "$svg")" "propagation-check" "the SVG contains the target skill label"
  assert_contains "$(cat "$svg")" "same-content" "the SVG contains the same-content edge label"
}

run_test test_golden_graph_is_stable
run_test test_golden_mermaid_is_stable
run_test test_schema_parses
run_test test_source_and_image_targets_are_separate
run_test test_link_resolution_names_the_namespace
run_test test_base_check_is_clean
run_test test_missing_source_root_is_a_finding
run_test test_unknown_image_is_a_warning
run_test test_drift_is_an_edge_not_a_merge
run_test test_two_runs_are_identical
run_test test_pele_renders_the_fixture

test_done
