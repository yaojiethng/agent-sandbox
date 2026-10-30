---
date: 2026-10-29
milestone: M3.3.3 - The skill maintenance pipeline
type: Plan
status: Closed
---

# Handover - File the skill-layer work units

## Objective

File the two green-to-green subtasks under the M3.3.3 provenance row, with the minimum M3.3.6 layer inventory pulled forward and no separate design document.

## Scope

Planning write-back for the M3.3.3 row **Every skill in the tree carries a maintenance record**. The operator directed that the minimum part of M3.3.6 be pulled into M3.3.3, so the provenance feature can deliver without waiting for the full skill graph.

The work is two subtasks under that row, in order. First, **The skill layer is inventoried, and its access is held**: the minimum pulled from M3.3.6. Second, **The provenance records and the tree-wide gate**: the four missing records, the `writing-for-agents` source, and the gate.

The full discoverability map, the hops and the budget stay in M3.3.6. The resolution map is generated and not committed; the provenance lockfile remains a committed artifact. No design brief and no separate design document: each subtask's handover and any ADR hold its model.

Out of scope, one sentence each with the reason: the full M3.3.6 map and budget stay with that sub-milestone; the provider and config-home records stay with **Ingest `pstack` upstream**; and the implementation of either subtask waits for its own scope gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The roadmap carries the M3.3.3 parent row with the two subtasks, in order | `rg` the three row titles; `git diff -- devlog/roadmap.md` | Agent [x] |
| The M3.3.6 row records the pull, and the full map and budget remain there | `rg` the M3.3.6 note | Agent [x] |
| The design-document call is recorded: task-list entries plus each subtask's handover and ADR, no separate design document | this record; the subtasks | Agent [x] |
| No implementation landed, and the withdrawn backfill is not in the tree | `git diff --stat`; this record's Scope | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The minimum layer inventory and access check are pulled into M3.3.3; the full map, hops and budget stay in M3.3.6 | The provenance records need the layer model and the cross-layer link; the full discoverability graph is not a dependency of the records. | this record; the M3.3.3 subtasks; the M3.3.6 note |
| The work is two green-to-green subtasks: layer inventory and access first, provenance records and gate second | The inventory settles the record scope and the cross-layer link; the records then land on a green tree with the gate they need. | this record; the roadmap |
| Task-list entries are enough; no separate design document | Each subtask's handover and any ADR hold its model; a separate design document would duplicate them and delay the work. | this record; the subtasks |
| The resolution map is generated and not committed; the provenance lockfile remains committed | The runtime map is a view that goes stale; source facts such as the upstream revision and license cannot be regenerated from the tree. | this record; the subtasks |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The operator asks for a layered skill provenance and resolution design before the backfill: a per-layer catalog versus a per-skill file, the access limits between layers, and a shadowing rule | scope | the backfill row depends on the design; the design is pulled into the M3.3.3 layer-inventory subtask, with the minimum needed for the records | this record; the layer-inventory subtask; the provenance subtask |
| The docs describe a three-layer skill model (provider, sandbox, user), while the operator names four layers (agent-sandbox, provider, workflow, project); the runtime loader is first-wins with collision diagnostics, and no declared precedence or cross-layer access rule exists | coherence | the layer-inventory subtask must reconcile the layer count and make the runtime order match the declared shadowing rule | this record; the layer-inventory subtask |
| The operator proposes deriving resolution, precedence, shadowing and access from the runtime, with knowledge tests, documentation and lint warnings, and using the generated skill graph -- outbound links, hops from the starting context, user-invoked versus discoverable -- instead of a committed resolution manifest | scope | the design changes from a new manifest to a generated map; the provenance lockfile is a separate artifact and stays committed | this record; the layer-inventory subtask |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the M3.3.3 parent row with the two subtasks; the M3.3.6 note that records the pull |
| [`devlog/handovers/20261029-14-plan-skill_layer_work_units.md`](20261029-14-plan-skill_layer_work_units.md) | this record |
