---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - Settle the load-level terms as umbrella labels

## Objective

Settle whether a load-level term earns a principle card, and land the ruling on row 389: the terms stay the umbrella's, and each card keeps its own leitwort.

## Scope

Roadmap row "The load-level terms have no owning principle". The operator ruled on 2026-11-16, at the two-loads settlement: "the cards can keep colocation and SSOT as their own leitworts with findability only as the umbrella benefit. note because we are doing organization. it could be that new principles get added that occupy those domain terms." The map records the position in its document-load paragraph: "The load-level terms are the umbrella's; a new principle that claims one defines it in its own body."

The row's end condition is the second branch, that the map records the terms as umbrella labels. It does.

In scope: the admission check, the `attach-as-you-read` Why, the row close with its Landed note, and the record deletion the close forces. Closing the row orphans `devlog/discussions/20261116-report-concluded-reader_context_dry_run.md`, whose only open naming row is 389; the convention deletes a concluded, orphaned record, so the dry run goes and the map drops its `**Dry run:**` carrier line and its "The dry run settled the rule" sentence. At the scope gate the operator ruled that [`communication-principle-attach-as-you-read`](../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-attach-as-you-read/SKILL.md) defines `extraneous load` in its `**Why.**` and anchors that Why on the benefit of reducing it, with no citation. Out of scope, one sentence each: the [`writing-for-agents`](../../src/reasoning/agent/skills/writing-for-agents/SKILL.md) load definitions stand; the map's other content is not rewritten; the just-in-time row is the next iteration.

## The admission check

**The case.** A load-level term names what the reader pays, not what the writer does. `findability` is the context load's benefit, `overload` its failure, and `extraneous load` the cognitive load's failure. Each names a cost or a benefit, and each resolves into moves a card already holds: `progressive disclosure` in the meta-skill, `keep-a-subject-near`'s `colocation`, `principle-single-source-of-truth`'s source, and the clarity cards for the reasoning load.

**The neighbour search.** `principle_inventory.mjs` reports 26 cards. No card's `intent` or `mechanism` claims one of the three terms. `keep-a-subject-near` names the umbrella and keeps `colocation` as its leitwort. `SSOT` keeps its acronym. The three terms carry a family aim, the level the seven families already occupy.

**The decision.** No card. A card on a load term would restate the moves that remove the load, so the placement is the duplicate branch: the term is the umbrella's, and a future principle that claims one defines it in its own body. The operator ruled it, and the map records it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The admission check states the case and the neighbour search, and the ruling is the operator's. | Read `## The admission check`; `node scripts/principle_inventory.mjs`. | Agent [x] |
| Row 389 is `[x]` with the umbrella-only Landed note and no discussion link. | Read `devlog/roadmap.md`. | Agent [x] |
| The dry-run record is deleted and both map carriers are gone. | `ls devlog/discussions/`; read the map header. | Agent [x] |
| The `attach-as-you-read` Why defines `extraneous load` and anchors on the benefit of reducing it. | Read the card; `bash scripts/lint.sh`. | Agent [x] |
| The gates are clean and the map stays named by an open row. | `bash scripts/lint.sh`; the record-lifecycle gate. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| No card is admitted to own a load-level term. | The term names the cost, and the cards already carry the moves that remove it; a new card would duplicate them. | This record; row 389's Landed note; the map's document-load paragraph. |
| `attach-as-you-read` names `extraneous load` and defines it in its Why, with no citation. | The operator ruled it at the scope gate: the card that makes the working-memory claim defines the term, and the umbrella keeps the reference. | This record; the card. |
| The terms stay the umbrella's, and each card keeps its own leitwort. | The operator's ruling, 2026-11-16: `findability` and `overload` are the umbrella benefit and failure, and `colocation` and `SSOT` are the cards'. | This record; row 389. |
| A future principle may claim one of the terms and defines it in its own body. | The operator kept the door open, and the map's sentence already states it. | This record; the map. |
| The dry-run record is deleted on the row close. | It is concluded and orphaned once 389 closes, and the map's rejected-first-cut table and D-table carry the reading choice it recorded. | This record; the map's header. |
| The Why states the properties of the text, not the shapes of the defect. | The operator ruled it at the gate: the load is a property of the text, and the shapes are the principles, which the test already carries. | This record; the card. |
| The Why defines `extraneous load` and carries no citation. | The operator ruled no citation, and the umbrella keeps the reference. | This record; the card. |
| The six sources in the sentence-structure evidence report stay as recorded, unverified. | The citation's home is the evidence report, and verifying them is the draft run's step 1; the card states the mechanism without a source. | This record. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's end condition was already met by the map before the iteration started. | record | The iteration is the admission check and the close, not new content; the map line stands as the record. | This record. |
| `keep-a-subject-near` already names the umbrella and keeps `colocation`. | process | The card is the working model for the ruling, and the term is not renamed. | This record. |
| The dry run's evidence lives in the map's rejected-first-cut table and D-table. | process | The record can go without losing the reading choice. | This record; the map. |
| `define-terminology-before-use` uses "overloaded term" for a term with two meanings, a different sense. | record | No edit; the retrieval sense of `overload` stays the umbrella's. | This record. |
| The operator ruled the card names `extraneous load` without the citation. | steering | The umbrella keeps the reference and the card defines the term where it makes the claim, so the citation is not restated. | This record; the card. |
| The operator reframed the property from the reader's failure to the text's load. | steering | The Why states the text's property and the reader's work, and the shapes stay in the test. | This record; the card. |
| The evidence report states six citations, all unverified. | record | The card cites none; the report keeps the marks. | This record. |
| The operator asked whether the sources need ingesting as citations. | steering | No: the report is their home and the card states the mechanism; verification is the draft run's step 1. | This record. |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-attach-as-you-read/SKILL.md` | The Why defines `extraneous load`, states the text's property and the benefit of reducing it. |
| `devlog/roadmap.md` | Row 389 closed with the umbrella-only ruling and the card's term. |
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | Drops the `**Dry run:**` link and the "The dry run settled the rule" sentence. |
| `devlog/discussions/20261116-report-concluded-reader_context_dry_run.md` | Deleted, concluded and orphaned by the row close. |
| `devlog/handovers/M3.3.7/20261117-05-workflow-load_level_terms.md` | This record. |
