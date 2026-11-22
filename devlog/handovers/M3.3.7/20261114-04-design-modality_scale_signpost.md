---
date: 2026-11-14
milestone: M3.3.7 - The principle corpus admission
type: Design
status: Closed
---

# Handover - The modal-strength axis has a signpost

## Objective

Define the scale the five modalities sit on as `modal strength`, with `strength` as its short form, and use it where the corpus states what a modality requires.

## Scope

The M3.3.7 row **The commitment axis has a signpost**, renamed by the decision below to **The modal-strength axis has a signpost**. The signpost lands as a registry definition, the two carriers that state what a modality requires, the ADR pointer, the roadmap row and its gate-row end condition, and this record.

Out of scope: the neighbour field, the admission pattern and the gate, which is the next row -- this iteration supplies the word the pattern will cite and does not build the pattern; the field migration; and the passthrough judgement.

The design question is settled by the decision below; the remaining work is the definition and its carriers.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `docs/reference/terminology.md` carries a `## modal strength` entry with Identity (necessity, graded, possibility; the order; the short form; the historical `force`), Scope (one sentence; not confidence, enforcement, commitment, or granularity), and Relationships (the five modalities are base x modal strength; `modality` cites it; the ADR). | Read the entry; `grep -n` the heading and its three subheadings. | Agent [x] |
| The `modality` entry cites `## modal strength` and keeps the five point-names unchanged. | Read the entry; compare `rule`, `judgement`, `permission`, `fact`, `claim`. | Agent [x] |
| `instruction-authoring/SKILL.md` and `agent_workflow.md` use `modal strength` at first mention and `strength` as the short form, and no bare `strength` names enforcement. | `rg -n "strength"` over both; read the changed lines. | Agent [x] |
| `instruction_modality.md` notes `force` as the historical word and names the "strength a kind buys" as enforcement strength. | `grep -n "historical\|enforcement" docs/adr/instruction_modality.md`; read both 2026-11-02 entries. | Agent [x] |
| The roadmap row reads "modal-strength axis", its end condition drops the pattern clause, and the gate row carries "the admission pattern refers to the modal strength". | Read the `git diff` at the close; `grep -n "modal-strength axis\|pattern refers" devlog/roadmap.md`. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the five carriers. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The reserved term is `modal strength`; `strength` is its defined short form, and enforcement strength is named in full. | The full term defines the scale once and carries the qualifier that keeps it apart from enforcement; the short form is the word the corpus already uses, so the signpost owns the existing word rather than coining one. It is used only where the sentence is already about modality, and first mention in a document is the full term. `certainty` was rejected: it names the epistemic base only, so "the certainty of a rule" or "the certainty of a permission" is a category error. `confidence` was rejected too: it names the writer's state, not the statement, and it fails the deontic points the same way. `modality` is the frame, not the degree; `commitment` is the pragmatic undertaking the act carries, a different axis, and its level reintroduces the ranking the ADR rejected. | This record; `docs/reference/terminology.md` `## modal strength` |
| The five are `modality` values, and `kind` is the ADR's historical word for one. | `kind` is vague and collides with the artifact `kind` in `.agents/registry/sources/`; `modality` is the term the registry defines. Live prose uses `modality`; the ADR's dated entries keep `kind`, noted at the registry and in the 2026-11-02 entry. | This record; `docs/reference/terminology.md` `## modality` |
| The dictionary framing contributes its exclusions and its "intrinsic to the statement" test, not its definition. | Its definition blends the base and the force ("necessity, obligation, or epistemic commitment"), and its per-kind bullets make each kind a different degree -- obligation, allowance, decisiveness, certainty, assertion -- which is five scales, not one. The corpus has one scale, modal strength, with the base separate. | This record; the `## modal strength` Scope |
| `force` becomes the ADR's historical word for the scale, noted at the registry, and the ADR entries keep their wording. | The ADR is a historical record; the prior term iteration's rule is that historical records are not retro-renamed. The registry's entry names `force` as the old word, so a reader meeting it in the ADR can resolve it. | This record; the `## modal strength` Identity |
| The scale is distinct from enforcement strength, granularity, and commitment. | The ADR's "strength a kind buys comes from what holds it" is enforcement, not the modal scale; the five modalities can share a modal strength and differ in what detects a breach. Granularity is the sentence-or-artifact axis the `modality` entry's Scope draws. Commitment is the pragmatic undertaking the act carries: a fact and a rule both commit, but to different things, so it is not one degree. | This record; the `## modal strength` Scope; `docs/adr/instruction_modality.md` |
| The signpost row's end condition drops the admission-pattern clause, and the gate row gains it. | The admission pattern is created by the gate row, so the signpost row cannot end on a file another row builds. The word is the signpost row's outcome; the pattern's use of the word is the gate row's. | This record; `devlog/roadmap.md` |
| No new ADR entry. | `docs/adr/instruction_modality.md` already records the base-and-force framework and the rejected strength ranking. The registry defines the word, and the ADR cites it; the alternatives are recorded here and do not need a second decision record. | This record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `docs/reference/agent_workflow.md` says a draft "reads as stronger or weaker" where it means modal strength. | record | The sentence is the signpost's motivating ambiguity: a reader reaches for strength instead of the scale's name. | This record |
| The signpost row's end condition requires "the admission pattern refers to the axis", but the gate row creates the pattern. | record | An acceptance criterion that cannot be satisfied inside this iteration. | The gate row; `devlog/roadmap.md` |
| The `modality` entry uses "force" without a headword of its own. | record | The scale has no definition a writer can cite; `force` is the ADR's historical word. | This record |
| `.agents/skills/instruction-authoring/SKILL.md`'s five-modality table states what each modality owes the writer without naming the scale. | record | The writer learns the obligations and not the scale they sit on. | This record |

| The section header said "The five kinds" without naming the genus, and the body reference points at that heading. | record | A reader must infer kinds of what; both the heading and the pointer need the edit. | This record |

| The convention's section restated the concept and the "nothing gates the choice" rule that `agent_workflow.md` already owns. | record | A second source for the concept with no drift gate; the section is the writer obligations, so it links the concept instead. | This record |

| The live carriers still called the five modalities "kinds", the vague placeholder the registry now names. | record | The term collides with the artifact `kind`; the sweep replaces it in the live prose and notes the ADR's historical use. | This record |

| The full suite timed out three heavy files on two runs under parallel load; each passed alone and the third run was green. | record | Wall-clock deadlines under parallel dispatch, not a defect in this change. | This record |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/roadmap.md` | Roadmap maintenance check before the handover: no finding; no edit. |
| `docs/reference/terminology.md` | Adds `## modal strength`: the scale, its order, the short form, the historical `force`, and the exclusions; the five are modalities, and `kind` is the ADR's historical word. |
| `docs/adr/instruction_modality.md` | The 2026-11-02 entries note `force` and `kind` as historical words and name the "strength a kind buys" as enforcement strength. |
| `.agents/skills/instruction-authoring/SKILL.md` | The section is headed for the writer obligations, links the concept and the no-gate rule to `agent_workflow.md`, keeps the table of five modalities, the scale, and the references, and reads the adjacent "more than one kind" as "more than one mode". |
| `.agents/skills/instruction-authoring/references/body.md` | The pointer follows the renamed heading. |
| `docs/reference/agent_workflow.md` | First mention reads "more or less modal strength"; the five are modalities; the section cites the scale. |
| `devlog/roadmap.md` | The row is renamed and closed; the gate row's end condition carries the pattern-axis clause. |
| `devlog/handovers/M3.3.7/20261114-04-design-modality_scale_signpost.md` | This record. |
