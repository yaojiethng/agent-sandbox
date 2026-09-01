# Agent Handover

**Date:** 2026-06-09
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation
**Status:** Closed

## Objective

Implement M2.7 Track A item 6 — make stop redesign (label-based filtering + prune support).

## Scope

1. **`scripts/stop.sh`** — Rewrite from `com.docker.compose.project` label to `agent-sandbox.project-name` + `agent-sandbox.sandbox-dir` labels. Add `--run-id` flag for run-specific stop. Add `--prune` flag for post-stop orphan cleanup with `PRUNE_AGE_DAYS=3` threshold.
2. **`scripts/templates/Makefile.template`** — Add `RUN_ID_FLAG` and `PRUNE_FLAG` variables; forward `RUN_ID` and `PRUNE` to `stop` target.
3. **`scripts/start_agent.sh`** — Update pre-stop check from `com.docker.compose.project` label to `agent-sandbox.project-name` + `agent-sandbox.sandbox-dir` labels.
4. **`devlog/roadmap.md`** — Item 6 marked `[x]`.

## Completed this session

| File | Change |
|---|---|
| `scripts/stop.sh` | Full rewrite: label-based filtering, `--run-id`, `--prune` |
| `scripts/templates/Makefile.template` | Added `RUN_ID_FLAG`, `PRUNE_FLAG`; forwarded in `stop` target |
| `scripts/start_agent.sh` | Pre-stop label check updated to our own label schema |
| `devlog/roadmap.md` | Item 6 marked `[x]` |
