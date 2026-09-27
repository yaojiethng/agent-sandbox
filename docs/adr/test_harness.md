# Test Harness

**Current:** 2026-09-22

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| 1 | Zero runtime dependencies | The unit-test runner runs with a standard bash on the runtime image and macOS; no provisioning step |
| 2 | Verdict exit | Any failure or skip makes the run exit non-zero |
| 3 | Order independence | A green verdict must not depend on test execution order; a reversed-order probe checks it |
| 4 | Per-test deadline | A hanging test cannot hang the suite or the tool |
| 5 | Silent-green prevention | A test that runs no assertion or fails to end in its verdict must not pass unnoticed |

## 2026-09-22 -- keep the bespoke unit-test harness; reject the bats-core migration

**Decision:** The project keeps the bespoke unit-test harness on the main line. The runner dispatches test files in parallel (`xargs -P8`) and gives each file a pure-bash kill-on-expiry deadline (default 5s). The harness contributes zero runtime dependencies.

**Rationale:** Measured on equal footing (both candidates re-ported onto the finished U1-U7 suite), the keep-current runner meets every comparison invariant with zero dependencies and a ~4.7x parallel speedup (46s serial to 9.7s), and keeps the two mechanical silent-green guards the framework candidate demotes to an authoring convention (no-assertion detection and trailing-rc zombie detection). The four harness-bug classes the study named are closed on both candidates, so the bug-reduction axis that favored outsourcing no longer does.

**Rejected alternatives:** bats-core migration (branch B) - rejected as insufficient, superseded by a strictly better option. It closes no bug class the keep-current runner lacks, adds three runtime dependencies (bats-core, GNU parallel, procps) none of which exist in the base image, and measures slower on serial (65s vs 46s) and parallel (31s vs 9.7s) wall. Its finer per-test deadline granularity does not justify the dependency, migration, and maintenance cost.

**Edge cases / drivers:** A failing test fails fast under both approaches (the bats candidate does not hold the suite for the deadline; the contrary claim in its report did not reproduce). A hung unit costs one deadline: per-file under the keep-current runner (the rest of the file's tests are lost and the verdict stays red), per-test under bats (the file continues). The 5s deadline margin thins under parallel contention; the merged runner stayed green with no spurious TIMEOUT.
