---
date: 2026-10-29
milestone: M3.3.6 - The skill map
type: Plan
status: Closed
---

# Handover - File the context graph tasks

## Objective

File the operator-facing context graph as two M3.3.6 slices, and record the provenance graph as a build diagnostic rather than the map.

## Scope

Planning write-back only. The context graph parent and its two subtasks are filed under M3.3.6; the existing provenance view gains the role that answers what it is for. No implementation lands in this unit.

The context graph is the operator-facing map: it starts at the assembled `AGENTS.md` context, the user-invokable skills and prompts, and the agent-invokable skill index; it follows direct links and exact skill-name references between whole-skill nodes; it groups skills by scope; it shows mediating project documentation as a secondary node; and it applies a declared expected/unexpected scope policy. Indirect mentions and agent auto-invocation are not edges. No SHA or version belongs in this view; drift is a separate diagnostic.

The primary graph data is a context-evidence bundle from the runtime loader, the entrypoints and the raw content. It is not `skill_sources`: that script is a source-catalog and maintenance-record gate, not a node/edge extractor. The new task owns its own evidence extraction, graph builder, fixtures, golden outputs and render tests.

Out of scope, one sentence each with the reason: the implementation is deferred because M3.3.6 is not the active sub-milestone; the provenance graph stays as a build/source-drift diagnostic and is not the context map; and `skill_sources` is not extended into a graph extractor because its subject is provenance and record completeness.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The M3.3.6 context graph parent and its two subtasks are filed | `rg` the roadmap rows | Agent [x] |
| The context graph's unit, entrypoints, direct-edge rule and scope policy are stated in the tasks | the parent and data sub-row | Agent [x] |
| The provenance view is recorded as a build/source-drift diagnostic, not the context map | the provenance sub-row's closing sentence | Agent [x] |
| `skill_sources` is not named as the graph's primary-data source | the data sub-row; this record's Scope | Agent [x] |
| The rendering task names Pele, scope, hop and theme without prescribing the implementation | the render sub-row | Agent [x] |
| No implementation landed and the working tree holds only the plan write-back | `git diff --stat`; this record | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The context graph is the operator-facing map; the provenance graph is a build/source-drift diagnostic | The operator asked what loads and from where, not which SHA or copy is current; the drift view answers a maintenance question | this record; the roadmap provenance sub-row; the context parent |
| The context graph's primary data is its own runtime evidence, not `skill_sources` | `skill_sources` validates source records and hashes; it does not parse entrypoints, links, prompts, docs or scopes | this record; the data sub-row |
| A node is one whole skill; an edge is a direct link or exact name reference | The skill is the operator's unit; indirect mentions rely on agent auto-invocation, which is represented by the agent entrypoint, not a skill edge | this record; the context parent |
| The agent entrypoint is separate from direct skill links | Availability through the model's skill index is not a dependency between two skills | this record; the context parent |
| Project documentation that mediates a skill path is a secondary node | The doc is the visible mediator; collapsing it into a direct skill edge hides the doc's role and its fan-out | this record; the data and render sub-rows |
| No SHA or version in this view; drift is separate | The operator wants the load origin and the graph, not artifact identity; drift is downstream provenance | this record; the context parent |
| The renderer is Pele, with a real background, scope boxes and level-of-detail views | The operator named Pele and the readability problem; the graph must be readable at overview and focus | this record; the render sub-row |
| The implementation is deferred | M3.3.6 is not the active sub-milestone; the tasks are the write-back, not this iteration's work | this record; the roadmap |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The provenance graph answered artifact identity and drift, not context loading | scope | it is a build diagnostic, not the operator-facing map; the context graph is filed separately | this record; the roadmap provenance sub-row |
| `skill_sources` validates catalog records and hashes; it has no adjacency, entrypoints, prompts or scopes | architecture | it cannot be the graph's primary data; it stays the provenance/record gate | this record; the data sub-row |
| The current graph script is also provenance; the context graph needs its own evidence and builder | architecture | the new task owns the context evidence, graph and tests | this record; the context parent |
| The operator's model separates direct links from agent auto-invocation | model | the graph omits indirect mentions; agent-invokable skills are invoked through the agent entrypoint | this record; the context parent |
| The operator wants documentation-mediated paths visible as a secondary node | model | the data and render sub-rows include the doc node and its distinct styling | this record; the sub-rows |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the M3.3.6 context graph parent and two subtasks; the provenance view's diagnostic role |
| [`devlog/handovers/20261029-18-plan-context_graph_tasks.md`](20261029-18-plan-context_graph_tasks.md) | this record |
