# Agent Handover

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Documentation
**Status:** Closed

## Objective

Record in the agent configuration how to launch a subagent so it survives to produce its result, and how to run several in parallel without orphaning any of them.

## Scope

- `src/reasoning/providers/pi/config/agent/AGENTS.md` - a new `### Keeping a subagent alive` subsection under `## Running Review Subagents`.

Excluded: any change to pi's dispatch, and any change to the review recipe, which was already correct.

## The defect

The review-subagent recipe already ran in the foreground, capped the run with `timeout`, captured to a file, and recorded the exit code and elapsed time. Following it was not the problem. The moment two agents were wanted at once, the natural move was `&`, the tool call returned, and every child was killed with it. Nothing reported an error. The logs were short, and a short log reads as an agent that never ran rather than a run that was cancelled.

Three launch attempts were lost this way during the upstream report validation, and a fourth was killed by a timeout I set and then misread as a failure.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The rule that a subagent outlives no tool call is stated in the agent configuration | `grep -n "Keeping a subagent alive" src/reasoning/providers/pi/config/agent/AGENTS.md` | Met |
| 2 | The parallel recipe keeps every child inside one call and does not return early | the code block in the new subsection | Met |
| 3 | The shape of a truncated run is recorded, so it is distinguishable from no work happening | the last paragraph of the new subsection | Met |
| 4 | The installed copy reaches the running agent context | `cp src/reasoning/providers/pi/config/agent/AGENTS.md ~/.pi/agent/AGENTS.md`, run by the operator on 2026-10-02 | Met |
| 5 | Lint is clean | `bash scripts/lint.sh` clean across 3 gates | Met |

## Completed

| File | Change | Status |
|---|---|---|
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | 20 lines: the foreground rule, the parallel recipe with `wait`, and the truncated-run signature | done |

## Findings

- The existing recipe was not wrong and did not need changing. The gap was that it did not say what to do when the goal is parallelism, which is exactly when the wrong move looks obvious. Recorded here so the next reader sees that the fix is an addition, not a correction.
- The installed copy at `~/.pi/agent/AGENTS.md` is a separate file, not a link to the repository source, so the two diverge until the config copy step runs. The operator applied the change on 2026-10-02.

## Final output artifacts

| Artifact | Home |
|---|---|
| the rule and the recipe | `src/reasoning/providers/pi/config/agent/AGENTS.md` |

## Resolution status

Closed.

## Records this supersedes

None.
