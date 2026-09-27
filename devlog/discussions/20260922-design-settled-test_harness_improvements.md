# Design: unified test-harness improvement plan (M3.1)

**Status:** settled -- the plan landed (U1-U7); the harness comparison it enabled is settled in [`20260922-design-settled-m3_1_test_harness_decision.md`](20260922-design-settled-m3_1_test_harness_decision.md).

## Purpose and scope

This plan brings the keep-current test suite to a trustworthy authoring baseline and places both comparison branches on that baseline. It is one task, owned on the main line.

The suite now runs each file's tests in-process in one shared shell. A test's `export`, `cd`, global writes, and `trap` persist into the next test. This makes the suite order-dependent: a green verdict means green in this order, not green. An order-dependent suite cannot underwrite blind claims or regression reads, and asserting failing cases is unreliable because a test's inputs can depend on what an earlier test left in the shell. The plan fixes the cause, not the symptom.

The two-branch harness comparison (keep-current `xargs -P8` vs bats-core) was settled after this plan landed: keep-current was adopted and bats-core was rejected.

## Design decisions

### Per-test isolation moves forward and is mandatory

Each test runs in its own subshell. This is the full coupled change: subshell-per-test execution, fail-fast assertions, and per-test unit accounting.

- `fail()` exits the current test subshell non-zero; it cannot accumulate a global `FAIL`.
- Accounting is per-test unit, not a global `PASS`/`FAIL` running sum.
- A non-zero exit from the test subshell is a failed test.

Isolation is a prerequisite for the rest. It also equalizes isolation across both branches, which makes the later harness comparison fairer.

### Untyped per-test allocation

`get_fixture_dir` (alias `get_test_dir`, the same backend) returns a fresh directory on each call. A test allocates as many directories as it needs and builds whatever contents it wants inside each. The allocator never reuses a directory across tests. Each allocation lives until just before the current test's teardown; nothing is guaranteed after.

`FIXTURE_DIR` remains as the per-test default root, a compatibility handle for the existing `$FIXTURE_DIR/repo_*` sub-path style. The allocator serves extras and replaces stray `mktemp -d` sites.

### Unified per-test teardown

One backend collects each test's allocated directories and removes them. Directories are just directories. Fixture vs scratch is decided by the contents a test puts in them, not by the allocator. A third folder kind later is a call to the same allocator, not a new mechanism.

### Authoring bar

The implementation addresses the checklist at the model-and-measured-violations level, then a full per-assertion sweep runs as the final review pass.

- Capture-and-assert: run the command, keep its rc and output, assert both.
- Assert the meaning, not the string.
- Per-test fixture directories, via the allocator.
- Explicit teardown, unified.
- No reliance on benign non-zero intermediates.
- Descriptive labels where they disambiguate a failure.
- Order-independence, verified by a reversed-run probe.

### Order-independence is a verification probe

With per-test subshells, order cannot matter. A reversed-run gate proves isolation instead of racing to find leaks. Item 7 stops being a sweep and becomes a probe. The gate was later retired as unowned (it was never invoked); order independence holds by construction.

### Commit style

Work lands as clean, readable units; a final squash happens only if the back-and-forth became messy. The commit history is the record. No separate parity-status document exists.

## Designs considered and rejected

| Design | Rejected because |
|---|---|
| Typed allocation (`fixture` vs `tmp` namespaces) | Fixture and scratch are both just directories. A type tag adds API surface without a structural benefit once no reuse between tests is guaranteed. |
| Two fixed globals (`FIXTURE_DIR` plus `TMP_DIR`) | Creates a second cleanup mechanism. The untyped allocator is one mechanism. |
| Register-and-clean teardown helper | Adds a second teardown path. Routing temps through the allocator keeps one. |
| Minimal fixture change (keep the shared parent, fix only sweep-found collisions) | Does not stop env/global leakage, so it cannot deliver the trust requirement. |
| Deferring isolation to the harness decision | Order-dependent green undermines every verdict and failing-case assertion. Isolation must precede the comparison. |
| Shuffle-probe as the primary detector | After isolation it is a verification gate, not a detector. |

## Work units

- U1  Execution model: subshell-per-test, fail-fast, per-test accounting, the untyped allocator, `FIXTURE_DIR` compatibility, unified teardown.
- U2  Capture-and-assert helper; migrate rc-only and output-discarding assertion sites.
- U3  Temp-dir routing: stray `mktemp -d` sites and file-scope alias fixtures to the allocator.
- U4  Benign-non-zero cleanup.
- U5  Assert-the-meaning labels where they disambiguate.
- U6  Order-independence verification probe (reversed-run gate).
- U7  Final full per-assertion sweep (fresh-subagent review).

## Harness comparison outcome

The three deferred items completed after this plan landed:

- Both branches were re-ported onto the finished harness.
- Both suites were re-measured on equal footing: wall time, an isolation probe, and dependency count.
- The harness decision settled: keep-current (branch A) adopted; bats-core rejected.
