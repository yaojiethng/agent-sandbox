---
date: 2026-10-29
milestone: M3.3.6 - The skill map
type: Workflow
status: Closed
---

# Handover - Build the skill provenance graph

## Objective

Build a tested artifact graph that keeps repo source and image copies separate, resolves each cross-boundary link to the namespace it is read from, and renders the result through a thin Pele adapter.

## Scope

Delivers the M3.3.6 sub-row **The skill map has a provenance view**. The graph builder is [`scripts/skill_graph.mjs`](../../scripts/skill_graph.mjs); the renderer is [`scripts/render_skill_graph.mjs`](../../scripts/render_skill_graph.mjs); the schema is [`scripts/skill_graph.schema.json`](../../scripts/skill_graph.schema.json); the tests and fixtures are under [`tests/`](../../tests/).

The graph is a pure function of an evidence bundle. `collectEvidence` records git HEAD and dirty state, the four source roots, the three image roots, the host mount, the project tree, tree hashes, raw Markdown links from both source and image copies, the Dockerfile COPY edges, the entrypoint seed, and mountinfo. `buildGraph` returns artifact nodes and typed edges. `toMermaid` serializes it. The renderer calls Pele and contains no graph logic.

The graph has 22 nodes and 15 links: 8 project cross-boundary links (5 repo-relative, 3 runtime-path) and 7 source-to-image links from the workflow source. It has 14 target skill nodes because each linked target has a repo and an image copy. The graph records 6 same-content relations and 5 drifts. The image digest is unavailable in this container, so every image node carries `image:unknown`; the graph warns rather than inventing a digest.

The release `--check` reports the five drifts and exits 1; the renderer opts into drift so the graph is still rendered. The four image roots are copied from the source by the Dockerfile and seeded into `$AGENT_HOME` by the entrypoint. The source and image copies are separate nodes even when their hashes match. A project relative link resolves to repo source; a project `/opt` link resolves to the image; a relative link inside `/opt` resolves to the image; a source workflow link to `/opt` resolves to the image. The duplicated `history-cleanup` link is one edge with `count: 2`.

Out of scope, one sentence each with the reason: the full 58-skill discoverability map, hops and budget stay with the parent M3.3.6 row; the provider and project skill records stay with their own tasks; the actual image digest stays unavailable until the image can be inspected, so the graph labels it unknown; and same-layer links are aggregated rather than drawn, because the graph is a cross-artifact view rather than a full dependency graph.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The graph is a pure builder over an evidence bundle; the renderer only calls Pele | `scripts/skill_graph.mjs` exports `collectEvidence`, `buildGraph`, `toMermaid` and `checkGraph`; `scripts/render_skill_graph.mjs` contains no resolution rules | Agent [x] |
| A repo source copy and an image copy are separate nodes with the same or different content | the fixture test `test_source_and_image_targets_are_separate`; the live graph's 14 target nodes | Agent [x] |
| Project relative links resolve to repo source and `/opt` links resolve to the image | the fixture test `test_link_resolution_names_the_namespace`; the live graph's 8 project links | Agent [x] |
| A duplicate link is one edge with `count: 2` | the fixture test; the live `history-cleanup` edge | Agent [x] |
| Drift is a typed edge and an unknown image is a warning | the fixture tests `test_drift_is_an_edge_not_a_merge` and `test_unknown_image_is_a_warning` | Agent [x] |
| A missing source root fails the graph check | `test_missing_source_root_is_a_finding`; `node scripts/skill_graph.mjs --check` | Agent [x] |
| A drift fixture fails the release check, and the renderer allows drift to render | `test_drift_is_an_edge_not_a_merge`; the live renderer output | Agent [x] |
| The graph JSON and Mermaid are golden and deterministic | the golden fixture tests and `test_two_runs_are_identical` | Agent [x] |
| Pele renders the fixture and the live graph | `test_pele_renders_the_fixture`; the output `skill-provenance.svg` | Agent [x] |
| The repository suite and lint remain green | `bash scripts/run_tests.sh`; 1378 tests across 101 files; `bash scripts/lint.sh`; 17 gates | Agent [x] |
| The roadmap sub-row is `[x]` with this handover, and the parent stays open | `rg` the M3.3.6 rows | Agent [x] |
| Every decision this iteration recorded is realized | Decisions table read against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The graph builder is pure; the renderer is a thin Pele adapter | The graph's quality is tested from evidence, not judged from the SVG; a renderer change cannot alter the graph | this record; `scripts/skill_graph.mjs`; `scripts/render_skill_graph.mjs` |
| Nodes are artifact instances with namespace, version and content hash | A skill name hides the difference between a repo file at a commit and a file in an image; the user's question is about that difference | this record; the graph schema; the fixtures |
| Source and image copies are separate nodes even when their hashes match | Same content is not the same artifact; a same-content edge states the relation without merging identities | this record; `buildGraph`; `test_source_and_image_targets_are_separate` |
| Link resolution follows the namespace the reader is in | A project relative link resolves in the project tree to repo source; a project `/opt` link resolves to the image; a source workflow `/opt` link resolves to the image | this record; `resolveTarget`; the fixture resolution test |
| Drift is a valid edge and a release-check finding; a structural finding fails too; the renderer opts into drift | A graph that hides drift is worse than a graph that shows it; the release check should fail on stale copies, while the renderer must still show them | this record; `checkGraph`; the drift fixture; the renderer |
| An unknown image digest is a warning and an `image:unknown` version | The container exposes no image digest; inventing one would make the version label false | this record; the graph evidence; the output README |
| The graph is a focus view, not a 58-node inventory | The subject is artifact identity and cross-boundary resolution; same-layer links are aggregated | this record; the 22-node live graph |
| The old simple skill map remains a separate view | It answers layer discovery; this graph answers provenance and resolution; neither replaces the other | this record; the M3.3.6 parent |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The live container has no image digest; the image nodes can only be `image:unknown` | evidence gap | the graph shows the unknown; the actual `/opt` hashes and the drift are still visible | the output README; the M3.3.6 parent when an image tool is available |
| The image copies of the agent-sandbox and workflow roots drift from the source, and the agent `propagation-check` and workflow `code-review` targets drift | stale image | the graph shows five drifts; the source and image nodes are not merged | this record; the graph; the README |
| The old layer map counted only 5 repo-relative project links; the graph also exposes 7 source-to-image links and the 3 project runtime-path links | coverage gap | the graph now includes 15 link occurrences, 13 distinct link edges | this record; the graph |
| The provider config copy matches between source and image, while the host `$AGENT_HOME` copy drifts | mount/seed | the graph distinguishes the seed from the bind and shows the host as a separate artifact | this record; the graph; the README |
| The current visual is 22 nodes, not 58; the target skills are source/image pairs with version labels | scope | the graph is deeper and smaller; the full discoverability map remains in the parent | this record; the roadmap parent |

## Completed

| File | Change |
|---|---|
| [`scripts/skill_graph.mjs`](../../scripts/skill_graph.mjs) | the evidence adapter, pure builder, check, Mermaid serializer and CLI |
| [`scripts/render_skill_graph.mjs`](../../scripts/render_skill_graph.mjs) | the thin Pele renderer |
| [`scripts/skill_graph.schema.json`](../../scripts/skill_graph.schema.json) | the graph schema |
| [`tests/test_skill_graph.sh`](../../tests/test_skill_graph.sh) | the 11 graph and render tests |
| [`tests/fixtures/skill_graph/base.json`](../../tests/fixtures/skill_graph/base.json) | the fixture evidence |
| [`tests/fixtures/skill_graph/base.expected.json`](../../tests/fixtures/skill_graph/base.expected.json) | the golden graph |
| [`tests/fixtures/skill_graph/base.expected.mmd`](../../tests/fixtures/skill_graph/base.expected.mmd) | the golden Mermaid |
| [`devlog/roadmap.md`](../roadmap.md) | the M3.3.6 provenance-view sub-row is `[x]`; the parent stays open |
| [`devlog/handovers/20261029-17-workflow-skill_provenance_graph.md`](20261029-17-workflow-skill_provenance_graph.md) | this record |
| `/home/agentuser/workspace/output/skill-provenance.svg` | the rendered live graph |
| `/home/agentuser/workspace/output/skill-provenance.json` | the live graph data |
| `/home/agentuser/workspace/output/skill-provenance.mmd` | the live Mermaid |
| `/home/agentuser/workspace/output/skill-provenance.md` | the evidence and reproduction note |
