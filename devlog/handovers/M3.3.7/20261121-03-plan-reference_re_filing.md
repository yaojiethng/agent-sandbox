---
date: 2026-11-21
milestone: M3.3.7 - The principle corpus admission
type: Plan
status: Closed
---

# Handover - Re-filing the reference half

## Objective

File the split-out rules and re-file the `write-for-the-reader` slice, the reference merge and the reach/scope/link/citation work to M3.3.8.

## Scope

The row is `Name the axis each reference principle owns`. The operator ruled one skill per iteration, then that the `write-for-the-reader` slice is the referent half of the M3.3.8 reference merge; the slice moves to M3.3.8, and this iteration is the re-filing. It files the split-out rules (`The permitted-form rule has a home`, the `rewrite-syntax-never-semantics` see-also, the `cut-metadiscourse` reciprocal boundary), moves the reach/scope/link/citation rows out of M3.3.6, creates M3.3.8, and leaves the `keep-a-subject-near` and `order-for-incremental-parsing` sub-rows in M3.3.7. The `write-for-the-reader` content is M3.3.8's merge. The voice row, the leitwort row and the `one-addressing-axis` list-form rule stay out; they are separate open rows. The file list belongs to the scope proposal.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| M3.3.8 exists with its objective, `Depends on`, sequencing and rows. | `grep -n '^##### M3.3.8'` and the heading body. | Agent [x] |
| `Reach is a property of distribution`, its three children, and `A durable document cites through the ADR` appear once each, under M3.3.8, absent from M3.3.6. | `grep -c` reads 1 for each; the M3.3.6 block no longer carries them. | Agent [x] |
| The M3.3.7 axis row covers `keep-a-subject-near` and `order-for-incremental-parsing`; the `write-for-the-reader` sub-row is gone. | `grep` reads the two sub-rows and 0 for the old sub-row. | Agent [x] |
| The M3.3.8 merge row depends on the reach/scope axis, and the `link` mechanism and the `rewrite-syntax`/`cut-metadiscourse` boundaries are its sub-rows. | The merge row and its two sub-rows are present. | Agent [x] |
| The summary table has the M3.3.8 `Not started` row, and its anchor matches the heading. | `grep -c 'M3.3.8 - The reference and reach layer'` reads 2. | Agent [x] |
| The handover is Plan, Active and renamed; the roadmap links resolve; the record and lint gates are clean. | `check_handover_format`, `check_record_citations`, `check_record_lifecycles`, `check_record_names`, `lint`. | Agent [x] |
| Every re-filing decision this iteration recorded is realized in `roadmap.md`. | The `## Decisions` rows are checked against the roadmap. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The umbrella is "the reader holds only the text"; the `write-for-the-reader` boundary is the reference outside the text. | The operator set the family intent and the skill's narrower boundary. | The M3.3.8 merge; this record. |
| The permitted-form rule is cut from `write-for-the-reader` and filed for its own home. | "Instead of X, do Y" is not a reference outside the text; the em-dash example belongs to the prohibited-characters/ASCII rule. | This record; `roadmap.md`, the row `The permitted-form rule has a home`. |
| The title is "Keep the referent inside the text", the description and `Fires on` name the outside-the-text cases, and the `metadata.intent` stays the family umbrella. | The operator set the umbrella as the family intent and the skill's boundary as the outside reference; the ADR states the intent is the family and the mechanism the axis. | The M3.3.8 merge; this record. |
| The body cuts the prohibition-only paragraph and its fourth test question, adds the `order-for-incremental-parsing` boundary, and updates the `The family` remedy phrase and the `Fires on` line. | The permitted-form rule is not this skill's boundary; the order principle owns the sentence-internal missing element. | The M3.3.8 merge; this record. |
| The name changes; the new name is settled after the title. | The operator accepted the placement scan's rename rule and put the content first. | The M3.3.8 merge; this record. |
| The merge and the reach/scope/link/citation work move to a new M3.3.8; M3.3.7 closes first. | The reach axis is M3.3.6's, the merge depends on it, and the operator wants M3.3.7 before M3.3.6. | This record; `roadmap.md`, the M3.3.8 milestone and the merge row. |
| The `metadata.intent` stays the family umbrella as it reads: "The text is written with the reader's context in mind; it does not reference context the reader does not have." | The operator confirmed it; `link-what-the-reader-can-open` carries the same intent, and the ADR records the sharing. | The M3.3.8 merge; this record. |
| The `write-for-the-reader` slice and its content decisions move to M3.3.8 with the merge; this iteration is the re-filing. | The referent half is half the merge; landing it now would be rewritten in M3.3.8. | This record; `roadmap.md`, the M3.3.8 merge row. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The `roadmap-maintenance` run reports the known 3.6 finding: the M3.3.7 closed rows still carry implementation narrative. | Record | None for this iteration; `/milestone-close` owns the compaction. | This record; `/milestone-close`. |
| The operator ruled one skill per iteration; the axis row splits, with the `write-for-the-reader` slice in M3.3.8. | Steering | The row's three-title end state becomes two sub-rows in M3.3.7 and the M3.3.8 merge. | `roadmap.md`, the axis row's sub-rows. |
| The `write-for-the-reader` body's "Where the sentence names only the prohibition" rule is "instead of X, do Y", not a reference outside the text; its em-dash example belongs to the prohibited-characters/ASCII rule. | Design | The rule is outside this skill's boundary; its home must be filed. | `roadmap.md`, the row `The permitted-form rule has a home`. |
| The placement scan finds the name `write-for-the-reader` predicts the family umbrella test, not the outside-reference test; the runbook's `Rename` rule applies. | Design | A rename touches the six neighbour lists, the index, `scope.md`, the roadmap and the handover. | The M3.3.8 merge; this record. |
| The H1's "referent" and the `Fires on` line use a term the body never defines. | Design | The `define-terminology-before-use` principle applies to the skill's own title. | The M3.3.8 merge; this record. |
| The `metadata.mechanism`'s "list bullets" does not name the axis. | Design | The operator-led mechanism needs a replacement. | The M3.3.8 merge; this record. |
| The earlier-version case's boundary with `rewrite-syntax-never-semantics` is unstated, and that skill declares `neighbours: []`. | Design | A see-also in `What it does not cover`; the neighbour field is a corpus decision. | The M3.3.8 merge; this record. |
| The session/narration precedence with `cut-metadiscourse` is one-way; that skill does not point back. | Design | A reciprocal scope note is a second skill; fold or file. | The M3.3.8 merge; this record. |
| The `link` skill's `metadata.mechanism` ("Discipline around links, references and records") claims the reference/record axis `write-for-the-reader` owns; the `link` axis is the target's reach. | Design | The two mechanisms overlap; the `link` mechanism is a second skill's change. | The M3.3.8 merge; this record. |
| One generic principle ("a reference resolves where the reader reads it") could subsume `write-for-the-reader` and `link-what-the-reader-can-open`, and be the `link` procedure's sole principle counterpart. The two share the same intent; the placement scan's `Consolidate` applies to the overlapping case (an unreachable link). | Design | The merge deletes or renames two skills, updates the six neighbours, the index, `scope.md`, the `linking` procedure, the roadmap and the ADR, and cites the reach/scope axis. | `roadmap.md`, the row `Consolidate the reference principles` in M3.3.8. |
| The `link` principle's "the target is reachable where the citing text is read" is the link-grain projection of the distribution reach/scope axis M3.3.6 owns (`check_reach.sh`, `documentation_taxonomy.md ## Reach`). A merge now would state the projection before the axis. | Design | The merge is sequenced after the reach axis; the `write-for-the-reader` referent half is independent. | `roadmap.md`, the M3.3.8 merge row; the reach/scope axis. |

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | The M3.3.8 milestone, the moved reach/scope/link/citation rows, the two-skill axis row, and the split-out rule. |
| [`20261121-03-plan-reference_re_filing.md`](20261121-03-plan-reference_re_filing.md) | The re-filing record. |
