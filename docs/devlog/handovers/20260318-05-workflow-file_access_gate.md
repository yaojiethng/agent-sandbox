# Agent Handover

**Session date:** 2026-03-18
**Milestone:** Workflow Policy Refinement — pre-M2.1
**Session type:** Workflow

## Objective
Audit and fix the workflow lapse where claude.ai chat produces outputs derived from repository files not uploaded to the conversation.

## Scope
Targeted fixes to `agents.md` and `agent_context_brief.md`. No implementation changes. No roadmap changes.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`agents.md`](agents.md) | Primary fix target: session definition, file access gate, output mechanism |
| [`agent_context_brief.md`](agent_context_brief.md) | Supporting fix: References block consequence, Read Discipline chat branch |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Define "session" explicitly as a single conversation | "Session" was used for both the memory boundary and the workflow unit; file access constraint depends on the former | `agents.md` — What a session is |
| Add file access gate as output-production prohibition | Prior framing was a pre-condition on session start, not a gate on output production; agent could comply and still proceed with reconstructed content | `agents.md` — File access gate |
| Add "missing file is a blocking condition" to References block | "Do not begin the session without it" was passive; consequence needed to be explicit | `agent_context_brief.md` — References |
| Add request-before-proceeding sentence to Read Discipline chat branch | Framing implied agent might already know something about a file; chat context has no such knowledge | `agent_context_brief.md` — Read Discipline |
| Remove explicit review request pattern from Output mechanism | Confirm step adds friction when operator is driving; operator reviews and requests amendments if needed; workflow invariant (operator commits) already enforces review | `agents.md` — Output mechanism |

## Completed this session

| File | Change |
|---|---|
| `agents.md` | Added `## What a session is` and `## File access gate` sections; revised Output mechanism to remove confirm-pattern and state artifacts are ready on production |
| `agent_context_brief.md` | References block: sharpened blocking condition language; Read Discipline: added one sentence to chat branch |

## Deferred items

None.

## Next session

**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

Resume M2.1 implementation from `roadmap.md`. All workflow policy work is complete.
