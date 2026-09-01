# Testing Conventions

Patterns, anti-patterns, templates, and checklists for writing tests in this project. For policy and rules, see [`testing_policy.md`](testing_policy.md).

---

## Fixture Management Patterns

### Pattern 1: Unique Paths Per Test

Each test function uses unique fixture paths derived from the test name:

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

When a helper creates subdirectories, use paths unique to the caller's SANDBOX_DIR, not shared paths:

```bash
# Right: sandbox path is unique per SANDBOX_DIR
make_session() {
  local SANDBOX_DIR="$1"
  local SANDBOX="$SANDBOX_DIR/sandbox-work"
  rm -rf "$SANDBOX"
  ...
}

# Wrong: sandbox path is shared across all tests
make_session() {
  local SESSION="$1"
  local SANDBOX="$FIXTURE_DIR/sandbox-${SESSION}"
  ...
}
```

### Pattern 3: Cleanup in Reverse Order

When tests create nested state, clean up in reverse order of creation. The `FIXTURE_DIR` trap handles top-level cleanup; helpers clean only what they own.

---

## Common Anti-Patterns

### Anti-Pattern 1: Destructive Reset After Creation

**Symptom:** Test passes in isolation, fails in sequence.

```bash
# Wrong: creates session, then deletes it
make_session() {
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION"
  mkdir -p "$SESSION_DIR/patches"
  rm -rf "$SANDBOX_DIR/.workspace"    # Deletes what we just created!
  mkdir -p "$SANDBOX_DIR/.workspace"
  echo "$CHECKPOINT_TAG" > "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"
}
```

**Fix:** Create parent directories first, then populate:

```bash
make_session() {
  mkdir -p "$SANDBOX_DIR/.workspace"
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION"
  rm -rf "$SESSION_DIR"
  mkdir -p "$SESSION_DIR/patches"
  echo "$CHECKPOINT_TAG" > "$SANDBOX_DIR/.workspace/checkpoint-latest.ref"
}
```

### Anti-Pattern 2: Shared Temporary Paths

**Symptom:** Tests interfere with each other when run in sequence.

```bash
# Wrong: multiple tests use same sandbox path
make_session() {
  local SANDBOX="$FIXTURE_DIR/sandbox-main"
  ...
}
```

**Fix:** Scope temporary paths to the test's fixture directory:

```bash
make_session() {
  local SANDBOX_DIR="$1"
  local SANDBOX="$SANDBOX_DIR/sandbox-work"
  ...
}
```

### Anti-Pattern 3: Silent State Accumulation

**Symptom:** Test passes first time, fails on re-run or in different order.

```bash
# Wrong: assumes directory is empty
make_project() {
  mkdir -p "$DIR"
  git -C "$DIR" init
  ...
}
```

**Fix:** Explicit cleanup before creation:

```bash
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
# Wrong
source "$REPO_ROOT/test_draft_workflow.sh"
```

**Fix:** Move the shared helper to `tests/libs/` and source it from both files.

### Anti-Pattern 5: Testing Absence of a Wrong Thing

**Symptom:** Test checks for absence of a specific string variant when a positive assertion already covers the invariant. Fragile — there are infinite variants of "wrong." If the docstring says "required," it cannot also claim a default; testing "required" is sufficient.

```bash
# Wrong — fragile, infinite wrong variants
if grep -q 'default: opencode' "$SCRIPT"; then
  fail "should not claim a default"
elif grep -q 'required' "$SCRIPT"; then
  pass "documents as required"
fi

# Right — positive assertion only; "required" and "default" are mutually exclusive
if grep -q 'required' "$SCRIPT"; then
  pass "documents as required (no default)"
else
  fail "does not document as required"
fi
```

---

## Test Structure Template

```bash
#!/usr/bin/env bash
# tests/test_example.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$TEST_DIR/../scripts/example.sh"

# Shared fixtures - source only from tests/libs/
source "$TEST_DIR/libs/test_common.sh"
source "$TEST_DIR/libs/git_fixtures.sh"

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# -------------------------
# Local helpers (not shared across files)
# -------------------------

make_fixture() {
  local DIR="$1"
  rm -rf "$DIR"
  mkdir -p "$DIR"
  ...
}

# -------------------------
# Tests
# -------------------------

test_example_feature() {
  local P="$FIXTURE_DIR/example_p"
  local S="$FIXTURE_DIR/example_s"
  make_fixture "$P"
  make_fixture "$S"
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
4. Check for: shared fixture paths, missing `rm -rf` in helpers, global state
   not cleaned up

### Symptom: Test Fails on Re-run in Same Session

**Likely cause:** Test doesn't clean up its own state.

**Debug steps:**
1. Run the test twice in the same shell
2. Check if the second run fails
3. Look for: git tags not deleted, directories not removed, files appended
   instead of overwritten

### Symptom: Test Behavior Changes Based on Test Order

**Likely cause:** Tests share state through a common path.

**Debug steps:**
1. Shuffle test order (manually reorder `run_test` calls)
2. Note which orderings fail
3. Check for: hardcoded paths, helpers that don't scope paths, global
   variables not reset between tests

---

## Mock Infrastructure for Dispatch Tests

When testing a CLI dispatch layer that routes flags to subcommand scripts:

1. **Override `exec()`** with a bash function that captures invocations:

```bash
exec() { echo "capture: exec $*"; }
```

2. **Create mock scripts** in a temp directory and point `SCRIPTS` at it:

```bash
MOCK_DIR=$(mktemp -d)
cat > "$MOCK_DIR/start_agent.sh" << 'SCRIPT'
echo "capture: MOCK start_agent.sh $*"
SCRIPT
chmod +x "$MOCK_DIR/start_agent.sh"
SCRIPTS="$MOCK_DIR"
```

3. **Resolve placeholder variables** before sourcing the harness:

```bash
resolved=$(mktemp)
sed "s|@@AGENT_SANDBOX_REPO@@|$REPO_ROOT|g" \
  "$REPO_ROOT/scripts/agent-sandbox.sh" > "$resolved"
source "$resolved"
rm -f "$resolved"
```

4. **Parse captured output** by filtering stdout lines with a marker:

```bash
CAPTURED=()
stdout=$(main "$@" 2>/dev/null) || true
while IFS= read -r line; do
  if [[ "$line" == capture:* ]]; then
    CAPTURED+=("${line#capture: }")
  fi
done <<< "$stdout"
```

This pattern covers `exec` calls, subprocess scripts, and sourced function calls in one harness.

---

## Checklist for New Tests

Before committing a new test:

- [ ] **Placement decided per `testing_policy.md` Test Placement rule**: our maintained seam with an API → `tests/test_*.sh` under `make test`; unmodifiable external seam / legacy mid-refactor → `tests/knowledge/knowledge_*.sh`; still-not-runnable end-to-end flow → `tests/integration/`
- [ ] Uses `mktemp -d` for fixture directory
- [ ] Has `trap 'rm -rf "$FIXTURE_DIR"' EXIT` for cleanup
- [ ] All helper functions clean their inputs before creating state
- [ ] No hardcoded paths outside fixture directory
- [ ] Sources shared fixtures from `tests/libs/` — no sourcing of other test files
- [ ] Sources `test_common.sh` for `pass()`/`fail()`/`skip()`/`run_test()`/`test_done()`
- [ ] Test passes when run in isolation
- [ ] Test passes when run after every other test in the file
- [ ] Test passes when run twice in a row
- [ ] `make test` passes clean after the new test is added
- [ ] **`make test` invariant held**: the unit suite reports `failed 0, skipped 0`; no `skip()` in a `tests/test_*.sh` file
- [ ] Test failure message clearly describes what went wrong

## Checklist for Lib and Script Changes

Before marking a lib or script change complete:

- [ ] `grep -rl "<changed file>" tests/` run; all returned files reviewed for staleness
- [ ] Any stale test cases updated in the same change
- [ ] `make test` passes clean
