# `tests/integration/`

Integration tests that cannot run deterministically inside the `make test` unit
harness, but whose coverage is too valuable to discard.

**Excluded from `make test`.** The runner glob (`tests/test_*.sh`) is
non-recursive, so this directory is not picked up by `scripts/run_tests.sh`.

## When a test lives here

Per `docs/development/testing_policy.md` (Test Placement), a test belongs here
only when the seam under test is **not deterministically runnable** in the unit
harness:

- chunky end-to-end / multi-process flows,
- requires a container or a daemon not present in the test environment,
- no clear pass/fail (metrics, timing, thresholds without a defined bound),
- operator interpretation required to judge the result.

## Rules

- If a seam here becomes unit-testable (e.g. via a docker mock), promote it to
  `tests/test_*.sh` and run it under `make test` — do not leave it here.
- These files are run manually, like the knowledge/diagnostic tests in
  `tests/knowledge/`.
- They source shared fixtures from `tests/libs/` where available.
