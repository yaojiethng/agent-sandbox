# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: test quality)
**Type:** Impl
**Status:** Closed

## Objective

Delete the last remaining sed-extraction probe (`template_version_probe_real` in `tests/test_onboard.sh`) and source `scripts/onboard.sh` directly, per the roadmap open item surfaced in handover `20260901-10`.

## Scope

The probe extracted the `template_version()` body from `scripts/onboard.sh` with sed and eval'd it in a subshell, breaking silently on function renames. `onboard.sh` is already sourced in-process by this test file (dual-use rule 1.11 guard), so the probe was redundant: call `template_version` on the shipped template directly.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | No `template_version_probe_real` or sed-extraction probe remains in `tests/test_onboard.sh` | grep | Agent -- pass |
| AC2 | `test_template_version_real_makefile_template_parses` passes via the in-process call | full suite | Agent -- pass (731/731) |
| AC3 | Roadmap open item closed; AGENT_FEEDBACK dual-use guards entry updated | grep | Agent -- pass |

## Completed

| File | Change |
|---|---|
| [`tests/test_onboard.sh`](tests/test_onboard.sh) | Probe function deleted; the test calls `template_version` in-process on the shipped `Makefile.template` |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Open item marked done |
| [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) | Dual-use guards entry: follow-up recorded as completed; extraction layer fully retired |

## Deferred items

None.

## What's Next

Next queued iteration: architecture-doc + `security.md` staleness sweep with an audit-effectiveness comparison report.
