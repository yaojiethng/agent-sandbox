# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Open

## Objective

U5 of the unified test-harness improvement plan: assert-the-meaning labels where they disambiguate a failure.

## Decision recorded

A full scan of the 419 assertions in `tests/test_*.sh` found the checklist item already satisfied: zero assertions use a helper's default label, zero pass a redundant default-string label, and every sampled label names the behavior under test. The survey's study-phase fact ("mostly default labels" for assert_eq/assert_contains/assert_rc) is stale for the current suite. U5 is therefore a verification unit: it records the audit and pins the convention in testing-conventions so future assertions keep the behavioral-label requirement.

## Acceptance criteria

Suite green; lint Clean; the label convention documented; the audit result recorded.

## Hot files

| File | Why in scope |
|---|---|
| `docs/development/testing-conventions.md` | The assert-the-meaning label convention. |

## What's Next

U6 (order-independence verification probe), U7 (final per-assertion sweep).
