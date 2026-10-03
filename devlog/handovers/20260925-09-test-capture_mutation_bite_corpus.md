# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Capture the read-through's 49 throwaway mutation bite scripts into the repository as a lint-clean, indexed draft corpus, note it on the M3.1 mutation-suite row, and repair the two suite consumers the capture broke.

## Scope

The executable-record half of the read-through close: the 49 `/tmp/bite*.sh` scripts move to `tests/mutations/`, gain a README index, and gain a sentence on the M3.1 mutation-suite row. The capture also put the suite red in two places - a repo-wide hint guard and a lint-file deadline margin - so the unit owns those consumer fixes as well: the guard's exclusion list and a per-file deadline declaration in the runner. No production code changes.

## Carried forward

None.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The 49 scripts are captured and no mutation literal differs | the parser's output before and after, per script | Agent [x] |
| Every captured script passes `shellcheck -S warning` | a per-file shellcheck run | Agent [x] |
| The corpus is not discovered as a test | the runner's `tests/test_*.sh` glob and `check_test_liveness.sh` | Agent [x] |
| The README indexes every script with its subject and count | the index table | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |
| The suite is unchanged | `bash scripts/run_tests.sh` | Agent [x] - green after the two consumer fixes |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/mutations/README.md`](../../tests/mutations/README.md) | new: the corpus record and index |
| `tests/mutations/*.sh` | new: the 49 captured scripts |
| [`devlog/roadmap.md`](../roadmap.md) | the M3.1 mutation-suite row gains the capture note |
| [`scripts/run_tests.sh`](../../scripts/run_tests.sh) | the per-file `# TEST_DEADLINE` declaration |
| `tests/test_lint_umbrella.sh` | declares its own 10s deadline |
| `tests/test_runner_selftest.sh` | a case pins the declaration, and the file declares its own deadline |
| `tests/test_dispatch.sh` | the confirm-hint guard excludes `tests/mutations/` |
| [`docs/development/test_harness_mechanism.md`](../../docs/development/test_harness_mechanism.md) | records the declaration and the selftest case |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The corpus lives under `tests/mutations/` as `.sh` files | the existing shellcheck gate already scans `tests/` recursively, so the corpus is linted with no new machinery | this handover and the README |
| The mutation literals stay verbatim; only lint findings are fixed, with targeted suppressions where a real fix would alter a triple | the corpus is evidence; a changed literal would invalidate the parser's `n` and live counts | the README's Call forms and Known-bad mutations sections |
| The five scripts that carry a subject or harness copy are classed `method`, not `sweep` | they do not run a mutation sweep | the README index |
| The runner reads a per-file `# TEST_DEADLINE: <seconds>` declaration from a file's first ten lines | two harness files legitimately run above the observed-max 5s default under parallel dispatch; a per-file declaration keeps the default tight instead of raising it for every file | this handover and `test_harness_mechanism.md` |
| The confirm-hint guard gains `tests/mutations/` as an exclusion rather than narrowing its scan | the corpus quotes the drift it documents, exactly as `devlog/handovers/` does; narrowing the guard's scope is the separate decision row 77 owns | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The repo-wide guard in `tests/test_dispatch.sh` (`test_confirm_hints_never_name_target`) greps every `*.sh` and `*.md` for `make confirm TARGET=`, which matches the D40 mutation literal in `tests/mutations/bite_draft.sh`. The guard already excludes `devlog/handovers/` for the same reason but not `tests/mutations/`. | contradiction | resolved here: the guard excludes `tests/mutations/`. Row 77 owns the wider question of the guard's scope. |
| `tests/test_lint_umbrella.sh` exceeds its 5s runner deadline with the 49 extra linted files. Alone it runs 3.4s without the corpus and 4.0s with it, and the default 8-way parallel suite run pushes it over. | blocker | resolved here: the runner reads a per-file `# TEST_DEADLINE` declaration, the file declares 10 seconds, and the selftest pins the declaration in both directions. |

## Completed

| File | Change |
|---|---|
| `tests/mutations/*.sh` | new: the 49 captured scripts, lint-clean, mutation literals unchanged |
| `tests/mutations/README.md` | new: status, discovery rule, 49-row index, call forms, naming problem, known-bad mutations, cost, register link, capture state |
| `devlog/roadmap.md` | M3.1 mutation-suite row names the `tests/mutations/` capture as the executable record of 318 mutations |
| `scripts/run_tests.sh` | the worker reads a `# TEST_DEADLINE: <seconds>` declaration from the file's first ten lines and uses it for that file's deadline |
| `tests/test_lint_umbrella.sh` | declares `# TEST_DEADLINE: 10`, because it runs the real umbrella gate repeatedly |
| `tests/test_runner_selftest.sh` | declares `# TEST_DEADLINE: 10` and adds case 15: a declaration shorter than the global deadline is the one named on expiry, and one longer than it lets a slow file pass |
| `tests/test_dispatch.sh` | the confirm-hint guard excludes `tests/mutations/` alongside `devlog/handovers/` |
| `docs/development/test_harness_mechanism.md` | the deadline paragraph, the gates paragraph, and the selftest list record the declaration |

## Deferred items

None. Both consumer fixes belong to the capture's own blast radius and landed with it.

## What's Next

The next iteration continues M3.1's rows, led by the rectification campaign. The mutation-suite row now owns the captured corpus as the raw material for its data file; the gate-placement decision still waits on the runtime measurement.

Watch-outs (two): the corpus is a draft capture, so a replay must read the register's known-bad mutations first; and the corpus's series labels must be mapped to `bite <row>.<n>` before any generated data file can key on them.

Read at iteration start: this handover, the M3.1 mutation-suite row, and the README.

**Conclusions from this iteration:** the read-through's executable mutation record now survives outside `/tmp`. The capture is not inert inside the repository: it tripped a repo-wide hint guard and a lint-deadline margin, and both fixes are folded in here, because a capture that leaves the suite red is not a delivery. The runner gained a per-file deadline declaration on the way.
