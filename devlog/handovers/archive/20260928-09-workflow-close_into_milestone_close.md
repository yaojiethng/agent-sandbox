# Agent Handover

**Date:** 2026-09-28
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Execute U4 of the M3.2.1 loop-to-workflow migration: write the close procedure into `/milestone-close` as a single general fractal protocol (option B), stripping the close procedure from `milestone_policy.md` Closing the Major Loop and `iteration_policy.md` Sub-milestone close and Steps 8-9. Created at the operator's request mid-session so that the milestone-close knowledge from the U3 discussion survives chat compaction.

## Scope

One unit, one commit, one handover. U4 redesigns `/milestone-close` to match actual close practice. This unit drafts a **stub-level** close prompt; refinement happens in the `Four per-prompt quality passes` after the migration (U1-U4).

The close is a **single general fractal protocol** (operator decision, U3): a sub-milestone and a full milestone close through the same prompt, stopping one level earlier for the sub-milestone. What changes across nesting levels is goal granularity, task count/order, and the size of the applicable residual task pool.

Files in scope: `workflow/coding-agent/prompts/milestone-close.md`, `workflow/coding-agent/prompts/milestone-close-run.md`, `docs/operations/milestone_policy.md` (Closing the Major Loop), `docs/operations/iteration_policy.md` (Sub-milestone close, Steps 8-9), `devlog/roadmap.md` (U4 row).

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `milestone-close.md` is a single general fractal close protocol (one prompt closes a sub-milestone and a full milestone), carrying the full close body: review gate, compaction, changelog, records update, escalation, close commit, invariants; folded from `milestone-close-run.md` | read the prompt's section map | Agent [x] accepted |
| AC2 | `milestone-close-run.md` is retired; its body is absorbed into `milestone-close.md` and no live reference to it remains outside historical records | `grep -rn "milestone-close-run"` | Agent [x] accepted: only historical handovers/roadmap rows remain |
| AC3 | The close procedure is stripped from the policies (option B): `milestone_policy.md` Closing the Major Loop and `iteration_policy.md` Sub-milestone close / Steps 8-9 keep rules + links and carry no step-by-step close procedure | read the policy sections | Agent [x] accepted: advisor confirmed |
| AC4 | `milestone_policy.md` and `iteration_policy.md` link the `/milestone-close` prompt | grep the links | Agent [x] accepted |
| AC5 | Lint clean | `scripts/lint.sh` | Agent [x] accepted: 0 findings |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/prompts/milestone-close.md` | rewritten as self-contained fractal close prompt |
| `workflow/coding-agent/prompts/milestone-close-run.md` | retired; body folded into `/milestone-close` |
| `docs/operations/milestone_policy.md` Closing the Major Loop | rules kept, prompts linked (option B) |
| `docs/operations/iteration_policy.md` Sub-milestone close and Steps 8-9 | procedure stripped, rules + links kept (option B) |
| `docs/adr/coding_agent_loop_workflow.md` | loop-artifact table updated (run template dropped) |
| `src/reasoning/agent/prompts/advisor.md` | documentation-review model preference + re-run usage criteria added |
| `devlog/AGENT_FEEDBACK.md` | advisor re-run marginal-value entry added |
| `devlog/roadmap.md` | U4 row is this unit |
| `devlog/handovers/archive/20260928-09-workflow-close_into_milestone_close.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `/milestone-close` is the single self-contained fractal close prompt, absorbing `milestone-close-run.md` | `/plan` and `/milestone-start` are single consolidated prompts; the migration drops the surface+run split, so `run.md` retires with its body folded in | this handover; ADR taxonomy updated |
| The close prompt owns the milestone-record close (review gate, compaction, changelog, records, escalation, close commit); the iteration close (Steps 8-9) stays with `/iter` | `/milestone-close` runs when a whole sub-milestone / milestone finishes; `/iter` closes each iteration. Different cadence, different prompt | this handover |
| Option B: strip the milestone-close procedure from `iteration_policy.md` Sub-milestone close (rules stay: `active -> pre-close -> close` sequence, probation decisions) + `iteration_policy.md` Steps 8-9 (the iteration close stays with `/iter`) and link `/milestone-close` | operator confirmed option B acceptable (2026-09-28) | this handover |
| `milestone_policy.md` Closing the Major Loop is a readiness gate (when major-loop planning ends and iteration begins), not a milestone-close record procedure; keep its rules and link the prompts | U4 row names it as a strip target, but the audit shows it carries no close-record procedure to strip | this handover |
| The close practice requirements (resolve tasks, roadmap->changelog, resolve AGENT_FEEDBACK, write deferred/new to the next milestone) are the fold targets U4 of the close prompt | operator's description of close practice | roadmap U4 row + U3 handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| Advisor (fresh `deepseek-v4-flash`, round 1) found the milestone-close commit-type guidance said a compaction-only close types `chore`, contradicting `git_policy.md` Active Types (which classes compaction and close bookkeeping as `plan`) and the sibling sentence in `iteration_policy.md` | defect (commit-type rule) | a close could be typed `chore` against the policy | Triaged to: Completed (both sources corrected to type `plan`) |
| Advisor (round 2) re-checked the correction: commit-type now consistent across `milestone-close.md`, `iteration_policy.md`, and `git_policy.md`; no remaining defects. Clean bill | verification | consensus reached | Triaged to: Completed (advisor consensus) |
| Advisor re-run has low marginal value after a clean consensus (round 2 merely re-verified a single mechanical fix) | process | advisor budget spent on low-value confirmation | Triaged to: AGENT_FEEDBACK `[A]` 2026-09-28 (advisor re-run) + advisor.md usage criteria |
| Operator instructed a glm-5.3-flash `high` rewrite pass over `milestone-close.md`; glm found 4 accepted improvements: (1) no operator release gate before the close commit; (2) "the close is the commit" / "the close direction" have no defined referent; (5) scope reconciliation unpointed at milestone grain; (6) "top-level close" should link the promotion phrase. Rejected 2 (already correct: `git_policy.md` link, ASCII argument-hint -- glm read a stale copy) | steering / rewrite | prompt correctness and termination clarity | Triaged to: Completed (accepted findings applied, prompt refined) |
| Advisor budget: 2 runs granted at unit start, 1 instructed re-run for the glm rewrite pass = 3 used. Per operator: budget increments only at operator instruction | budget accounting | transparency | Triaged to: this handover |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/milestone-close.md` | rewritten as a single self-contained fractal close prompt: orient, verify completeness, review gate, compact, close boundary, changelog, records, escalation, close commit, invariants; absorbs `milestone-close-run.md` body; commit-type guidance corrected to `plan` |
| `workflow/coding-agent/prompts/milestone-close-run.md` | retired (deleted): its body folded into `/milestone-close`, no live references remain |
| `docs/operations/iteration_policy.md` | Sub-milestone close: review-gate procedure stripped, rules + `active -> pre-close -> close` kept, `/milestone-close` linked; Steps 8-9: kept as rules + links to `/iter` and `/milestone-close`, procedure text yeilded; commit-type guidance corrected to `plan` |
| `docs/operations/milestone_policy.md` | Closing the Major Loop keeps readiness rules and links `/milestone-start`, `/plan`, `/milestone-close` |
| `docs/adr/coding_agent_loop_workflow.md` | loop-artifact table: `/milestone-close` now points to `milestone-close.md` only (run template dropped) |
| `src/reasoning/agent/prompts/advisor.md` | Invocation: documentation reviews prefer `opencode-go` `glm-5.3-flash` at `high` thinking; Work to consensus: re-run only for structural/cross-file changes |
| `devlog/AGENT_FEEDBACK.md` | `[A]` 2026-09-28 entry: advisor re-run has low marginal value after a clean consensus |
| `workflow/coding-agent/prompts/milestone-close.md` (second pass) | operator-release gate before the close commit added; "the close is the commit" / "close direction" referents clarified; scope reconciliation pointed at milestone grain; top-level-close phrase linked (glm-5.3-flash `high` rewrite pass) |

## Deferred items

None.

## What's Next

The migration units U1-U4 of M3.2.1 are complete: `/iter`, `/milestone-start`, `/plan`, and `/milestone-close` are now single self-contained loop prompts; the policy files (`iteration_policy.md`, `milestone_policy.md`) state rules + links and carry no step-by-step loop procedure.

**This unit (U4) delivered:** `/milestone-close` rewritten as a single fractal close protocol (orient, verify, review gate, compact, close boundary, changelog, records, escalation, close commit, invariants); `milestone-close-run.md` retired with its body absorbed; the close procedure stripped from `iteration_policy.md` Sub-milestone close / Steps 8-9 and `milestone_policy.md` Closing the Major Loop (rules + links kept); the ADR loop-artifact table updated. Advisor (deepseek-v4-flash) consensus reached after one correction: the milestone-close commit-type guidance now types `plan`, aligned with `git_policy.md` Active Types and the `iteration_policy.md` sibling sentence; both M2.7 and M3.1 closes typed `plan`.

**Next (successor):** the `Four per-prompt quality passes` roadmap row -- one roadmap task per loop prompt (`/iter`, `/milestone-start`, `/milestone-close`, `/plan`), each raising the prompt to an operator-approved quality bar before the migration milestone closes. The prompts are structurally coherent and advisor-reviewed to consensus; the quality passes polish each against the operator's practice.
