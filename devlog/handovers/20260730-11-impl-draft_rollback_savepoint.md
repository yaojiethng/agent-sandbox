# Agent Handover

**Date:** 2026-07-30
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Type:** Implementation — Draft rollback on patch failure
**Status:** Active

## Objective

`make draft` applies patches sequentially to a draft branch. If a mid-series patch fails, the branch is left in a partially-applied state. Add a local tag savepoint before patch application; on failure, `git reset --hard <savepoint>`.

## Design

From roadmap: "Local tags don't push by default — no remote pollution. On success, delete the tag."

Implementation in `scripts/workflows/draft.sh` or wherever patch application lives:
1. Before applying patches: `git tag draft-savepoint` (local only)
2. Apply patches one by one
3. On failure: `git reset --hard draft-savepoint; git tag -d draft-savepoint`; exit with error
4. On success: `git tag -d draft-savepoint`

## Scope

Single concern: savepoint tag before patch loop, rollback on failure, cleanup on success.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Local tag created before patch application |  |
| 2 | On patch failure, branch reset to savepoint |  |
| 3 | Tag deleted after successful application |  |
| 4 | Tag deleted after rollback |  |
| 5 | Tag never pushed (git push default excludes tags) |  |
