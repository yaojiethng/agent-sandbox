# Agent Handover

**Session date:** 2026-06-09
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Implement M2.7 Track A item 3 — Container naming with RUN_ID. Replace `SESSION_TS` with `RUN_ID` in container name format.

## Recovery checks

| Check | Result |
|---|---|
| Roadmap reflects prior handover state | ✅ Items 1 and 2 marked `[x]` in roadmap |
| Trigger B pending | ✅ None pending |

## Scope

**In scope — this session:**

1. **`scripts/start_agent.sh`** — Change `SANDBOX_CONTAINER_NAME` from `sandbox-<project>-<SESSION_TS>` to `sandbox-<project>-<RUN_ID>`. Change `AGENT_CONTAINER_NAME` from `<provider>-<project>-<SESSION_TS>` to `<provider>-<project>-<RUN_ID>`.
2. **`src/build/compose.sh`** — Update the doc comment that says `(sandbox-<project>-<timestamp>)` / `(<provider>-<project>-<timestamp>)`.

That's it — `{{RUN_ID}}` substitution is already in place from item 1. Container names are derived in `start_agent.sh` and substituted into compose via `{{SANDBOX_CONTAINER_NAME}}` / `{{AGENT_CONTAINER_NAME}}`.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| A | Container names use RUN_ID instead of SESSION_TS | RUN_ID is shorter (6 chars vs 15), encodes identity factors (sandbox instance + timestamp), and is unique per session |
| B | SESSION_TS retained in container labels for human readability | `docker inspect` and logs still show the timestamp |

## Completed this session

| File | Change |
|---|---|
| `scripts/start_agent.sh` | `SANDBOX_CONTAINER_NAME` and `AGENT_CONTAINER_NAME` use `$RUN_ID` instead of `$SESSION_TS` |
| `src/build/compose.sh` | Doc comment updated to `run_id` instead of `timestamp` |

## Next session

Track A item 4 — Docker labels on containers.
