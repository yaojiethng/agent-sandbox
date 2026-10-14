---
date: 2026-10-14
milestone: M3.4 - Environment and Argument Resolution
type: Implementation
status: Open
---

# Handover - Implementation: U2 prelude split

## Objective

Finish the U2 split from the onion env-resolution design: the prelude stops resolving identity and consumes the resolved triple, leaving a single env load there.

## Scope

The working tree already contains the partial rename (tests point at `resolve_and_init`; census tightened to one load site). Remaining: rename the function, move identity resolution to the three entry scripts, and retarget the identity tests accordingly.

## Hot files

| File | Why in scope |
|---|---|
| `src/libs/session_env.sh` | function rename and identity-resolution removal |
| `scripts/start_agent.sh` | resolve before the prelude |
| `scripts/run_agent.sh` | resolve before the prelude |
| `scripts/resume_agent.sh` | resolve before the prelude |
| `tests/test_session_env.sh` | identity assertions against the new entry |
| `tests/test_env_read_discipline.sh` | pinned census target |

## Decisions

None yet.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Partial U2 rename left the tree non-green | scope change | this iteration |

## Completed

None yet.
