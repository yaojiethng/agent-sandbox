---
description: "Owns the testing rules not yet moved: test placement, the `make test` invariant, registration liveness, and keeping tests current. The judgements and patterns for writing a test live in the `testing` convention-skill; this document is the migration bridge for the rest."
scope: ["tests/"]
---

# Testing Policy - agent-sandbox

**When to write tests:** any function with meaningful branching, error handling, or external dependencies gets tests. Tests are produced alongside implementation, not deferred.

## Shared Fixtures (`tests/libs/`)

Helpers used by more than one test file live in `tests/libs/` and are sourced explicitly; the `testing` skill's fixture pattern lists the files and the sourcing rule.

**Rules for `tests/libs/` files:**

- Helper functions only - no test execution
- Every helper follows the `testing` skill's judgements: isolation, clean before create, and no shared state
- A new helper belongs in `tests/libs/` if and only if it is used by two or more test files; otherwise it lives in the test file itself

Do not add a new `tests/libs/` file without a clear category boundary. If a helper does not fit an existing file, name the new file to reflect its distinct scope.

## Test Placement -- `tests/`, `tests/knowledge/`, `tests/integration/`

Tests live in one of three homes based on **who owns the seam under test** and **whether the harness can run it deterministically**.

### The decision rule

> A test belongs under the **`make test` suite** (`tests/test_*.sh`) when the seam is **our own maintained code with a callable API**. Write the test **directly against that API**.
>
> A test belongs in `tests/knowledge/knowledge_*.sh` only when it probes a seam the harness **cannot** test through an API -- an **unmodifiable** seam: an external binary/library/network service, or legacy code **mid-refactor** where we are documenting current behaviour before reworking it.
>
> A test belongs in `tests/integration/` when it is **still not runnable** in the unit harness (chunky end-to-end flows, container/daemon needs, no clear pass/fail, metrics without thresholds) but the knowledge is too valuable to discard.

Knowledge tests and integration tests are **not** run by `make test`. The runner glob is `tests/test_*.sh` (non-recursive), so `tests/knowledge/` and `tests/integration/` are excluded.

**Do not treat the knowledge test as a primitive for testing our own code.** If the seam is our maintained code, it is testable by definition -- write a unit test under `tests/` and run it in `make test`. A knowledge test is a *last resort for unmodifiable seams*, not a source of truth for internal behaviour.

### The file and the unit

A test file is named for its subject, and holds that subject's units: `tests/test_A.sh` tests `A.sh`, and the file name is the lookup for where that subject is covered. Do not keep a roster of which file covers what: it goes stale as soon as a subject moves, and it is one more thing to keep true.

### Promotions over time

If a seam was previously untestable but becomes testable -- e.g. a docker mock now allows asserting the exact `docker ...` command we pass -- promote the coverage to a **unit test** (`tests/test_*.sh`) using that mock, rather than leaving it as a knowledge/integration note.

### `tests/knowledge/` Directory -- three categories

The `tests/knowledge/` directory contains three file categories with distinct purposes. All files must be self-contained, create and clean up their own temporary directories, and exit 0 on success or non-zero on failure.

### 1. Knowledge tests (`knowledge_*.sh`)

Document behavioural assumptions about **unmodifiable** seams (git, docker, rsync, pi, external libs) that inform the harness design. These are one-off executable documents produced during investigation sessions. A one-off feasibility probe from an investigation is a knowledge test and uses the `knowledge_` prefix.

**Purpose:** Record what was learned about an external tool's behaviour, assert key assumptions still hold, and provide a reference for future developers.

**Rule:** A knowledge test's assertions are **not** acceptance criteria for implementation sessions. They document external tool behaviour, not internal system behaviour. **A knowledge test must not probe our own maintained code that has an API -- that belongs in `tests/` under `make test`.** Implementation acceptance criteria are defined per-session in the handover.

### 2. Diagnostic scripts (`diagnose_*.sh`)

Debug helpers that verify the internal invariants of a specific production script or subsystem, referenced when dry-run or pre-flight checks fail to isolate the root cause. They run inside a container for troubleshooting -- **not** as regression unit tests. A `diagnose_` script tests current behaviour to find the exact behavioural violation behind an error, especially when the unit tests pass.

**Purpose:** Provide a structured troubleshooting path for a specific failure domain (e.g. "why does the dry-run reasoning probe fail?"). Each section checks one link in the chain -- environment, library sourcing, path resolution, script hygiene, etc. Because they are diagnostic (not deterministic pass/fail, may need operator interpretation, or run only in a container), they are **not** in the `make test` suite.

**Relation to ACs:** Diagnostic scripts can be referenced from acceptance criteria as a regression-guard AC for a recurring bug class where a full unit test is impractical. See the acceptance-criteria invariants in [`iteration_policy.md`](../policies/iteration_policy.md#acceptance-criteria-invariants).

**Naming:** `tests/knowledge/diagnose_<subsystem>.sh` -- mirrors the production script name it diagnoses.

### 3. Workflow tests (`workflow_*.sh`)

End-to-end sequence validators that exercise a complete operator workflow (e.g. draft -> confirm, draft -> reject) against a mock repository to avoid side effects.

**Purpose:** Validate that a multi-step workflow produces the expected repository state, file layout, and exit codes without requiring a full harness session. Used during implementation and regression-checked after refactors.

**Relation to ACs:** Workflow test assertions are system behaviour and can be referenced from acceptance criteria. Prefer adding a workflow test over manual verification for any multi-step operator workflow.

### 4. Integration tests (`tests/integration/`)

End-to-end or environment-gated tests that cannot run deterministically in the `make test` harness (container/daemon requirements, chunky multi-process flows, metrics/thresholds without a defined pass/fail). **Excluded from `make test`** so the unit suite stays deterministic.

**Purpose:** Preserve valuable coverage of flows the unit harness cannot exercise, while keeping `make test` a fully-green, deterministic assertion of **failed 0**.

**Rule:** If an integration flow's seam becomes unit-testable (e.g. via a mock), promote it to `tests/test_*.sh`. Do not use `integration/` as a permanent place for code our own unit suite *could* cover.

### The `make test` invariant

`make test` (the `tests/test_*.sh` suite) **must report `failed 0`**. A test that cannot run deterministically (missing utility, container/daemon absent, optional file absent) must be made deterministic or moved to `tests/knowledge/` / `tests/integration/`.

A `skip()` in a `tests/test_*.sh` file is a **temporary** state -- the subject is not ready (an unstubbed operation, a dependency absent from the container) -- reported as a warning, not a failure. Skips are tolerated for wip / mid-sub-milestone work, and the cause is resolved so skips trend back to zero. The runner (`scripts/run_tests.sh`) counts skips and warns; a skip does not fail the run.

A prerequisite is something the suite needs before a test runs: an executable stub, or a docker shim that must be present. A prerequisite failure is not a test failure. The runner checks the prerequisites before it runs the tests. It reports a missing prerequisite by name. A broken environment then reports one prerequisite error, not many unrelated test failures. This rule records a real failure: a stub lost its exec bit and failed 67 tests with exit 126 before the cause was found.

### Shared Fixtures in Knowledge/Integration/Diagnostic Tests

Knowledge, workflow, integration, and diagnostic tests **must** source shared fixture libraries instead of defining boilerplate inline:

| Boilerplate | Source instead | Files affected |
|---|---|---|
| `pass()`, `fail()`, `PASS=0`, `FAIL=0` | `tests/libs/test_common.sh` | All `knowledge_*.sh` and `workflow_*.sh` files |
| `make_repo()` | `tests/libs/git_fixtures.sh` | Any file that creates git repos |
| `make_export_with_diffs()`, etc. | `tests/libs/session_fixtures.sh` | Workflow tests needing session export fixtures |

**Exception:** Diagnostic scripts (`diagnose_*.sh`) that run inside containers may keep inline `pass()` / `fail()` because `tests/libs/` is not available in the container filesystem.

**Rules:**

- Every new `knowledge_*.sh` or `workflow_*.sh` file must source `tests/libs/test_common.sh` for `pass()` / `fail()` instead of defining them inline.
- If the test creates git repositories, source `tests/libs/git_fixtures.sh` for `make_repo()` / `make_committed_repo()` instead of defining them inline.
- Domain-specific helpers used by only one file (e.g. `make_binary()`, `make_sandbox()`) stay local -- do not add them to a shared library until a second consumer exists.

These rules align with the core principle that `tests/libs/` is the only allowed source of shared test helpers.

## Running the Test Suite

The full suite is run via:

```bash
make test
# or
bash scripts/run_tests.sh
```

This runs all test files in sequence and prints a consolidated pass/fail summary per file. Use this as the primary verification step - running individual test files is for debugging only.

**Rule:** A change to any lib or script is not complete until `make test` passes clean. Running a subset of test files is not sufficient.

### Registration liveness

A `test_*()` function that is defined but never registered via `run_test` never executes -- it rots silently, and the suite still reports green. A `run_test` target without a definition fails at runtime with an unrelated error.

**Rule:** every `test_*()` function in `tests/test_*.sh` carries exactly one `run_test` registration in the same file, and every `run_test` target resolves to a defined function. Parameterized helpers invoked by registered wrappers are named outside the `test_` namespace.

**Check:** `make test-liveness` (or `bash scripts/check_test_liveness.sh`) verifies both directions statically, plus prerequisite liveness for the docker stub and stub libs. Run it alongside `make test` when touching test files; it is advisory like the other static checks, but a finding is a defect to fix in the same change.

## Keeping Tests Current

When a lib or script changes behaviour, the corresponding test files must be reviewed for staleness.

**Rule:** Before marking a lib or script change complete, run:

```bash
grep -rl "script_or_lib_name" tests/
```

Read each file returned and assess whether any test case is invalidated or no longer sufficient given the change. If a test needs updating, update it in the same change - do not defer test updates to a follow-up.

A handover or finding must not claim a code path that no test exercises. A behaviour branch claimed in a handover or finding is covered by a test, or the handover states why it is untested.

This applies to renames, interface changes, flag additions, and behavioural fixes. It does not apply to internal refactors that produce identical external behaviour - but if in doubt, grep and check.

## See Also

[`.agents/skills/testing/SKILL.md`](../../.agents/skills/testing/SKILL.md) -- the judgements and patterns for writing a test.

[`testing-conventions.md`](testing-conventions.md) -- the debugging guide and the two checklists (migration bridge).

[`test_harness_mechanism.md`](test_harness_mechanism.md) -- the runner, the unit contract, the result protocol and the gates.
