# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Apply to the roadmap and milestone policy the same invariant/first-decoupling convention landed for `iteration_policy.md` in iteration `20260929-11`: the roadmap-policy sections whose procedure the milestone workflows have superseded (`milestone-start.md`, `milestone-close.md`, and the minor-loop runbooks) keep only durable invariants and canonical deterministic procedures; loose judgment-heavy procedure lives in the runbooks, which name and link the invariants. Then quality-pass `milestone-close.md` and `milestone-start.md` as the new homes of the moved procedure.

## Scope

- `roadmap_policy.md` superseded procedure blocks: `Roadmap-update timing rule`, `### Iteration start`, `Pre-close write-back`, `### Iteration end`, `### Compaction cascading`, `### Top-level milestone close`, `### Summary table update`, `### Carry-forward escalation`, `## Milestone Promotion` (`### Promotion check`, `Promotion transport`).
- Quality pass on `milestone-close.md` and `milestone-start.md` as the homes of the moved procedure.
- Out of scope: Record shape, Fractal Milestone Numbering, filing rules, Changelog Format, corrections; the `[O]` "convergence must be optional" AGENT_FEEDBACK entry.

Confirmed by the operator at the scope gate, 2026-09-29.

## Decisions

- The former minor-loop **Promotion check** (set the targeted milestone `In progress` at the scope gate) is owned by `/iter` Scope gate, not `/milestone-start`: it is a per-iteration minor-loop moment, while `/milestone-start` handles milestone opening. `/iter` therefore carries the promotion check; policy names it as an invariant and the runbook executes it.
- The **Promotion transport** at top-level close stays owned by `/milestone-close` Update the records.
- The **Roadmap-update timing rule**, the compaction cascade, and the top-level close sequence are durable; compaction and top-level close stay in policy because they are deterministic canonical procedures that multiple runbooks invoke (`/milestone-close`, `/wrapup`) and must not restate.

## Acceptance criteria

1. In `roadmap_policy.md`, no procedural block is duplicated in a runbook; each superseded block is either reduced to invariants or restated as canonical/deterministic procedure with its runbook owner named.
2. The decoupling principle is stated for the roadmap/milestone layer as it was for the iteration layer.
3. `milestone-close.md` and `milestone-start.md` own all moved procedure, name and link the rules they satisfy, and carry no stale roadmap-policy anchors.
4. Lint clean; no cross-document dead anchors introduced.
5. The `[O]` AGENT_FEEDBACK "convergence must be optional" entry remains untouched.

## Completed

| File | Change | Status |
|---|---|---|
| `docs/operations/roadmap_policy.md` | reduced `Roadmap-update timing rule`, `### Iteration start`, `Pre-close write-back`, `### Iteration end` to invariants; named runbook owners; kept compaction + top-level-close as canonical with owners; merged `Promotion check`/`Promotion transport` into one `### Promotion invariant` owned by `/iter` and `/milestone-close`; added Decoupling principle and Two-forms-of-rule | done |
| `workflow/coding-agent/prompts/iter.md` | added the promotion check to the Scope gate | done |
| `docs/operations/handover_policy.md` | retargeted the `#when-the-roadmap-is-touched` pointer to invariants + runbooks | done |
| `workflow/coding-agent/prompts/milestone-close.md` | added `#top-level-milestone-close` fragment to the close-boundary link | done |
| `docs/operations/roadmap_policy.md` | glm-fix: self-referential wording at top-level-close; trimmed the runbook-overlay paragraph to the load-bearing invariant line | done |
| `docs/operations/roadmap_policy.md` | moved `Carry-forward escalation` out of the maintenance procedure into a `Roadmap task placement` filing rule (the escalate-vs-re-defer decision is the finding write-back, owned by the `iteration_policy.md` close invariant + `/wrapup` + `/milestone-close`) | done |
| `workflow/coding-agent/prompts/milestone-close.md` | retargeted the escalation reference from the removed block to the Roadmap task placement filing rule | done |
| `devlog/handovers/20260929-12...md` | scope, decisions, AC, completed, findings | done |

**glm advisor review (glm-5.3-flash, high, 2026-09-29):** ran after the draft; verified no duplication (canonical keeps justified), correct promotion-check placement and owner attributions, no orphaned behavior, no stale anchors, decoupling/two-forms present. Found two wording defects (fragment-less navigation link, self-referential policy prose) - both fixed and re-linted; verdict after fixes CONVERGED.

## Findings

| Finding | Type | Impact |
|---|---|---|
| **Carry-forward escalation restates the finding write-back procedure** (operator + glm advisor, 2026-09-29): the escalate-vs-re-defer decision is the handover's finding write-back (close invariant), not a roadmap-policy rule; only the placement filing rule (don't re-list, nest under current sub-milestone) is durable in this file. Moved during this iteration. | steering | `roadmap_policy.md` -- resolved: folded to `Roadmap task placement` filing rule; `/milestone-close` retargeted |

## Deferred items

_(filled at close)_

## What's Next

_(filled at close)_
