# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 — Session Persistence
**Type:** Housekeeping
**Status:** Closed

## Objective

Fix lost executable bits in the git index: every shebang-carrying script (101 `*.sh`, plus `test/stubs/docker`) is stored as `100644` although the working tree carries them executable. Direct-exec call sites (`start_agent.sh` → `run_agent.sh`; tests PATH-shadowing the docker stub; `exec bash` dispatch is unaffected but direct `./script` invocation is not) only work because disk modes diverge from the index — a fresh clone yields a broken tree.

## Scope

Index mode flip to `100755` for shebang-carrying tracked files only. No content change; docs and devlog excluded by definition. Found during the campaign-ingest series validation (scratch-clone suite failures rc=126); flagged in handover `20260823-04`.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | No tracked file with a shebang remains `100644` | `git ls-files -s` sweep: zero hits | accepted |
| AC2 | Fresh-clone equivalence: stub and direct-exec paths usable without manual chmod | Scratch clone + suite green (validated during ingest) | accepted |
| AC3 | Suite still green in place | `scripts/run_tests.sh`: 587/0 failed | accepted |

## Deferred items

None.

## What's Next

M2.6 continues per roadmap.
