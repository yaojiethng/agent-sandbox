# Study: test-suite complexity audit (M3.1 - read-through, phase 0)

## Status

Active.

## Context

The last open M3.1 task is the test-suite read-through. Before reading every test file, the operator asked for an uncomplect audit of the test harness and every test file: parse the mechanism and the suite for sources of complexity, and name which findings are anomalous. This document records the audit and the resolutions that followed. The mechanism write-up that the read-through phase 1 produces is [`docs/development/test_harness_mechanism.md`](../../docs/development/test_harness_mechanism.md).

## Method

The audit applied the uncomplect lenses to the harness: Hickey's complection table (what is braided), Ousterhout's depth (what removes more complexity than it adds), and Young's deletability (what can be removed). It read the runner (`scripts/run_tests.sh`), the shared helpers (`tests/libs/test_common.sh`), the self-test, the test-side gates, and a structural scan of the 58 test files.

## Complection map

| Concern | Braided together | Independent values | Evidence |
|---|---|---|---|
| Unit-result transport | the pass/fail/skip fact with its printed presentation | the fact, the presentation | `test_common.sh` wrote PASS/FAIL markers; the runner re-derived counts by grep |
| Skip status | a counted, meant-to-be-temporary state with no producer | the skip fact | no `skip()` existed; the runner hard-failed on any skip |
| Assertion vocabulary | raw `pass`/`fail` and the `assert_*` helpers, with no governing rule | one authoring rule | 41 files mix them; raw calls outnumbered the helpers |
| Registration shape | "what a `run_test` registration looks like" defined in two tools | the shape | the runner's inline awk and the liveness gate's grep |
| Worker to parent handshake | the result with its transport | result, transport | a positional four-integer record |
| Order-independence probe | the probe with the production vocabulary | the probe, the vocabulary | `REVERSE_RUN` changed `run_test` and `test_done` semantics |

## Findings and resolutions

F1. The order-independence gate was a landed-but-unowned leftover. An earlier idea to run the unit tests in a random execution order was not passed through as a feature; what survived was a deterministic reversed-order comparison gate that no Makefile target, hook, or script ever invoked. It contradicted its own claim ("order independence is proven, not assumed") because it was never run. Resolution: the gate was deleted and `REVERSE_RUN` was stripped from the shared helpers. Order independence already holds by construction: each test runs in its own subshell with a fresh fixture, so shell state cannot leak between tests.

F2. Skipping was intentional but the mechanism was underbuilt. `testing_policy.md` listed `skip()` as a helpful vocabulary while it did not exist, and the runner hard-failed on any skip. The intended model: a skip is valid for wip or mid-milestone work when the subject is not ready (an unstubbed docker operation, a missing dependency), and is resolved so skips trend to zero. Resolution: `skip()` was implemented as a real producer; a skipped unit is counted and reported as a warning, never a failure; the docs now agree.

F3. Two assertion idioms coexist with no governing rule; `pass` and `fail` carry two meanings through an in-shell mode flag. The suite is green and the labels were already audited, so there is no wrong-verdict risk. Resolution: recorded as a note; the helpers' header was reworded so it calls them "one way to assert," not "the standard way."

F4. The unit-result transport hid a silent-green hazard. Counts came from re-parsing the printed markers, so a marker-format drift made every count zero while the run still exited 0. Resolution: counts now ride an authoritative, self-describing `UNIT:` report the file must emit; a missing or malformed report is a hard failure, and the runner's `no-report` and `zero-unit` cases fail loudly. The failure count also rides the file's real exit status, which cannot drift.

F5. The registration shape was defined in two tools. The two checks are complementary and the louder of them backstops a shape drift, so there was no silent risk, but the duplication was real. Resolution: the liveness gate now owns the whole registration contract (unregistered, dangling, and dead-after-`test_done`); the runner's inline scan was deleted.

F6. The worker-to-parent record was a positional protocol. The reader and writer are the same file in the same run, so there is no cross-version contract to version. Resolution: no version field. The record became self-describing key-value and the reader validates it strictly; a malformed record is a loud failure.

## Verdict

The harness is more complicated locally than it needs to be for the risk it guards, but not badly so. The machinery exists to serve one invariant: a trustworthy green or red signal from a hermetic, dependency-free bash suite. The audit removed the one leftover, built the one intended-but-missing feature, and made the result path loud by construction. No finding is left open.

## Unknowns ledger

Known facts: the runner behavior, the unit accounting, the registration contract, and the assertion vocabulary, each read from source.

Known unknowns: the full inventory of every test file's assertions and mechanisms. That is the subject of the read-through phases 2 to 4.

Suspected unknown unknowns: whether any external consumer reads the `UNIT:` report or the worker record in a form a stricter shape would break. Both are internal to the harness and the runner.
