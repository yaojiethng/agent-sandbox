---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - The version assertion in the bump runbook

## Objective

Close the census's finding that the image's version lives in two records, by putting an equality assertion where the bump happens instead of adding a gate that would run when nothing has moved.

## Scope

One roadmap row, **The settings record holds the image's version pin as a literal**, and one ruling the operator took in a single exchange: no CI gate, because the cost of drift is one replayed changelog and the only event that can separate the two values is a bump. The assertion goes in `pi-bump`, the runbook that moves both.

No design document. A unit whose whole content is one ruling and one snippet records its decision in the roadmap and here; a discussion record would be a second copy of the same paragraph.

Out of scope: the second equality case the census raised, the chart's `## Commands` table, which stays with the parked cited-command design; and the mutation corpus, which is a deletion or a generator rather than a check.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| A1 | The bump runbook asserts equality and no longer greps for the new number | `grep -c 'version assertion' .agents/skills/pi-bump/SKILL.md` reports 2 -- the checklist line and the block heading; `grep -c 'grep -rn "<NEW>"'` reports 0 | Agent [x] |
| A2 | The assertion fails on a mismatch and names both values | run with the pin read as `1.4.0`: prints `mismatch: pin=1.4.0 settings=1.3.0`, exit 1 | Agent [x] |
| A3 | The assertion passes on the tree as it stands | run from the repo root: `match: 1.3.0` | Agent [x] |
| A4 | The roadmap row is closed and carries the ruling | `grep -n "version pin as a literal" devlog/roadmap.md` reports the closed row, naming `providers/pi/base.dockerfile` and `pi-bump` step 6 | Agent [x] |
| A5 | The census record stops claiming the field has no gate | the `settings.json` classification cell reads as a copy asserted by the runbook that moves it, and the reviewer finding's sentence names `20261023-09` | Agent [x] |
| A6 | Every decision this iteration recorded is realized in the files | D1 the ruling and D2 the replacement are both readable in the files A1 to A5 verify | Agent [x] |
| A7 | The record chain carries no reference to the deleted census script | `grep -n "The census query" devlog/discussions/20261023-design-settled-derived_artifacts.md devlog/handovers/20261023-07-*.md` reports 0 | Agent [x] |

## Decisions

| # | Decision | Rationale | Where recorded |
|---|---|---|---|
| D1 | No equality gate; the assertion lives in `pi-bump` step 6 and the bump is not complete until it prints a match | The only event that can separate the two values is a bump, so a check at that moment is a complete detector for this artifact. A CI gate would rerun the comparison on every commit to catch a difference only a bump can create, and the cost of the drift it prevents is one changelog reprinted | roadmap row, `pi-bump` |
| D2 | The assertion replaces the `<NEW>` grep rather than joining it | A grep for the new number cannot say which side moved, and it misses a stale literal outside the range it searched. The assertion reads both files and reports both values | `pi-bump` step 6 |

## Decisions pending

None.

## Findings

| # | Finding | Type | Impact | Triaged to |
|---|---|---|---|---|
| F1 | The roadmap row named `src/reasoning/base.dockerfile`, which is the shared base and pins no agent. The pin is in `src/reasoning/providers/pi/base.dockerfile`. Both files exist, so the wrong path read as plausible | defect in the record | the row's evidence pointed at a file that does not hold the literal | fixed in place, A4 |
| F2 | The census handover's A1 pointed at `## The census query`, the section dropped from the design record when that unit was released | defect in the record | a closed record cited a deleted section | fixed in place, A7 |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/pi-bump/SKILL.md`](../../.agents/skills/pi-bump/SKILL.md) | step 6's `<NEW>` grep and its read-them line become one assertion that prints a match or names both values |
| [`devlog/roadmap.md`](../roadmap.md) | the version-literal row closes with the ruling, and its dockerfile path corrected |
| [`devlog/discussions/20261023-design-settled-derived_artifacts.md`](../discussions/20261023-design-settled-derived_artifacts.md) | the settings cell reads as a copy asserted by the runbook that moves it; the reviewer finding's consequence names the unit |
| [`devlog/handovers/20261023-07-workflow-derived_artifacts_census.md`](20261023-07-workflow-derived_artifacts_census.md) | A1 stops citing the dropped section |
