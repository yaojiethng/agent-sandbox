# Agent Handover

**Session date:** 2026-07-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Housekeeping — Defer AC-machinery discussion to M3, add M3 process items
**Status:** Closed

## Objective

Route the AC-machinery policy discussion finding from `20260722-05` to M3, and add three operator-specified process items to the M3 checklist in `roadmap_future.md`.

## Scope

- `devlog/roadmap_future.md` M3 section — three checklist additions (operator phrasing preserved):
  1. Converting the roadmap to linear-style task tracking
  2. Moving next-session seed out of handover and into a next-task subheader in the sub-milestone
  3. AC-machinery policy discussion for chores, doc, plan type sessions
- `devlog/roadmap.md` M2.7 section — remove the "Deferred from M2.7" block (scope expanded mid-session):
  - Harness-sig → `roadmap_future.md` Harness Packaging and Versioning section (its declared destination)
  - Process improvements → `roadmap_future.md` M9 Governance Hardening
- `devlog/roadmap.md` Deferred section — move incomplete Doc bloat item to `roadmap_future.md` Deferred (Unplanned); drop the completed Docs-directory-restructuring entry (recorded in `20260722-04` handover); docker compose race item stays
- `devlog/roadmap.md` "Addressed in upcoming milestones" section — removed; host-side harness staleness rolled under the harness-sig point (the Packaging section already carries the problem statement)

The closed handover `20260722-05` is not edited — the finding's rerouting is recorded here and in the roadmap, per the carry-forward escalation rule (deferred items not picked up in the immediately following session escalate to a named roadmap entry).

## Carried forward

| Item | From handover |
|---|---|
| AC-machinery policy discussion (fails in practice for doc-only interactive sessions) | `20260722-05-design-security_model_reframe.md` — Mid-session findings |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Three items present as separate checklist entries in M3 section of `roadmap_future.md` | `grep -c "linear-style task tracking\|next-task subheader\|AC-machinery" devlog/roadmap_future.md` = 3 | Accepted — Operator |
| 2 | "Deferred from M2.7" block removed from `roadmap.md`; both items present in `roadmap_future.md` destinations | `grep -c "Deferred from M2.7" devlog/roadmap.md` = 0; harness-sig in Packaging section, process improvements in M9 | Accepted — Operator |
| 3 | Doc bloat relocated to `roadmap_future.md` Deferred (Unplanned); "Addressed in upcoming milestones" section removed | `grep -c "Doc Bloat" devlog/roadmap_future.md` >= 1; `grep -c "Addressed in upcoming" devlog/roadmap.md` = 0 | Accepted — Operator |

## Hot files

| File | Why in scope |
|---|---|
| `devlog/roadmap_future.md` | M3 checklist additions |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| AC-machinery discussion deferred to M3, not next session | Operator direction; grouped with two related process items | `roadmap_future.md` M3 |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `devlog/roadmap_future.md` | Three process items added to M3 checklist; harness-sig added to Harness Packaging section as M2.7-deferred follow-on; process improvements added to M9; Doc Bloat subsection added under Deferred (Unplanned) |
| `devlog/roadmap.md` | "Deferred from M2.7" block removed (both items relocated); Doc bloat and completed Docs-restructuring entries removed from Deferred section; "Addressed in upcoming milestones" section removed (rolled under harness-sig) |

## Deferred items

None.

## Next session

M2.6.4 — Mount Model Design Session (decision phase): resolve the 7 remaining design questions in `devlog/roadmap.md`.
