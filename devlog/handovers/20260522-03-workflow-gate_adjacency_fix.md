# Agent Handover

**Date:** 2026-05-22
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Workflow
**Status:** Closed

## Objective

Disentangle `handover_policy.md` and `iteration_policy.md` after the Gate 2/3 lapse investigation (session 20260522-02) revealed they are conjoined at the operational layer. `iteration_policy.md` must own the operational flow; `handover_policy.md` must become a declarative content-rules document defining what a valid handover looks like at each workflow stage.

## Scope

**End-to-end document split.** Move all operational rules from `handover_policy.md` into `iteration_policy.md`. Rephrase remaining `handover_policy.md` content from procedural to declarative ("at Step 1, populate X" → "Pre-implementation state: X = null marker"). Gaps discovered during rule migration are logged as resolved mid-session findings and analyzed for patterns at session close.

Three sub-scopes:

1. **Move operational rules** — all `handover_policy.md` Population Rules subsections (Step 1, Step 2, During, Step 5, Step 7, Steps 8–9, Seed next session) → `iteration_policy.md` table rows. Each rule is tagged `drop` (already in the table) or `migrate` (filling a gap in the table).
2. **Rephrase `handover_policy.md`** — remove step-bound procedural language. Content rules become declarative: "The AC field has three valid states: empty (`Not yet defined.`), defined (table), resolved (each row marked)." Format sections retain procedural references for validation: "Populated at Step 1 per `iteration_policy.md`."
3. **Policy amendments** — retain and apply Amendment 1 (session type at Gate 1) and Amendment 3 (Gate 2 exit harmonization). Drop Amendment 2 ("Next: Gate N" pointers) — it reinforces the split instead of healing it.

## Carried forward

| Item | From handover |
|---|---|
| Session type must be presented at Gate 1 in `iteration_policy.md` | 20260522-02 |
| Step/Gate flow split across documents — structural fix needed, not band-aid | 20260522-02 |
| Gate 2 exit ("All criteria verified") vs Step 5 exit ("Operator confirmed") — inconsistent | 20260522-02 |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `handover_policy.md` contains no procedural population rules | `grep -c "At Step" docs/operations/handover_policy.md` → 0 | Accepted |
| 2 | Format section field entries reference `iteration_policy.md` for population timing | `grep "iteration_policy.md" docs/operations/handover_policy.md` — cross-references present | Accepted |
| 3 | Every Migrate gap report entry has a corresponding row/subsection in `iteration_policy.md` | Manual tick of 14 entries | Accepted |
| 4 | Gate 1 row includes session type presentation (Amendment 1) | `grep "session type" docs/operations/iteration_policy.md` — present in Gate 1 | Accepted |
| 5 | Gate 2 exit harmonized with Step 5 exit (Amendment 3) — both use "confirmed" + "criteria" | `grep "criteria" docs/operations/iteration_policy.md` — consistent | Accepted |
| 6 | `handover-audit.skill.md` draft created | File exists | Accepted |
| 7 | `new-session.md` Step 1 delegation path → `iteration_policy.md` | `grep "iteration_policy" agent/prompts/new-session.md` | Accepted |
| 8 | No broken cross-references to old `handover_policy.md` anchors | `grep -rn "handover_policy.md#at-session-open"` → 0 | Accepted |
| 9 | `handover_policy.md` opens with role statement | `head -3` | Accepted |
| 10 | Gate 2 action requires AC table presentation to operator | `grep "present the acceptance criteria table" docs/operations/iteration_policy.md` | Accepted |
| 11 | Step 7 and Gate 3 require AC status table with per-criterion visibility | `grep "four-column table" docs/operations/iteration_policy.md` | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | Absorbs all operational rules; receives Amendment 1 and 3 |
| [`docs/operations/handover_policy.md`](../../docs/operations/handover_policy.md) | Sheds Population Rules; reframed as declarative content rules |
| `agent/drafts/handover-audit.skill.md` | New — captures procedural rules that don't fit declarative form |
| `agent/prompts/new-session.md` | Updated Step 1 delegation path (handover_policy → iteration_policy) |

## Decisions made this session

### Gap report — rules migrating from handover_policy.md to iteration_policy.md

**Drop (already in iteration_policy.md) — no migration needed:**

| Rule | Already in |
|---|---|
| After handover draft, present scope proposal | Step 2 action |
| Exit condition: operator confirmed scope | Step 2 exit |
| No output before scope confirmed | Gate 1 |
| Replace null marker before Step 5 exits | Step 5 exit |
| Step 7 is mandatory gate | Step 7 row |
| Propose compaction entries | Step 7 action |
| Operator releases with explicit forward signal | Step 7 exit |
| Apply approved compaction | Steps 8–9 action |
| Run Trigger B if applicable | Steps 8–9 action |

**Migrate (gap in iteration_policy.md) — fill during this session:**

| Gap | Destination row |
|---|---|
| Recovery check: verify roadmap against prior handover | Step 1 action |
| Compaction check (post-Gate 3, no longer Step 1) | Step 1 action — note: compaction moved to Steps 8–9 |
| Populate Carried forward / Hot files / Session type / null markers | Step 1 action |
| If context insufficient, ask one question at a time | Step 2 action |
| Multi-unit session: spec per active unit only | Step 2 or new Step 2 rules column |
| During-session write-back (task completion, discovery, steering) | New "During the session" row needed |
| Record decisions/AC/deferrals immediately | New "During the session" row |
| Propagation replay trigger conditions | Step 7 action |
| "Packaging does not release gate" | Step 7 exit |
| Scope reconciliation | Steps 8–9 action |
| Carry-forward resolution gate | Steps 8–9 action |
| Carry-forward escalation rule | Steps 8–9 action |
| Mid-session findings triage gate | Steps 8–9 action |
| Seed next session (8 detail rules) | Steps 8–9 exit / seed subsection |

**Keep — rephrase as declarative content rules in handover_policy.md:**

| Current (procedural) | Rephrased (declarative) |
|---|---|
| "Closed handovers are immutable" | "A closed handover is a read-only record." |
| "Completed table = null marker before implementation" | "Pre-implementation state: Completed table = `No file changes yet.`" |
| "Never leave a section blank" | "Every section must contain either its canonical null marker or populated content." |
| "Universal preconditions are preconditions, not AC" | "AC describe session-specific deltas; universal gates belong in pre-close verification." |
| "Code block in spec requires grep for live signatures" | "Any code block in a spec must be validated against live source within the same session." |
| "Structured output format must be defined before implementation" | "A spec requiring structured output must define the output format before implementation begins." |
| Unit naming convention (`Unit 1`, `Unit 2`) | "Implementation sessions name units sequentially: `Unit 1`, `Unit 2`, etc." |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| **Gate 2 AC format conflated with Step 7 AC format.** The columns `Verified by` (Gate 2 — who can verify) and `Status` (Step 7 — did it pass) were close enough that the agent reused the Gate 2 format at Step 7. | process gap | Triaged to: `iteration_policy.md` Step 7 Details — added explicit "Do not reuse the Gate 2 format" directive. |
| Triaged to: `iteration_policy.md` Step 7 Details | — | — |

## Completed this session

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | Absorbed ~120 lines operational rules from handover_policy.md; expanded table rows; added Step Details (Step 1, 2, Gate 1, Step 5, Gate 2, During the session, Step 7, Gate 3, Steps 8-9, Seed); Amendments 1+3 applied; Gate 2/3/Step 7 hardened; Verified by/Status distinction clarified |
| `docs/operations/handover_policy.md` | Removed Population Rules (~110 lines); added role statement; rephrased Lifecycle to declarative; updated Format field refs to iteration_policy.md; fixed new-session-v2→new-session ref; added handover-audit.skill.md link |
| `agent/drafts/handover-audit.skill.md` | New — spec-to-source integrity, structured output format, validation tool coverage audit checks |
| `agent/prompts/new-session.md` | Updated Step 1 delegation (handover_policy → iteration_policy); hardened Gate 2 with pre-verification procedure + Verified by column |
| `eval/eval_protocol.md` | Added deferred modular-threshold design note |
| `docs/devlog/handovers/20260522-03-workflow-gate_adjacency_fix.md` | This handover |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Modular threshold for `new-session.md` — if prompt grows past ~120 lines, extract handover-creation into a skill | Threshold noted; no action until it fires | `eval/eval_protocol.md` Limitations |

## Next session

**M2.7 Track A (items 1–4)** — `run_id`, Docker labels, `make stop` redesign, `make prune`. Or story advancement (`story_prompt_evals.md` open questions 1–3: minimum viable eval, dependency tracking, regression eval placement).

**Pending operator review:** AC 3 (14 migrate entries tick) — operator confirms all operational rules landed in `iteration_policy.md`.

**Conclusions from this session:**
- `iteration_policy.md` is now the single source of truth for the minor loop. `handover_policy.md` is a declarative content-rules document.
- Gate 2 format (`Verified by` — who can verify) and Step 7 format (`Status` — did it pass) are distinct and must not be conflated.
- The three Amendments initially proposed were reduced to two (session type at Gate 1, Gate 2 exit harmonization); the "Next: Gate N" pointer amendment was dropped as a band-aid.
- The gap report (14 migrate entries) was the real deliverable — every operational rule found a home in `iteration_policy.md`.

---
[CORRECTION — 2026-05-22]: Post-close eval of commit 3 found one defect — `new-session.md` Gate 2 prose said "three columns" while the table header defined four columns. Corrected to "four-column table." Full eval (35/35 PASS) confirmed all commit 3 changes effective: 16 iteration_policy checks, 9 handover_policy checks, 4 new-session checks, 4 audit skill checks, 2 cross-document consistency checks. Eval script persisted at `eval/eval_commit3.sh`.

[CORRECTION — 2026-05-22]: Scope proposal in `iteration_policy.md` Step 2 Details converted from prose bullet list to literal template (`**Session type:**`, `**In scope:**`, `**Deferred:**`, `**Questions:**`). Eval: 9/9 PASS. Script at `eval/eval_templates.sh`.
