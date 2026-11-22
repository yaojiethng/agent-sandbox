---
date: 2026-11-14
milestone: M3.3.7 - The judgement corpus admission
type: Plan
status: Closed
---

# Handover - The judgement corpus is admitted by case

## Objective

Decide how a judgement enters and changes in the corpus, so a missing or duplicated rule is caught at admission rather than by a periodic whole-corpus pass.

## Scope

The M3.3.7 question: whether a judgement-corpus bin opens, and what mechanism it holds. In scope: the A+B admission mechanism, the mechanical inventory lever, the case replay, and the write-back target.

Out of scope: the passthrough rule's own content, which moves into this milestone's task list as **A relay that adds no guarantee has one judgement, not three fragments** so this session does not carry it; W2's taxonomy and leitwort population; and M3.3.6's map, budget and record layer.

The scope boundary is explicit: M3.3.7 opens with the replay as its first iteration. If the replay shows only the catch-all bin (C) is viable, the milestone narrows to C and the field, gate and migration rows retire.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The A+B mechanism is specified: what the author declares, what the gate checks, and where the admission step lives. | The design record's decision section and the ADR entry. | Agent [x] |
| The case set is named, with what each case tests and the expected outcome; the excluded cases carry their reason. | The case-replay table in the design record. | Agent [x] |
| The write-back target is a design record and an ADR entry, with the field justified by its consumers. | This handover's Decisions and `docs/adr/principle_skill_shape.md`. | Agent [x] |
| The roadmap write-back rows are proposed for the close: M3.3.7, the passthrough row, and the work rows. | This handover and the close. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The neighbour edge is a declared kind, not any Markdown link. | A judgement link can mean a handoff ("apply this next") or a neighbour ("a similar application under a different domain"); counting all links conflates the two, and a handoff would satisfy an orphan check without a neighbour. | This record; the design record |
| The neighbour declaration is a frontmatter `neighbours:` list. | It gives the lever an explicit machine index, keeps handoffs out of the neighbour relation, and needs no per-edge explanation. The body's scope statement carries the meaning; the admission record carries a contested distinction. | This record; the design record |
| The field lists neighbour skill names only; handoffs stay in prose. | The field's subject is the neighbour relation. A handoff is a different edge, and giving it a field or a kind adds more schema than the check needs. | This record; the design record |
| The gate checks liveness and presence, with a shrinking baseline over the existing judgement skills. | The field is the machine edge, so orphanhood is a non-empty list; the baseline makes the check enforceable before the migration completes and shrinks as skills gain the field. | This record; the design record |
| The replay set is the four direct cases: passthrough, `absent`, boundary merge, and the `cut-what-serves-nothing` rename. | They test admission, duplication and unit change, which is the mechanism's subject. The leitwort revert, the review-runbook purpose gap and the materialization rename are different failure modes and are named with their reason. | This record; the design record |
| The admission step is a pattern under `instruction-authoring`, cited from step 1 and from the `scope` prompt's `## Check the boundary`. | The pattern owns the question; step 1 is where a judgement's purpose is settled; the scope prompt is where a unit's boundary is first drawn, so it points at the pattern rather than restating it. | This record; the design record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A corpus-wide semantic pass is not feasible under the operator's cost and reliability constraints. | record | The pass is replaced by admission-time decisions and a case replay. | The design record |
| The general passthrough test was retired with `principle-delegation-over-machinery` and did not survive the SSOT merge. | record | The passthrough row is the first case the mechanism must catch. | `devlog/roadmap.md` |
| A scan of the two judgement roots finds 54 judgement directories and most carry no outgoing judgement link under the narrow edge definition. | record | An orphan gate would fail on today's tree; orphanhood is report-only until the corpus is link-complete, while liveness can gate now. | The design record |
| Judgement links carry at least two kinds: a neighbour (similar application, different domain) and a handoff (next in a sequence). | record | Counting all Markdown links conflates them and makes orphanhood a false proxy for a declared neighbour. | The design record |
| Standards bodies, lint catalogs and legal codes do not carry a per-neighbour explanation. They carry a scope statement and a citation; the boundary is argued where a case contests it. | record | The explanation is owed at admission, not stored per skill; the declaration needs the edge and its kind, not an essay. | The design record |
| The frontmatter field reopens the 2026-10-28 ADR entry that removed metadata from a principle. | record | The ADR needs a new entry justifying this field by its consumers: the lever, the gate, and the admission pattern. | `docs/adr/principle_skill_shape.md` |
| The repo-owned judgement corpus is 25 skills under `src/reasoning/agent-runtime/pi/config/agent/skills`; `$AGENT_HOME` carries extras and duplicates and is not the gate's subject. | record | The lever reads the provider root, and any migration baseline is over 25 skills. | The design record |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/roadmap.md` | Opens M3.3.7 with the three work rows and the passthrough row, and moves the record from M3.3.6. |
| `devlog/discussions/20261114-design-concluded-judgement_corpus_admission.md` | The design record: the problem, the A+B mechanism, the four-case replay, the rejected alternatives. |
| `docs/adr/principle_skill_shape.md` | The 2026-11-14 entry: `metadata.neighbours`, the admission pattern, the liveness/presence gate and the shrinking baseline. |
| `devlog/handovers/M3.3.7/20261114-01-plan-judgement_corpus_admission.md` | This record. |
