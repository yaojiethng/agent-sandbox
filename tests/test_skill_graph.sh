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
#   collected       -- live evidence derives its roots, its copy edge and its seed edge from the manifest
#   no provision    -- a manifest with no provision row fails the check
#   no manifest     -- a tree with no manifest fails the check
#   ambiguous row   -- two image rows reaching one layer fail the check
#   missing row     -- a shipped layer with no image row fails the check
#   unresolvable    -- a provision row with no resolvable home fails the check
#   missing copy    -- a skill the image copy lacks is a finding
#   two provisions  -- two provision rows reaching one layer fail the check
#   unresolved home -- a $AGENT_HOME link with no resolved home fails the check
#   project copy    -- a manifest row reaching the project layer builds its copy edge
#   other copy      -- a link to a declared destination outside /opt is kept
#   seeded copy     -- a home copy is compared with the image it came from
#   schema          -- a graph violating the declared contract is rejected
#   working dir     -- the graph reads the repository, not the shell's directory
#   render          -- Pele renders the fixture Mermaid to SVG with the labels

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRAPH="$REPO_ROOT/scripts/skill_graph.mjs"
LAYERS="$REPO_ROOT/scripts/skill_layers.mjs"
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

# collected_evidence -- a fixture tree with one agent-layer skill and a manifest
# whose single image row declares where that layer's payload lands.
collected_evidence() {
  local root="$FIXTURE_DIR/collect" image="$FIXTURE_DIR/collect/image-skills"
  local home="$FIXTURE_DIR/collect/home"
  mkdir -p "$root/src/reasoning/agent/skills/probe-skill" "$root/src/build" "$image"
  mkdir -p "$home/agent/skills/probe-skill" "$image/config/agent/skills/probe-skill"
  printf '%s\n' '---' 'name: probe-skill' 'description: The probe.' '---' '' 'Probe.' \
    >"$root/src/reasoning/agent/skills/probe-skill/SKILL.md"
  cp "$root/src/reasoning/agent/skills/probe-skill/SKILL.md" "$home/agent/skills/probe-skill/SKILL.md"
  cp "$root/src/reasoning/agent/skills/probe-skill/SKILL.md" "$image/config/agent/skills/probe-skill/SKILL.md"
  write_manifest "$root" "$image" "$home"
  printf '%s\n' "$root"
}

test_a_missing_manifest_is_a_finding() {
  local root out rc
  root="$(collected_evidence)"
  rm "$root/src/build/container-interface.json"
  out="$(node "$GRAPH" --root "$root" --check 2>&1)"; rc=$?
  assert_rc 1 "$rc" "a tree with no manifest fails the check"
  assert_contains "$out" "src/build/container-interface.json: missing or does not parse" "the missing manifest is named by path"
}

# mutate_manifest ROOT EXPRESSION -- rewrite the fixture manifest through a
# JavaScript expression over the parsed object.
mutate_manifest() {
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const manifest = JSON.parse(fs.readFileSync(path, "utf8"));
    const next = new Function("manifest", `return (${process.argv[2]});`)(manifest);
    fs.writeFileSync(path, JSON.stringify(next, null, 2) + "\n");
  ' "$1/src/build/container-interface.json" "$2"
}

test_two_rows_reaching_one_layer_is_a_finding() {
  local root out rc
  root="$(collected_evidence)"
  mutate_manifest "$root" '(() => { manifest.image.push({ provider: "hermes", source: "src/reasoning/agent/skills/", destination: "/opt/hermes/skills/" }); return manifest; })()'
  out="$(node "$GRAPH" --root "$root" --check 2>&1)"; rc=$?
  assert_rc 1 "$rc" "two rows reaching one layer fail the check"
  assert_contains "$out" "2 image rows reach agent-sandbox" "the ambiguity is named"
}

test_a_layer_with_no_image_row_is_a_finding() {
  local root out rc
  root="$(collected_evidence)"
  mutate_manifest "$root" '(() => { manifest.image = manifest.image.filter((row) => row.source !== "src/reasoning/agent/skills/"); return manifest; })()'
  out="$(node "$GRAPH" --root "$root" --check 2>&1)"; rc=$?
  assert_rc 1 "$rc" "a shipped layer with no image row fails the check"
  assert_contains "$out" "agent-sandbox has no image row" "the layer is named"
}

test_an_unresolvable_provision_home_is_a_finding() {
  local root out rc
  root="$(collected_evidence)"
  mutate_manifest "$root" '(() => { manifest.env = manifest.env.filter((row) => row.name !== "AGENT_HOME"); return manifest; })()'
  out="$(node "$GRAPH" --root "$root" --check 2>&1)"; rc=$?
  assert_rc 1 "$rc" "a provision row whose home does not resolve fails the check"
  assert_contains "$out" "the provision row for pi names no resolvable home" "the row is named"
}

test_a_skill_missing_from_its_copy_is_a_finding() {
  local root out rc
  root="$(collected_evidence)"
  mkdir -p "$root/src/reasoning/agent/skills/extra-skill" "$root/.agents/skills/linker"
  printf '%s\n' '---' 'name: extra-skill' 'description: The extra.' '---' '' 'Extra.' \
    >"$root/src/reasoning/agent/skills/extra-skill/SKILL.md"
  printf '%s\n' '---' 'name: linker' 'description: The linker.' '---' '' \
    'See [extra](../../../src/reasoning/agent/skills/extra-skill/SKILL.md).' \
    >"$root/.agents/skills/linker/SKILL.md"
  out="$(node "$GRAPH" --root "$root" --check 2>&1)"; rc=$?
  assert_rc 1 "$rc" "a skill the image copy lacks fails the check"
  assert_contains "$out" "image agent-sandbox does not hold skill 'extra-skill'" "the missing copy is named"
}

test_two_provision_rows_reaching_one_layer_is_a_finding() {
  local root out rc
  root="$(collected_evidence)"
  mutate_manifest "$root" '(() => { manifest.provision.push({ ...manifest.provision[0], provider: "pi" }); return manifest; })()'
  out="$(node "$GRAPH" --root "$root" --check 2>&1)"; rc=$?
  assert_rc 1 "$rc" "two provision rows reaching one layer fail the check"
  assert_contains "$out" "more than one provision row reaches provider" "the ambiguity is named"
}

test_an_unresolved_agent_home_link_is_a_finding() {
  local root out rc
  root="$(collected_evidence)"
  mkdir -p "$root/.agents/skills/homer"
  printf '%s\n' '---' 'name: homer' 'description: The homer.' '---' '' \
    'See [home]($AGENT_HOME/agent/skills/probe-skill/SKILL.md).' \
    >"$root/.agents/skills/homer/SKILL.md"
  mutate_manifest "$root" '(() => { manifest.env = manifest.env.filter((row) => row.name !== "AGENT_HOME"); return manifest; })()'
  out="$(node "$GRAPH" --root "$root" --check 2>&1)"; rc=$?
  assert_rc 1 "$rc" "a \$AGENT_HOME link with no resolved home fails the check"
  assert_contains "$out" 'targets $AGENT_HOME, whose home the manifest does not resolve' "the unresolved home is named"
}

test_a_project_image_row_builds_its_copy_edge() {
  local root out
  root="$(collected_evidence)"
  mkdir -p "$root/.agents/skills/probe-skill" "$root/project-image"
  printf '%s\n' '---' 'name: probe-skill' 'description: The project probe.' '---' '' 'Project.' \
    >"$root/.agents/skills/probe-skill/SKILL.md"
  PROJECT_IMAGE="$root/project-image" mutate_manifest "$root" '(() => { manifest.image.push({ provider: "pi", source: ".agents/skills/", destination: process.env.PROJECT_IMAGE + "/" }); return manifest; })()'
  out="$(node "$GRAPH" --root "$root" --json 2>/dev/null)"
  assert_contains "$out" '"id": "root:repo:project"' "the project layer's root is a repository root"
  assert_contains "$out" '"from": "root:repo:project"' "the project image row becomes a copy edge from the project root"
  assert_contains "$out" '"to": "root:image:project"' "the copy edge targets the project's image root"
}

test_a_link_to_another_declared_destination_is_kept() {
  local root out
  root="$(collected_evidence)"
  mkdir -p "$root/.agents/skills/linker" "$root/project-image/probe-skill"
  printf '%s\n' '---' 'name: probe-skill' 'description: The project copy.' '---' '' 'Project.' \
    >"$root/project-image/probe-skill/SKILL.md"
  printf '%s\n' '---' 'name: linker' 'description: The linker.' '---' '' \
    "See [the project copy]($root/project-image/probe-skill/SKILL.md)." \
    >"$root/.agents/skills/linker/SKILL.md"
  PROJECT_IMAGE="$root/project-image" mutate_manifest "$root" '(() => { manifest.image.push({ provider: "pi", source: ".agents/skills/", destination: process.env.PROJECT_IMAGE + "/" }); return manifest; })()'
  out="$(node "$GRAPH" --root "$root" --json 2>/dev/null)"
  assert_contains "$out" '"resolution": "image"' "a link to a declared destination outside /opt is kept"
  assert_contains "$out" '"to": "root:image:project"' "the link resolves to the declared image root"
}

test_a_seeded_copy_is_compared_with_its_source() {
  local root out
  root="$(collected_evidence)"
  mkdir -p "$root/.agents/skills/linker"
  printf '%s\n' '---' 'name: linker' 'description: The linker.' '---' '' \
    'See [the home copy]($AGENT_HOME/agent/skills/probe-skill/SKILL.md).' \
    >"$root/.agents/skills/linker/SKILL.md"
  out="$(node "$GRAPH" --root "$root" --json 2>/dev/null)"
  assert_contains "$out" '"from": "skill:host:provider:probe-skill"' "the home copy is a node"
  assert_contains "$out" '"to": "skill:image:provider:probe-skill"' "the home copy is compared with the image it was seeded from"
  assert_not_contains "$out" '"to": "skill:repo:provider:probe-skill"' "the home copy is not compared with the repository copy"
}

test_the_schema_rejects_an_invalid_graph() {
  local out
  out="$(GRAPH_MODULE="$REPO_ROOT/scripts/skill_graph.mjs" GRAPH_FILE="$EXPECTED_JSON" node -e '
    const fs = require("fs");
    const { pathToFileURL } = require("url");
    import(pathToFileURL(process.env.GRAPH_MODULE).href).then(({ checkGraph }) => {
      const graph = JSON.parse(fs.readFileSync(process.env.GRAPH_FILE, "utf8"));
      graph.nodes[0].namespace = "bogus";
      graph.nodes[1].kind = "widget";
      graph.nodes[2].unexpected = true;
      graph.edges[0].line = "not a number";
      delete graph.summary.drift;
      graph.edges[0].count = 0;
      graph.findings = [42];
      graph.evidence = null;
      console.log(checkGraph(graph, { allowDrift: true }).findings.join("\n"));
      const broken = { ...graph, nodes: null };
      console.log(checkGraph(broken, { allowDrift: true }).findings.join("\n"));
      const brokenEdges = { ...graph, edges: [null] };
      console.log(checkGraph(brokenEdges, { allowDrift: true }).findings.join("\n"));
    });
  ' 2>&1)"
  assert_contains "$out" "is not one of repo, image, host" "an invalid namespace is rejected"
  assert_contains "$out" 'expected "artifact"' "an invalid kind is rejected"
  assert_contains "$out" "field 'unexpected' is not declared" "an undeclared field is rejected"
  assert_contains "$out" "line: must be integer" "a mistyped field is rejected"
  assert_contains "$out" "summary: missing required field 'drift'" "a required field of a nested object is enforced"
  assert_contains "$out" "count: must be at least 1" "a numeric minimum is enforced"
  assert_contains "$out" "findings[0]: must be string" "an item rule is enforced"
  assert_contains "$out" "evidence: must be object" "a wrong-typed object is reported, not descended into"
  assert_contains "$out" "graph.nodes: must be array" "a null node list is a shape finding"
  assert_not_contains "$out" "missing endpoint" "a malformed graph is not walked"
  assert_contains "$out" "graph.edges[0]: must be object" "a malformed edge list is a shape finding, not a crash"
}

# write_manifest ROOT IMAGE HOME -- the manifest rows the collector reads: the
# image rows for the two shipped layers, the provider home, and its provision row.
write_manifest() {
  local root="$1" image="$2" home="$3"
  cat >"$root/src/build/container-interface.json" <<EOF
{
  "image": [
    {
      "provider": "pi",
      "source": "src/reasoning/agent/skills/",
      "destination": "$image/"
    },
    {
      "provider": "pi",
      "source": "src/reasoning/providers/pi/config/",
      "destination": "$image/config/"
    }
  ],
  "env": [
    {
      "provider": "pi",
      "name": "AGENT_HOME",
      "value": "$home"
    }
  ],
  "provision": [
    {
      "provider": "pi",
      "source": "src/reasoning/providers/pi/config/",
      "template": "$image/config/",
      "home": "\$AGENT_HOME/"
    }
  ]
}
EOF
}

test_collected_evidence_follows_the_manifest() {
  local root out listed
  root="$(collected_evidence)"
  out="$(node "$GRAPH" --root "$root" --json 2>/dev/null)"
  assert_contains "$out" '"id": "root:image:agent-sandbox"' "the collector builds the image root"
  assert_contains "$out" "\"path\": \"$root/image-skills\"" "the image root is the manifest's destination"
  assert_contains "$out" '"kind": "copy"' "the manifest row becomes a copy edge"
  assert_contains "$out" 'container-interface.json: src/reasoning/agent/skills/' "the edge's evidence names the row"
  assert_contains "$out" '"id": "root:host:provider"' "the collector builds the provider home root"
  assert_contains "$out" "\"path\": \"$root/home/agent/skills\"" "the home root is the provision row's home"
  assert_contains "$out" '"kind": "seed"' "the provision row becomes a seed edge"
  assert_contains "$out" 'container-interface.json: provision pi' "the seed edge's evidence names the provision row"
  listed="$(node "$LAYERS" --list --root "$root")"
  assert_contains "$listed" "$root/image-skills" "the layer table reports the same image path"
}

test_a_manifest_without_a_provision_row_is_a_finding() {
  local root out rc
  root="$(collected_evidence)"
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const manifest = JSON.parse(fs.readFileSync(path, "utf8"));
    delete manifest.provision;
    fs.writeFileSync(path, JSON.stringify(manifest, null, 2) + "\n");
  ' "$root/src/build/container-interface.json"
  out="$(node "$GRAPH" --root "$root" --check 2>&1)"; rc=$?
  assert_rc 1 "$rc" "a manifest with no provision row fails the check"
  assert_contains "$out" "the manifest declares no provision row" "the missing declaration is named"
}

test_the_graph_reads_the_repository_not_the_working_directory() {
  local from_root from_docs
  from_root="$(node "$GRAPH" --json 2>/dev/null | grep -c '"role": "root"')"
  from_docs="$(cd "$REPO_ROOT/docs" && node "$GRAPH" --json 2>/dev/null | grep -c '"role": "root"')"
  if [[ "$from_root" == "$from_docs" && "$from_root" != "0" ]]; then
    pass "the graph collects the same roots from a subdirectory ($from_root)"
  else
    fail "the graph collects $from_docs roots from docs/ and $from_root from the root"
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
run_test test_collected_evidence_follows_the_manifest
run_test test_a_manifest_without_a_provision_row_is_a_finding
run_test test_a_missing_manifest_is_a_finding
run_test test_two_rows_reaching_one_layer_is_a_finding
run_test test_a_layer_with_no_image_row_is_a_finding
run_test test_an_unresolvable_provision_home_is_a_finding
run_test test_a_skill_missing_from_its_copy_is_a_finding
run_test test_two_provision_rows_reaching_one_layer_is_a_finding
run_test test_an_unresolved_agent_home_link_is_a_finding
run_test test_a_project_image_row_builds_its_copy_edge
run_test test_a_link_to_another_declared_destination_is_kept
run_test test_a_seeded_copy_is_compared_with_its_source
run_test test_the_schema_rejects_an_invalid_graph
run_test test_the_graph_reads_the_repository_not_the_working_directory
run_test test_pele_renders_the_fixture

test_done
