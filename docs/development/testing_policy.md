# Testing Policy - agent-sandbox

This document defines the testing standards, patterns, and anti-patterns for the agent-sandbox test suite. It is designed to ensure test reliability, isolation, and maintainability.

---

## Core Principles

### 1. Test Isolation is Mandatory

Every test must be independent and reproducible. Tests must not depend on:
- State from previous tests
- User's home directory or working directory
- Any path outside the test's temporary fixture directory

**Rule:** All test fixtures must live under a temporary directory created with `mktemp -d` and cleaned up on exit.

```bash
# ✓ Correct: isolated fixture directory
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

P="$FIXTURE_DIR/test_project"
S="$FIXTURE_DIR/test_sandbox"
```

### 2. Fixtures Must Be Cleaned Before Use

Helper functions that create fixtures must explicitly remove existing state before creating new state. Silent accumulation of state causes non-deterministic test failures.

```bash
# ✓ Correct: explicit cleanup before creation
make_project() {
  local DIR="$1"
  rm -rf "$DIR"              # ← Clean first
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet
  ...
}

# ✗ Wrong: assumes directory is empty
make_project() {
  local DIR="$1"
  mkdir -p "$DIR"            # ← May contain stale state
  git -C "$DIR" init --quiet
  ...
}
```

### 3. Avoid Shared State Between Test Calls

When a test calls a helper function multiple times (e.g., to create multiple sessions), each call must not destroy state created by previous calls unless that is the explicit purpose of the test.

```bash
# ✓ Correct: preserves other sessions, cleans only its own
make_session() {
  local SANDBOX_DIR="$1"
  local SESSION="$2"
  mkdir -p "$SANDBOX_DIR/.workspace"          # ← Create if needed, don't destroy
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION"
  rm -rf "$SESSION_DIR"                       # ← Clean only this session
  mkdir -p "$SESSION_DIR/patches"
  ...
}

# ✗ Wrong: destroys all sessions including ones just created
make_session() {
  local SANDBOX_DIR="$1"
  local SESSION="$2"
  rm -rf "$SANDBOX_DIR/.workspace"            # ← Destroys previous sessions!
  mkdir -p "$SANDBOX_DIR/.workspace"
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION"
  ...
}
```

### 4. Test Files Must Be Self-Contained

A test file may only source helpers from `tests/libs/`. It must never source another test file, and must never depend on another test file having run first.

`tests/libs/` files contain only helper functions - no test execution, no `run_test` calls, no pass/fail counters. A `tests/libs/` file sourced in isolation must produce no output and have no side effects.

```bash
# ✓ Correct: source only from tests/libs/
source "$REPO_ROOT/tests/libs/test_common.sh"
source "$REPO_ROOT/tests/libs/git_fixtures.sh"
source "$REPO_ROOT/tests/libs/session_fixtures.sh"

# ✗ Wrong: sourcing another test file
source "$REPO_ROOT/test_draft_workflow.sh"   # ← Executes tests, pollutes state
```

---



## Shared Fixtures (`tests/libs/`)

Helpers used by more than one test file live in `tests/libs/` and are sourced explicitly. Four fixture files are established:

| File | Contains |
|---|---|
| `tests/libs/test_common.sh` | Pass/fail/skip counters and reporting: `pass()`, `fail()`, `skip()`, `run_test()`, `test_done()` |
| `tests/libs/git_fixtures.sh` | Git repo setup helpers: `make_repo()`, `make_committed_repo()`, `make_sandbox_fixture()`, `get_init_sha()`, `write_session_state()`, `commit_change()` |
| `tests/libs/session_fixtures.sh` | Session fixture: `make_session_fixture()` — unified session directory creator with optional patches and uncommitted.diff |


**Rules for `tests/libs/` files:**
- Helper functions only - no test execution
- Every helper must follow Core Principles 1-3 (isolation, clean-before-create, no shared state)
- A new helper belongs in `tests/libs/` if and only if it is used by two or more test files; otherwise it lives in the test file itself

Do not add a new `tests/libs/` file without a clear category boundary. If a helper does not fit an existing file, name the new file to reflect its distinct scope.

### Using `test_common.sh`

Always source `test_common.sh` instead of defining `pass()`, `fail()`, and counter variables inline. It provides:

- `pass()` / `fail()` — identical formatting across all test files
- `skip()` — for tests that cannot run in the current environment
- `run_test()` — test runner that continues on failure
- `test_done()` — summary reporter that exits with failure count

```bash
source "$REPO_ROOT/tests/libs/test_common.sh"
```

Every test file and knowledge test file must source `test_common.sh` instead of defining `pass()` / `fail()` locally. The only exception is diagnostic scripts (`diagnose_*.sh`) that run inside containers where `tests/libs/` is not available.

---

## Test Placement — `tests/`, `tests/knowledge/`, `tests/integration/`

Tests live in one of three homes based on **who owns the seam under test** and **whether the harness can run it deterministically**.

### The decision rule

> A test belongs under the **`make test` suite** (`tests/test_*.sh`) when the seam is **our own maintained code with a callable API**. Write the test **directly against that API**.
>
> A test belongs in `tests/knowledge/knowledge_*.sh` only when it probes a seam the harness **cannot** test through an API — an **unmodifiable** seam: an external binary/library/network service, or legacy code **mid-refactor** where we are documenting current behaviour before reworking it.
>
> A test belongs in `tests/integration/` when it is **still not runnable** in the unit harness (chunky end-to-end flows, container/daemon needs, no clear pass/fail, metrics without thresholds) but the knowledge is too valuable to discard.

Knowledge tests and integration tests are **not** run by `make test`. The runner glob is `tests/test_*.sh` (non-recursive), so `tests/knowledge/` and `tests/integration/` are excluded.

**Do not treat the knowledge test as a primitive for testing our own code.** If the seam is our maintained code, it is testable by definition — write a unit test under `tests/` and run it in `make test`. A knowledge test is a *last resort for unmodifiable seams*, not a home for internal behaviour.

### Promotions over time

If a seam was previously untestable but becomes testable — e.g. a docker mock now allows asserting the exact `docker ...` command we pass — promote the coverage to a **unit test** (`tests/test_*.sh`) using that mock, rather than leaving it as a knowledge/integration note.

### `tests/knowledge/` Directory — three categories

The `tests/knowledge/` directory contains three file categories with distinct purposes. All files must be self-contained, create and clean up their own temporary directories, and exit 0 on success or non-zero on failure.

### 1. Knowledge tests (`knowledge_*.sh`)

Document behavioural assumptions about **unmodifiable** seams (git, docker, rsync, pi, external libs) that inform the harness design. These are one-off executable documents produced during investigation sessions. A one-off feasibility probe from an investigation is a knowledge test and uses the `knowledge_` prefix.

**Purpose:** Record what was learned about an external tool's behaviour, assert key assumptions still hold, and provide a reference for future developers.

**Rule:** A knowledge test's assertions are **not** acceptance criteria for implementation sessions. They document external tool behaviour, not internal system behaviour. **A knowledge test must not probe our own maintained code that has an API — that belongs in `tests/` under `make test`.** Implementation acceptance criteria are defined per-session in the handover.

### 2. Diagnostic scripts (`diagnose_*.sh`)

Debug helpers that verify the internal invariants of a specific production script or subsystem, referenced when dry-run or pre-flight checks fail to isolate the root cause. They run inside a container for troubleshooting — **not** as regression unit tests. A `diagnose_` script tests current behaviour to find the exact behavioural violation behind an error, especially when the unit tests pass.

**Purpose:** Provide a structured troubleshooting path for a specific failure domain (e.g. "why does dry-run Phase 2 fail?"). Each section checks one link in the chain — environment, library sourcing, path resolution, script hygiene, etc. Because they are diagnostic (not deterministic pass/fail, may need operator interpretation, or run only in a container), they are **not** in the `make test` suite.

**Relation to ACs:** Diagnostic scripts can be referenced from acceptance criteria as a regression-guard AC for a recurring bug class where a full unit test is impractical. See [handover policy Acceptance criteria — Regression guard](handover_policy.md#acceptance-criteria).

**Naming:** `tests/knowledge/diagnose_<subsystem>.sh` — mirrors the production script name it diagnoses.

### 3. Workflow tests (`workflow_*.sh`)

End-to-end sequence validators that exercise a complete operator workflow (e.g. draft → confirm, draft → reject) against a mock repository to avoid side effects.

**Purpose:** Validate that a multi-step workflow produces the expected repository state, file layout, and exit codes without requiring a full harness session. Used during implementation and regression-checked after refactors.

**Relation to ACs:** Workflow test assertions are system behaviour and can be referenced from acceptance criteria. Prefer adding a workflow test over manual verification for any multi-step operator workflow.

### 4. Integration tests (`tests/integration/`)

End-to-end or environment-gated tests that cannot run deterministically in the `make test` harness (container/daemon requirements, chunky multi-process flows, metrics/thresholds without a defined pass/fail). **Excluded from `make test`** so the unit suite stays deterministic.

**Purpose:** Preserve valuable coverage of flows the unit harness cannot exercise, while keeping `make test` a fully-green, deterministic assertion of **failed 0, skipped 0**.

**Rule:** If an integration flow's seam becomes unit-testable (e.g. via a mock), promote it to `tests/test_*.sh`. Do not use `integration/` as a permanent home for code our own unit suite *could* cover.

### The `make test` invariant

`make test` (the `tests/test_*.sh` suite) **must report `failed 0, skipped 0`**. Any test that cannot run deterministically (missing utility, container/daemon absent, optional file absent that yields a `skip`) must be made deterministic or moved to `tests/knowledge/` / `tests/integration/`. The runner (`scripts/run_tests.sh`) enforces this by treating `skip` as a failure.

A `skip()` in a `tests/test_*.sh` file is a **defect** under this policy — it means the seam was moved out of the unit suite rather than made deterministic.

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
- Domain-specific helpers used by only one file (e.g. `make_binary()`, `make_sandbox()`) stay local — do not add them to a shared library until a second consumer exists.

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

---

## Keeping Tests Current

When a lib or script changes behaviour, the corresponding test files must be reviewed for staleness.

**Rule:** Before marking a lib or script change complete, run:

```bash
grep -rl "script_or_lib_name" tests/
```

Read each file returned and assess whether any test case is invalidated or no longer sufficient given the change. If a test needs updating, update it in the same change - do not defer test updates to a follow-up.

A handover or finding must not claim a code path that no test exercises. A behaviour branch claimed in a handover or finding is covered by a test, or the handover states why it is untested.

This applies to renames, interface changes, flag additions, and behavioural fixes. It does not apply to internal refactors that produce identical external behaviour - but if in doubt, grep and check.

---

## See Also

[`testing-conventions.md`](testing-conventions.md) — fixture patterns, anti-patterns, templates, checklists, and debug steps.
