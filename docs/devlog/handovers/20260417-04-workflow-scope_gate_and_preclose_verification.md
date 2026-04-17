# Agent Handover

**Session date:** 2026-04-17
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Workflow
**Status:** Closed

## Objective

Strengthen two workflow gates: the scope confirmation gate (Step 1b) to require an explicit release signal before any output is produced, and a new pre-close verification gate (Step 7b) to require operator sign-off on implementation state before session close.

## Scope

Policy changes across two documents:

- `docs/operations/iteration_policy.md` — Step 1b exit condition; new Step 7b row in step table; Step 7b added to both diagrams
- `docs/operations/handover_policy.md` — scope confirmation exit condition and step-by-step release rule; new `At pre-close verification (Step 7b)` section; descriptive filename naming rule

## Carried forward

None.

## Acceptance criteria

| # | Check | Result |
|---|-------|--------|
| AC-1 | `iteration_policy.md` Step 1b exit condition requires explicit release signal, not just scope acknowledgement | ✅ Accepted |
| AC-2 | `iteration_policy.md` Step 1b action states release applies to immediately following step only | ✅ Accepted |
| AC-3 | `iteration_policy.md` Step 7b row exists in step table with entry condition, action, and exit condition | ✅ Accepted |
| AC-4 | `iteration_policy.md` Step 7b appears in both the top-level diagram and the session type diagram | ✅ Accepted |
| AC-5 | `handover_policy.md` scope confirmation exit condition names "hold changes" as a non-releasing message | ✅ Accepted |
| AC-6 | `handover_policy.md` step-by-step release rule states a single release does not authorise the full session | ✅ Accepted |
| AC-7 | `handover_policy.md` `At pre-close verification (Step 7b)` section exists with four-part summary format and three operator response modes | ✅ Accepted |
| AC-8 | `handover_policy.md` filename description rule requires concrete subject, includes bad/good examples, and updates the example filename | ✅ Accepted |

## Hot files

| File | Why in scope |
|------|--------------|
| [`docs/operations/iteration_policy.md`](../../../docs/operations/iteration_policy.md) | Step 1b exit condition; Step 7b added to diagrams and step table |
| [`docs/operations/handover_policy.md`](../../../docs/operations/handover_policy.md) | Scope confirmation rules; pre-close verification section; filename naming rule |

## Decisions made this session

| Decision | Rationale | Where recorded |
|----------|-----------|----------------|
| Release signal required to exit Step 1b, not scope acknowledgement alone | Agent was interpreting any confirmatory message as permission to advance; "go ahead and make a handover" was treated as a global session release | `iteration_policy.md`, `handover_policy.md` |
| Release is step-scoped, not session-scoped | A single release authorising one step was being used to run the entire session; step-by-step rule prevents this | `iteration_policy.md`, `handover_policy.md` |
| Step 7b inserted as explicit pre-close gate | No gate existed between implementation complete and session close; agent was closing sessions without surfacing AC verification status or manual check recommendations | `iteration_policy.md`, `handover_policy.md` |
| Filename description rule requires concrete subject with bad/good examples | Agent was defaulting to generic labels (`policy_audit`, `m2_3_impl`) that don't distinguish sessions of the same type when scanning a file list | `handover_policy.md` |

## Completed this session

| File | Change |
|------|--------|
| `docs/operations/iteration_policy.md` | Step 1b exit condition strengthened; step-by-step release rule added; Step 7b added to both diagrams and step table; Step 7 exit condition no longer requires operator confirmation (moved to 7b) |
| `docs/operations/handover_policy.md` | Scope confirmation exit condition and rules block replaced; step-by-step release rule added; new `At pre-close verification (Step 7b)` section; filename description row updated with concrete guidance and bad/good examples |

## Deferred items

None.

## Next session

**Next sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline (continuing — Change 2)

Context handover: [`20260417-02-impl-worktree_namespaced_checkpoints.md`](20260417-02-impl-worktree_namespaced_checkpoints.md)

Change 2 scope is fully specified — no blocking design questions. Read the context handover before scoping. Proceed to implementation after confirming scope at Step 1b.

Watch-outs:
- `SESSION_NAME` must be exported to docker-compose for container injection — verify not already partially implemented before starting
- Change 2 context frozen in `20260412-02-m2_3_onhold.md`; cross-check against current spec in `design_git_workflow_improvements.md` before writing code
- Trigger B is not pending — milestone is mid-flight
- `iteration_policy.md` and `handover_policy.md` were both updated this session — next impl session should upload the updated versions, not stale copies
