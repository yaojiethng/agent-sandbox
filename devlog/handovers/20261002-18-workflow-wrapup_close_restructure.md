# Handover - The wrapup close restructure and the handover skeleton reduction

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Iteration loops and workflow
**Type:** Workflow
**Status:** Closed

## Objective

Restructure `/wrapup`'s close into prepare, commit, post-commit self-check, and report; drop the handover's transient task-record sections; and make the roadmap write-back unconditional so every handover commit pairs with exactly one row event.

## Problem

The 2026-10-02 dispatch run shipped four violation classes past every gate because no step read the session's commit log against the rules, and the handover skeleton carried three transient task-record sections (`Carried forward`, `Deferred items`, `What's Next`) that duplicated the roadmap write-back and let scope leak across iterations without one.

## Decisions

Settled in the plan session's grill-me (`20261002-17`).

1. The close becomes B9 (prepare all files, the unconditional one-row write-back confirmed) -> B10 (generate the message per `git_policy.md`, land the commit) -> B11 (post-commit compliance self-check, eight tests, `wip:` exempt, violations fixed or recorded as deviation before B12) -> B12 (the success report ending in the agent-led recommendation for what to pick up next).
2. The handover skeleton drops all three task-record sections. Deferred-with-destination is written back to the roadmap as an open row; an item ruled out is one Scope sentence with its reason. Carried forward dies with them: a carried item is either completed in the iteration or becomes a roadmap row.
3. Handovers carry no cross-iteration state beyond the milestone marker and the iteration's own write-back; Scope opens with a one-line continuation pointer only when the iteration works a subtask of a parent row.
4. `iter.md` stops deriving scope from the prior handover: an empty directive is an unmet scope-gate precondition, so the agent stops and asks; a reply to a wrapup report that names a next task is the directive, not an empty scope.
5. Findings routing destinations collapse to the Decisions table, `roadmap.md`, and `devlog/AGENT_FEEDBACK.md`.

## Changes

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/wrapup.md` | B9-B12 restructure, the eight-test self-check |
| `docs/operations/handover_policy.md` | skeleton drops the three sections; the null-marker table and the correction-procedure routing reworded |
| `docs/operations/iteration_policy.md` | carry-forward invariant replaced by deferred resolution and unconditional write-back; findings routing destinations |
| `docs/operations/roadmap_policy.md` | deferred-work wording |
| `workflow/coding-agent/prompts/iter.md` | orientation reads Objective and Findings; empty-directive stop; comparison machinery dropped |
| `workflow/coding-agent/prompts/plan.md` | the What's Next read dropped |
| `workflow/coding-agent/prompts/milestone-close.md` | deferred items route to the roadmap; the carry-forward gate renamed |
| `src/reasoning/agent/prompts/defer.md` | parks to a roadmap open row instead of a handover section |
| `src/reasoning/agent/prompts/propagation-check.md` | deferred gaps write back to the roadmap |
| `workflow/coding-agent/skills/handover-maintenance.md` | the deferred-chain step checks the write-back pairing |
| `workflow/coding-agent/audits/audit.skill.md` | structural completeness and the deferred-chain audit reworded |
| `workflow/coding-agent/audits/surface-area-report.md`, `test-assertion-sweep-brief.md` | reference updates |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The close is four steps with the self-check post-commit | `wrapup.md` B9-B12 | pass |
| 2 | No handover skeleton section is a transient task record | `handover_policy.md` skeleton | pass |
| 3 | Every consumer reworded | the twelve files in Changes; stale-reference sweep clean | pass |
| 4 | Suite and lint green | run at close: 1012 of 1012, lint clean across 4 gates, frontmatter gate clean | pass |

## Findings

- The self-check's first live run found two of its own test definitions wrong: the handover-only test needed the record-change exception, and the roadmap-only test was over-broad because a standalone `plan:` commit is bookkeeping, not a separated write-back. Both fixed in the B11 text this unit lands.
- The B11 test 8 (the scope lands as one unit in one commit) is the same test the M3.2.2 reviewer counterparty inherits for gateless closes.
