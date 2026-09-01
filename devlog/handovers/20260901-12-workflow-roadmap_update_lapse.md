# Handover 20260901-12 — study roadmap-update lapse: session audit and causes

**Milestone:** M2.6 - Session Persistence
**Type:** workflow
**Status:** Closed
**Date:** 2026-09-01

## Objective

Operator report: roadmap updates have lapsed (recorded as GOTCHAS
`2026-08-31` roadmap staleness). Two questions:

1. Does this session (`20260901-04` .. `-12`) contain such lapses — completed
   iterations that generated or completed roadmap-worthy work without a
   roadmap write-back?
2. Why does the lapse happen (mechanism, not blame), and what countermeasure
   would actually catch it?

## Acceptance Criteria

- AC1: Iteration-by-iteration audit of this session's roadmap obligations
  (generated tasks, completed tasks) with a verdict per iteration.
- AC2: Root-cause analysis grounded in the recorded workflow (where in the
  loop the write-back should have fired and what displaced it).
- AC3: Countermeasure proposal(s) presented for operator decision — policy
  text only after per-section approval.

## Completed

| Task | Evidence |
|---|---|
| Session audit vs roadmap obligations | Findings below; `devlog/roadmap.md` M2.6 lines 158–162, 208; handovers `-04`..`-11` |
| Policy-mechanism review | `iteration_policy.md` Step 7 + Steps 8–9 table row; `roadmap_policy.md` post-close bookkeeping + Roadmap-update timing rules; `handover_policy.md` Step 1 population rule |
| Countermeasure A+B implemented (operator-directed) | `iteration_policy.md` Step 7: single compaction bullet replaced by two mandatory roadmap write-back rows — completed work (compaction entry or explicit `none worked this iteration`) and generated tasks (roadmap entry, recorded destination, or `no additional tasks`); Steps 8–9 wording aligned (compaction summaries + generated-task destinations) |
| Non-ASCII resurfacing handled | AF `2026-08-09` lifted back to open with `20260901-12` resurfaced note (four section-sign references in this handover, caught by operator); scrubbed on sight |

## Findings

**Q1 — lapses within this session (`20260901-04`..`-12`): one minor, no checkbox staleness.**

| Iter | Work | Roadmap obligation | Verdict |
|---|---|---|---|
| -04 | ADR recreation + concept sweep | completed roadmap item (`roadmap.md` line 162, marked `[x]` with summary) | ✅ |
| -05 | two-container + correspondence ADRs | operator-directed new docs work; no roadmap item existed; no generated task | ✅ (invisible on roadmap, but nothing owed) |
| -06/-07/-09 | consolidation, prose, reconcile rule | chores/policy; no generated tasks | ✅ |
| -08 | runner selftest | advances the already-`[x]` hardening item; no new task | ✅ |
| -10 | runner fix + doc drift + AF reconcile | **generated follow-up task: delete the sed-extraction probe layer, source the guarded scripts directly** — recorded in handover Findings + AF entry, NOT on roadmap | ❌ lapse per the `roadmap_policy.md` Roadmap-update timing rule ("a task without a roadmap destination can fall through" — it did) |
| -11 | wrapping policy + sweep + tooling | tooling promoted in-iteration; no open generated task | ✅ |
| extra | roadmap_future M3 workflow-separation task | written to roadmap when directed | ✅ |

**Q2 — why it happens (mechanism, grounded in the recorded workflow):**

1. **The gate verifies compaction, not generation.** Step 7's roadmap activity is "propose roadmap compaction entries — for each fully-completed task group." When the iteration is not working a roadmap task group (operator-directed chore/docs/study — this entire session), compaction reads as not-applicable and is skipped wholesale, taking the *generated task?* question with it. That question lives in the roadmap-policy timing rule, which is read before roadmap tasks — never at close.
2. **Roadmap-less iterations lose the roadmap frame.** Step 1 populates scope "from the roadmap entry for the target sub-milestone." Directed work outside the task list never consults the roadmap at open, so nothing re-enters the loop until close — where no artifact asks about newly generated tasks. The `-10` lapse is exactly this shape.
3. **The lapse is invisible at the gate built to catch it.** The AC table covers the iteration's own ACs; no reviewed artifact lists "tasks generated this iteration: yes/no." The 2026-08-31 class (closed handover, open checkbox) and this session's class (generated task parked in records) both slip through the same hole: roadmap obligations are enforced by principle ("Roadmap reflects reality") plus memory, not by a reviewed artifact.

**Countermeasure proposals (operator decides; policy text only after per-section approval):**

- **A — Step 7 split** (`iteration_policy.md`, small): reword the Step 7 roadmap bullet into two mandatory rows — (a) compaction entries for completed groups, or an explicit "none worked this iteration"; (b) tasks generated this iteration, each either proposed as a roadmap entry or explicitly declared deferred/no-task. Forces the timing-rule question to Gate 3 for every iteration type.
- **B — Handover close-section field** (`handover_policy.md` template): fixed "Roadmap write-back: none / <entry>" line in the close section — the footprint becomes part of the reviewed artifact. Heavier (template change).
- **C — Mechanical check** (no policy change): `scripts/manual/roadmap_reconcile.sh` flags `- [ ]` roadmap items whose text references a handover ID whose Status is Closed (the 2026-08-31 class). Cheap, on-demand or at close.
- **D — Record only:** accept the rare lapse; this audit is the record.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Countermeasure A (Step 7 split) with B's row format; C and D rejected | the generated-task question must be a reviewed pre-close artifact; a mechanical checker would not catch destination-parking |

## What's Next

- New Step 7 rows apply from the next close (first exercised by this iteration's own close-out).
