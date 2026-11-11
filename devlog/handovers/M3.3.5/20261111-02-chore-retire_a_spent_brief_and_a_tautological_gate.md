---
date: 2026-11-11
milestone: M3.3.5 - The eval pipeline
type: Housekeeping
status: Closed
---

# Handover - The unit vocabulary gate and a spent brief are retired

## Objective

Remove two artifacts that carry no reader: the `unit` vocabulary gate, which restates a rule `terminology.md` already states, and the `gm` ablation brief, whose run is closed.

## Scope

The gate and everything that exists only for it: `scripts/lint/unit.mjs`, the `scripts/check_unit_vocabulary.sh` wrapper, and `tests/test_unit_vocabulary.sh`, with the wrapper's line in `scripts/lint.sh`. The rule the gate copied stays where it is stated, in `docs/reference/terminology.md` `## Usage`. The brief is `.agents/drafts/gm-ablation-run.md`, and nothing in the tree reads it: its two roadmap rows are closed, its case is `tests/eval/gm-section-ablation/case.json`, and its decisions are in the handovers of 2026-11-09 and 2026-11-10.

The gate was widened in the preceding commit, to admit `experimental unit`, which shows the defect rather than fixing it: a rule stated in `terminology.md` had to be transcribed into a gate, and the transcription disagreed with the rule. That is why the gate is removed rather than corrected again.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No gate is lost by accident. | `bash scripts/lint.sh` names 26 gates where it named 27, and the one removed is the unit vocabulary gate | Agent [x] |
| The rule the gate copied survives its gate. | `grep -n 'is not a reserved term' docs/reference/terminology.md` still prints the paragraph, with the experimental unit among its quantifiers | Agent [x] |
| Nothing in the tree reads the retired brief. | `grep -rn 'gm-ablation-run'` over the tree returns no hit | Agent [x] |
| The suite stays green. | `bash scripts/run_tests.sh` | Agent [x] |

## Findings

| Finding | Category | Consequence | Disposition | Triaged to |
|---|---|---|---|
| A vocabulary rule in `docs/reference/terminology.md` was transcribed into `scripts/lint/unit.mjs`, and the two disagreed on `experimental unit`, so a legal use failed the gate. | structure | A rule with a second copy has a second answer, and the copy governed what a writer could say. | fixed: the gate is deleted and the doc is the only statement of the rule | this table |
| The `gm` ablation brief stayed in `.agents/drafts/` after its run closed, and its check line named `tests/eval/cases/gm-focus-milestone.json`, a path removed earlier in the series. | record | A stale brief reads as a live plan and its check cannot run. | fixed: the brief is deleted; its design is in the case and its decisions in the handovers | this table |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The word `unit` keeps its guidance and loses its gate. | `terminology.md` is the single statement of the vocabulary rule; a gate that must be widened to agree with it is a copy that has drifted. | this table |
| A closed run's brief is deleted rather than archived. | Its design lives in the case and its decisions in the handovers, so the brief is a second source with no reader. | this table |

## Completed

| File | One-line change summary |
|---|---|
| `scripts/lint/unit.mjs`, `scripts/check_unit_vocabulary.sh`, `tests/test_unit_vocabulary.sh` | Removed with the gate they existed for. |
| `scripts/lint.sh` | The gate list drops the removed wrapper. |
| `.agents/drafts/gm-ablation-run.md` | Removed; the run it planned closed in the previous milestone series. |
| `devlog/handovers/M3.3.5/20261111-02-chore-retire_a_spent_brief_and_a_tautological_gate.md` | This record. |

## Evidence

`bash scripts/lint.sh` reports 26 gates clean. `bash scripts/run_tests.sh` reports the suite green, one file fewer. `git log --oneline -2` shows the docs delivery commit beneath this one and the brief's deletion above it.

## Decisions pending

None. The two decisions above are recorded, and the operator released the work.
