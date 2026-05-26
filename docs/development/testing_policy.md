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
source "$SCRIPT_DIR/tests/libs/test_common.sh"
source "$SCRIPT_DIR/tests/libs/git_fixtures.sh"
source "$SCRIPT_DIR/tests/libs/session_fixtures.sh"

# ✗ Wrong: sourcing another test file
source "$SCRIPT_DIR/test_draft_workflow.sh"   # ← Executes tests, pollutes state
```

---

## Fixture Management Patterns

### Pattern 1: Unique Paths Per Test

Each test function should use unique fixture paths derived from the test name:

```bash
test_draft_creates_branch() {
  local P="$FIXTURE_DIR/draft_branch_p"
  local S="$FIXTURE_DIR/draft_branch_s"
  make_project "$P"
  make_session "$P" "$S"
  ...
}

test_draft_applies_patches() {
  local P="$FIXTURE_DIR/draft_patches_p"
  local S="$FIXTURE_DIR/draft_patches_s"
  make_project "$P"
  make_session "$P" "$S"
  ...
}
```

### Pattern 2: Unique Paths Per Helper Call

When a helper creates subdirectories (e.g., sandbox working directories), use paths unique to the caller's SANDBOX_DIR, not shared paths:

```bash
# ✓ Correct: sandbox path is unique per SANDBOX_DIR
make_session() {
  local SANDBOX_DIR="$1"
  local SANDBOX="$SANDBOX_DIR/sandbox-work"   # ← Unique per test
  rm -rf "$SANDBOX"
  ...
}

# ✗ Wrong: sandbox path is shared across all tests
make_session() {
  local SESSION="$1"
  local SANDBOX="$FIXTURE_DIR/sandbox-${SESSION}"  # ← Collision if same SESSION
  ...
}
```

### Pattern 3: Cleanup in Reverse Order

When tests create nested state, clean up in reverse order of creation:

```bash
# Creation order:
# 1. Project directory
# 2. Sandbox directory
# 3. Session directory inside sandbox workspace
# 4. Checkpoint tag in project

# Cleanup (handled by trap, but be mindful in helpers):
# 1. Session directory (rm -rf "$SESSION_DIR")
# 2. Sandbox directory (rm -rf "$SANDBOX")
# 3. Project directory (rm -rf "$PROJECT_DIR")
# 4. Checkpoint tag (git tag -d)
```

---

## Shared Fixtures (`tests/libs/`)

Helpers used by more than one test file live in `tests/libs/` and are sourced explicitly. Four fixture files are established:

| File | Contains |
|---|---|
| `tests/libs/test_common.sh` | Pass/fail/skip counters and reporting: `pass()`, `fail()`, `skip()`, `run_test()`, `test_done()` |
| `tests/libs/git_fixtures.sh` | Git repo setup helpers: `make_repo()`, `make_committed_repo()`, `make_sandbox_fixture()`, `get_init_sha()`, `write_session_state()`, `commit_change()` |
| `tests/libs/session_fixtures.sh` | Session fixture: `make_session_fixture()` — unified session directory creator with optional patches and uncommitted.diff |
| `tests/libs/mock_repo_fixtures.sh` | Mock agent-sandbox repo layout: `make_mock_repo()` |

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
source "$SCRIPT_DIR/tests/libs/test_common.sh"
```

Every test file and knowledge test file must source `test_common.sh` instead of defining `pass()` / `fail()` locally. The only exception is diagnostic scripts (`diagnose_*.sh`) that run inside containers where `tests/libs/` is not available.

---

## `tests/knowledge/` Directory

The `tests/knowledge/` directory contains three file categories with distinct purposes. None are run by `make test` or `scripts/run_tests.sh` — the runner uses `tests/test_*.sh` and the knowledge directory is excluded by glob. All files must be self-contained, create and clean up their own temporary directories, and exit 0 on success or non-zero on failure.

### 1. Knowledge tests (`knowledge_*.sh`)

Document behavioural assumptions about external tools (git, docker, rsync, etc.) that inform the harness design. These are one-off executable documents produced during investigation sessions.

**Purpose:** Record what was learned about a tool's behaviour, assert key assumptions still hold, and provide a reference for future developers.

**Rule:** A knowledge test's assertions are **not** acceptance criteria for implementation sessions. They document external tool behaviour, not internal system behaviour. Implementation acceptance criteria are defined per-session in the handover.

### 2. Diagnostic scripts (`diagnose_*.sh`)

Debug helpers that verify the internal invariants of a specific production script or subsystem. They are referenced when dry-run or pre-flight checks fail, to isolate the root cause.

**Purpose:** Provide a structured troubleshooting path for a specific failure domain (e.g. "why does dry-run Phase 2 fail?"). Each section checks one link in the chain — environment, library sourcing, path resolution, script hygiene, etc.

**Relation to ACs:** Unlike knowledge tests, diagnostic scripts test internal invariants and can be referenced from acceptance criteria — e.g. as a regression-guard AC for a recurring bug class. See handover policy §Acceptance criteria — Regression guard.

**Naming:** `tests/knowledge/diagnose_<subsystem>.sh` — mirrors the production script name it diagnoses.

### 3. Workflow tests (`workflow_*.sh`)

End-to-end sequence validators that exercise a complete operator workflow (e.g. draft → confirm, draft → reject). They run against a mock repository to avoid side effects.

**Purpose:** Validate that a multi-step workflow produces the expected repository state, file layout, and exit codes without requiring a full harness session. Used during implementation and regression-checked after refactors.

**Relation to ACs:** Workflow test assertions are system behaviour and can be referenced from acceptance criteria. Prefer adding a workflow test over manual verification for any multi-step operator workflow.

### Shared Fixtures in Knowledge Tests

Knowledge tests, workflow tests, and diagnostic scripts **must** source shared fixture libraries instead of defining boilerplate inline:

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

This applies to renames, interface changes, flag additions, and behavioural fixes. It does not apply to internal refactors that produce identical external behaviour - but if in doubt, grep and check.

---

## Common Anti-Patterns

### Anti-Pattern 1: Destructive Reset After Creation

**Symptom:** Test passes in isolation, fails in sequence.

```bash
# ✗ Wrong: creates session, then deletes it
make_session() {
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION"
  mkdir -p "$SESSION_DIR/patches"
  # create patches and diff files
  rm -rf "$SANDBOX_DIR/.workspace"    # ← Deletes what we just created!
  mkdir -p "$SANDBOX_DIR/.workspace"
  echo "$CHECKPOINT_TAG" > "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"
}
```

**Fix:** Create parent directories first, then populate:

```bash
# ✓ Correct: prepare parent, then create child
make_session() {
  mkdir -p "$SANDBOX_DIR/.workspace"  # ← Prepare first
  
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION"
  rm -rf "$SESSION_DIR"               # ← Clean only this session
  mkdir -p "$SESSION_DIR/patches"
  # create patches and diff files
  echo "$CHECKPOINT_TAG" > "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"
}
```

### Anti-Pattern 2: Shared Temporary Paths

**Symptom:** Tests interfere with each other when run in sequence.

```bash
# ✗ Wrong: multiple tests use same sandbox path
make_session() {
  local SANDBOX="$FIXTURE_DIR/sandbox-main"  # ← Same for all tests with same session
  # ...
}
```

**Fix:** Scope temporary paths to the test's fixture directory:

```bash
# ✓ Correct: each test has its own sandbox
make_session() {
  local SANDBOX_DIR="$1"
  local SANDBOX="$SANDBOX_DIR/sandbox-work"  # ← Unique per test
  # ...
}
```

### Anti-Pattern 3: Silent State Accumulation

**Symptom:** Test passes first time, fails on re-run or in different order.

```bash
# ✗ Wrong: assumes directory is empty
make_project() {
  mkdir -p "$DIR"
  git -C "$DIR" init  # ← Fails if already a git repo
  # ...
}
```

**Fix:** Explicit cleanup before creation:

```bash
# ✓ Correct: guaranteed clean state
make_project() {
  rm -rf "$DIR"
  mkdir -p "$DIR"
  git -C "$DIR" init
  # ...
}
```

### Anti-Pattern 4: Cross-Test-File Sourcing

**Symptom:** Sourcing a test file to reuse its helpers executes its tests as a side effect and may corrupt state.

```bash
# ✗ Wrong: sources a test file to get its helpers
source "$SCRIPT_DIR/test_draft_workflow.sh"
```

**Fix:** Move the shared helper to `tests/libs/` and source it from there in both files.

---

## Test Structure Template

```bash
#!/usr/bin/env bash
# tests/test_example.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../scripts/example.sh"

# Shared fixtures - source only from tests/libs/
source "$SCRIPT_DIR/tests/libs/test_common.sh"
source "$SCRIPT_DIR/tests/libs/git_fixtures.sh"
# source "$SCRIPT_DIR/tests/libs/session_fixtures.sh"  # if needed

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# -------------------------
# Local helpers (not shared across files)
# -------------------------

make_fixture() {
  local DIR="$1"
  rm -rf "$DIR"              # ← Always clean first
  mkdir -p "$DIR"
  # ... setup ...
}

# -------------------------
# Tests
# -------------------------

test_example_feature() {
  local P="$FIXTURE_DIR/example_p"
  local S="$FIXTURE_DIR/example_s"
  make_fixture "$P"
  make_fixture "$S"
  # ... test logic ...
  if [[ condition ]]; then
    pass "description"
  else
    fail "description"
  fi
}

# -------------------------
# Run all tests
# -------------------------

run_test test_example_feature

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
```

---

## [FINDINGS: 2026-05-22] — Proposed Testing Rules from Session Practice

This section captures rule proposals derived from hands-on debugging and investigation patterns during sessions. These are **not adopted policy** — they are candidates observed to solve recurring problems. After multiple sessions produce overlapping proposals, common patterns will be distilled into the main testing policy sections above.

Each entry states the observed symptom, the provisional rule that addressed it, and the reasoning.

---

### Finding: Layered debugging — strip orchestration to isolate root cause

**Observed:** EPERM warnings in Pi's settings.json locking required tracing through five layers (main.js → settings-manager.js → proper-lockfile → fs.utimesSync → kernel). The root cause — 9p filesystem not supporting `utime()` — was confirmed by a 6-line Node.js script that bypassed all orchestration and called `fs.utimesSync` directly on a test path.

**Proposed rule:** When debugging a failure that crosses abstraction layers, write a minimal reproduction that bypasses all but the suspected layer. The reproduction should:

1. Import/call only the system call or primitive that is suspected to fail.
2. Use literal paths (not configuration-derived paths) to eliminate indirection.
3. Print only the error and exit — no logging framework, no orchestration.
4. Run from a clean state (no prior setup, no environment variables beyond what is required for the call itself).

```bash
# Example: reproducing a filesystem permission issue
node -e "
const fs = require('fs');
try {
  fs.utimesSync('/path/to/test', new Date(), new Date());
  console.log('OK');
} catch(e) {
  console.error('FAILED:', e.code, e.message);
}
"
```

**Rationale:** Each abstraction layer adds failure modes (caching, error handling, concurrency, retry logic). A minimal reproduction eliminates all of them. If the minimal reproduction succeeds, the bug is in the orchestration. If it fails, the orchestration is irrelevant — the root cause is at the tested layer.

**When to apply:** Any investigation where the error message originates from a system call (filesystem, network, process) and the call chain is more than two layers deep from the entrypoint.

---

### Finding: Mount-as-evidence — verify filesystem type before debugging behaviour

**Observed:** The filesystem type (9p) was the root cause of EPERM on `utime()` and EXDEV on cross-filesystem `mv()`. In both cases, running `mount | grep <path>` or `stat -f <path>` at the start of debugging would have identified the constraint immediately, saving the time spent tracing through application code.

**Proposed rule:** When a bug involves file operations (read, write, rename, utime, chmod) and the path may be a bind mount or network filesystem, check the filesystem type first:

```bash
# Is the path on the expected filesystem?
df -T /path/to/suspect   # Filesystem type (ext4, 9p, overlay, tmpfs, nfs)
mount | grep /path       # Mount source and options
stat -f /path/to/suspect  # Filesystem ID and type
```

If the filesystem type is unexpected (e.g., 9p for a path assumed to be ext4, or overlay for a path assumed to be a bind mount), stop debugging the application code — the behaviour is a filesystem constraint, not a software bug.

---

### Finding: Layer-jumping — test the innermost assumption first

**Observed:** The EPERM debugging session followed a clean innermost-first chain: identify the system call (`utimesSync`) → test it directly → confirm failure → check filesystem type → confirm 9p constraint. This produced a definitive answer in minutes.

**Proposed rule:** When investigating a failure, order your tests from innermost (system call) to outermost (application orchestration). Do not start by reading application code — start by testing the primitive that the error message names. If the primitive works, move outward. If it fails, you have found the layer where the bug lives.

---

## Debugging Test Failures

### Symptom: Test Passes in Isolation, Fails in Sequence

**Likely cause:** State pollution from previous test.

**Debug steps:**
1. Run the full test suite and note which test fails
2. Run only the failing test - it should pass
3. Run the test immediately before the failing test, then the failing test
4. Check for:
   - Shared fixture paths
   - Missing `rm -rf` in helper functions
   - Global state (tags, branches, files) not cleaned up

### Symptom: Test Fails on Re-run in Same Session

**Likely cause:** Test doesn't clean up its own state.

**Debug steps:**
1. Run the test twice in the same shell
2. Check if the second run fails
3. Look for:
   - Git tags not deleted
   - Directories not removed
   - Files appended to instead of overwritten

### Symptom: Test Behavior Changes Based on Test Order

**Likely cause:** Tests share state through a common path.

**Debug steps:**
1. Shuffle test order (manually reorder `run_test` calls)
2. Note which orderings fail
3. Check for:
   - Hardcoded paths (e.g., `/tmp/sandbox` instead of `$FIXTURE_DIR/...`)
   - Helper functions that don't scope paths to their caller
   - Global variables not reset between tests

---

## Checklist for New Tests

Before committing a new test:

- [ ] Uses `mktemp -d` for fixture directory
- [ ] Has `trap 'rm -rf "$FIXTURE_DIR"' EXIT` for cleanup
- [ ] All helper functions clean their inputs before creating state
- [ ] No hardcoded paths outside fixture directory
- [ ] Sources shared fixtures from `tests/libs/` - no sourcing of other test files
- [ ] Sources `test_common.sh` for `pass()`/`fail()`/`skip()`/`run_test()`/`test_done()` instead of defining them inline
- [ ] Test passes when run in isolation
- [ ] Test passes when run after every other test in the file
- [ ] Test passes when run twice in a row
- [ ] `make test` passes clean after the new test is added
- [ ] Test failure message clearly describes what went wrong

## Checklist for Lib and Script Changes

Before marking a lib or script change complete:

- [ ] `grep -rl "<changed file>" tests/` run; all returned files reviewed for staleness
- [ ] Any stale test cases updated in the same change
- [ ] `make test` passes clean
