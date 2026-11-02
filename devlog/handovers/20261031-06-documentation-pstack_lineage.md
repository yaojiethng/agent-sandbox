---
date: 2026-10-31
milestone: M3.3.3 - The skill maintenance pipeline
type: Documentation
status: Active
---

# Handover - Attribute the pstack lineage

## Objective

Settle what the tree actually took from pstack, correct the two records that claim it, and reframe the rows that assumed pstack would be ingested into the tree.

## Scope

Continues `Ingest pstack upstream` under M3.3.3, after the dependency boundary in handover `20261031-05`.

In scope: the store row whose reason describes an ingestion the dependency replaces, the tracking document that states a count of the live store, both maintenance records that name pstack, and the two roadmap rows premised on tree ingestion.

Out of scope: installing the dependency, which waits on the mechanism, and the `pstack-skills.json` deletion that an earlier draft of this scope proposed, because a forked record names that source and the gate holds the two together.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The audit names every tree skill's add commit, and the two candidates its handovers | `git log --diff-filter=A` over both skill roots; the archived import handover and the deconfliction handover read | Agent [x] |
| One skill's pstack lineage is corroborated, and the record says what the corroboration is | `principle-guard-the-context-window/MAINTENANCE.md`; eleven shared six-word runs against the corpus | Agent [x] |
| The uncorroborated claim is dropped and the record states home-grown | `rg -n 'Source: home-grown' communication-principle-one-addressing-axis/MAINTENANCE.md`; no `pont` in the tree | Agent [x] |
| The store row describes the route rather than an ingestion, and still names the source the vendored fork cites | `pstack-skills.json`; `bash scripts/check_skill_sources.sh` | Agent [x] |
| The tracking document states the store's liveness without a count | `rg -n 'live store holds' docs/development/source_tracking.md` returns nothing | Agent [x] |
| Both roadmap rows are settled | `rg -n 'pstack' devlog/roadmap.md` | Agent [x] |
| Every decision recorded this iteration is realized in the files | read `## Decisions`; check each destination | Agent [x] |
| Lint, the handover gate and the store gate are clean | `bash scripts/lint.sh`; `bash scripts/check_handover_format.sh`; `node scripts/source_bump.mjs check` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The pstack lineage is settled by two instruments: the commit that added each skill and the handover it carries, and a six-word shingle comparison against the whole pstack corpus | The handover says where a file came from and the corpus says whether the text is that source's; each answers what the other cannot, and no dispatch is needed to re-derive either | this handover |
| Exactly one tree skill is a pstack fork | Text and history agree on `principle-guard-the-context-window` and on nothing else | this handover |
| `communication-principle-one-addressing-axis` is recorded as home-grown and its claim is dropped | pstack carries no skill of that name and the text shares nothing with the corpus, so the claim asserts a source that cannot be shown | this handover |
| The store row stays, with its reason rewritten as a route | A forked record names that source and the gate holds the two together, so deleting the row would break the skill it certifies; `skill_dependency_declaration` R6's new edge case covers a source with one vendored artifact and a declared remainder | this handover |
| The tracking document states the store's liveness without a count | A count is derived from the store, which owns it, so the copy goes stale in silence | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| 47 of the 58 pstack skill names are present in the config home, which holds 81 skills | measurement | the copied population is the config home, not the tree; the dependency route replaces it and the tree needs no ingestion | this handover |
| Both records said the set was `pont`/`pstack`; `pont` names nothing else in the repository | defect | gone from both records | this handover, Completed |
| An earlier draft of this scope proposed deleting `pstack-skills.json` | correction | the gate requires a record's named source to exist, so the row stays and its reason changes | this handover, Decisions |
| `communication-principle-one-addressing-axis` arrived through the deconfliction handover as "the skill after its writing pass", with no upstream named | history | the text is not pstack's, and the config-home original cannot be established | this handover, Decisions |

## Completed

| File | Change |
|---|---|
| `.agents/registry/sources/pstack-skills.json` | The reason states the one vendored fork and the dependency route for the rest. |
| `docs/adr/skill_dependency_declaration.md` | An edge case for a source with one vendored artifact and a declared remainder; folded into the commit that added the record. |
| `docs/development/source_tracking.md` | The live-store sentence states liveness without a count. |
| `.../principle-guard-the-context-window/MAINTENANCE.md` | Names the evidence for its lineage and points at the dependency route for the rest of the set. |
| `.../communication-principle-one-addressing-axis/MAINTENANCE.md` | `Source: home-grown`, with the measured reason the earlier attribution was dropped. |
| `devlog/roadmap.md` | The ingestion row closes with the dependency answer; the optional-module row owns the module and the `unslop` reconciliation. |
| `devlog/handovers/20261031-06-documentation-pstack_lineage.md` | This record. |
