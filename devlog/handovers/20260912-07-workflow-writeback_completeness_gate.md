# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (general cross-cutting track)
**Type:** Workflow
**Status:** Closed

## Objective
Close the roadmap-write-back gap surfaced by the gm survey after `733189b`: the Step 7 gate required row changes only for tasks touched, so a semantics overhaul of already-completed work (dry-run overhaul in `561dba7`) invalidated a done row's text ("gates on a hard image-staleness check", roadmap l.96) without any gate step requiring its correction. Widen the gate's completeness criterion and apply it retroactively.

## Scope
1. `docs/operations/iteration_policy.md` Step 7 item 2 — amended (done during scope confirmation with operator approval of the phrasing "and completed rows the change supersedes or invalidates"). Rejected phrasings: "every done row the change makes false" (STE100: nonstandard phrasing), "state `no existing rows invalidated`" (else case is obvious; no signal needed).
2. Corrective write-back: roadmap done-row "Build + dry-run interface" (l.96) — replace the retired "gates on a hard image-staleness check" statement with the current mechanism (always-rebuild + digest roundtrip gate; staleness is warning-only preflight).
3. `devlog/AGENT_FEEDBACK.md` 20260818-03 — mark closed/mitigated: the test-quality campaign (folded in `561dba7`) removed its last instance (the repo-presence file-existence loop in `test_run_agent.sh`).
4. Roadmap row for this iteration's own work (the gate amendment), per the canonical timing rule.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Step 7 item 2 states the widened criterion | offline read | pass — "and completed rows the change supersedes or invalidates" |
| AC2 | Roadmap l.96 row states the current dry-run gate mechanism; no other done row invalidated by recent changes | offline read | pass — row rewritten (always-rebuild + roundtrip gate + two-pass verification; staleness warning-only, ADR linked); sweep of done rows found no other invalidated statements (survey l.156 mount row and general-track rows unaffected) |
| AC3 | AGENT_FEEDBACK 20260818-03 status updated with the closing evidence | offline read | pass — state: closed with evidence and preserved body |

## Completed

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | Step 7 item 2: roadmap write-back now covers "completed rows the change supersedes or invalidates" |
| `devlog/roadmap.md` | Corrective write-back: "Build + dry-run interface" done row now states the current gate mechanism (roundtrip, always-rebuild, two-pass); new `[x]` row for this iteration's gate amendment |

## Deferred items
(none yet)
