# Handover - The model-refresh implementation changelog and the task-queue compat suite

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Iteration loops and workflow
**Type:** Implementation
**Status:** Closed

> Backfilled handover. The iteration ran as worker unit `extB` in the first fan-out wave and landed without a record; this file is written during the history rescope from the session log and the worker's brief and result. Log span: entries 621, 643 to 653, 667, and 674 to 703 of the session log (`2026-10-01T04-35-20-741Z`, main session file). Claims carry their entry numbers.

## Objective

Record the model-refresh extension's implementation history in a standalone changelog, and prove the task-queue extension loads and runs under pi 0.99.2, the version the pin was bumped to.

## Why

Unit B of the operator's three-unit dispatch (entry 621): the model-merge extension patches an existing defect and new APIs have shipped, so the extension needs its own changelog and a check of whether the `mergeModels` workaround can now be dropped; and the task-queue extension needs a confirmation that it works under the new version.

## Decisions

- `mergeModels` stays unreachable at 0.99.2, so the extension's own merge logic cannot be deleted and no simplification happens. Measured, not assumed: the package `exports` map has four subpaths (`.` , `./rpc-entry`, `./client`, `./experimental/plugin`) and `mergeModels` is absent from both the pi-coding-agent package entry and the pi-ai entry in both 0.87.1 and 0.99.2 (entries 649-653). The worker brief carried this as established context (entry 667).
- The task-queue confirmation takes the form of a compat test, not a manual run: the test loads the extension through jiti against both the installed pi and the 0.99.2 probe copy and asserts the module graph resolves and the factory runs (entry 667).

## Changes

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/CHANGELOG.md` | new, seeded from the extension's git history, with a 2026-10-02 entry recording the `mergeModels` measurement |
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md` | assumption row A12 falsification note updated against 0.99.2 |
| `tests/extensions/pi/task-queue/compat-0992.test.ts` | new, loads the task-queue extension against both pi versions |
| `tests/test_taskq.sh` | registers the new test file |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The changelog exists and records the `mergeModels` measurement | commit `2ac965a`, 21 insertions | pass |
| 2 | The task-queue extension loads under 0.99.2 | entries 689-690: task-queue suite 270 passed, model-refresh 157 passed | pass |
| 3 | Full suite green | entries 702, 706: suite 1012 of 1012, lint clean | pass |

## Findings

- The test-registration guard caught the new compat test as unregistered in `tests/test_taskq.sh` (entries 692-698). The registration is part of this iteration's diff.
- The primary's `.brief.md` inside the worker worktree tripped markdownlint in the `docC` sibling worktree; the failure was the brief, not worker work (entries 678-680).

## Deferred

- Revisiting `mergeModels` simplification if a future pi version exports it from the package entry.
