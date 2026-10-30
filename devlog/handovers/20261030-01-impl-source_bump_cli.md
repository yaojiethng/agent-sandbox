---
date: 2026-10-30
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - Build the source-bump tracking CLI skeleton

## Objective

Settle the per-source tracking file shape and scope, and build a tested CLI skeleton that validates and updates that store without performing a merge.

## Scope

Continues the source-bump subtask under **Package skill ingestion as its own workflow** and the design record [`20261029-design-draft-skill_source_update.md`](../discussions/20261029-design-draft-skill_source_update.md). The operator settled one tracking file per source. This unit settles the file schema and the artifact scope, writes the contributor reference, and builds the `source-bump` CLI with `add`, `record` and `check` over fixtures.

The CLI owns the tracking file. The merge agent owns the local artifact and the design doc. This unit does not fetch an upstream, generate a diff, prepare a merge workspace or resolve a conflict; those commands are named in the design record and deferred. The ADR also lands with the migration, because the live catalog still governs and a second current ADR would contradict it.

The live store is not populated and no existing `MAINTENANCE.md` or `source-catalog.json` is removed. The migration of the five live forks, the empty pstack and caveman source rows, and the per-skill records is a separate unit, so this iteration leaves the current gates and attribution intact.

Out of scope, one sentence each with the reason: upstream fetching is deferred because `check` must stay deterministic and offline; the live migration is deferred because replacing the catalog and the records without a shipped attribution replacement would break the current provenance answer; and the provider pstack forks stay out of the store until **Ingest `pstack` upstream** supplies a revision. A bump runs only when the operator directs it, and the store stays pinned by default; `source-bump check` is a validation command, not a lint gate. The design record stays active until the live migration and the source-bump pattern land; the handover closes now because the tracking store and CLI are complete.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The reference and the design record state one JSON file per source at `.agents/registry/sources/<source-id>.json` | `rg -n "one JSON file per source" docs/development/source_tracking.md devlog/discussions/20261029-design-draft-skill_source_update.md`; `bash tests/test_source_bump.sh` | Agent [x] |
| The CLI `check` validates the source and artifact schema, and fails on a missing local path, a duplicate local path, an invalid kind, a non-commit base and an empty source with no reason | `bash tests/test_source_bump.sh` | Agent [x] |
| `add` creates a source or appends one artifact edge and writes canonical sorted JSON; `add --empty` creates an empty source with a reason; `record` moves `base` and preserves `origin`; neither writes when validation fails | `bash tests/test_source_bump.sh` | Agent [x] |
| The CLI implements only `add`, `record` and `check`; `diff` and `prepare` are absent | `node scripts/source_bump.mjs --help`; `rg -n "commandDiff" scripts/source_bump.mjs`; `rg -n "commandPrepare" scripts/source_bump.mjs` | Agent [x] |
| The store scope is upstream-derived artifacts with a known revision; an empty source carries a reason and no status field | `rg` the reference and design record; `bash tests/test_source_bump.sh` | Agent [x] |
| The design record is `active` and states the store shape and scope; the roadmap source-bump row no longer names `upstream_sha256` or `skill_sources.mjs --write`, and its sub-row names this handover | `rg -n "Status: active" devlog/discussions/20261029-design-draft-skill_source_update.md`; `rg -n -e upstream_sha256 -e "skill_sources.mjs --write" devlog/roadmap.md`; `rg -n "20261030-01" devlog/roadmap.md` | Agent [x] |
| No live catalog, skill record or live store is added or changed | `git status --short`; `git diff --name-only` filtered for `src/reasoning/agent/skills` and `.agents/registry` | Agent [x] |
| Every decision in the handover's Decisions table is realized in the files | read the table against `git diff`; `rg` each named file | Agent [x] |
| The design record's shape and scope questions are resolved; source cache, design-doc shape and attribution stay open, and gate strictness is settled as no lint gate with an operator-directed, pinned bump | `rg` the design record's settled and open lists | Agent [x] |
| The contributor reference is under `docs/development/` with the agreed skeleton and no status line | `head -20 docs/development/source_tracking.md`; `rg -n "^status:" docs/development/source_tracking.md`; `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The store is one JSON file per source at `.agents/registry/sources/<source-id>.json`. | The operator chose one file per source; a fan-out can work one source without touching another. | this record; the design record; the reference |
| A source file holds the source facts and the artifact edges, and no local or upstream hashes. | Source facts are not derivable from the tree; hashes are derived and go stale on every edit. | this record; the design record |
| `origin` is fixed at the fork point and `base` is the per-artifact upstream revision the next merge uses. | One source can hold artifacts at different revisions, so a source-level revision cannot be true for all of them. | this record; the design record |
| The store holds upstream-derived artifacts with a known revision; home-grown artifacts are absent. | A provenance row exists to make an upstream relation maintainable; a home-grown artifact has no upstream edge. | this record; the reference |
| An empty source carries `artifacts: []` and a `reason`; it carries no status field. | The source is still a row a reader can find, and the reason is what makes the empty row meaningful. | this record; the reference |
| The artifact kinds are `skill`, `runbook` and `prompt`; a runbook names its parent, a prompt names none. | A nested runbook is a separate artifact, and its parent is the skill directory that owns it. | this record; the reference |
| The CLI exposes `add`, `record` and `check`; `diff` and `prepare` are deferred. | `add` and `record` are the tracking-file writes this unit owns; the merge inputs belong to the next unit. | this record; the design record |
| `add` creates the source file when the first edge lands, and `add --empty` creates an empty source with a reason; source facts are immutable after creation. | The migration must create every source file through the CLI, or the only-writer rule is broken at the first row. | this record; the reference |
| A bump runs only when the operator directs it, and the store stays pinned by default; `source-bump check` is a validation command, not a lint gate. | This matches `pi-bump`; the upstream review is discretionary, and an automatic gate would turn a pin into a drift alarm. | this record; the design record; the reference |
| The ADR lands with the migration. | The live catalog still governs, so a second current ADR would contradict it; this unit records the decision in the design record and the handover. | this record; the design record |
| No live store or skill record is rewritten in this unit. | Replacing the current catalog without a shipped attribution replacement would remove the only provenance answer in the image. | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The roadmap source-bump row said to refresh `upstream_sha256` and run `skill_sources.mjs --write` | record | it described the superseded hash-and-write model, not the base-and-generated-diff model | resolved in [`devlog/roadmap.md`](../roadmap.md); the row is rewritten |
| The M3.3.6 summary said Not started while its provenance sub-row is `[x]` | record | the summary table understated the milestone's progress | corrected in [`devlog/roadmap.md`](../roadmap.md) |
| The two provider pstack forks have no known upstream revision | provenance | they cannot enter the tracking store until the pstack ingest names a revision | roadmap **Ingest `pstack` upstream** |
| The existing `MAINTENANCE.md` files still point at `source-catalog.json` | provenance | they remain correct until the migration unit replaces the catalog | roadmap **The live provenance store migration** |
| The old ADR still describes the hash-and-catalog model | record | it remains current for the live catalog; the new design is not an ADR until the migration | roadmap **The live provenance store migration** |
| The live store is empty, so `source-bump check` is fixture-tested and not a lint gate | provenance | the CLI and schema are proved, but the current catalog is still the only live source; a reader cannot run `source-bump check` on the repository yet | roadmap **The live provenance store migration** |
| The design record's command table said `record` refreshes the license; the CLI changes only `base` | record | the table now matches the CLI, and source facts are immutable after creation | corrected in the [design record](../discussions/20261029-design-draft-skill_source_update.md) |
| The roadmap migration row and the reference made `source-bump check` a future lint gate | design | an automatic gate contradicts the operator-directed, pinned bump; the check is a validation command | corrected in this record, the reference, the design record and the roadmap |

## Completed

| File | Change |
|---|---|
| [`scripts/source_bump.mjs`](../../scripts/source_bump.mjs) | the `source-bump` CLI: `check`, `add`, `add --empty` and `record`, with an atomic canonical write and no network |
| [`tests/test_source_bump.sh`](../../tests/test_source_bump.sh) | 16 fixture tests for the source shape, the edge kinds, the refusals and the two writes |
| [`docs/development/source_tracking.md`](../../docs/development/source_tracking.md) | the maintainer reference for the store, the schema, the CLI, the operator-directed pinned bump and the agent boundary |
| [`devlog/discussions/20261029-design-draft-skill_source_update.md`](../discussions/20261029-design-draft-skill_source_update.md) | status active; the tracking store section, D11 and the settled gate strictness, the settled and open questions, and the command table corrected |
| [`devlog/roadmap.md`](../roadmap.md) | corrected the M3.3.6 summary status; rewrote the source-bump row to the base model, added the completed tracking-store sub-row and the open live-migration sub-row, and kept the check outside lint |
| [`devlog/handovers/20261030-01-impl-source_bump_cli.md`](20261030-01-impl-source_bump_cli.md) | this record |
