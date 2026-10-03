# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Implementation
**Status:** Closed

## Objective

Build the two machine gates the task-queue review-hardening row asks for, so that a green suite is evidence rather than an absence of evidence: a mutation tier that replays deliberate breaks of every op and fails unless the suite turns red, and a named invariant report whose failure names the invariant.

## Scope

The conformance suite `tests/extensions/pi/task-queue/` and its harness wrapper `tests/test_taskq.sh`. No production code changes: the extension, its transition table, and its tool surface are untouched.

Out of scope: the pool join (`join_all`, roadmap row 91) and the adversarial novel-bug review, which stays one focused reviewer.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | A catalog of deliberate breaks replays in a throwaway mirror, and the gate fails unless the owning suite turns red against every row | `node --test tests/extensions/pi/task-queue/mutation.test.ts`; 22 rows, 22 proven | Met |
| 2 | A row whose mutant does not load, or whose anchor text no longer matches, is a loud failure rather than a pass | the catalog's `unloadable` and `no-op` verdicts both fail the gate | Met |
| 3 | The invariant report holds one named case per invariant and prints an index whose red line names the invariant | `node --test tests/extensions/pi/task-queue/invariants.test.ts`; 22 cases across 19 invariants | Met |
| 4 | The lifecycle cases are derived from `transitions.ts`, so no phase enumeration is written in the report | the R12 case asserts the derived set equals `TASK_PHASES`; `stepInto` reads the row | Met |
| 5 | The J4 case is phrased as one held join-unit (a single join or one pool batch) | the report's J4 statement and the `it` name | Met |
| 6 | The tool surface is unchanged: nine tools, no additions, no removals | the S3 case asserts the registered names equal the surface | Met |
| 7 | The whole node suite stays green with both gates registered | `node --test tests/extensions/pi/task-queue/*.test.ts` (247/247, from 202/202) | Met |
| 8 | The harness suite stays green | `bash scripts/run_tests.sh` (1004/1004 across 67 files) | Met |
| 9 | Lint is clean | `bash scripts/lint.sh` | Met |
| 10 | No mutation of the extension leaves the working tree modified | the runner copies into a temp mirror; `git status` shows only the new test files | Met |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/extensions/pi/task-queue/mutation.test.ts`](../../tests/extensions/pi/task-queue/mutation.test.ts) | the gate: one case per catalog row |
| [`tests/extensions/pi/task-queue/mutation/catalog.ts`](../../tests/extensions/pi/task-queue/mutation/catalog.ts) | the catalog: 22 rows, each with its invariant, its anchor, and the suites that must catch it |
| [`tests/extensions/pi/task-queue/mutation/runner.ts`](../../tests/extensions/pi/task-queue/mutation/runner.ts) | the replay engine: temp mirror, anchor check, load probe, child suite run |
| [`tests/extensions/pi/task-queue/invariants.test.ts`](../../tests/extensions/pi/task-queue/invariants.test.ts) | the invariant cases over the wired surface |
| [`tests/extensions/pi/task-queue/invariants.ts`](../../tests/extensions/pi/task-queue/invariants.ts) | the case catalog and the index renderer |
| [`tests/test_taskq.sh`](../../tests/test_taskq.sh) | registers the two new suites and states the budget the mutation tier needs |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A mutation row names the suites that own the invariant, not the whole suite | the gate replays the catalog on every run; the whole suite per row is minutes of wall clock for no extra evidence | this handover |
| The gate replays into a temp mirror, never the working tree | a replayed row that crashed mid-edit would leave the repository with a broken extension, and the agent's own rule is that verification runs in `/tmp` | this handover |
| A mutant that does not load is rejected rather than counted as proven | a syntax error turns every suite red for a reason that says nothing about the invariant | this handover |
| The invariant report is a catalog plus a renderer, not a second conformance suite | the depth already exists in the per-invariant suites; the report's job is to name the invariant a red line belongs to | this handover |
| The report's lifecycle cases are derived from the transition table | a written phase list is a second list to drift, and the pool join merges into this report only if the table stays its source | this handover |
| The three surviving rows are answered with three new invariant cases, not by weakening the rows | a survivor is a finding about the suite, and the finding was a real hole: nothing asserted the tool writes its own bring-back intent, that the state write is a rename, or that the close audit refuses a pending entry | this handover |
| The mutation tier runs at concurrency 2 | at 4 it starved the bash suite running beside it: `test_runner_contract.sh` missed its 10 s deadline under load. At 2 the wall time is the same and the harness is green | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| A nested `node --test` inherits `NODE_TEST_CONTEXT` and exits 0 without running anything, so the first gate run reported all 22 rows as survivors in 10 s | bug | Fixed: the runner strips the marker from the child environment. Recorded in [`AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) under `## Node` |
| Three catalog rows survived: nothing asserted the tool writes its own bring-back intent, that the state write is a rename rather than an in-place rewrite, or that the close audit refuses a pending entry | bug | Fixed: the I7, I11, and I1 cases now hold each of them, and the rows are proven |
| The `node --test` tier adds about 80 s of child processes to a suite that runs 67 files at 8-way parallelism | scope change | The mutation tier runs at concurrency 2, and `tests/test_taskq.sh` declares a 420 s budget instead of 180 |

## Completed

| File | What changed and why |
|---|---|
| `tests/extensions/pi/task-queue/mutation.test.ts` (new) | The gate. One case per row, rendered as a table after the run. |
| `tests/extensions/pi/task-queue/mutation/catalog.ts` (new) | The 22-row catalog: a dropped gate, a reordered effect, a weakened identity, and a removed heartbeat, each with the invariant it attacks and the suites that must notice. |
| `tests/extensions/pi/task-queue/mutation/runner.ts` (new) | The replay engine: a temp mirror of the extension and the suite, a unique-anchor check, a jiti load probe, and a child suite run. |
| `tests/extensions/pi/task-queue/invariants.test.ts` (new) | The invariant cases over the real tool surface, read from `taskq_status` snapshots and the transition table. Includes the three cases that close the survivors. |
| `tests/extensions/pi/task-queue/invariants.ts` (new) | The case catalog and the index renderer. `TOOL_OF_ACTION` keys the tool map by the action union, so an action the table gains is a type error here. |
| `tests/test_taskq.sh` | Registers the two new suites and raises the declared budget to 420 s. |
| `devlog/AGENT_FEEDBACK.md` | The `NODE_TEST_CONTEXT` entry under a new `## Node` section. |
| `devlog/roadmap.md` | The review-hardening row closed. |

## Deferred items

None.

## What's Next

The pool join (`join_all`, roadmap row 91). It reads this report: the J4 case is already phrased for a join-unit, and the lifecycle cases are derived, so a pool batch is a new case rather than a rewrite.

**Conclusions from this iteration:** a green suite is only evidence when a broken suite is red, and the cheapest way to find the lines that are unpinned is to break them on purpose -- the first catalog run found three real holes the 202-test suite did not. The gate's own first run was wrong in the direction that hides everything (all 22 rows "survived" because the child suites never ran), so a replay harness must prove the mutant was exercised, not only that the harness exited zero. Under `node --test`, a test that spawns test runners is a second-order harness and needs the recursion marker stripped.
