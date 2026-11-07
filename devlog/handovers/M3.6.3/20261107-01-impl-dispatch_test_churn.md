---
date: 2026-11-07
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - The dispatch tests lose their churn

## Objective

Remove the dispatch tests that duplicate a stronger case or restate the implementation, then narrow the source seams only those tests required.

## Scope

The dispatch library's tests and the exports they hold open: `tests/test_dispatch.sh`, `tests/dispatch/machine/classify.test.ts`, `tests/dispatch/machine/state.test.ts`, `tests/dispatch/seats/seating.test.ts`, and the dispatch modules under `src/libs/dispatch/`. This is test and API maintenance against M3.6.3, whose sub-milestone is already complete; it adds no routing behaviour and reopens no roadmap row. Out of scope: the worker and seat script cases, the mutation gate, and the table unit suite, which stay as the evidence for the remaining behaviour.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The shell suite no longer repeats the table grammar, runtime decision, argv shapes or `table check` that the unit suite holds | `grep -c '^run_test' tests/test_dispatch.sh` reports 33, and the removed names are absent | Agent [x] |
| The low-value unit cases are gone: the setter test that asserted its own content, the constructor-shape duplicate, the modulo formula and the direct candidate filter | `git diff -- tests/dispatch` shows the four cases removed | Agent [x] |
| The seams those tests alone held open are internal | `grep -n '^export' src/libs/dispatch/classify.ts src/libs/dispatch/state.ts src/libs/dispatch/seats.ts` no longer names `PATTERNS`, `nextUtcMidnight`, `emptyState`, `decodeState`, `save` or `seatCandidates` | Agent [x] |
| The suite is green | `bash scripts/run_tests.sh` reports 1443 passed, 0 failed | Agent [x] |
| The lint gates are clean | `bash scripts/lint.sh` reports clean across 22 gates | Agent [x] |
| The churn claim is re-derivable | `git log --all --name-only --pretty=format: -- 'tests/test_dispatch.sh'` counts 47 commits at the base revision | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The unit suite owns the table grammar, runtime decision, argv and `table check`; the shell file owns only the script seam | the shell cases called `cli.ts` directly, so they added a node process without adding a distinct subject | this handover |
| The 28 duplicate shell cases are deleted rather than rewritten | a second test of one behaviour is a second place to update, and the unit case is faster and closer to the function | this handover |
| The state file is read through `load`, the real seam, instead of `decodeState` | a direct decoder test holds an export open for no caller; the file contract is what the product uses | this handover |
| `nextUtcMidnight` is checked through `classify` | the public verdict carries the reset; the helper is an implementation detail | this handover |
| The formula and candidate-filter cases are deleted | one restated `i % m`, the other repeated the cooldown refusal the seat run already proves | this handover |
| The record lives under M3.6.3 | the dispatch library belongs to that sub-milestone, and a maintenance record does not need a new roadmap row | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `tests/test_dispatch.sh` is the tree's highest-churn test file: 47 commits, 27 of which also touch `src/`, and most of its first half repeats `table.test.ts` through the same `cli.ts` | mechanism | the duplicate suite made every table or argv edit a two-file lock-step change for no added evidence | fixed in this iteration |
| `state.test.ts` named a temporary-file property but asserted the saved JSON body, and another case rebuilt the expected empty state with the product constructor | tautology | neither case could fail for the property it named; both are removed and the file cases now assert literal state through `load` | fixed in this iteration |
| `seating.test.ts` asserted the modulo formula and the candidate filter directly | change-mirror | the formula case restated the implementation, and the filter case held `seatCandidates` exported for its own caller | fixed in this iteration |
| Six dispatch exports had no reader outside their module and the tests | dead surface | the tests held the module API wider than the product needs; the exports are internal now | fixed in this iteration |

## Completed

| File | Change |
|---|---|
| `tests/test_dispatch.sh` | 28 duplicate table, runtime, plan and check cases removed; the header names the unit suite as their owner |
| `tests/dispatch/machine/classify.test.ts` | the reset is asserted through `classify`, with the midnight helper no longer imported |
| `tests/dispatch/machine/state.test.ts` | literal state and file reads through `load`; the setter-content and constructor-shape cases removed |
| `tests/dispatch/seats/seating.test.ts` | the modulo formula and direct candidate-filter cases removed |
| `src/libs/dispatch/classify.ts` | `PATTERNS` and `nextUtcMidnight` are internal |
| `src/libs/dispatch/state.ts` | `emptyState`, `decodeState` and `save` are internal |
| `src/libs/dispatch/seats.ts` | `seatCandidates` is internal |
| `devlog/handovers/M3.6.3/20261107-01-impl-dispatch_test_churn.md` | this handover |
