# Handover 20260901-08 — impl runner self-test residual risk closure

**Milestone:** M2.6 - Session Persistence
**Type:** impl
**Status:** Closed
**Session date:** 2026-09-01

## Objective

Close the residual risk recorded in AGENT_FEEDBACK `2026-08-21` ("Marker-based
pass/fail counting made silent tests invisible", state: mitigated): the
runner counts failures by grepping captured output for markers, so "a second
output-format drift reintroduces the class. A runner self-test (feed it a
synthetic PASS/FAIL stream, assert counts) would lock the contract."

Orientation found the self-test already exists (`tests/test_runner_selftest.sh`,
present since the repo baseline) and covers five contract cases: all-pass
counting, fail counting, marker-less crash (silent zombie), SKIP-as-failure
policy, aggregate sums. This iteration extends it to the remaining contract
points the recorded zombie class actually exercised, then retires the
feedback entry per the files' own policy (delete when resolved).

## Scope

- Extend `tests/test_runner_selftest.sh`:
  - assertion-less `run_test` fails and `test_done` emits the exact `  FAIL:`
    marker the runner greps (locks both halves of the landed mitigation),
  - the recorded zombie patterns: undefined function (exit 127) and a test
    whose only branch was `cmd && pass` (fails under `set -e` semantics at
    end-of-file),
  - multi-FAIL counting (2 failed),
  - FAIL marker with rc 0 still counts as failure (markers trump exit code).
- Retire the AGENT_FEEDBACK entry (state mitigated → resolved by this lock);
  milestone-close compaction records it in the changelog.
- Full suite run to confirm green.

Out of scope: runner behavior changes — this locks the existing contract.

## Acceptance Criteria

- AC1: New cases pass; full `make test` green.
- AC2: Each recorded zombie class (undefined fn, crashed fixture, `cmd && pass`)
  has a named case in the self-test.
- AC3: AF entry retired; handover closed in the delivery commit (`feat:`).

## Completed

- Orientation: a runner self-test already existed (`tests/test_runner_selftest.sh`,
  present since the repo baseline) covering five cases — the recorded
  residual-risk note was partially stale; the specific zombie patterns and
  the marker-emission half of the mitigation were untested.
- Extended the self-test from 8 to 17 assertions (cases 6–9): assertion-less
  `run_test` + `test_done` marker emission; `cmd && pass` and exit-127
  zombie patterns reported by name; multi-FAIL counting; FAIL-marker-with-
  rc-0. Self-test green 17/0/0.
- Full suite: 770 tests / 43 files, 703 passed, 67 failed — the 67 are
  pre-existing docker-absence failures (12 docker/trace files; baseline
  stash-check shows identical 67 without this change; +9 passing from the
  new cases).
- AC1 ✅ AC2 ✅ (each recorded zombie class has a named case).
- Retired the AGENT_FEEDBACK `2026-08-21` marker-counting entry (resolved:
  durable fix landed `20260821-14`, residual risk now locked). Per file
  policy the entry is deleted; **note for milestone-close compaction:
  record this resolution in the changelog**.
- AC3: delivery commit `feat:` with this handover.

## Findings

- The self-test existed but the feedback entry's residual-risk sentence
  predates it; the entry was never reconciled when the selftest landed.
  Lesson (existing gotcha family): reconcile feedback entries against the
  current tree before acting on them.

## What's Next

- Both autonomous iterations (07, 08) complete — reporting to the operator.
