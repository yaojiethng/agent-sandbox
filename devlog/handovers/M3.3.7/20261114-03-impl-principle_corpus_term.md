---
date: 2026-11-14
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The principle corpus is named for what it is

## Objective

Anchor the artifact term: `principle-` for the general meta-level skill and `<type>-principle-` for its domain-narrowed form, and sweep the live artifacts so none of them calls the artifact a judgement.

## Scope

The M3.3.7 row **The principle corpus is named for what it is**. The sweep covers the terminology entry, the authoring convention, the live design record, the ADR entries, the M3.3.7 roadmap section, the lever and its test. Closed handovers keep their historical wording; a link to a renamed record is repaired only where a gate requires it.

Out of scope: the commitment axis's signpost, which is a separate M3.3.7 row and the next iteration; the neighbour field, the admission pattern and the gate, which is the row after it; the field migration; and the passthrough judgement. The gate design drafted before this re-scope is withdrawn and belongs to the gate row, not this record.

The term does not settle the commitment axis. This iteration stops using "judgement" for the artifact and leaves "judgement" as one point on the axis, whose signpost the next row chooses.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `docs/reference/terminology.md` carries a `## principle skill` entry with Identity, Scope and Relationships; it defines `principle-` and `<type>-principle-`, states the meta-level intent, and cites `modality` and `principle_skill_shape.md`. | Read the entry; `grep -n` the heading and the three subheadings. | Agent [x] |
| `instruction-authoring/references/skill-conventions.md` says the skill carries a judgement rather than is one, and cites the entry; its heading reads "A principle skill". | `grep -n` the heading and the sentence. | Agent [x] |
| No live artifact calls the artifact class a judgement; the design record, ADR, roadmap, lever and test read `principle`. | `rg -n "judgement corpus\|judgement skill\|judgement inventory\|judgement-inventory"` over the live carriers; read every remaining `judgement` hit as a modality or an act. | Agent [x] |
| The lever and test are at `scripts/principle_inventory.mjs` and `tests/test_principle_inventory.sh`; the old paths are gone and the test passes. | `test -f` both pairs; `bash tests/test_principle_inventory.sh`. | Agent [x] |
| The design record is at `devlog/discussions/20261114-design-concluded-principle_corpus_admission.md`; the old path is gone and the live links resolve. | `test -f` both; `bash scripts/check_record_lifecycle.sh`; read the roadmap links. | Agent [x] |
| The two ADRs stay separate: `instruction_modality.md` keeps the modality scope and gains the home relation, while `principle_skill_shape.md` keeps the artifact shape and cites it. | Read both entries; `grep -n` the cross-references. | Agent [x] |
| The M3.3.7 title and objective read "principle corpus", the handover's milestone field matches, and the lever finds the same principle names and findings. | Read the roadmap section; run the renamed lever. | Agent [x] |
| Every decision this iteration recorded is realized in the files. | Read the Decisions table against the five carriers. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The definition is a `## principle skill` entry in `docs/reference/terminology.md`, in the registry's Identity, Scope and Relationships shape. | The registry is where a reserved term is defined; the term is scattered across the shape ADR and the authoring convention today, and one of those calls the skill a judgement. | This record |
| The two ADRs stay separate: `instruction_modality.md` owns the modality axis and the boundary that a judgement's home is a principle skill; `principle_skill_shape.md` owns the artifact's shape and intent, and cites the modality entry. | The joined sentence "a principle is a narrowed judgement-type skill at the meta-level" splits into a modality claim and an artifact claim. Merging would give one record two subjects with different change triggers, and the modality entry already says it does not classify an artifact. | This record; `docs/reference/terminology.md` |
| A principle is a workflow document that carries a norm; the norm's modality is the `modality` axis. | The `modality` entry says it does not classify an artifact, so the artifact and the norm kind are separate axes. | This record; `docs/reference/terminology.md` |
| `principle-` names the general meta-level skill; `<type>-principle-` names a domain-narrowed principle, and the type is a domain qualifier rather than a second class. | The corpus is one class of skills that help produce or choose criteria; a domain prefix narrows the application, it does not change the class. | This record |
| "Judgement" names a point on the commitment axis, not the artifact. A principle may carry a judgement; the skill is not one. | The project already uses judgement as one modality beside claim, rule, permission and fact, and the artifact-class use collides with it. | This record |
| The live sweep is the design record, the ADR entry, the M3.3.7 roadmap section, the lever and its test. Closed handovers stay as written. | A record states what was true when it closed; a live artifact that still says "judgement corpus" is the carrier this iteration fixes. | This record |
| The design record is renamed `20261114-design-concluded-principle_corpus_admission.md`; the lever becomes `scripts/principle_inventory.mjs`; the test becomes `tests/test_principle_inventory.sh`. | The filename is the first routing surface a reader meets, and the tool's name is the term in its most visible form. | This record |
| The lever's set rule becomes `^(?:[a-z][a-z0-9]*-)?principle-`, so any domain qualifier is accepted, not only `communication-`. | The naming rule is `<type>-principle-`, and a gate that knows only one type would miss the next domain-narrowed principle. | This record |
| The commitment-axis word is not chosen here. | It is the next row's subject; choosing it now would fold two decisions into one iteration. | This record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The gate draft used "judgement" for the artifact class in its pattern, gate and handover names. | record | The operator withdrew the gate scope before release; the gate row will be built on the settled term and the commitment-axis signpost. | The gate row |
| `scope.md`'s `## Refine the plan and the prose` names four judgement skills that are installed but not shipped. | record | A container seeded from the image carries the pointer and not the skill; this iteration does not touch the file, and the gate row will cite the admission pattern there. | The existing M3.3.3 **Ingest `pstack` upstream** row, recorded in handover `20261024-01` |
| The design record, the ADR, the M3.3.7 roadmap section, the lever and its test are the live carriers of the artifact-class word. | record | The sweep must reach all five, or one of them keeps asserting the old term. | This record |
| `instruction-authoring/references/skill-conventions.md` says a skill whose directory name carries `principle-` is a judgement, which contradicts the `modality` entry's scope. | record | A writer is told the artifact is a norm kind; the terminology entry and this sentence must change together. | This record; `docs/reference/terminology.md` |
| The registry had no `principle skill` entry, so the term was defined only by the shape ADR and the authoring convention. | record | The definition now lands in the registry, and both carriers cite it. | This record; `docs/reference/terminology.md` |
| The full suite timed out the same two heavy files on two runs under parallel load; both pass alone and the third run is green. | record | The deadlines are wall-clock under parallel dispatch, not a defect in this change; the suite is green on the clean run. | This record |

## Completed

| File | One-line change summary |
|---|---|
| `docs/reference/terminology.md` | Adds the `## principle skill` entry: the general and domain-narrowed forms, the meta-level intent, and the artifact/norm boundary; the `modality` entry gains the home relation. |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | The heading is "A principle skill", the skill carries a judgement, and the entry is cited. |
| `.agents/skills/instruction-authoring/SKILL.md` | Step 2 cites the terminology entry and the `disable-model-invocation` sentence reads "principle skill". |
| `docs/adr/principle_skill_shape.md` | The 2026-11-14 entry reads principle and cites the terminology and modality entries; the 2026-10-21 pointer names the new heading. |
| `docs/adr/instruction_modality.md` | The 2026-10-17 entry points at the terminology definition and the shape ADR. |
| `devlog/discussions/20261114-design-concluded-principle_corpus_admission.md` | Renamed and swept to principle; the settled questions become `## Remaining work`. |
| `scripts/principle_inventory.mjs` | Renamed; the set rule accepts any `<type>-principle-` prefix; the output labels read principle. |
| `tests/test_principle_inventory.sh` | Renamed and updated for the new module and the general prefix. |
| `devlog/roadmap.md` | The M3.3.7 title, objective, sequencing and rows read principle; the lever and design-record links move. |
| `devlog/handovers/M3.3.7/20261114-03-impl-principle_corpus_term.md` | This record. |
