---
name: testing
description: agent-sandbox's testing convention - the suite and the lint umbrella, the judgements a test answers to, the patterns for writing one here, and the checks before a change closes. Use when writing, changing or reviewing a test, deciding where it belongs, or closing a change to tested code.
---

# testing

A change is verified by the project's suite: `make test` runs `scripts/run_tests.sh` over `tests/test_*.sh`, and `bash scripts/lint.sh` runs the gates. The harness's mechanism - discovery, parallel dispatch, the result protocol, the unit contract - is [`docs/development/test_harness_mechanism.md`](../../../docs/development/test_harness_mechanism.md).

## Judgements

A test's quality is judged, not gated; no cheap check detects a breach. These are the standards a test answers to.

- **Isolation.** Every test starts from state it alone created, and nothing from a sibling test, the user's environment or a path outside its fixture decides its result. The harness approximates this: `run_test` runs each test in a fresh subshell with its own `FIXTURE_DIR`. True isolation would need separate environments and post-run reconciliation, which the harness does not have, so this stays a judgement.
- **Clean before create.** A helper removes stale state before it builds, so a re-run cannot inherit an earlier run's debris.
- **No shared state between calls.** A helper call preserves what an earlier call created unless destroying it is the test's purpose.
- **Self-contained files.** A test file sources only `tests/libs/`; it never sources another test file, because that file's tests would run as a side effect.
- **Tests arrive with the code.** Any function with meaningful branching, error handling, or external dependencies gets tests, produced alongside the implementation rather than deferred.
- **Where a test belongs.** A seam of our own maintained code with a callable API is tested directly under `tests/test_*.sh`, in the suite `make test` runs. A knowledge test is the last resort for a seam the harness cannot call - an external binary or network service, or legacy code mid-refactor whose current behaviour is being documented - and is never a source of truth for our own behaviour. A flow that cannot run in the unit harness but is worth keeping goes to `tests/integration/`. When a mock makes a seam callable, promote it to a unit test.

## Where to look

| File | Open when |
|---|---|
| [`patterns/fixtures.md`](patterns/fixtures.md) | you create, name or clean a fixture, or share a helper between files |
| [`patterns/structure.md`](patterns/structure.md) | you shape a test file, name it, or decide how many units it holds |
| [`patterns/assertions.md`](patterns/assertions.md) | you choose what a unit asserts |
| [`patterns/dispatch-mocks.md`](patterns/dispatch-mocks.md) | you test a CLI dispatch layer |
| [`patterns/debugging.md`](patterns/debugging.md) | a test fails and the cause is not obvious |
| [`references/test-homes.md`](references/test-homes.md) | you choose between the unit suite, `tests/knowledge/` and `tests/integration/` |

The fill-in file is [`assets/test-file-template.md`](assets/test-file-template.md).

## Before you commit the test

- The placement judgement decided the home.
- The fixture comes from `FIXTURE_DIR` or `get_fixture_dir`, never a bare `mktemp -d`; the allocator tears it down, so the test carries no `trap ... EXIT`.
- Every shared helper is sourced from `tests/libs/`; no test file sources another test file.
- One unit per behaviour, and the assertion states the meaning ([`patterns/assertions.md`](patterns/assertions.md)).
- Every `test_*()` carries exactly one `run_test` in the same file; the liveness gate is the check.
- The failure message says what went wrong, and an assertion that pins a behaviour names the record that explains it.
- `make test` passes clean with the new test in place.

## Before you close the change

A change to a library or script is not complete until its tests are reviewed and the suite is green. Running a subset of test files is not sufficient.

- Run `grep -rl "<changed file>" tests/`, read every file it returns, and update any test case the change invalidates or leaves insufficient - in the same change, not a follow-up. This covers renames, interface changes, flag additions and behavioural fixes; an internal refactor that keeps external behaviour may still be checked.
- Run `make test`; the suite reports `failed 0`.
- When the change touches test files, run `make test-liveness`; a finding is a defect to fix in the same change.
- A handover or finding does not claim a behaviour branch no test exercises. Where a branch is untested, state why at the code, per [`patterns/structure.md`](patterns/structure.md).
- An output-contract change produces a propagation checklist per the [`propagation-check`](../../../src/reasoning/agent/skills/propagation-check/SKILL.md) skill.
