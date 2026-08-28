# Agent Handover

**Session date:** 2026-05-22
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Workflow
**Status:** Closed

## Objective

Address all items identified in the audit of the last 30 handovers: reinstate dropped deferred items into the roadmap, log unresolved findings to the appropriate documents, and propose a policy change to prevent future handover-chain breaks.

## Scope

One task group: audit remediation. All items from the audit report:

1. D1 — Add `test_capability_layer.sh` test subsumption to roadmap
2. D2/D3 — Add autosave/session-save reliability issue to roadmap (nested under one issue)
3. D4 — Add provider dry-run checks to roadmap
4. F1/F2 — Log in `recovery_protocol.md` as discovered gaps
5. F3 — List in roadmap as deferred, triaged as plausible but unlikely, no milestone
6. F4 — Add diff-type flag to roadmap
7. V1/V2 — Propose policy change in `handover_policy.md` for systematic deferred-item and mid-session-finding handling at session close and during corrections

## Carried forward

None.

## Audit report

**Audit scope:** `20260504-04-impl-add_session_state_checks_to_dry_run.md` through `20260521-06-impl-sandbox_preflight_and_container_identity_hardening.md` (30 handovers).

### Dropped deferred items

| ID | Description | Origin | Status |
|---|---|---|---|
| D1 | Subsuming `test_capability_layer.sh` skipped tests into dry-run | `20260513-02` | ✅ Roadmap item 11f |
| D2/D3 | Autosave subshell resilience + EXIT trap error checking | `20260513-02` | ✅ Roadmap item 13 |
| D4 | Provider dry-run checks hook in `dry_run_reasoning.sh` | `20260513-08` (carried to `20260513-10`, then lost) | ✅ Roadmap item 12 sub-item (existing, now marked ❌) |

### Unresolved mid-session findings

| ID | Description | Origin | Status |
|---|---|---|---|
| F1 | No expected test count baseline for recovery verification | `20260512-07` (parked in `20260513-01` open questions) | ✅ Logged in `recovery_protocol.md` Open questions |
| F2 | Chat history is the only complete change record | `20260512-07` (parked in `20260513-01` open questions) | ✅ Logged in `recovery_protocol.md` Open questions |
| F3 | `docker compose down -v` race with EXIT trap | `20260513-02` | ✅ Roadmap deferred (no milestone) |
| F4 | No Makefile variable or CLI flag for diff type | `20260521-03` | ✅ Roadmap item 14 |

### Policy violations

| ID | Description | Resolution |
|---|---|---|
| V1 | Carried-forward item unresolved but not re-deferred (provider dry-run checks from `20260513-08` → `20260513-10`) | ✅ Step 8 now has carry-forward resolution gate requiring every carried-forward item to be completed, re-deferred, or escalated |
| V2 | Mid-session findings not fully triaged at close (multiple handovers) | ✅ Mid-session findings triage gate now requires empty section or entries with `Triaged to:` annotation before close |

### Open correction

| Description | Origin | Status |
|---|---|---|
| utime EPERM on 9p mounts — workaround documented, code fix not implemented | `20260513-10` CORRITION block | ⚠️ Referenced in `story_windows_filesystem_incompatibilities.md`; not escalated to roadmap |

### Root cause pattern

Mid-session findings and deferred items fall out of the handover chain because the triage step at session close is not structurally enforced. Findings are recorded in the originating handover but never routed to Deferred items (if unresolved) or to the roadmap (if they survive more than one hop). The correction procedure had no triage gate either — findings surfaced during corrections (e.g. utime EPERM) ended up embedded in CORRECTION blocks rather than actionable in the roadmap or deferred-items chain. The amendments to Step 8 and the corrections procedure in this session address both gaps.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | All deferred items D1–D4 appear as roadmap entries with scope notes | ✅ Accepted — D1 as 11f, D2/D3 as item 13, D4 has ❌ under item 12, all with scope notes |
| 2 | F1 and F2 are documented under a "Discovered gaps" section in `recovery_protocol.md` | ✅ Accepted — already existed in Open questions section; added audit cross-references |
| 3 | F3 appears in the roadmap as deferred, with triage note (no milestone) | ✅ Accepted — added under "Deferred (not milestone-scoped)" with full triage note |
| 4 | F4 appears in the roadmap as a pending task | ✅ Accepted — added as item 14 |
| 5 | `handover_policy.md` has amendments that explicitly gate on deferred-item and mid-session-finding triage before close | ✅ Accepted — Step 8 now has carry-forward resolution gate + mid-session findings triage gate; corrections procedure has findings triage step |
| 6 | Mid-session finding in this handover records the root cause pattern from the audit | ✅ Accepted — recorded under Mid-session findings above |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/devlog/roadmap.md`](../../docs/devlog/roadmap.md) | D1, D2/D3, D4, F3, F4 added/modified |
| [`docs/operations/recovery_protocol.md`](../../docs/operations/recovery_protocol.md) | F1/F2 cross-references added |
| [`docs/operations/handover_policy.md`](../../docs/operations/handover_policy.md) | Step 8 and corrections section amended per V1 |
| [`docs/devlog/handovers/20260522-01-workflow-audit_remediation.md`](../../docs/devlog/handovers/20260522-01-workflow-audit_remediation.md) | This handover |

## Decisions made this session

None.

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| **Root cause pattern: mid-session findings and deferred items fall out of the handover chain because the triage step at session close is not structurally enforced.** Across the last 30 handovers, four deferred items and four mid-session findings were dropped or parked without resolution. In each case the originating session recorded the item but failed to route it to Deferred items (if unresolved) or to the roadmap (if it survived more than one hop). The next session has no discovery mechanism — Carried forward is the only bridge, and items not carried forward are invisible. The correction procedure has no triage gate either — corrections that surface new findings (e.g. the utime EPERM correction in 20260513-10) have no mandated routing step, so the finding ends up embedded in a CORRECTION block rather than actionable in the roadmap or deferred-items chain. | policy gap | This session — propose amended Step 8 triage enforcement and a corrections triage gate |
| **Dangling reference: `roadmap_policy.md` path mismatch.** Every cross-reference in the codebase — `handover_policy.md` (Population Rules, At session open), `iteration_policy.md` (References table), and the `roadmap_policy.md` file itself at its own header — says `docs/development/roadmap_policy.md`. But the actual file lives at `docs/operations/roadmap_policy.md`. All in-text links pointing to `docs/development/roadmap_policy.md` are broken. | contradiction | Policy audit — fix all references to point to `docs/operations/roadmap_policy.md` |

## Completed this session

| File | Change |
|---|---|
| `docs/operations/roadmap_policy.md` | Full restructure: During session, Step 7, Steps 8–9 merged, Trigger B revised, load-bearing statement replaced, "Completed task groups" rule updated, dangling paths fixed |
| `docs/operations/handover_policy.md` | Step 1 recovery check updated, Step 7 compaction proposal added, Steps 8–9 merged with all gates, corrections triage added, Related Skills table added |
| `docs/operations/iteration_policy.md` | Step table: 7 / Gate 3 / 8–9 rows merged, Trigger B parenthetical removed |
| `docs/operations/recovery_protocol.md` | F1/F2 audit cross-references added |
| `docs/devlog/roadmap.md` | M2.7 compacted to `- [x]`/`- [ ]` format; items 8–10 compacted; item 11a–11e compacted; item 6 removed; summary line removed; items 13/14 added; User Stories section added; dangling reference fixed |
| `agent/drafts/` | Directory renamed from `skill-drafts/` |
| `agent/drafts/roadmap-management.skill.md` | Updated for new policy |
| `agent/drafts/roadmap-audit.skill.md` | New — 4 audit categories with survival table checks |
| `agent/drafts/roadmap-management.skill.md` | Updated dangling reference |
| `docs/discussions/story_prompt_evals.md` | New — investigation into prompt/skill evaluation; I1–I8 golden dataset; code-based eval script; case study analysis |
| `/tmp/eval-new-session.sh` | Code-based capability eval script — run against both new-session prompts, produces structured report |
| `docs/devlog/handovers/20260522-01-workflow-audit_remediation.md` | This handover |

## Deferred items

| Item | Reason |
|---|---|
| `new-session-v2.md` update (fix I2 + I7 failures) | Deferred to next session — eval results produced, v2 identified as winner |
| `new-session.md` (v1) replacement | Deferred to next session — replace with updated v2 after fixes applied |
| `story_prompt_evals.md` open questions (minimal viable eval, dependency tracking, regression eval placement) | Investigation in progress — next session can advance |

## Policy revision work items

Open items from the roadmap policy audit, tracked here during the grill-me session. Updated as each is resolved.

| # | Issue | Decision | Status |
|---|---|---|---|
| **G1** | Define "task group" | Any item with sub-items, a checklist, or paragraph context beyond ~2 lines. Creation-side: prefer group structure when carrying design context (looser guideline, not a hard limit). | ✅ Resolved |
| **G2** | Move compaction from Step 1 to Step 8 | Eliminate "previous session" ambiguity. Session that marks last ✅ compacts the group at Step 8, after Gate 3 release. | ✅ Resolved |
| **G3** | Nested compaction | Sub-group within incomplete parent compacts independently. Clarifying sentence: "Compaction applies at every level of nesting — a sub-group within an incomplete parent compacts independently once its own items are all complete." | ✅ Resolved |
| **G4** | What replaces checklist | `- [x]` markdown outcome summary (1–3 sentences). `- [x]` header line survives. Multi-level: when all subtasks done, compact to task-level summary too. Survival table from earlier conversation governs component retention. | ✅ Resolved |
| **G4a** | Trigger B "do not collapse" prohibition | **Not contradictory.** The prohibition refers to not collapsing the *entire sub-milestone* into a paragraph instead of removing it. Per-task incremental compaction at Step 8 is a different operation. Clause stays. | ✅ Resolved — clause stays |
| **G4b** | Trigger B fallback wording and placement | Remove fallback sentence from `roadmap_policy.md` Trigger B header (session workflow belongs in `handover_policy.md`). Update `handover_policy.md` Step 1 recovery check (line 181) to reflect new ordering: create handover → run Trigger B → record in handover → present in scope proposal. | ✅ Resolved |
| **G4c** | Load-bearing separation statement replacement | Replaced by new Step 7/8/9 structure. Step 7: agent proposes compaction text for operator review at Gate 3. Steps 8–9: apply approved changes mechanically — Gate 3 is the verification surface. During-session `- [x]` marking with revert-on-disagreement at Step 7. | ✅ Resolved |
| **G4d** | Step 8 numbering rejig | Superseded by new Step 7 (propose compaction) / Step 8–9 (apply approved) structure. No standalone renumbering needed. | ✅ Resolved by restructure |
| **G4e** | Trigger B Step 1 — delete parenthetical | Subject to G4a resolution — clause stays, so no deletion | ✅ Resolved — clause stays |
| **G4f** | Step 1 Session open — remove compaction responsibility | Superseded by new model — Step 1 has no compaction role. Addressed in the full rewrite. | ✅ Resolved by restructure |
| **G5** | Summary line governance | Remove floating prose summary — `- [x]` task list is the visual summary. No governance rules needed. | ✅ Resolved |
| **G6** | Superseded item lifecycle | Remove immediately on supersession; rationale in session handover + discussion doc if architecturally significant. | ✅ Resolved |

## Deferred items

None.

## Conclusions from this session

- **Policy architecture settled.** Three amended documents (`roadmap_policy.md`, `handover_policy.md`, `iteration_policy.md`) with a coherent Step 7/8/9 flow — compaction at session close after Gate 3, `- [x]`/`- [ ]` format, during-session marking with revert-on-disagreement.
- **Roadmap compacted.** M2.7 converted to `- [x]`/`- [ ]` format. Completed groups (items 8–10, 11a–11e) compacted to outcome summaries. Superseded item 6 removed. Floating summary line removed. New items 13/14 tracked.
- **Skill → policy mapping added** to `handover_policy.md` as a Related Skills table. Two new/updated skill drafts: `roadmap-management.skill.md` and `roadmap-audit.skill.md`.
- **Eval infrastructure story opened.** `story_prompt_evals.md` with 8-invariant golden dataset and code-based evaluators.
- **Root cause of handover chain breaks identified and fixed** — carry-forward resolution gate and mid-session findings triage gate added to Step 8.

## Next session — eval continuation (policy deviation: findings recorded here)
**Deviation note:** The next handover was intentionally deferred. Findings from the eval continuation task were recorded in this section as a working scratchpad because an active session would conflict with behavioral eval of session-start prompts. This is a known limitation related to parallel sessions (scoped under M2, not yet milestone-assigned). The findings have been migrated to the next session.

