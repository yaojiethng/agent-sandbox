# Skill Provenance Diagnostic

**Current:** 2026-11-01

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One subject, one graph | The artifact answers where each copied skill came from, which links cross a boundary, and which copies no longer match what they were made from; no second artifact restates it |
| R2 | A finding, never a silent pass | A question the graph cannot answer -- a manifest that will not parse, a row that reaches no root, an absent root, a skill its copy lacks -- is reported in the graph itself |
| R3 | The builder is the contract | An edge carries its kind's fields because it is constructed that way, not because a second checker agrees with the first; no schema validates the graph JSON as a format |
| R4 | No gate depends on it | The check is read by an agent or the operator, never by a lint gate, because it compares this tree with the image built from an earlier commit |

## 2026-11-01 -- A diagnostic its readers query, not a validated wire format

**Decision:** [`scripts/skill_graph.mjs`](../../scripts/skill_graph.mjs) builds a provenance graph whose nodes are the four layer roots and the target artifacts of cross-boundary links, and whose edges are the manifest's copy and seed rows, each skill's Markdown links, and the content comparison each copy gets against the copy it was made from. Its readers are an agent auditing a copy, locating a skill or asking what a change reaches, and the operator reading the render; the graph JSON is the artifact and the Pele render from [`scripts/render_skill_graph.mjs`](../../scripts/render_skill_graph.mjs) is optional.

The graph owes its readers R2 and owes no one R3's agreement. Every question it cannot answer is a finding in the graph: a manifest that will not parse, an image row that reaches no layer, a shipped layer with no image row, a provision row whose home does not resolve, a link whose declared target root is absent, a skill the compared copy does not hold, a home link whose home the manifest does not declare. An unknown image digest is a warning rather than a finding, because an unbuilt image is a legitimate state. Drift is a finding, because a copy that no longer matches its source is the fact the check exists for.

The edge perimeter is held by construction. `linkEdge`, `compareEdge` and `buildEdge` sit beside `addNode` and `addEdge`, and each writes the fields its kind needs: a link names its expression, its source site and the namespace it resolved to; a comparison is computed from the two hashes it names; a build edge names the manifest row that declares it. There is no schema file and no validator, so nothing reads the graph JSON as a format, and nothing can disagree with the builder about it. `checkGraph` returns the graph's own findings, the drift count and the unknown-image warning, and nothing else.

`node scripts/skill_graph.mjs --check` exits 1 on a finding or on drift and is run by hand. No gate in [`scripts/lint.sh`](../../scripts/lint.sh) runs it, and none should: the image roots describe an image built from an earlier commit, so on a working tree the comparison is red for a reason that is not a defect. A consumer that needs a release condition writes a query over the graph, not a gate over its format.

**Rationale:** The graph is generated from a live tree, not exchanged between components: the only producer is `buildGraph`, the only consumers are a process that imports the module and a reader. A shape contract therefore has nothing to bind. When one existed, it was a 77-line schema plus a hand-written checker for a subset of JSON Schema, and the checker's own gaps were reported as defects in the graph: an unimplemented keyword failed a valid graph. The rules a schema could not state -- a link carries its expression, a comparison agrees with its hashes -- were restated in a second walk over the same data, which is the duplication the schema was introduced to remove. Construction removes both: the malformed edge cannot be written, so neither the rule nor its check has a place to live.

The remaining guarantee is the one a reader can use. An empty or partial graph that reports clean is worse than a red one, because the reader stops looking; a graph that names what it could not read sends them to the missing row, which is the whole value of a diagnostic.

**Rejected alternatives:**

### A schema file with a run-time validator

Rejected as insufficient, neither on intent nor on execution. It works, and it buys a guarantee no consumer can feel: the JSON is written by one function in this repository and read by no other system, so a violation could only mean the builder and the schema were edited apart, which the committed golden already shows. Its cost was real -- a partial implementation of a standard whose gaps reported against the graph rather than against the checker, and two statements of the same kind-specific rules.

### Gate the check in the lint suite

Rejected on R4, on intent. A lint gate is a claim that the tree can pass it. This check compares the tree with an image built from an earlier commit, so a clean pass is unavailable by construction and the gate would either be permanently red or be waived, and a waived gate teaches a reader to skip the file. The condition a release actually needs -- that a copy matches the image it ships in -- is answered by running the check against that image, by hand or from a release step, not from a lint run over a source tree.

### Report only what was found, silently skipping the rest

Rejected on R2, on execution. This was the first shape: a missing manifest produced an empty graph and a clean check, an absent host root dropped every home-rooted link, and a layer holding no skill printed as clean. Each compiled and each read as a healthy tree, so the defect was indistinguishable from a good result until someone looked for a skill that was not there.

**Edge cases / drivers:** The comparison's peer is the declared build relation, not a namespace preference, so a seeded home copy is compared with the image it was seeded from and a repository copy with the image made from it; a bundle that declares no build edge declares no peer and gets no comparison rather than a wrong one. A link is kept when a declared root resolves it, whichever preamble it was written with, so an absolute target outside `/opt` and a `$AGENT_HOME` target resolve by the same rule; the resolution and the scope check share one normalisation, because two of them disagreed and dropped a kept link with no finding. `--evidence FILE` feeds an evidence bundle, not a graph, so the fixture corpus states a graph's expected content without becoming a format anybody validates against. The report that records the review this decision came out of is [`20261031-report-settled-thermonuclear_review_skill_pipeline.md`](../../devlog/discussions/20261031-report-settled-thermonuclear_review_skill_pipeline.md).
