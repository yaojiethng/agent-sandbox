# Testing Policy — agent-sandbox

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

A test file may only source helpers from `tests/lib/`. It must never source another test file, and must never depend on another test file having run first.

`tests/lib/` files contain only helper functions — no test execution, no `run_test` calls, no pass/fail counters. A `tests/lib/` file sourced in isolation must produce no output and have no side effects.

```bash
# ✓ Correct: source only from tests/lib/
source "$SCRIPT_DIR/../tests/lib/git_fixtures.sh"
source "$SCRIPT_DIR/../tests/lib/session_fixtures.sh"

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

## Shared Fixtures (`tests/lib/`)

Helpers used by more than one test file live in `tests/lib/` and are sourced explicitly. Two fixture files are established:

| File | Contains |
|---|---|
| `tests/lib/git_fixtures.sh` | Git repo setup helpers: `make_committed_repo`, `get_init_sha`, `current_branch`, `branch_exists`, `commit_change` |
| `tests/lib/session_fixtures.sh` | Workspace/session structure helpers: `make_export_with_diffs`, `make_diffs_session`, `make_changes_session` |

**Rules for `tests/lib/` files:**
- Helper functions only — no test execution
- Every helper must follow Core Principles 1–3 (isolation, clean-before-create, no shared state)
- A new helper belongs in `tests/lib/` if and only if it is used by two or more test files; otherwise it lives in the test file itself

Do not add a third `tests/lib/` file without a clear category boundary. If a helper does not fit `git_fixtures.sh` or `session_fixtures.sh`, name the new file to reflect its distinct scope.

---

## Running the Test Suite

The full suite is run via:

```bash
make test
# or
bash scripts/run_tests.sh
```

This runs all test files in sequence and prints a consolidated pass/fail summary per file. Use this as the primary verification step — running individual test files is for debugging only.

**Rule:** A change to any lib or script is not complete until `make test` passes clean. Running a subset of test files is not sufficient.

---

## Keeping Tests Current

When a lib or script changes behaviour, the corresponding test files must be reviewed for staleness.

**Rule:** Before marking a lib or script change complete, run:

```bash
grep -rl "script_or_lib_name" tests/
```

Read each file returned and assess whether any test case is invalidated or no longer sufficient given the change. If a test needs updating, update it in the same change — do not defer test updates to a follow-up.

This applies to renames, interface changes, flag additions, and behavioural fixes. It does not apply to internal refactors that produce identical external behaviour — but if in doubt, grep and check.

---

## Common Anti-Patterns

### Anti-Pattern 1: Destructive Reset After Creation

**Symptom:** Test passes in isolation, fails in sequence.

```bash
# ✗ Wrong: creates session, then deletes it
make_session() {
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION"
  mkdir -p "$SESSION_DIR/patches"
  # ... create patches and diff files ...
  
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
  # ... create patches and diff files ...
  
  echo "$CHECKPOINT_TAG" > "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"
}
```

### Anti-Pattern 2: Shared Temporary Paths

**Symptom:** Tests interfere with each other when run in sequence.

```bash
# ✗ Wrong: multiple tests use same sandbox path
make_session() {
  local SANDBOX="$FIXTURE_DIR/sandbox-main"  # ← Same for all tests with same session
  ...
}
```

**Fix:** Scope temporary paths to the test's fixture directory:

```bash
# ✓ Correct: each test has its own sandbox
make_session() {
  local SANDBOX_DIR="$1"
  local SANDBOX="$SANDBOX_DIR/sandbox-work"  # ← Unique per test
  ...
}
```

### Anti-Pattern 3: Silent State Accumulation

**Symptom:** Test passes first time, fails on re-run or in different order.

```bash
# ✗ Wrong: assumes directory is empty
make_project() {
  mkdir -p "$DIR"
  git -C "$DIR" init  # ← Fails if already a git repo
  ...
}
```

**Fix:** Explicit cleanup before creation:

```bash
# ✓ Correct: guaranteed clean state
make_project() {
  rm -rf "$DIR"
  mkdir -p "$DIR"
  git -C "$DIR" init
  ...
}
```

### Anti-Pattern 4: Cross-Test-File Sourcing

**Symptom:** Sourcing a test file to reuse its helpers executes its tests as a side effect and may corrupt state.

```bash
# ✗ Wrong: sources a test file to get its helpers
source "$SCRIPT_DIR/test_draft_workflow.sh"
```

**Fix:** Move the shared helper to `tests/lib/` and source it from there in both files.

---

## Test Structure Template

```bash
#!/usr/bin/env bash
# tests/test_example.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../scripts/example.sh"

# Shared fixtures — source only from tests/lib/
source "$SCRIPT_DIR/../tests/lib/git_fixtures.sh"
# source "$SCRIPT_DIR/../tests/lib/session_fixtures.sh"  # if needed

PASS=0
FAIL=0
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_test() {
  echo "[ $1 ]"
  $1 || true
}

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

## Debugging Test Failures

### Symptom: Test Passes in Isolation, Fails in Sequence

**Likely cause:** State pollution from previous test.

**Debug steps:**
1. Run the full test suite and note which test fails
2. Run only the failing test — it should pass
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
- [ ] Sources only from `tests/lib/` — no sourcing of other test files
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
