---
date: 2026-10-29
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - Restore the empty catalog row

## Objective

Record the caveman and pstack sources as empty catalog rows, settle the empty-row shape, and keep the four pstack skills out of the shared tree.

## Scope

Delivers the M3.3.3 row **Identify the source of `teach`, `how`, `why` and `unslop`** and restores the empty catalog row that the previous iteration's non-empty rule removed. The source facts belong in the manifest; the ADR states the shape and points at the manifest, not at live revisions.

The pstack source is `cursor/plugins`, `pstack/` at `12d587dfb20741cafc376c42c696c5f6e2a64487` (2026-09-23), MIT, `Copyright (c) 2026 Lauren Tan`; all four local files match. The caveman source is `JuliusBrussee/caveman` at `af5375d6f0151b1441f638d855f6829f5e6724df` (2026-04-04), Apache-2.0, `Copyright 2026 Julius Brussee`; the skill was removed. Both become rows with `skills: []`, a `reason`, and `import_commit: null`.

The generator and its test accept an empty row with a reason and refuse one without; the repository count becomes three sources and four skills. The pstack four stay in the config home because other agent-sandbox projects must not assume them, and `unslop` overlaps `writing-for-agents`; `teach` is pstack's skill, not mattpocock's. The ADR's pstack live-values entry is replaced by the empty-row decision, and the caveman values move into their row. The identification row is marked, and the optional-module and source-bump rows stay future. The `writing-for-agents` gap is a finding routed to the backfill row.

Out of scope, one sentence each with the reason: the import stays with the optional-module row, because the four are not base skills; the `principle-*` pstack set stays with **Ingest `pstack` upstream**, because it is a different set; the `writing-for-agents` record stays with **Every skill in the tree carries a maintenance record**, because the gap is one instance of the backfill; and the source-bump implementation stays with its row, because this unit only records the source.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The catalog holds three sources and four skills: `mattpocock-skills` forked, `juliusbrussee-caveman` and `pstack-skills` empty `skills`, a `reason` and a null `import_commit` | `jq` reads the three rows; `node scripts/lint/skill_sources.mjs --check` | Agent [x] |
| The generator accepts an empty row with a reason, refuses one without a reason, and keeps the forked checks | the new tests; `node scripts/lint/skill_sources.mjs --check` | Agent [x] |
| The tests cover the empty-row acceptance and rejection, and the repository count is three sources and four skills | `bash tests/test_skill_sources.sh` | Agent [x] |
| The ADR states the empty-row shape and points at the manifest; the source values live only in the catalog, and the previous non-empty rule is superseded | `rg` the ADR; the ADR carries no live source revision or license | Agent [x] |
| No pstack skill enters `src/reasoning/agent/skills/` and no pstack record is added | `test ! -e` the four directories; `rg` the records | Agent [x] |
| The identification row is `[x]` with the catalog outcome; the optional-module and source-bump rows stay open | `rg` the roadmap rows | Agent [x] |
| The `writing-for-agents` provenance gap is recorded and routed to the backfill row | the handover Findings table; the open **Every skill** row | Agent [x] |
| Every decision this iteration recorded is realized | Decisions table read against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The catalog is the source of truth for source facts, forked or not; a source that is not forked is an empty row: `skills: []`, a `reason` and a null `import_commit` | Live values in prose go stale; the manifest is machine-readable and gated, and the `reason` keeps the catalog from becoming an upstream index. This supersedes the previous iteration's non-empty-source rule. | this record; the ADR; the catalog |
| `juliusbrussee-caveman` and `pstack-skills` are the first empty rows, and the caveman values move out of the ADR | The caveman source facts were live values in the ADR; the row is their structured home. The pstack source is the same case. | this record; the ADR; the catalog |
| The four pstack skills stay in the config home; no pstack skill enters the shared tree | Other agent-sandbox projects must not assume the four exist, and the operator has used them without importing them. | this record; the catalog `reason`; the optional-module row |
| `unslop` is not imported while `writing-for-agents` is the tree's prose standard | The two overlap; a future import must reconcile one prose standard before `unslop` can land. | this record; the catalog `reason`; the ADR |
| `teach` is pstack's skill, not mattpocock's | The local `teach` composes `how` + `why` and matches pstack; the mattpocock `teach` is a different teaching-workspace skill and was absent at the catalogued revision. | this record; the catalog |
| `writing-for-agents` is adapted from mattpocock but has no record and is not in the `mattpocock-skills` source row | The first source's skill set is incomplete; the backfill row owns the missing record, and this unit only records the gap. | this record; the roadmap **Every skill in the tree carries a maintenance record** |
| The ADR states the empty-row policy and points at the manifest; it carries no live source revision or license | The ADR is a decision record, not a lookup table; the manifest is the single source of truth. | this record; the ADR |
| The source bump is a `skill-scaffolder` pattern, not a top-level skill, and `pi-bump` keeps its name | The unit is the source, not the skill; `bump-skills` would name the wrong object and a rename would sweep references with no behaviour change. | this record; the roadmap sub-row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The operator is not ready to import the pstack four: they are used from the config home so other agent-sandbox projects do not assume their existence, and `unslop` overlaps `writing-for-agents` | scope | the import is withdrawn; the source is recorded as an empty catalog row; a future import belongs to the optional module | this record; the catalog; the ADR; roadmap **The four pstack skills are optional, not base** |
| The operator asked to restore the empty catalog row: live source values belong in the structured manifest, not the ADR; this supersedes the previous iteration's non-empty-source rule | scope | the catalog gains empty rows for caveman and pstack; the ADR points at the manifest; the generator and tests change | this record; the ADR; the catalog |
| `writing-for-agents` is adapted from mattpocock but has no `MAINTENANCE.md` and is not in the `mattpocock-skills` source row | provenance gap | the first source's skill set is incomplete; the backfill row owns it | roadmap **Every skill in the tree carries a maintenance record** |

## Completed

| File | Change |
|---|---|
| [`source-catalog.json`](../../src/reasoning/agent/skills/source-catalog.json) | the caveman and pstack empty rows: `skills: []`, a `reason`, no import commit |
| [`scripts/lint/skill_sources.mjs`](../../scripts/lint/skill_sources.mjs) | an empty source needs a reason and a null import commit; forked sources keep the existing checks |
| [`tests/test_skill_sources.sh`](../../tests/test_skill_sources.sh) | the empty-row acceptance and rejection; the repository count is three sources and four skills |
| [`docs/adr/skill_source_catalog.md`](../../docs/adr/skill_source_catalog.md) | the empty-row decision; the source values point at the manifest; the non-empty rule is superseded |
| [`devlog/roadmap.md`](../roadmap.md) | the identification row takes the catalog outcome; the source-bump and pstack-optional rows stay |
| [`devlog/handovers/20261029-13-workflow-empty_catalog_rows.md`](20261029-13-workflow-empty_catalog_rows.md) | this record |
