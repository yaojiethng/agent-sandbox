---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - the destination table is generated from the model

## Objective

Give the layer-to-destination mapping one source, `src/build/container-interface.json`, and make a shipped reference cite it through a generated block instead of restating it, so a copy that drifts from the model fails a gate rather than reading as current.

## Scope

The roadmap row **The surface documentation cites the model instead of restating it** under M3.3.3, one slice: the block, its generator, the gate that holds it, and the recorded errors.

Out of scope: the other files that name the mapping outside `docs/reference/`, which the row does not bind, and the reach declaration row that builds the manifest itself, which already exists.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The provider `AGENTS.md` is stated at the tree's path, `src/reasoning/providers/<n>/config/agent/AGENTS.md`, in `agent_workflow.md` and `system_overview.md`, and the template record in `provider_lifecycle.md` at `config/agent/settings.json` | `node src/build/surface_table.mjs check`; the three paths resolve | Agent [x] |
| The destination table in `docs/reference/agent_workflow.md` is the manifest's own output: regenerating changes nothing | `node src/build/surface_table.mjs write` reports no rewritten path | Agent [x] |
| A table row in a reference document that restates a declared source-and-destination pair outside the generated block fails, and so does a backticked repository path the tree does not hold | `bash tests/test_surface_table.sh`; 13 cases, including both planted violations | Agent [x] |
| The manifest's note claims no key the file does not carry | `grep -c reachable src/build/container-interface.json`; 0 | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The block is the destination table emitted from the manifest's `image` rows between generator markers, and the generator writes it in place | A document may cite the model only where the block is the model's own output; a marker lets the gate tell a citation from a restatement without reading prose | this record |
| The gate reads `docs/reference/*.md` only | The row binds reference documents; a stronger rule over every shipped file would need a destination model for the how-to corpus, which does not exist | this record |
| The restatement rule applies to a table row, not to every line that names a source and a destination | 30 shipped-reference lines name an image path, and most are about the environment or one file's copy; a table is where this corpus states a mapping, so the rule catches the mapping and leaves the sentence that a reader needs | this record |
| A `<placeholder>` segment in a backticked repository path resolves against each provider's directory | `src/reasoning/providers/<n>/...` is how the reference names a per-provider file, so the path is checkable without banning the form | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `src/build/container-interface.json`'s own note said "every cell declares `reachable`", and no cell carried the key: the ADR retired it on 2026-11-01 and the note was not carried | defect | the model's statement about itself is the first thing a reader of the manifest believes | fixed in this iteration |
| The recorded wrong path was `docs/reference/agent_workflow.md:39`, which placed the provider `AGENTS.md` at `src/reasoning/providers/<n>/config/AGENTS.md`; the same defect stood in `system_overview.md:73` and `provider_lifecycle.md:99` for the settings record, so the row's count of one was low | defect | a shipped reference sends a reader to a path that does not exist | fixed in this iteration: all three paths, and the rule that now catches the class |
| `agent_workflow.md`'s four-layer table restated two destinations in its `Loaded via` column, and one row paired a source with its destination | defect | the table is the mapping in table form, which is what the generated block is for | fixed in this iteration: the column states the mechanism, and the block states where each source lands |
| The manifest's `image` rows hold 15 entries for 10 distinct source-and-destination pairs, because each provider repeats them | finding | the generated table groups by provider, so the block reads as 10 rows and no row is lost | this record |

## Completed

| File | Change |
|---|---|
| `src/build/surface_table.mjs` | new: renders the block from the manifest, rewrites it, and checks the two rules |
| `scripts/check_surface_table.sh` | new: the gate wrapper, with `SURFACE_TABLE_SCAN_ROOT` as the test seam |
| `scripts/lint.sh` | registers the gate; 20 gates |
| `tests/test_surface_table.sh` | new: 13 cases over the block, both planted violations and the fail-closed paths |
| `docs/reference/agent_workflow.md` | the generated block before the four-layer table, the `Loaded via` cells state the mechanism, and the provider `AGENTS.md` path corrected |
| `docs/reference/system_overview.md` | the provider `AGENTS.md` path corrected |
| `docs/reference/provider_lifecycle.md` | the provider settings record path corrected |
| `src/build/container-interface.json` | the note states the model the ADR settled, with no `reachable` key |
| `docs/development/instruction-surface-conventions.md` | `## The gates` names the new gate and the rule it holds |
| `devlog/roadmap.md` | the row's completion summary |
