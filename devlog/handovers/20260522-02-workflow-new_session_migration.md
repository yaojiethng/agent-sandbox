# Agent Handover

**Date:** 2026-05-22
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Workflow
**Status:** Closed

## Objective

Migrate the canonical `new-session.md` prompt to V3 (the eval winner). Archive v1 and v2. Record the eval findings from the prior session's deviation scratchpad.

## Scope

1. Replace `new-session.md` with V3 content — no versions, canonical name
2. Archive old v1 and delete v2 (superseded)
3. Record eval findings in this handover
4. Note the protocol deviation from prior session

## Carried forward

| Item | From handover |
|---|---|
| Eval results from three-way prompt comparison (v1/v2/v3) | 20260522-01 — recorded in Next session as a protocol deviation |

## Eval findings (carried from prior session)

### Three-way eval results

| Invariant | v1 | v2 | v3 |
|---|---|---|---|
| I1 — No "Step 1b" | ❌ | ✅ | ✅ |
| I2 — No compaction at Step 1 | ❌ | ❌ | ✅¹ |
| I3 — Trigger B present | ✅ | ✅ | ✅² |
| I4 — Scope + AC gates | ✅ | ✅ | ✅ |
| I5 — Policy doc references | ✅ | ✅ | ✅ |
| I6 — No old Trigger B wording | ✅ | ✅ | ✅ |
| I7 — No old compaction wording | ✅ | ❌ | ✅ |
| BONUS — Divergence detection | ❌ | ✅ | ✅ |
| **Total** | **5/7** | **6/7** | **7/7** |

¹ False positive — V3 says "Compaction is no longer a Step 1 action." The grep catches proximity but not negation.
² V3 adds explicit Trigger B ordering per amended policy.

### V3 improvements over V2

1. Explicit Trigger B recovery ordering — "after creating this handover but before presenting the scope proposal" (per amended `handover_policy.md`)
2. Compaction clarification — explicitly tells the agent compaction is Steps 8–9, not Step 1

### Known eval limitations

- **Code-based evaluators can't parse negation.** The I2 check false-flags clarification text ("no longer a Step 1 action"). Fix: add exclusion patterns or accept human triage of false positives.
- **Behavioral evals blocked by active session.** Running a session-start prompt headless would operate on real project state. Requires parallel session support (M2, not yet milestone-assigned). Recorded in `story_prompt_evals.md` as open question 4.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `new-session.md` is the V3 prompt (canonical, no version suffix) | ✅ |
| 2 | v1 superseded, v2 deleted | ✅ |
| 3 | Eval findings recorded in this handover | ✅ |
| 4 | Clean commit attribution — one commit per session | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `agent/prompts/new-session.md` | Replaced with V3 content |
| `agent/prompts/new-session-v2.md` | Deleted (superseded) |
| `agent/prompts/new-session-v3.md` | Deleted (source migrated) |

## Decisions made this session

None.

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| **Eval process validated the code-based evaluator approach.** Eight grep checks (I1–I7 + BONUS) surfaced every policy regression across three prompt variants at zero cost. The 20% gap is semantic checks and behavioral validation — blocked by the pre-state setup problem (no sandboxed sessions). | learning | Advance `story_prompt_evals.md` — document the pre-state gap, add it to M2 scope |
| **V3 beat V2 on two dimensions the eval captured precisely.** Trigger B ordering (explicit "after creating handover, before scope proposal") and compaction clarification ("no longer a Step 1 action"). Without the eval table, these differences would be invisible in a read-through. | learning | The golden dataset approach works — keep expanding invariants |
| **Session type miscategorized as chore.** This session touches prompts, skills, and policy documents — that's `workflow`. The categorization was not explicitly presented for operator approval at scope confirmation. | process gap | Update session type in handover; add explicit type presentation to Gate 1 in `iteration_policy.md` (not `handover_policy.md` — the gate itself lives there) |
| **Steps 5 (AC confirmation) and 7 (pre-close verification) were skipped.** Gate 2 and Gate 3 were not observed before the agent attempted to close. Root cause: agent collapsed Steps 5–7 into implementation for a session with trivial AC. The policy says "every session type without exception" for both gates. | discipline lapse | Recovered. But investigation reveals deeper structural issues — see findings below. |
| **Deeper — session type presentation belongs in `iteration_policy.md`, not `handover_policy.md`.** The scope proposal template lives in `handover_policy.md`, but Gate 1 (the scope gate) is defined in `iteration_policy.md`. Adding the type-presentation rule to `handover_policy.md` puts it in the wrong document — it should live with the gate definition. The two documents are duplicating gate-related rules across different locations. | policy structure gap | Flagged for next session — consolidate gate definitions in `iteration_policy.md` or add cross-reference from gates to their corresponding `handover_policy.md` sections |
| **Deeper — Step/Gate flow not visually obvious across documents.** Step 7 and Gate 3 are adjacent rows in the `iteration_policy.md` table — their relationship is visually obvious. But Step 5 (AC definition) is defined in `handover_policy.md`, and Gate 2 follows in `iteration_policy.md`. The agent must read two separate documents to understand a single gate sequence. This structural separation is the root cause of the Gate 2 skip — the agent read Step 5 rules in one document and didn't context-switch back to `iteration_policy.md` to find Gate 2. | policy structure gap | Flagged for next session — consider merging gate-step adjacency into a single flow, or adding explicit "Next: Gate 2" pointers at the end of each `handover_policy.md` step section |
| **Deeper — Gate 2 exit description inconsistent with Step 5 exit.** Gate 2's exit: "All criteria verified as satisfiable. Explicit release received." Step 5's exit: "Operator confirmed. `Not yet defined.` replaced." These describe the same moment with different language. An agent reading only the Step 5 exit might think operator confirmation is the final step, unaware that Gate 2 requires an additional explicit release. | wording gap | Flagged for next session — harmonize exit descriptions so agent can't conclude a step is complete without looking at the gate |

## Completed this session

| File | Change |
|---|---|
| `agent/prompts/new-session.md` | Replaced with V3 content (7/7 eval invariants) |
| `agent/prompts/new-session-v2.md` | Deleted (superseded by V3) |
| `agent/prompts/new-session-v3.md` | Deleted (source migrated to canonical name) |
| `docs/discussions/story_prompt_evals.md` | Added pre-state setup problem, learnings from three-way eval, false-positive analysis |
| `docs/devlog/handovers/20260522-02-chore-new_session_migration.md` | This handover |

## Deferred items

None.

---

## Conclusions from this session

- **new-session.md is now the canonical V3 prompt** — 7/7 eval invariants, divergence detection, explicit Trigger B ordering, compaction clarification. No versioned variants remain.
- **Eval infrastructure works.** Code-based evaluators caught every policy regression. The pre-state gap (no sandboxed session for behavioral eval) is the next bottleneck to address.

## Next session

**Sub-milestone:** M2.7 — Session Identity and Harness Versioning

**Priority — policy structure investigation (from this session's Gate 2/3 lapse):**

1. **Session type presentation at Gate 1.** Add explicit type-presentation rule to Gate 1 in `iteration_policy.md` (not `handover_policy.md`), where the gate is defined. The scope proposal must include: session type + justification.

2. **Step/Gate flow adjacency is split across documents.** Steps are in `handover_policy.md`, gates are in `iteration_policy.md`. Step 5 and Gate 2 are in different files, making it easy for an agent to read Step 5's rules and never see Gate 2. Fix options: (a) add "Next: Gate 2 — see iteration_policy.md" pointers at the end of each step section in `handover_policy.md`, or (b) merge step and gate descriptions into a single flow.

3. **Gate exit descriptions inconsistent with step exits.** Gate 2 exit ("All criteria verified") and Step 5 exit ("Operator confirmed") describe the same moment differently. Harmonize so an agent cannot conclude a step is complete without looking at the gate.

**Also pending:** M2.7 Track A (items 1–4) or story advancement (`story_prompt_evals.md` open questions 1–3).

---
[CORRECTION — 2026-05-22]: Post-close changes — eval artifacts that were generated during this session but initially left in /tmp/ have been persisted to permanent locations. `docs/discussions/eval_protocol.md` and `docs/discussions/eval_new_session.sh` moved to project-root `eval/` directory. Story reference at `docs/discussions/story_prompt_evals.md` updated to point to the new paths. The /tmp/ comparison and analysis files (audit-skill-pass.md, policy-pass.md, comparison.md, skill-comparison.md, compacted-m2_7.md) were not persisted — their results are already reflected in the updated skill drafts, compacted roadmap, and story findings.
