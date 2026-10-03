# Agent Handover

**Date:** 2026-09-28
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Workflow
**Status:** Closed

## Objective

Execute U2 of the M3.2.1 loop-to-workflow migration: mirror the minor-loop procedure from `iteration_policy.md` into the `/iter` prompt, aligning the prompt faithfully to the canonical policy. The policy is unchanged this unit (option A); stripping its procedure bodies out is a deferred follow-on (option B), after the migration is confirmed.

## Scope

One unit, one commit, one handover. The migration moves the agent-performed minor-loop procedure (Step Details, the gate mechanics as procedure, File Tracking) into `workflow/coding-agent/prompts/iter.md`. `iteration_policy.md` keeps the invariants and links to the prompt. The policy keeps what rules the procedure must not break; the procedure itself runs from the prompt.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `iteration_policy.md` Minor Loop retains its full procedure -- it is unchanged and canonical this unit | `git diff` shows no change to `iteration_policy.md` | Agent [x] accepted: policy untouched (option A) |
| AC2 | `iter.md` carries the complete minor-loop procedure in the policy's step order, with no skipped step | read `workflow/coding-agent/prompts/iter.md` section map | Agent [x] accepted: Orient, handover, Gate 1, Steps 3-6, Gates 2-3, Steps 7-9, sub-close, file tracking, policy pointer |
| AC3 | The front-half divergences are corrected: type confirmation, unit rule, purpose reconciliation, and the inserted Steps 3 and 4 | read `iter.md` Gate 1, Steps 3-4 | Agent [x] accepted: all present |
| AC4 | The gate numbering collusion is resolved: Step 5 is Step 5, Gate 2 is stop-before-implementation, Gate 3 is stop-before-close | read `iter.md` headings | Agent [x] accepted |
| AC5 | The prompt's broken `AGENT_FEEDBACK` link is fixed and all prompt policy links are root-relative per convention | grep the links | Agent [x] accepted |
| AC6 | Lint clean and the suite passes | `scripts/lint.sh`, `scripts/run_tests.sh` | Agent [x] accepted: lint clean, 1002/0 |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/prompts/iter.md` | gains the minor-loop procedure |
| `docs/operations/iteration_policy.md` | loses the procedure body, keeps rules + link |
| `devlog/handovers/archive/20260928-07-workflow-minor_loop_into_iter.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| U2 mirrors the minor-loop procedure into `iter.md` with the policy unchanged (option A) | the operator set the sequencing: mirror first, strip the policy only after the migration is confirmed successful | this handover |
| The prompt is a faithful mirror of `iteration_policy.md`, which stays canonical | the operator directed: follow the policy where the prompt and policy diverge | this handover |
| The missing Steps 3 and 4 are inserted into `iter.md` | policy runs Step 2 - Gate 1 - Step 3 - Step 4 - Step 5; the prompt skipped them | this handover |
| The gate numbering is reconciled to the policy (Step 5, Gate 2 stop-before-implementation, Gate 3 stop-before-close) | the old prompt's "Gate 2 = AC" collided with policy's Gate 2 | this handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| The front-half of `iter.md` skipped Steps 3 and 4 of the policy minor loop | divergence | an agent running `/iter` would skip the design doc and the information-gathering pass | corrected in this unit (steps inserted) |
| The old prompt numbering called the AC step "Gate 2", colliding with policy's Gate 2 (stop-before-implementation) | divergence | running agents would mis-order the gates | corrected in this unit (Step 5 + real Gates 2 and 3) |
| The prompt's `AGENT_FEEDBACK` link was malformed (`docs/../../devlog`) | defect | a broken link in the migrated procedure | corrected in this unit |
| A handover table's last row repeatedly gains a stray pipe-cell during my write/edit ordering | recurring record defect | this is the third occurrence (U1, U2 cleanup, U2) of the same Table-column-count lint failure | monitor in U3; guard by lint-checking every handover table before pre-close |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/iter.md` | full minor-loop procedure mirrored from policy; missing Steps 3/4 inserted; gate numbering reconciled; type/unit/purpose-reconciliation added to Gate 1; universal-preconditions rule added to Step 5; `AGENT_FEEDBACK` link fixed |
| `docs/operations/iteration_policy.md` | unchanged this unit (option A: policy stays canonical and full) |
| `devlog/handovers/archive/20260928-07-workflow-minor_loop_into_iter.md` | this handover |

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| Strip the minor-loop procedure bodies out of `iteration_policy.md`, leaving rules + a link (option B) | only after the mirror is confirmed to work | a follow-on policy cleanup unit after U2-U4 are proven |

## What's Next

U3: mirror the major-loop procedure into `/plan` and `/milestone-start`. U4: mirror the close procedure into `/milestone-close`. Then: confirm the mirrored prompts are sound, and only after that strip the procedure bodies out of the policy docs (option B, deferred from U2). Then the four per-prompt quality passes.
