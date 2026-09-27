# Handover 20260926-10 -- Implementation: runner subset selection (row 88)

**Status:** Closed
**Type:** Implementation
**Milestone:** M3.1 - Backpressure
**Branches:** `feat/M_3_1-backpressure`

## Scope

Land roadmap row 88: `scripts/run_tests.sh` accepts file or directory arguments and a documented `TEST_FILES` environment variable; `--help` works; the registration liveness gate stops being dropped by a discovery override and moves behind an explicit self-test flag. Run under the `/auto` protocol: the plan was released before dispatch, one unit, one fresh subagent, primary verification, one commit.

Decisions made (confirmed against the tree, stated in the plan and released):

| Decision | Choice |
|---|---|
| Selector precedence | positional args > `TEST_FILES` env var > discovery |
| Gate under subset runs | the gate always scans the real suite directory; a subset run does not drop the whole-suite check |
| Self-test bypass | explicit `RUN_TESTS_SELFTEST` flag; it also suppresses the `MUTATION=1` tier |
| `RUN_TESTS_DIR` | stays as the discovery override seam (back-compat); it no longer changes what the gate scans |
| Heavy harness file | `tests/test_runner_contract.sh` declares `# TEST_DEADLINE: 10` rather than raising the runner default |

## Carried forward

None.

---

[CORRECTION -- 2026-09-27: section added with the canonical `None.` marker; the record was closed without it. Flagged in handover `20260927-01`.]

---

## Acceptance criteria

| # | Criterion | Checked by | Status |
|---|---|---|---|
| 1 | `bash scripts/run_tests.sh tests/test_env.sh` runs exactly that file | aggregate `across 1 files` | Accepted -- 12 tests across 1 files |
| 2 | `bash scripts/run_tests.sh tests/` runs the directory's files | aggregate `across 66 files` | Accepted -- 997 across 66 files |
| 3 | `TEST_FILES` selects the named files | aggregate `across 2 files` | Accepted -- 25 across 2 files (real names: `test_env.sh` `test_common_lib.sh`) |
| 4 | `--help` prints usage and exits 0 | rc 0, usage text | Accepted -- rc 0; unknown option names itself and adds the `--help` hint |
| 5 | Subset selection does not drop the whole-suite gate; only `RUN_TESTS_SELFTEST=1` skips it | gate-stub marker | Accepted -- marker present under selection, absent under the flag, `NOTE:` line emitted |
| 6 | Plain run unchanged | rc 0, counts, gate on | Accepted -- 997 tests across 66 files, 997 passed, 0 failed |
| 7 | Suite green, lint clean | `run_tests.sh`, `lint.sh` | Accepted -- 997/0; 3 gates, 0 findings |
| 8 | Mechanism doc updated; row 88 write-back and handover land with the commit | read the files | Accepted -- selector and gate contract in the doc; zero stale `RUN_TESTS_DIR`-bypass claims |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| The subagent raised the runner's `TEST_TIMEOUT` default from 5 to 10 to absorb the always-on gate cost in `tests/test_runner_contract.sh` (honest runtime 4.8s, spiked past the 5s deadline under parallel dispatch, observed twice). The default is M3.1 backpressure documented in three places; the row does not own it. The primary reverted to 5 and gave the contract file the designed per-file `# TEST_DEADLINE: 10` declaration instead | steering | current iteration -- corrected by the primary before landing | Triaged to: resolved in-tree (runner default 5, contract file declares 10); no AGENT_FEEDBACK entry needed, the declaration mechanism is the designed answer |
| The brief's AC3 command named `tests/test_common.sh`, which does not exist in the tree (the file is `test_common_lib.sh`). The subagent rejected the stale name with the new `ERROR: no such test file` path and verified the selection with the real files | brief error (`[A]` proposed) | current iteration -- corrected at verification, AC3 re-run with the real names | Triaged to: recorded here; AC3's check command uses the real file names |
| AC5's fixture case sets `RUN_TESTS_DIR` alongside a file argument to pin "the discovery override never redirects the gate" (the marker is scan-sensitive) | steering | current iteration -- in-tree, part of the gate-attribution case | Triaged to: in-tree (selftest case 19 in the file header) |

## Completed

| File | Change |
|---|---|
| `scripts/run_tests.sh` | selectors (args > `TEST_FILES` > discovery) via `select_files`, `-h`/`--help` usage, gate always scans `$REAL_TESTS_DIR` with `RUN_TESTS_SELFTEST` bypass, `MUTATION=1` suppression on the flag |
| `tests/test_runner_selftest.sh` | `RUN_TESTS_SELFTEST=1` on every runner invocation; six new cases (file arg, dir arg, `TEST_FILES`, help/unknown-option, gate attribution, args override env) |
| `tests/test_runner_contract.sh` | `# TEST_DEADLINE: 10` header (consequential one-line correction, recorded in Findings) |
| `docs/development/test_harness_mechanism.md` | selector precedence, always-on gate contract, `RUN_TESTS_SELFTEST` named in gate and selftest sections |
| `devlog/roadmap.md` row 88 | write-back: checked, settled, `/auto` run, handover named |
| this handover | written at close |

## Hot files

- `scripts/run_tests.sh`
- `tests/test_runner_selftest.sh`
- `tests/test_runner_contract.sh`
- `docs/development/test_harness_mechanism.md`

## Deferred items

None.

---

[CORRECTION -- 2026-09-27: section added with the canonical `None.` marker; the record was closed without it. Flagged in handover `20260927-01`.]

---

## What's Next

M3.1 - Backpressure. Roadmap maintenance: current, mid-milestone; rows 85 (compact the read-through record) and 88 (this, now closed) were the named open work -- row 85 remains. The mutation tier (row 87) is live: 62 open survivor rows in `tests/mutations/runs/20260926-184023-mutation_run.jsonl` await collect-then-process disposition; the M4 frequency decision is a `roadmap_future.md` task; the T1 run-brief workflow edit is a roadmap-named successor. The M3.1 pre-close review gate (`docs/operations/iteration_policy.md`) still opens at the sub-milestone end.
