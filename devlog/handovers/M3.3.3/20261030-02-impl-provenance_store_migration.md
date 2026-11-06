---
date: 2026-10-30
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - Migrate the provenance records to the source store

## Objective

Make the per-source tracking store the live provenance record, retire the hash-and-catalog model, and keep the attribution shipped with the forks.

## Scope

Continues the source-bump subtask under **Package skill ingestion as its own workflow** and the open migration row under **The source bump is a pattern, and `pi-bump` keeps its name**. The `source-bump` CLI and the design record [`20261029-design-draft-skill_source_update.md`](../discussions/20261029-design-draft-skill_source_update.md) are in place.

This unit creates the three live source files with the CLI, moves the five forked artifact edges and the two empty source rows, updates the five `MAINTENANCE.md` records, drops the retired catalog clause from the three home-grown records, adds the shipped attribution, removes `source-catalog.json`, rewrites the record gate, and records the store decision in the catalog ADR. The CLI remains the only writer of the tracking file; `source-bump check` remains a validation command and is not added to lint.

The bump procedure and the `diff` and `prepare` commands stay out of scope; the source-bump pattern row owns them. The design record stays active until that pattern and its remaining open questions land; the ADR current entry is the live decision.

Out of scope, one sentence each with the reason: the provider pstack records stay unchanged because they name no source id and **Ingest `pstack` upstream** owns their provenance; the source cache and the per-artifact design doc stay open because the pattern row owns the merge workspace; and the historical `source-catalog.json` references in the ADR and closed handovers stay because a historical record states what was true when it was written.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The live store holds three sources and five edges, and `source-bump check` is clean | `node scripts/source_bump.mjs check` | Agent [x] |
| The four mattpocock edges use `62f43a1`; `writing-for-agents` uses `5beb35b0`; no hash, revision date or import commit is stored | `node scripts/source_bump.mjs check`; `rg -n -e sha256 -e revision_date -e import_commit .agents/registry/sources` | Agent [x] |
| The five forked records name `mattpocock-skills` and link `../NOTICE`; the three home-grown records keep `Source: home-grown.` and drop the retired catalog clause; every agent-layer skill has a record | `bash scripts/check_skill_sources.sh`; `rg -n "^Source:" src/reasoning/agent/skills/*/MAINTENANCE.md` | Agent [x] |
| `NOTICE` lists the three source URLs, licenses and copyrights, and ships under the existing skills `COPY` | `test -f src/reasoning/agent/skills/NOTICE`; `rg -n -e mattpocock-skills -e pstack-skills -e juliusbrussee-caveman src/reasoning/agent/skills/NOTICE`; `rg -n "COPY src/reasoning/agent/skills/" src/reasoning/providers/pi/provider.dockerfile` | Agent [x] |
| `source-catalog.json` is removed and no live scanner, test or skills file references it | `test ! -e src/reasoning/agent/skills/source-catalog.json`; `rg -n source-catalog.json src/reasoning/agent/skills scripts/lint tests` | Agent [x] |
| The record gate checks records and known source ids without hashes, a catalog or `--write` | `bash tests/test_skill_sources.sh`; `rg -n -e sha256 -e source-catalog -e --write scripts/lint/skill_sources.mjs` | Agent [x] |
| The ADR carries a current store entry and revised requirements; the older entries are historical | `rg -n -e "^\*\*Current:\*\*" -e 2026-10-30 -e "The catalog retires" docs/adr/skill_source_catalog.md` | Agent [x] |
| The reference and design record say the store is live, the attribution is the `NOTICE`, and `source-bump check` is not a lint gate | `rg` both files for `live store`, `NOTICE`, `not a lint gate` | Agent [x] |
| `source-bump` is not added to `scripts/lint.sh`; lint still runs 17 gates and the manual check is clean | `rg source_bump scripts/lint.sh`; `bash scripts/lint.sh`; `node scripts/source_bump.mjs check` | Agent [x] |
| The roadmap migration row is `[x]` with handover `20261030-02`; the source-bump parent remains `[ ]` | `rg -n -e "live provenance store migration" -e 20261030-02 devlog/roadmap.md` | Agent [x] |
| The provider pstack records are unchanged; the `pstack-skills` source file is empty | `node scripts/source_bump.mjs check`; `git diff --name-only -- src/reasoning/providers/pi/config/agent/skills` | Agent [x] |
| Every decision in the handover is realized in the files | read the decisions table against `git diff` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The live store is created by the `source-bump` CLI: one file for `mattpocock-skills` with five edges, and empty files for `pstack-skills` and `juliusbrussee-caveman` with their reasons. | The CLI is the only writer, so the migration uses `add` and `add --empty`; the empty rows stay findable. | this record; the reference |
| The four earlier mattpocock edges take `origin` and `base` `62f43a1`; `writing-for-agents` takes `5beb35b0`. Dates and import commits are dropped. | The store records the derivation edge; the date and the local import commit are derived history, and one source can feed artifacts at different revisions. | this record; the design record |
| The five forked records keep `MAINTENANCE.md` and point at the source id and the shipped `NOTICE`; the three home-grown records keep `Source: home-grown.` and drop the retired catalog clause. | The local answer stays in the skill directory; the source facts move to the store; the image keeps an attribution it can open. | this record; the reference |
| A `NOTICE` at `src/reasoning/agent/skills/NOTICE` lists the URL, license and copyright for all three sources and ships with the skills. | The catalog was the shipped attribution; removing it without a replacement loses the notice. The `COPY` of the skills root carries the file, and pi ignores it. | this record; the ADR |
| The record gate remains a lint gate: it reads the source ids from the store, requires a well-shaped record for every agent-layer skill, and checks no hash or catalog. `source-bump check` stays outside lint. | A missing record is a tree invariant; the store schema and the bump are the CLI's, and the operator-directed bump is not a lint gate. | this record; the reference |
| The existing `docs/adr/skill_source_catalog.md` gains a current entry and a revised requirements table; its older entries remain historical. | One standing principle keeps one ADR and a stable name; the record says the catalog retired while the history stays. | this record; the ADR |
| The provider pstack records stay unchanged; the `pstack-skills` source file carries no edge. | Their provenance is **Ingest `pstack` upstream**'s subject, and this unit does not invent an edge. | this record; the roadmap |
| The migration row is marked complete; the source-bump parent stays open for the pattern. | The store and records land; the bump procedure is the parent's remaining work. | this record; the roadmap |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The catalog stores `revision_date` and `import_commit`, which the store does not | provenance | the migration drops them by design; `origin` and `base` carry the two revisions that matter | this record; the design record |
| The current `skill_sources.mjs` gate re-hashes files and reads the catalog | gate | the hash model is retired, so the scanner is rewritten to the record and source-id check | this record; the scanner; the tests |
| The five forked records link `source-catalog.json`, which this unit removes | provenance | each record points at the shipped `NOTICE` instead | this record; the records |
| The three home-grown records say "no catalog entry", which the removed catalog makes false | provenance | the records keep the home-grown answer and drop the retired clause | this record; the records |
| The deleted catalog left closed handover and roadmap links pointing at a missing file | record | the historical text stays; the links become code spans | this record; the historical records |
| The catalog was the shipped attribution | attribution | a `NOTICE` in the skills root replaces it; the image copy carries it | this record; the ADR |
| The provider pstack records have no source id | provenance | they stay outside this migration; **Ingest `pstack` upstream** owns the source | roadmap **Ingest `pstack` upstream** |

## Completed

| File | Change |
|---|---|
| [`.agents/registry/sources/mattpocock-skills.json`](../../.agents/registry/sources/mattpocock-skills.json) | the live source file with five edges |
| [`.agents/registry/sources/pstack-skills.json`](../../.agents/registry/sources/pstack-skills.json) | the live empty source file |
| [`.agents/registry/sources/juliusbrussee-caveman.json`](../../.agents/registry/sources/juliusbrussee-caveman.json) | the live empty source file |
| [`src/reasoning/agent/skills/NOTICE`](../../src/reasoning/agent/skills/NOTICE) | the shipped attribution for the three sources |
| [`domain-model/MAINTENANCE.md`](../../src/reasoning/agent/skills/domain-model/MAINTENANCE.md) | points at the source id and `NOTICE` |
| [`grill-me/MAINTENANCE.md`](../../src/reasoning/agent/skills/grill-me/MAINTENANCE.md) | points at the source id and `NOTICE` |
| [`improve-codebase-architecture/MAINTENANCE.md`](../../src/reasoning/agent/skills/improve-codebase-architecture/MAINTENANCE.md) | points at the source id and `NOTICE` |
| [`setup-pre-commit/MAINTENANCE.md`](../../src/reasoning/agent/skills/setup-pre-commit/MAINTENANCE.md) | points at the source id and `NOTICE` |
| [`writing-for-agents/MAINTENANCE.md`](../../src/reasoning/agent/skills/writing-for-agents/MAINTENANCE.md) | points at the source id and `NOTICE` |
| [`propagation-check/MAINTENANCE.md`](../../src/reasoning/agent/skills/propagation-check/MAINTENANCE.md) | drops the retired catalog clause |
| [`state-machine-specification/MAINTENANCE.md`](../../src/reasoning/agent/skills/state-machine-specification/MAINTENANCE.md) | drops the retired catalog clause |
| [`write-locations/MAINTENANCE.md`](../../src/reasoning/agent/skills/write-locations/MAINTENANCE.md) | drops the retired catalog clause |
| `src/reasoning/agent/skills/source-catalog.json` | removed; the facts moved to the store and `NOTICE` |
| [`scripts/lint/skill_sources.mjs`](../../scripts/lint/skill_sources.mjs) | the record gate reads the store, with no hash, catalog or `--write` |
| [`scripts/check_skill_sources.sh`](../../scripts/check_skill_sources.sh) | the wrapper header matches the record gate |
| [`tests/test_skill_sources.sh`](../../tests/test_skill_sources.sh) | seven record-gate tests replace the hash fixtures |
| [`docs/adr/skill_source_catalog.md`](../../docs/adr/skill_source_catalog.md) | the current store entry, requirements and retired catalog |
| [`docs/development/source_tracking.md`](../../docs/development/source_tracking.md) | the live store and `NOTICE` state |
| [`devlog/discussions/20261029-design-draft-skill_source_update.md`](../discussions/20261029-design-draft-skill_source_update.md) | the live store and the attribution settlement |
| [`devlog/roadmap.md`](../roadmap.md) | the migration completes; the source-bump parent stays open; the maintenance check required no correction |
| [`devlog/handovers/20261029-12-workflow-source_keyed_catalog.md`](20261029-12-workflow-source_keyed_catalog.md) | the removed catalog link becomes a code span |
| [`devlog/handovers/20261029-13-workflow-empty_catalog_rows.md`](20261029-13-workflow-empty_catalog_rows.md) | the removed catalog link becomes a code span |
| [`devlog/handovers/20261029-16-workflow-provenance_records.md`](20261029-16-workflow-provenance_records.md) | the removed catalog link becomes a code span |
| [`devlog/handovers/20261030-02-impl-provenance_store_migration.md`](20261030-02-impl-provenance_store_migration.md) | this record |
