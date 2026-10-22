---
name: testing
description: agent-sandbox's testing convention - the suite and the lint umbrella, the judgements a test answers to, and the patterns for writing one here. Use when writing, changing or reviewing a test, or deciding where it belongs.
---

# testing

A change is verified by the project's suite: `make test` runs `scripts/run_tests.sh` over `tests/test_*.sh`, and `bash scripts/lint.sh` runs the gates. The harness's mechanism - discovery, parallel dispatch, the result protocol, the unit contract - is [`docs/development/test_harness_mechanism.md`](../../../docs/development/test_harness_mechanism.md).

## Judgements

A test's quality is judged, not gated; no cheap check detects a breach. These are the standards a test answers to.

- **Isolation.** Every test starts from state it alone created, and nothing from a sibling test, the user's environment or a path outside its fixture decides its result. The harness approximates this: `run_test` runs each test in a fresh subshell with its own `FIXTURE_DIR`. True isolation would need separate environments and post-run reconciliation, which the harness does not have, so this stays a judgement.
- **Clean before create.** A helper removes stale state before it builds, so a re-run cannot inherit an earlier run's debris.
- **No shared state between calls.** A helper call preserves what an earlier call created unless destroying it is the test's purpose.
- **Self-contained files.** A test file sources only `tests/libs/`; it never sources another test file, because that file's tests would run as a side effect.

## Patterns

Each pattern states a situation and the form to use instead. Open the file the situation names.

| File | Open when |
|---|---|
| [`patterns/fixtures.md`](patterns/fixtures.md) | you create, name or clean a fixture, or share a helper between files |
| [`patterns/structure.md`](patterns/structure.md) | you shape a test file or decide how many units it holds |
| [`patterns/assertions.md`](patterns/assertions.md) | you choose what a unit asserts |
| [`patterns/dispatch-mocks.md`](patterns/dispatch-mocks.md) | you test a CLI dispatch layer |

The fill-in file is [`assets/test-file-template.md`](assets/test-file-template.md).

The placement rules and the debugging guide still live in the documents the migration is emptying: [`docs/development/testing_policy.md`](../../../docs/development/testing_policy.md) and [`docs/development/testing-conventions.md`](../../../docs/development/testing-conventions.md).
