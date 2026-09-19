# 20260919-14-workflow-agents_md_hardening_handover_gate

- **Handover:** 20260919-14
- **Type:** Workflow
- **Milestone:** M2.6 - Session Persistence (governance)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Hardens the project-root `AGENTS.md` so a handover-less green iteration cannot
be mistaken for a close. Five iterations ran after handover 20260919-08 without
creating a handover (recorded in GOTCHAS 2026-09-19); the guard makes the
Step-1 trigger explicit and codifies the close requirement.

## Scope

- Amend the `## Iteration Lifecycle` section of the project-root `AGENTS.md` to
  state that the operator signalling a new iteration triggers Step 1 (Open
  handover) before any output, and that a green suite plus typed commits do not
  close an iteration without the handover carrying Status Closed.
- Record the gotcha as routed (already filed in GOTCHAS 2026-09-19).

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | The phrase "new iteration" / "next iteration" (or a re-scoping directive) is named as a Step-1 (Open handover) trigger that precedes any output |
| AC2 | The text states that a green suite and correctly typed commits do not close an iteration; the close commit must carry the handover with Status Closed |
| AC3 | The amendment follows documentation-policy prose rules (one paragraph per physical line) |
| AC4 | No behavioural rule change to other policies; this is an AGENTS.md text guard only |