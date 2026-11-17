---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Design
status: Closed
---

# Handover - The reader-context five, a dry run

## Objective

Run the survey on the five reader-context principles and hand the operator their cards, map and conflict docket, so the process is confirmed or revised before the full survey.

## Scope

The M3.3.7 row **The five-card dry run**. In scope: the five cards, the readings and the operator's cut, the candidate edges and the docket, in the dry-run report. No skill is edited and the field stays `[]`.

Out of scope: the full survey and the link normalisation. The dry run is complete with the operator's correction; it does not run the full survey.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The five cards, the two readings of the map and the docket exist in the report. | Read `devlog/discussions/20261116-report-open-reader_context_dry_run.md`. | Agent [x] |
| The operator reads and corrects the five, and confirms or revises the process. | The operator's reply on this handover. | Agent [x] |
| No principle skill is edited and the field stays `[]`. | `git diff --stat` shows no `src/reasoning/agent-runtime/pi/config/agent/skills/` file. | Agent [x] |
| The two-side cut and the `single-train-of-thought` placement are recorded. | Read the Decisions table and the report's docket. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The dry run stops for the operator's correction. | The process is confirmed by use, and the five are the family the reverted migration found contested. Scaling to 25 before the correction would repeat the migration's cost. | This record; the report |
| Reading A and Reading B are both carried to the operator. | The process did not force one reading; the defect facet's granularity decides whether the five are one judgement or five under an umbrella. That is the decision the process was built to surface. | This record; the report's docket |
| The operator's cut is the two-sided umbrella: prior disclosure and forward dispatch. | It answers D2 and narrows D1 to the placement of `single-train-of-thought`. | This record; the report's D1 and D2 |
| `single-train-of-thought` is RT to the umbrella, not an NT. | Good progressive disclosure leads with the important context and discloses details in order, so a single train of thought is a neighbouring goal the same rules serve. It is not the umbrella's intent, which is to smooth engagement and improve transference. | This record; the report |
| No edge is written and the field stays `[]`. | The map is the survey's output. The field is an admission index, and the existing corpus declares no neighbour. | This record; the report |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The five carry 11 of the 30 censused cross-references, and `What it does not cover` carries most of them. | record | The cards can be read from the existing parts without opening a body. | The report |
| The process reached two readings and two cases rather than a tangle. | record | The dry run's cost was five cards, and the decision is visible rather than buried in the values. | The report |
| `write-for-the-reader` and `link-what-the-reader-can-open` both tell the writer to link once, but at different grains. | record | They are RT under either reading, not a duplicate. | The report |
| `single-train-of-thought` serves the umbrella's two sides without being one of them. | record | The umbrella's map carries four NTs and one RT; the full survey keeps the distinction. | The report; roadmap P4 |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/discussions/20261116-report-open-reader_context_dry_run.md` | The five cards, the two readings, the candidate edges and the docket. |
| `devlog/roadmap.md` | Marks the five-card row done and re-points the dry-run report to the full-survey row. |
| `devlog/handovers/M3.3.7/20261116-11-design-reader_context_dry_run.md` | This record. |
