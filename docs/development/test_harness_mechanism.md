# Test Harness Mechanism

## Purpose and scope

This document describes how the unit-test harness runs: discovery, parallel dispatch, the result protocol, and the gates around the suite. It is the mechanism layer. Authoring rules live in [`testing-conventions.md`](testing-conventions.md) and policy in [`testing_policy.md`](testing_policy.md).

The harness guarantees one invariant: a trustworthy green or red signal. Every unit result must be counted exactly once, and a failure must never look green. The design satisfies this by carrying counts over a self-describing report, not by re-parsing the test's printed noise.

## The runner (`scripts/run_tests.sh`)

`run_tests.sh` discovers every `tests/test_*.sh` file, checks the suite prerequisites, gates the registration contract, and dispatches the files in parallel.

Discovery globs `$TEST_DIR/test_*.sh`, sorts the names, and warns when it finds none. `TEST_DIR` defaults to `tests/`; `RUN_TESTS_DIR` overrides it for the runner self-test.

The prerequisite gate checks that the docker stub (`tests/stubs/docker`) exists and is executable. A broken stub otherwise fails dozens of tests with unrelated exit 126 or 127 errors.

The registration liveness gate runs before dispatch (see The gates). It is skipped under a `RUN_TESTS_DIR` override because the self-test feeds synthetic files.

Dispatch runs every file through a child copy of the runner: `printf '%s\n' "$TEST_FILES" | xargs -P"$TEST_PARALLEL" -I{} bash "$0" --worker "{}"`. Each worker handles one file. Workers always exit 0 so `xargs` schedules every file regardless of any single failure; failure state rides the record the worker writes (see The result protocol). `TEST_PARALLEL` defaults to 8.

The deadline is pure bash: `run_with_deadline DEADLINE OUT FILE` backgrounds the file, polls it at 0.1 second, kills it on expiry with SIGTERM, and returns 124. No external `timeout` binary is needed, which keeps the runner safe on the GNU and BSD `sleep` variants. The deadline is `TEST_TIMEOUT` (default 5 seconds), and a file may declare its own with a `# TEST_DEADLINE: <seconds>` line in its first ten lines; the declaration overrides the default for that file only, so a heavy harness file states its own budget instead of raising the deadline for every file. The declaration is a budget, not a licence: the file must stay near the cost it declares.

The parent summarizes the workers' records, prints the aggregate line, and exits 1 when any unit failed or timed out.

## The unit contract (`tests/libs/test_common.sh`)

A test file sources `test_common.sh`, writes one `test_*()` function per unit, registers each with `run_test NAME`, and ends with `test_done`.

One test is one unit. `run_test` runs the named function in a fresh subshell, so a test's environment, working directory, globals, and traps cannot leak into a sibling. The same subshell allocates a fresh `FIXTURE_DIR` (the test's default root) and removes it, and every directory the test allocates, when the subshell exits. `get_fixture_dir` (alias `get_test_dir`) allocates extra per-test directories; a test never uses a bare `mktemp -d`. `test_setup` at file scope sets `TEST_DIR`, `REPO_ROOT`, and a file-scope `FIXTURE_ROOT` for scaffolding a file's tests share.

The assertion helpers (`assert_eq`, `assert_contains`, `assert_run`, and the rest) each call `pass` or `fail` themselves. They are one way to assert; an inline `if ...; then pass; else fail; fi` is the alternative. fail-fast means a `fail()` inside a test ends the subshell immediately.

A unit is one of three outcomes:

- PASS: the subshell exited 0 and emitted at least one assertion.
- FAIL: the subshell exited non-zero (a `fail()` or a crash) or completed with no assertion.
- SKIP: the test called `skip()` because its subject is not ready (an unstubbed operation, a missing dependency). A skip is a warning, not a failure. `skip()` ends the test immediately and counts the unit as skipped; the cause is resolved so skips trend back to zero.

`test_done` prints the per-file report: `Results: N passed, M failed, K skipped`. It exits with the failing-unit count, so a file's exit status carries the number of failures. It also emits the `UNIT:` report line described next.

## The result protocol

Counts travel from the test file to the runner as self-describing key-value lines. The reader validates every line strictly; a malformed line is a loud failure, never a silent number.

`test_done` emits one report line:

```text
UNIT: pass=16 fail=0 skip=1
```

The worker finds the last `UNIT:` line in the file's output and validates it against the anchored shape `UNIT: pass=<int> fail=<int> skip=<int>`. A file that produced no `UNIT:` line (a crash, a missing `test_done`) or a malformed line (a drifted shape) is a failure by construction. A report of `pass=0 fail=0 skip=0` is also a failure: a test file that executed no unit is broken.

The worker writes one record per file for the parent to aggregate:

```text
pass=16 fail=0 skip=1 rc=0
```

The parent reads the record and validates it against the same strict key-value shape. A missing or malformed record is a failure. The failure verdict rides the exit code or the fail count; a skip never fails the run.

Why drift is loud by construction: the failure count rides the file's real exit status (which cannot be misparsed), and the pass and skip counts ride a self-describing `UNIT:` report the file must emit or the run fails. A format drift at either hop becomes a missing or malformed line, which is a hard error. A test file cannot silently report fewer units than it passed by accident of presentation.

## The gates

`scripts/check_test_liveness.sh` owns the registration contract. It reads each test file and flags three defects:

- UNREGISTERED: a defined `test_*()` function with no `run_test` registration.
- DANGLING: a `run_test` target with no matching function definition.
- DEAD-REGISTRATION: a `run_test` after `test_done`; `test_done` exits the process, so the registration never runs.

The gate accepts a directory argument (defaulting to the real suite) so the runner self-test can point it at a fixture. The runner calls it before dispatch and the self-test calls it directly.

`scripts/check_test_smoke.sh` syntax-checks the excluded `tests/knowledge/`, `tests/integration/`, and `tests/eval/` scripts with `bash -n`, so excluded scripts cannot rot silently. It is non-gating.

`scripts/check_test_coverage.sh` is an ad hoc helper: given changed file paths, it prints which test files reference each. It is not a gate.

The runner's deadline and the result protocol are also gates: a hanging file times out at `TEST_TIMEOUT` (default 5 seconds, or the file's own `# TEST_DEADLINE` declaration), a crash or missing report fails loudly, and a skip is reported as a warning.

## The selftest (`tests/test_runner_selftest.sh`)

The runner is load-bearing infrastructure, so `tests/test_runner_selftest.sh` pins its contracts. It feeds synthetic files through the runner under a `RUN_TESTS_DIR` override and asserts:

- a passing file is counted and exits 0;
- a failing file is counted and exits non-zero;
- a crash (no `UNIT:` report) is flagged with a named cause;
- a file that exits 0 with no `UNIT:` report is a failure (the silent-green guard);
- a skip is reported as a warning and does not fail the run;
- the aggregate line sums per-file counts exactly;
- parallel dispatch counts every file exactly;
- an empty discovery warns and exits non-zero;
- a broken prerequisite is reported once, by name;
- a deadline-beating file is reported as `TIMEOUT`;
- a file's own `# TEST_DEADLINE` declaration overrides the default, in both directions;
- the liveness gate flags a dead registration.

## What the harness cannot observe

A unit test sees what the docker stub reproduces. The stub records every invocation's arguments and simulates failure through environment variables, so an argument is assertable. It does not present a TTY, prompt, progress table, or stdin, so a guard whose only job is to shape an interactive compose session cannot fail a unit.

The following guards in `scripts/run_agent.sh` rest on live observation, not on a unit:

- `-T` on the seeder invocation, which the script's comment cites to an attach that never closed.
- the two `< /dev/null` redirections on compose invocations, which keep an attached session from reading the caller's stdin.
- `--progress quiet` on two compose invocations, which keeps a progress table out of the operator's output.

A green suite is not evidence that one of these guards still earns its place, and it is not evidence that removing it is safe. Change one against a live run.

## See also

- [`testing-conventions.md`](testing-conventions.md) -- the authoring bar and the test structure template.
- [`testing_policy.md`](testing_policy.md) -- test placement and the `make test` invariant.
- [`docs/adr/test_harness.md`](../adr/test_harness.md) -- the harness decision record.
