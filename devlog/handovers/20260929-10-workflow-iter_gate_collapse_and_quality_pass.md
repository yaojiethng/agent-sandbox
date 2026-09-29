# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Active

## Objective

Reform the `/iter` prompt's gating and raise it to the per-prompt quality bar (roadmap row 83): collapse Gate 1 and Gate 2 into one release gate, give the final gate a semantic name (`release gate`) that is not `/iter`-specific, and cut the per-step confirmation pauses so the operator responds only at the gates (the live over-pausing finding, 2026-09-29).

## Scope

**Iteration A (this iteration): gate collapse + rename + propagation.** Collapse `/iter` Gate 1 (confirm scope) and Gate 2 (confirm AC) into one **scope gate** that presents scope and acceptance criteria together and clears on a single operator approval. Rename the final gate **release gate** (the common acceptance gate for operator-involved workflows, which hands off to `/wrapup` Part B after its release). The conditional remains: if scope is unclear, the prompt still asks the operator to define task scope before presenting the formal scope gate. At the end there are exactly two gates: scope gate and release gate.

**Gate names (glm review, 2026-09-29):** the operator requested a glm review of the provisional names "task scope gate" and "acceptance gate". glm-5.3-flash recommended `scope gate` (already established at `iteration_policy.md:104`, one-term-one-meaning, delete-test) and `release gate` (avoids the reserved "acceptance criteria" collision, matches roadmap row 83's recorded decision and the existing `release` verb). Operator approved both (2026-09-29).

**Iteration B (next, same roadmap row): quality pass.** Audit the minor-loop logic in `iteration_policy.md` and the mentions of it in both `AGENTS.md` files and the `/iter` prompt; collapse with the over-pausing (pedantic) finding as the explicit quality target. Do not release the acceptance gate automatically; wait for operator review.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Gate 1 = `scope gate` (not "task scope gate") | glm review: "task" is a noun-stack modifier, collides with the established `scope gate` term at `iteration_policy.md:104`, fails the delete-test | this handover, `[O]` 2026-09-29 glm-naming; operator approved |
| Gate 2 = `release gate` (not "acceptance gate") | glm review: "acceptance" collides with reserved "acceptance criteria" terminology and would sit at two gates with two meanings; `release` matches the existing gate-release verb and roadmap row 83's recorded decision | this handover, `[O]` 2026-09-29 glm-naming; operator approved |
| Minor loop has exactly two gates | operator directive (2026-09-29) and roadmap row 83 | this handover |
| `milestone-start`, `auto`, `parallel-auto` do not use the two gates | milestone-record close is `/milestone-close`; auto runs substitute autonomous acceptance | this handover |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `/iter` has exactly two gates: scope gate and release gate | read `/iter` section map | Met |
| 2 | Scope gate presents scope and AC together, clears on one approval, and still prompts for task-scope definition when scope is unclear | read `/iter` `## Step 2` and `## Scope gate` | Met |
| 3 | Release gate is the common acceptance gate and hands off to `/wrapup` Part B | read `/iter` `## Release gate` | Met |
| 4 | Propagation complete: no stale Gate 1/2/3 for the minor loop in live docs | grep for `Gate [123]` in live docs, major-loop gates excepted | Met |
| 5 | `iteration_policy.md`, `roadmap_policy.md`, project `AGENTS.md`, skills, eval, audit all use the new names and lint clean | read + `check_markdown.sh` | Met |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/iter.md` | Gate 1+Step 5+Gate 2 collapsed into scope gate; Step 2 renamed to define task scope; Gate 3 renamed release gate |
| `docs/operations/iteration_policy.md` | minor-loop gate collapse + rename (scope gate, release gate); Step 2 renamed; Step 5 removed |
| `docs/operations/roadmap_policy.md` | Gate 3 -> release gate |
| `AGENTS.md` | Gate 1 -> scope gate |
| `src/reasoning/agent/drafts/roadmap-management.skill.md` | Gate 3 -> release gate |
| `tests/eval/eval_protocol.md` | Gate 1/2 -> scope/release gate |
| `workflow/coding-agent/audits/handover-audit.skill.md` | Gate 2 -> scope gate |
| `docs/operations/handover_policy.md` | scope/AC gates plural -> scope gate and release gate |
| `workflow/coding-agent/audits/surface-area-report.md` | scope and acceptance gates -> scope gate and release gate |
| `devlog/roadmap.md` | row 83 gate-collapse landing noted |

**glm review round (glm-5.3-flash, high, 2026-09-29):** the first review found six defects (dangling Step-5 reference, Step-4-to-6 numbering gap, Step 7 counting as a third gate, Step 3 exit reintroducing a confirmation pause, stale eval invariant I4, stale scope/AC plural in handover_policy and surface-area-report). All six fixed in a second pass; the re-review verdict is CONVERGED (log `/tmp/gate-collapse.refix.log`).

## Findings

| Finding | Type | Impact |
|---|---|---|
| **Conversational numbering ambiguity** (operator, 2026-09-29): when the agent presents several numbered or lettered sets in one exchange (a review's numbered findings beside lettered option choices), the operator's index reply (".ok, .ok") can map to the wrong axis, so the agent must guess. The agent presented glm's findings (1, 2) and its own options (A, B) in the same turn; the operator's reply indexed the findings, not the options. | steering | Recorded as `[O]`; the numbering convention in `documentation_policy.md` `### Numbering and cross-references` must be sharpened so the reference axis is unambiguous -- fold the fix into this iteration's quality pass or a dedicated convention amendment |

## Deferred items

_(filled at close)_

## What's Next

_(filled at close)_
