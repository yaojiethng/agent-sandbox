# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (general cross-cutting track)
**Type:** Workflow
**Status:** Closed

## Objective
Document the first autonomous review pass (iteration `20260912-05`: thermo-nuclear code review + test-quality campaign run as fresh subagents, WIP-commit fix rounds, review-until-APPROVE, proposal accept + fold, squash into delivery) as a reusable prompt draft, so the process can be invoked again.

## Scope
1. New prompt template `workflow/coding-agent/prompts/autonomous-review-pass.md` -- the main-agent orchestration template, generalized from what iteration 20260912-05 actually did:
   - Preconditions (working tree committed as WIP so subagents review exact commits; campaign-style subagents may leave proposals uncommitted).
   - Spawn review subagents (`pi -p`) with: scoped diff range, do-not-modify constraint, prior-round blockers to verify, explicit VERDICT contract.
   - Review loop: triage verdict -> fix blockers as WIP commits -> re-run fresh subagent (not the same context) -> repeat until APPROVE; cap rounds and escalate to operator if not converging.
   - Proposal handling: campaign subagent returns uncommitted changes + report; operator decides accept (fold into iteration) / defer / reject; folded changes ride the delivery commit.
   - Close: roadmap write-back, handover Close, squash WIPs into one typed delivery commit per git_policy.
   - What worked / calibration notes from 20260912-05 (scoping the diff range explicitly; swallows-exit-code class found twice; doc-contract drift is the blocker class reviews keep finding).
2. Not in scope: changing the audit skills themselves (`workflow/coding-agent/audits/*` are already the subagent-side prompts); no policy-document changes; no test changes.
3. Update `docs/development/project_index.md` row for the new prompt (one table row).

## Design decisions

| Decision | Rationale |
|---|---|
| Name: `review-pass-run.md` | Consistent with `test-quality-campaign-run.md` (main-agent invocation template naming). |
| Doc-contract drift + contract-without-mechanism seeded as standing review instructions in the template | Both were the highest-yield finding classes in 20260912-05 (doc-contract drift alone blocked 3 of 8 rounds); reviewer skills do not produce them reliably unprompted; seeding costs one prompt block. |
| Round cap ~6 with operator escalation | 20260912-05 converged in 8; a cap prevents silent grinding, and late-round churn is mostly self-checkable classes. |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/review-pass-run.md` | New main-agent orchestration template: preconditions (WIP commit first), spawn contract (scope, read-only, context, prior blockers, VERDICT), standing review instructions (doc-contract drift, contract-without-mechanism), fix-round loop with round cap and fresh-subagent-per-round, campaign proposal accept/defer/reject handling, close sequence (write-back, handover, squash) |
| `docs/development/project_index.md` | One table row for the new prompt under Coding-Agent Workflow |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Prompt template exists, follows the prompt-layer rules (consumer of policy, no authoritative rules inlined) | offline read | pending |
| AC2 | Process steps match what 20260912-05 actually did (generalized, no session-specific narration) | offline read | pending |
| AC3 | project_index row added; no other docs claim to index prompts/ | offline grep | pending |

## Deferred items
(none yet)
