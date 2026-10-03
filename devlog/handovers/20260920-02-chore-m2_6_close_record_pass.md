# Agent Handover

**Date:** 2026-09-20
**Milestone:** M2.6 - Session Persistence
**Type:** chore
**Status:** Closed

## Objective

Run the M2.6 close record pass. Write the write-backs the 2026-09-20 check-in flagged and the operator assigned: the Milestone Summary rows (Option A -- rows only), the GOTCHAS commit-hash citation, the pre-fold changelog derivations, the missing settled-design implementation citations, and the feedback backlog's missing roadmap home.

## Scope

Per the operator's instruction "chore commit, fix discrepancies 1 2 3 4 6": the five write-backs below land as one chore commit. Option A keeps the M2 section in `roadmap.md`; M3 is not promoted and stays `Not started`. Discrepancy 5 (the `tests/test_draft_workflow.sh` split has no roadmap row) stays open until the split iteration lands. The `run_test` `set -e` suppression (inventory item 2) is the next iteration.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `roadmap.md` summary rows M2 and M2.6 read `Complete`; M3 stays `Not started`; the M2 section remains | `grep -n "M2 - Reasoning\|M2.6 - Session" devlog/roadmap.md` | accepted |
| AC2 | GOTCHAS `2026-09-20` cites `a1684f3`; no `ea080bf` remains in the repo | `grep -rn "ea080bf" .` | accepted |
| AC3 | Both pre-fold changelog derivations carry `[SUPERSEDED in M2.6]` tags | `grep -n "SUPERSEDED in M2.6" devlog/changelog.md` | accepted |
| AC4 | Both settled 20260831 design docs cite their implementation handover; handover `20260904-07` references the `-settled-` name | `grep -rn "Implemented by" devlog/discussions/20260831-design-settled-*.md`; `grep -n "design-settled" devlog/handovers/20260904-07*.md` | accepted |
| AC5 | `roadmap_future.md` M3 carries the skill-maintenance backlog row | `grep -n "Skill-maintenance" devlog/roadmap_future.md` | accepted |
| AC6 | The five AGENT_FEEDBACK entries for discrepancies 1-4 and 6 read `state: closed`; the Markdown lint gate passes | `make lint` | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](devlog/roadmap.md) | Summary rows M2 / M2.6 (AC1) |
| [`devlog/GOTCHAS.md`](devlog/GOTCHAS.md) | `2026-09-20` hash citation (AC2) |
| [`devlog/changelog.md`](devlog/changelog.md) | Pre-fold derivations (AC3) |
| [`devlog/discussions/20260831-design-settled-image_and_harness_version_identity.md`](devlog/discussions/20260831-design-settled-image_and_harness_version_identity.md) | Missing implementation citation (AC4) |
| [`devlog/discussions/20260831-design-settled-session_identity_prefactor.md`](devlog/discussions/20260831-design-settled-session_identity_prefactor.md) | Missing implementation citation (AC4) |
| [`devlog/handovers/20260904-07-impl-harness_version_identity.md`](devlog/handovers/20260904-07-impl-harness_version_identity.md) | Pre-rename `-active-` design reference (AC4) |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | Skill-maintenance backlog row (AC5) |
| [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) | Five entries to close (AC6) |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Option A for discrepancy 1 | Operator choice: rows only, no top-level close, no M3 promotion | this handover |
| `run_test` and the test split are the next iteration | Operator's "After that" line | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Both settled designs already have implementation handovers (`20260831-07`, `20260904-07`); the gap is citations, not implementation. The `20260904-07` handover cites the pre-rename `-active-` name, which no longer resolves | steering | corrected -- citations added, handover reference fixed |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | M2 and M2.6 summary rows -> `Complete` |
| `devlog/GOTCHAS.md` | `ea080bf` -> `a1684f3` in the `2026-09-20` entry |
| `devlog/changelog.md` | `[SUPERSEDED in M2.6]` tag on both pre-fold derivation claims |
| `devlog/discussions/20260831-design-settled-image_and_harness_version_identity.md` | `Implemented by` citation to handover `20260904-07` |
| `devlog/discussions/20260831-design-settled-session_identity_prefactor.md` | `Implemented by` citation to handover `20260831-07` |
| `devlog/handovers/20260904-07-impl-harness_version_identity.md` | `-active-` design reference -> `-settled-` with correction tag |
| `devlog/roadmap_future.md` | M3 gains the skill-maintenance backlog row |
| `devlog/AGENT_FEEDBACK.md` | Five entries -> `state: closed` |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Full M2 top-level close (changelog entry, section removal, M3 promotion) | Operator Option A | not scheduled |
| `run_test` `$1 \|\| true` `set -e` suppression | Operator "After that" line | next iteration |
| Split `tests/test_draft_workflow.sh` | Operator "After that" line | next iteration (M3 backpressure group) |

## What's Next

The next iteration resolves inventory item 2: the `run_test` `$1 || true` `set -e` suppression, then splits `tests/test_draft_workflow.sh` into the M3 backpressure group. The test split's missing roadmap row (discrepancy 5) lands with that iteration.

[CORRECTION -- 2026-09-21]: the check-in survey's explanatory entries (roadmap-state-lagged, gotcha-commit-hash, changelog-identity, settled-designs-without-citation, feedback-backlog-has-no-home) were already closed and were deleted by the M3 cleanup pass as resolved historical records. The run_test `$1 || true` set-e suppression entry was closed (its fix landed) and deleted. Their durable resolutions remain the operative guidance; no active backlog entry survives.
