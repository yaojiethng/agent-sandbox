# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Closed

## Objective

Give the runner's rc-driven test-file failures an accompanying reason. When a test file exits non-zero without a `FAIL:` marker (a crash or an uncaught non-zero command), the runner prints `FAIL <file>` but the `grep "^  FAIL:"` reason list is empty. This is robustness leftover 3 of 3, run under the operator's advance close authorization (Mode B).

## Decided approach

In `scripts/run_tests.sh`, the per-file failure report already distinguishes marker-driven failures from crashes only by an empty reason block. Add a fallback reason when the file failed with no `FAIL:` marker: report the exit code and that no marker exists. Applied to the default (VERBOSE=0) and VERBOSE=1 branches; VERBOSE=1 excludes the 124-timeout path (a timeout already prints its own `TIMEOUT` line and is not a crash). In VERBOSE=0 the crash branch is only reached when RC is neither 0 nor 124, so no extra guard is needed there.

The reason line uses the existing two-space-dash reason prefix, so it reads consistently with the `FAIL:` reasons and is not counted as a unit marker (counting reads the `.record` file, not stdout).

## Acceptance criteria

A marker-less non-zero-exit file reports `FAIL <file>` plus a reason naming the exit code; the marker-driven path is unchanged; the unit count stays 712; selftest (extended crash case) 16/16; suite 712/712; order gate 58/58; lint Clean; roadmap row flips to `[x]`.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Fallback reason line, not structured output | the reason text is human-facing and reuses the existing reason-prefix shape; no new machine-readable surface to page parsers | roadmap row |

## Completed

- [x] Runner appends a reason under `FAIL <file>` when the file failed with no `FAIL:` marker (VERBOSE=0 and VERBOSE=1; VERBOSE=1 excludes the 124-timeout path)
- [x] Extended the selftest crash case to pin the reason line; unit count unchanged
- [x] Verified: 712/712 suite green (10s P8); order gate 58/58; selftest 16/16; lint Clean

## Next steps

All three robustness leftovers are landed and closed. M3.1's open research is the operator test-suite read-through onboarding task; the harness-robustness work is done.
