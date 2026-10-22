# Debugging patterns

Open this when a test fails and the cause is not obvious. Each pattern names the symptom, the likely cause, and the steps that settle it.

## Test passes in isolation, fails in sequence

**Likely cause:** the test reads state left by a file-scope scaffold or a sibling test. Each test already runs in its own subshell, so environment, working directory, globals and traps cannot leak; the remaining coupling is file-based.

1. Run the full suite and note which test fails.
2. Look for a `$FIXTURE_ROOT`-scoped scaffold a test mutated, or a file one test wrote and another read (`test.diff` is the recorded example).
3. Make the failing test self-contained: build its input under its own `$FIXTURE_DIR`, or rebuild the scaffold inside the test.
4. A test that depends on what a sibling changed is a smell. Fix the test, do not restore the coupling.

## Test fails on a re-run in the same session

**Likely cause:** the test does not clean up its own state.

1. Run the test twice in the same shell.
2. Check whether the second run fails.
3. Look for a git tag not deleted, a directory not removed, a file appended instead of overwritten.

## Test behaviour changes with test order

**Likely cause:** tests share state through a common path.

1. Reorder the `run_test` calls by hand.
2. Note which orderings fail.
3. Look for a hardcoded path, a helper that does not scope its paths, or a global not reset between tests.
