# Testing Conventions

The pattern catalogue, the test-file template and the dispatch mocks moved to the `testing` convention-skill at [`.agents/skills/testing/SKILL.md`](../../.agents/skills/testing/SKILL.md). This document is the migration bridge: it carries the debugging guide and the two checklists, which a later unit moves or retires.

For placement, the suite rules and the mechanism, see [`testing_policy.md`](testing_policy.md) and [`test_harness_mechanism.md`](test_harness_mechanism.md).

## Debugging Test Failures

### Symptom: Test Passes in Isolation, Fails in Sequence

**Likely cause:** The test reads state left by a file-scope scaffold or a sibling test. Each test already runs isolated in its own subshell, so env, cwd, globals, and traps cannot pollute; the remaining coupling is file-based.

**Debug steps:**

1. Run the full test suite and note which test fails
2. Check for a `$FIXTURE_ROOT`-scoped scaffold that a test mutated, or a file one test wrote and another reads (`test.diff` is the recorded example)
3. Make the failing test self-contained: build its own input under its own `$FIXTURE_DIR`, or rebuild the scaffold inside the test
4. A test that depends on what a sibling test changed is a smell -- fix the test, do not restore the coupling

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

## Checklist for New Tests

Before committing a new test:

- [ ] **Placement decided per `testing_policy.md` Test Placement rule**: our maintained seam with an API -> `tests/test_*.sh` under `make test`; unmodifiable external seam / legacy mid-refactor -> `tests/knowledge/knowledge_*.sh`; still-not-runnable end-to-end flow -> `tests/integration/`
- [ ] Calls `test_setup` at file scope; `run_test` allocates the per-test `FIXTURE_DIR`; extras come from `get_fixture_dir`, never a bare `mktemp -d`
- [ ] Relies on the allocator's unified teardown -- no manual `trap 'rm -rf "$FIXTURE_DIR"' EXIT`
- [ ] All helper functions clean their inputs before creating state
- [ ] No hardcoded paths outside the fixture directories
- [ ] Sources shared fixtures from `tests/libs/` -- no sourcing of other test files
- [ ] Sources `test_common.sh` for `pass()`/`fail()`/`run_test()`/`test_done()`
- [ ] The test never depends on a sibling test's written files -- any cross-test fixture is a smell; make it self-contained
- [ ] `make test` passes clean after the new test is added
- [ ] **`make test` invariant held**: the unit suite reports `failed 0`; no `skip()` in a `tests/test_*.sh` file for a fixable seam (a skip is a temporary warning, resolved short-term)
- [ ] Test failure message clearly describes what went wrong
- [ ] An assertion that pins a behaviour a future reader would be tempted to change names the record (ADR, design record, or handover decision) that explains why the behaviour is correct
- [ ] Every `test_*()` in the file is registered via `run_test`, and every `run_test` target resolves

## Checklist for Lib and Script Changes

Before marking a lib or script change complete:

- [ ] `grep -rl "<changed file>" tests/` run; all returned files reviewed for staleness
- [ ] Any stale test cases updated in the same change
- [ ] `make test` passes clean
- [ ] An output-contract change produced a propagation checklist per the [`propagation-check`](../../src/reasoning/agent/skills/propagation-check/SKILL.md) skill, covering tests, docs, and downstream consumers
