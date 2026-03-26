# Agent Handover

**Session date:** 2026-03-26
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Workflow

## Objective

Audit and fix unreliable session open housekeeping — handover creation and roadmap compaction were not firing consistently at session start. Define an operator convention and policy gates to make both mandatory.

## Scope

- `agents (claude.ai).md` — session open convention (operator template, agent fallback)
- `handover_policy.md` — compaction gate at Step 1

## Acceptance criteria

- [ ] Operator can paste a single session open message and the agent runs Step 1 housekeeping before accepting any task — verified by opening a new session with the convention message and observing the agent compact and create the handover before asking for task input.
- [ ] If operator sends a task prompt with no session open message, agent pauses and runs Step 1 before acting — verified by opening a session with a bare task prompt and observing the pause.

## Hot files

| File | Why in scope |
|---|---|
| [`agents (claude.ai).md`](agents%20(claude.ai).md) | Session open convention added; Session start section rewritten |
| [`handover_policy.md`](handover_policy.md) | Compaction gate added to At session open (Step 1) |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Session open message is operator-sent, not agent-prompted | Separates session initialisation from task prompt; agent cannot enforce ordering if both arrive simultaneously | `agents (claude.ai).md` |
| Opening message includes uploaded files list (required) and focus (optional) | Files list lets agent check required reading immediately; focus narrows Hot files scope without overriding roadmap | `agents (claude.ai).md` |
| Agent fallback: if task prompt arrives with no session open signal, pause and run Step 1 before acting | Operator may forget convention; agent must not silently skip housekeeping | `agents (claude.ai).md` |
| Compaction is a gate: Hot files must not be populated until compaction is confirmed done or declared not applicable | Compaction was being skipped as silent preamble; making it a prerequisite to Hot files population enforces it structurally | `handover_policy.md` |

## Completed this session

| File | Change |
|---|---|
| `agents (claude.ai).md` | New Session open convention section; Session start rewritten as numbered sequence |
| `handover_policy.md` | Compaction check added as second bullet in At session open (Step 1), with Hot files gate |

## Deferred items

None.

## Next session

**M2.2 — Reasoning Layer Modularisation** (continuing from `20260326-01-impl`).

Trigger B has not run — M2.2 is still active.

Priority order per prior handover:
1. Investigate why `docker-compose.yml` in `SANDBOX_DIR` still contains `${...}` placeholders. Upload `scripts/start_agent.sh` and `scripts/onboard.sh` to diagnose.
2. Implement `scripts/stop.sh` using Option B2 (compose project filter) once root cause is understood.
3. If stop is resolved and all criteria met: run Trigger B for M2.2.

**Watch-out items:**
1. `docker-compose.yml` placeholder issue may mean the file is regenerated each run — Option B2 for stop is the right path regardless.
2. Trigger B cannot fire until `make stop` criterion is resolved or explicitly dropped from M2.2 scope.
3. Architecture docs are current as of `20260326-01-impl` — no further doc updates needed before Trigger B.
