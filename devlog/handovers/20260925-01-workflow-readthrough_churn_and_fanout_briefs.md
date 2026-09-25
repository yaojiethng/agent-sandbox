# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Workflow
**Status:** Closed

## Objective

Write the read-through, churn-analysis and fan-out standing workflow briefs, link them from the testing policy, and republish the read-through register's table.

## Scope

The first product of the read-through close (roadmap M3.1, `Read-through close: operator review, then a findings-to-tasks plan session`). The three briefs and the register repair only; the fix lanes and the lesson plan are separate units with their own handovers.

## Carried forward

| Item | From handover |
|---|---|
| Read-through close: operator review, then a findings-to-tasks plan session | roadmap M3.1 (the read-through iteration closed without a handover, by operator waiver) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The three briefs exist in `workflow/coding-agent/prompts/` and are linked from the testing policy | file presence and the policy's See Also section | Agent [x] |
| The churn brief's pinned command and window reproduce its own worked numbers | re-run the command | Agent [x] (679 commits; 88 and 54 for the two named files) |
| The register's findings table is one contiguous table holding the same 312 finding texts, ascending | scripted comparison against the previous revision | Agent [x] |
| The register stays lint-clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/read-through-run.md`](../../workflow/coding-agent/prompts/read-through-run.md) | new: the standing read-through brief |
| [`workflow/coding-agent/prompts/churn-analysis-run.md`](../../workflow/coding-agent/prompts/churn-analysis-run.md) | new: the churn-analysis brief |
| [`workflow/coding-agent/prompts/fanout-run.md`](../../workflow/coding-agent/prompts/fanout-run.md) | new: the fan-out draft brief |
| [`docs/development/testing_policy.md`](../../docs/development/testing_policy.md) | the three briefs are linked here |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.md`](../discussions/20260924-design-active-test_suite_readthrough.md) | the register: table repair |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Repair the register with a content-preserving transform | the record is the durable output; all 312 row texts were verified character-identical after the repair | this handover |
| Pin the churn window as the full history from HEAD with `--follow`, no date bound | the record's own counts were unreproducible; a count without its command cannot be compared | the churn brief |
| Keep the fan-out brief at `Status: draft` | it has one run's evidence; the settling conditions are listed in the brief itself | the fan-out brief |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The register's findings table was fragmented by blank lines and a prose paragraph, so markdownlint never parsed it as a table and 20 MD056 plus 18 MD038 defects were hidden; it was lint-clean only because of the fragmentation. | bug | current iteration |
| Any script that reads the register must split on unescaped pipes and key rows by number, confined to the findings section, because the triage table repeats the same numbers and 27 rows carry escaped pipes. | contradiction | next iteration |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/read-through-run.md` | new: triggers, unit, frame, the bite requirement with four verdicts and three trap families, register integrity, glossary, close |
| `workflow/coding-agent/prompts/churn-analysis-run.md` | new: the pinned command and window, mechanical against functional churn, the register cross-reference, a worked example |
| `workflow/coding-agent/prompts/fanout-run.md` | new draft: frozen snapshot, file ownership, serialized suites, the findings block, the integrity check, six observed failure modes |
| `docs/development/testing_policy.md` | the three briefs linked from See Also |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.md` | the findings table rebuilt as one table in ascending order with in-cell pipes escaped and padded code spans trimmed; the consolidation map made one table |

## Deferred items

None. The remaining read-through work is roadmap rows 83 and 84.

## What's Next

M3.1 - Backpressure remains active. The next unit is the instrument fix lane, then the remaining three lanes.

**Conclusions from this iteration:** the register's 312 finding texts survive a table repair unchanged, so the repair is a presentation fix; the register's lint cleanliness had been vacuous.
