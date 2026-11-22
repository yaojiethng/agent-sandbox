---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Design
status: Closed
---

# Handover - One home for a change to the principle corpus

## Objective

Give the principle corpus a single home for a change, with a named caller, by consolidating the admission pattern, the maintained parts of the survey procedure and the shape rules the ADR states, and retiring what the consolidation supersedes.

## Scope

The M3.3.7 row, the principle corpus has no home for a change. Row 390, the just-in-time judgement, is parked as the home's first application and is not worked here.

The operator's direction, recorded. A runbook in place of a convention skill, because a convention skill becomes a loose collection of procedures with no owner, and it is either never run or run at every possibility. The system is at its most valuable when a principle changes, so the change is what the home serves.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The home exists, and no live pointer names a retired file. | `grep -rn "admission.md\|corpus-survey"` over every file type returns no hit outside `devlog/`; `bash scripts/lint.sh` clean. | [x] Accepted. The two script comments that named them are corrected; lint clean across 29 gates. |
| The five intents, add, consolidate, split, rename and remove, are answered in the home, one section each, at the grain of a named artefact. | Read the five sections against `## Decisions`. | [x] Accepted. `## The five intents` carries one row per intent, each with the question and what settles it. |
| The three joints are answered in the home: how a principle task is described, how it is evaluated on pickup, and what information the doer surfaces and for which decision. | Read the three sections. | [x] Accepted. Steps 1 and 2 answer the description, 3 and 4 the pickup and the information, 5 where the decision lands. |
| The overlap rule is stated once, as one recorded case with both artefacts' determinations compared, and it enumerates no axes. | Read the rule for an example list. | [x] Accepted. Step 3 states one rule and names no axis. |
| `card` is gone from the live surface, and no term is registered for it. | `grep -roiE "\bcards?\b" .agents docs src/reasoning/agent-runtime/pi/config/agent/skills` returns nothing. | [x] Accepted. 21 uses removed across four files; the grep returns 0. |
| Applied to the two admissions this milestone settled, the home reaches the same ruling and names no missing step. | Apply it to the passthrough admission and the load-level ruling, and read the result against their records. | [x] Accepted, applied by the doer. The passthrough is an add no live artefact claims. The load-level ruling is an add at section grain, claimed by the umbrella with a different determination, so the boundary is recorded in both. No step was missing. An independent reader has not run it. |
| The roadmap carries the new row closed, row 390 parked with its dependency, and the sub-milestone's criterion. | `git diff <iteration-base> -- devlog/roadmap.md`. | [x] Accepted. The row closes with its Landed note, row 390 is parked and names the two reference records, and the criterion is rewritten. |
| Every decision this iteration records is realized in the files. | Read each `## Decisions` row against the tree. | [x] Accepted. The row below records each in the file that holds it. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The home is a runbook with a named caller, not a convention skill. | A convention skill becomes a loose collection of procedures with no owner and no trigger. A runbook names who calls it and who does not, so the question of when it runs is answered once, in the file. | This record; the home's `## Called from`. |
| The home subsumes `patterns/admission.md` and `references/corpus-survey.md`. | The survey is a one-time act, so its filed procedure is the wrong artefact to maintain. What keeps the established system coherent moves into the home, and a retired procedure is not carried forward beside it. | This record; the two retired files. |
| `card` is removed from live text, and no term is registered for it. | With the survey retired, the index entry it named has no live referent, so the word has nothing to define. The artefact is a principle skill. | This record; the two ADRs. |
| The five intents are also the admission questions. | A change to the corpus is one of five, and each intent poses the question the admission must answer. One spine serves both, instead of a second procedure beside the pattern. | This record; the home. |
| The overlap rule is one recorded case, with both artefacts' determinations on it compared. | Any overlap claim says two artefacts determine the same outcome for the same input, so the witness is that input and the two outcomes. One general form covers every axis without enumerating them, and an example list would be read as exhaustive. | This record; the home. |
| The `**The test.**` part is the discriminator an overlap check runs. | The shape requirement gains an operational use, so the test part is no longer a prose formality. | This record; the home. |
| A roadmap row states the intent and the supplementing information, and leaves the method to the doer. | The operator applied `communication-principle-state-intent-delegate-method` at the gate. A row naming the carrier, the files to edit or a route check has taken the decision the doer owes. | This record; row 390. |
| The mechanism edge's type is prose, and its adjacency is the field. | `metadata.neighbours` is a symmetric, untyped list, so it records nearness, never which artefact is the instance. One typed relation does not pay for a new field, gate and convention. | This record; the home. |

## Decisions pending

None. The three questions were answered at the release. The home is `runbooks/principle-change.md`, titled "Change a principle". `patterns/admission.md` is deleted rather than narrowed. The home points at the ADR for the body shape and restates none of it.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The operator ruled the corpus survey a one-time act, so the filed procedure is the wrong artefact to maintain. | steering | What is filed is how the system the survey established stays coherent, which is the gap this iteration owns. | This record; the home. |
| The operator ruled the overlap witness takes one general form, and an example list would be read as exhaustive. | steering | The rule is stated once, as one recorded case with both determinations compared. | This record; the home. |
| The operator ruled the contradiction census impractical at sentence grain and the bounded validation practical. | steering | The home validates a named pair only, and never searches the surface for contradictions. | This record; the home. |
| `card` carries two referents: the survey's per-principle index entry, which is its defined meaning, and the principle skill, which two live ADRs and row 390 use it for. The term entered with the survey in `918cb25c` and has no entry in the terminology registry. | terminology | One word names two things, and the survey's own definition says the entry is not the body, so a reader cannot tell which artefact a sentence means. | The home; the two ADRs; row 390. |
| The operator found that the row's rewrite still prescribed the method: the term, the carrier options and a route check. | steering | A row-level fix reproduced the row's defect at a smaller grain, so the row now states intent and supplement only. | This record; row 390. |
| Row 390's premise was its own conclusion, and it embedded the settled mechanism-instance ruling as an open question. | defect | The row read as an unmotivated corpus-level gap, which is why it did not state what fixing it buys. | Row 390, rewritten. |
| The originating question was one skill's signpost, not a missing principle, and the row's provenance was absent. | provenance | A reader could not tell that the trigger was the 2026-11-15 field review, so the row invited a carrier without a problem. | Row 390; this record. |
| The row's warrant is the operator's 2026-11-15T19:29 review of `dont-forecast-undone-work`'s neighbour field, in session `2026-11-14T05-08-33-645Z`. | record | The provenance now sits in the row, and the park is the home's first application. | Row 390; this record. |
| The concept's primary sources separate four things the corpus must not conflate: the system, the mechanism (pull against push), the waste (over-production) and the limit (work in progress). | vocabulary | The operator's 2026-11-15 message used all four correctly, and a single word collapses them. | Row 390, parked. |
| Just-in-time's cost is the absent buffer, since an unreliable supply with no inventory stops the line. | boundary | The corpus analogue is `justify-materialization-cost`'s impossible re-derivation, so the future home must carry the boundary or the rule reads as absolute. | Row 390, parked. |
| The 2026-11-15 field value for `dont-forecast-undone-work`, `write-for-the-reader`, was superseded by the empty-field design of 2026-11-16. | record | A reader of the source exchange could expect a field value the corpus does not carry. | This record. |
| The Write Discipline ladder in `AGENTS.md` states the demand judgement at step 1, "Does this need to exist?". | boundary | A principle stating the same judgement duplicates a live instruction unless the ladder cites it. | Row 390, parked. |
| The map states the survey at 25 scale, and the corpus now holds 26. | drift | A concluded record carries a count the tree falsifies. | The map's header, with the retired procedure. |
| The survey's five relation kinds carry no mechanism instance, so the shared-mechanism edge fits BT/NT. | vocabulary | The corpus records the edge as a broader and narrower judgement in prose, as the context cluster does. | This record; the home. |
| The record lifecycle has no class for a concluded record that becomes standing reference: closing the row that owned the map and the admission design orphaned both. | gap | The gate offers deletion or an open row's name, and neither fits a record the corpus reads after its task ends. Row 390 names both, and the rule needs a third disposition. | This record; a future row on the record layer. |
| Roadmap maintenance found stale counts in five closed M3.3.7 rows. | defect | Each row asserted a corpus or census count that later work changes. | Fixed in this iteration's maintenance pass. |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/instruction-authoring/runbooks/principle-change.md` | The home: five intents, the overlap case, the edges, the conflict docket, and its two callers. |
| `.agents/skills/instruction-authoring/patterns/admission.md` | Deleted, subsumed by the home. |
| `.agents/skills/instruction-authoring/references/corpus-survey.md` | Deleted; the maintained parts moved into the home and the one-off procedure retired. |
| `.agents/skills/instruction-authoring/SKILL.md` | Step 1 and the carries table point at the home. |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | The neighbour rule points at the home, and its `card` use is corrected. |
| `docs/adr/principle_skill_shape.md` | The home owns the change, and 12 `card` uses are corrected. |
| `docs/adr/closed_record_corrections.md` | 3 `card` uses corrected. |
| `docs/reference/terminology.md` | The admission mechanism entry points at the home. |
| `workflow/coding-agent/prompts/scope.md` | Its admission pointer names the home. |
| `scripts/check_principle_frontmatter.sh` | Its header names the home. |
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | The procedure line points at the home, and the 25-scale counts drop. |
| `devlog/roadmap.md` | Five closed rows drop a stale count; row 390 is rewritten to intent and parked; the new row closes with its Landed note. |
| `devlog/handovers/M3.3.7/20261117-06-design-principle_change_home.md` | This record. |
