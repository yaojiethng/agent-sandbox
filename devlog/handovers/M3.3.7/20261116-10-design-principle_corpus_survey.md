---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Design
status: Closed
---

# Handover - The corpus survey has a procedure and a census

## Objective

Write the survey procedure to its durable home and census every existing cross-reference, so the five-card dry run starts from a measured link picture rather than a guess.

## Scope

The M3.3.7 row **The corpus survey process is written and the cross-references are censused**. In scope: the procedure reference, the read-only census, its report record, and the ADR pointer. The census is evidence, not an edge set; no skill is edited and the field stays `[]`.

Out of scope: the five-card dry run and the full survey, which are the next rows, and the conditional link normalisation.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The procedure is written at its durable home, with the card, the three facets, families by literary warrant, bounded candidate edges, the five relation kinds, the docket, the precedence rules and the five rules. | Read `.agents/skills/instruction-authoring/references/corpus-survey.md`. | Agent [x] |
| The census covers all 25 principles by source, named part, pointer form, target and first-pass kind. | Read the report's table; `node .scratchpad/census.mjs` reports 30 rows across 15 sources. | Agent [x] |
| The ADR entry names the procedure. | Read the 2026-11-16 entry's Edge cases. | Agent [x] |
| No principle skill is edited and the field stays `[]`. | `git diff --stat` shows no `src/reasoning/agent-runtime/pi/config/agent/skills/` file in this iteration. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the reference, the report and the ADR. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The procedure lives at `.agents/skills/instruction-authoring/references/corpus-survey.md`. | The corpus is that convention's subject, and the field's shape and the admission pattern already live there. The ADR records the decision; the procedure is the reference. This is the default taken under the operator's autonomy grant and is reversed by naming another home. | This record; the ADR's 2026-11-16 entry |
| The census is a `report` record, `open` until the full survey ends, and the full-survey row owns it. | The census is evidence for the dry run and the full survey, so it must outlive the row that creates it. Linking it from the full-survey row keeps it owned after this row closes. | This record; roadmap P4 |
| The census is read-only; no skill is edited and the link normalisation stays conditional. | The census measures the forms; it does not decide the normal form. A required `See also` section would change the principle body shape before the relation kinds are settled. | This record; roadmap P5 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Ten of the 25 principles carry no cross-reference, and the 30 references that exist sit under four named parts. | record | The corpus is sparse, so the candidate set is small and the survey can review it by eye. | The survey report; roadmap P4 |
| The forms are uneven: 21 bare names, 6 `$AGENT_HOME` paths and 3 Markdown links. Only the links are openable by a repository reader; the `$AGENT_HOME` paths are outside the image. | record | A normalisation pass may be worth it, but only after the relation kinds are settled. | The survey report; roadmap P5 |
| Two references point outside the provider root: `principle-check-placement` names `principle-encode-lessons-in-structure` and `principle-sequence-verifiable-units`. | record | They are cross-layer references, not candidates for the corpus map. | The survey report |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/instruction-authoring/references/corpus-survey.md` | The survey procedure: card, facets, families, bounded edges, relation kinds, docket, precedence and rules. |
| `devlog/discussions/20261116-report-open-principle_link_census.md` | The read-only census: 30 references across 15 principles, by part, form and kind. |
| `docs/adr/principle_skill_shape.md` | The 2026-11-16 entry names the survey procedure. |
| `devlog/roadmap.md` | Marks the survey procedure and census row done; the full-survey row owns the census report. |
| `devlog/handovers/M3.3.7/20261116-10-design-principle_corpus_survey.md` | This record. |
