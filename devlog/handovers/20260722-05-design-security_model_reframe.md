# Agent Handover

**Session date:** 2026-07-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Design — Reframe security model from tier numbering to delivery × backing axes
**Status:** Closed

## Objective

Replace the three-tier mount model terminology (Tier 1/2/3) with a two-axis security model — delivery (copy vs. mount) × backing (fresh baseline vs. worktree) — ahead of the M2.6.4 design session, so that the session's ADR and architecture doc updates are written in the final vocabulary.

## Scope

Confirmed by operator with two amendments: (1) durability axis carries its own security content — live-mount exposure; (2) drop the "offered configurations" numbered list — express the model as configuration options with per-option exposure.

1. **ADR** — records the reframe decision; supersedes the three-tier structure of `docs/adr/sandbox_delivery_model.md` (the worktree decision itself stands).
2. **`docs/architecture/security.md` restructure** — universal invariants stated once; configuration options with per-option exposure; invariant profiles per backing (fresh-baseline, worktree) with template *mounts added → exposure introduced → compensating controls → residual risk*; raw project dir documented as non-goal. Proposed section by section per governance-doc rules.
3. **Propagation pass** — ~50 tier references across `docs/concepts/sandbox_identity.md`, `devlog/roadmap.md`, `scripts/build.sh`, and the two core docs.
4. **Roadmap** — M2.6.4 task list rewritten in the new vocabulary, ready for the follow-on design session.

**Not in scope:** the 6 open mount-wiring questions from `devlog/discussions/20260722-study-settled-mount_wiring_survey.md` (baked vs. runtime WORKTREE_DIR, compose overlay shape, Pi bind mounts, `--volumes-from`, `make apply` role, snapshot pipeline in worktree mode, migration flag). Those remain for the M2.6.4 design session, which follows this one.

## Carried forward

None.

## Acceptance criteria

Defined at close per operator decision: the status summary table serves as the acceptance table. Doc-only interactive design session — no runnable checks beyond the tier-reference grep, which was run (zero mount-model tier references in live docs outside the intentional historical entry).

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Mount-model decision record consolidated: both pre-settlement ADRs removed; canonical record is an active design doc with settlement path | `ls docs/adr/` shows no mount-model ADR; design doc exists | Accepted — Operator |
| 2 | `security.md` restructured: Mount modes table with support statuses, universal invariants, worktree not asserted, raw project dir in Non-goals | Manual review; `grep -n "Tier" docs/architecture/security.md` — zero hits | Accepted — Operator |
| 3 | Worktree integrity content lives in a gated design proposal, not in `security.md` | Mechanism design doc exists with audit gate; `security.md` contains only the pointer | Accepted — Operator |
| 4 | Propagation pass: all live mount-model tier references assessed and retargeted | Propagation checklist — every row accounted for (rewritten, confirmed unrelated build-tier, or intentional historical) | Accepted — Operator |
| 5 | Roadmap M2.6.4 rewritten in new vocabulary with decisions recorded and audit gate | Manual review of M2.6.4 section | Accepted — Operator |

## Hot files

All files completed. Files that entered scope mid-session (the two design docs, the survey doc, `documentation_policy.md`) are reflected in Completed this session.

| File | Why in scope |
|---|---|
| [`docs/architecture/security.md`](../../docs/architecture/security.md) | Restructured — tier-free |
| [`devlog/discussions/20260722-design-active-mount_model.md`](../../devlog/discussions/20260722-design-active-mount_model.md) | Created — canonical mount-model record |
| [`devlog/discussions/20260722-design-active-worktree_mount_mechanism.md`](../../devlog/discussions/20260722-design-active-worktree_mount_mechanism.md) | Created — gated mechanism proposal |
| `devlog/roadmap.md` | M2.6.4 rewritten in new vocabulary |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Two-axis model (delivery × backing) replaces tier numbering | Tiers 1 and 2 are the same security posture — the copy-vs-mount difference is delivery, not posture; the only genuine security jump is coupling to the host object store | `devlog/discussions/20260722-design-active-mount_model.md` |
| Delivery axis carries its own security exposure | Operator steering: a live mount means mid-session host changes (incl. accidentally introduced secrets) are visible to the agent; increases user-error surface; rests on the mount-containment assumption, whose strength erodes over time | `devlog/discussions/20260722-design-active-mount_model.md` |
| Raw project dir mount is a non-goal | Operator: never intends to mount the raw dir or grant push access at the current stage | `devlog/discussions/20260722-design-active-mount_model.md` |
| Model expressed as configuration options with per-option exposure, not an ordered configuration list | Operator steering: the numbered "offered configurations" list reintroduces the tier ladder; ordering of combinations is derived, not stated | `docs/architecture/security.md` — Mount modes |
| Capability-layer git mediation retired — the agent runs git in the reasoning layer | Operator correction: the capability layer never invokes git; a read-only `.git` mount cannot accept commits. Repository-integrity controls must be filesystem- and network-level | `devlog/discussions/20260722-design-active-worktree_mount_mechanism.md` — Context |
| Trust boundaries structured per-folder, then compressed to a mode table | Operator steering (two rounds): per-folder structure, then table with `.snapshot/` and `.git` columns; invariants/assumptions as labeled lines | `docs/architecture/security.md` — Mount modes |
| Worktree explicitly unsupported until implemented and audited; mechanism written as design proposal | Operator steering: the security model change is contingent on execution — cannot assert the posture before audit | `security.md` Mount modes + status line; `devlog/discussions/20260722-design-active-worktree_mount_mechanism.md` — gate |
| Mount-model ADRs consolidated: both removed pre-settlement; canonical record is an active design doc (no `adr_policy.md` change) | Operator: the ADRs were labeled settled but revised within days with nothing implemented against them; the record started mid-exploration. Criterion: an ADR whose decision was never implemented and is still being revised is a design document, not a settled record. Settlement path: design doc → canonical ADR when the restructure lands and holds; worktree mechanism → own ADR post-audit | `devlog/discussions/20260722-design-active-mount_model.md` — Consolidation note |
| ADR immutability retained — supersede-only rule unchanged | Operator considered allowing amendment, settled on keeping ADRs immutable records | `docs/operations/adr_policy.md` (unchanged) |
| Section sign (``) banned in documentation | Operator style rule — non-standard character | `docs/operations/documentation_policy.md` — Character set |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| Existing `` usage in 6 live files: `docs/development/testing_policy.md`, `docs/operations/handover_policy.md`, `docs/operations/iteration_policy.md`, `devlog/roadmap.md`, `src/reasoning/agent/prompts/new-session.md`, and the old worktree ADR (frozen — exempt) | scope note | next session — sweep as chore after the style rule lands |
| Uncommitted modification to `scripts/start_agent.sh` present at container start (removes `local` from top-level `REFRESH_FLAG=""`) — not made by this session | scope note | operator — commit separately; excluded from this session's commit |
| The acceptance-criteria machinery fails in practice for doc-only interactive design sessions: ACs were never defined upfront (Gate 2 never formally ran), scope evolved turn-by-turn via per-section confirmation, and at close there were no runnable checks to pre-verify. The formal AC table had to be retrofitted at close from the status summary | contradiction | next session — candidate policy discussion: how `iteration_policy.md` Gates 1–2 and the AC requirement should behave for doc-only interactive sessions. Triaged to: Next session |

## Completed this session

| File | Change |
|---|---|
| `devlog/discussions/20260722-design-active-mount_model.md` | New canonical mount-model design doc (active) — axes, modes with support statuses, consolidation note, settlement path |
| `devlog/discussions/20260722-design-active-worktree_mount_mechanism.md` | New design proposal (active) — gitdir pointer rewrite, refs/agent namespace, preflight/teardown permissions, residual risks, audit gate |
| `docs/adr/sandbox_delivery_model.md` | Deleted (`git rm`) — consolidated into the mount-model design doc |
| `docs/adr/20260722-adr-settled-mount_model_axes.md` | Deleted (uncommitted) — consolidated into the mount-model design doc |
| `docs/architecture/security.md` | Section 1 restructured: Trust Boundaries intro + Principle + Mount modes table + invariants/assumptions; three tier subsections removed |
| `devlog/discussions/20260722-study-settled-mount_wiring_survey.md` | Required-reading link retargeted from deleted ADR to the mount-model design doc; status line corrected to `settled` (filename already said so) |
| `docs/architecture/security.md` | Section 2 (Security Invariants) restructured to universal set + mount-delivery revision + worktree not-asserted pointer; Execution Model Assumptions and Non-goals tier references retargeted; raw project dir added to Non-goals. File is tier-free |
| `devlog/roadmap.md` | M2.6.4 section rewritten in new vocabulary: status → In progress, Decisions block, pre-design investigations marked complete (incl. this reframe), 7 remaining design questions, anticipated tasks incl. safety-audit gate |
| `docs/operations/documentation_policy.md` | Added Character set convention banning `` |

## Deferred items

None.

## Next session

**M2.6.4 — Mount Model Design Session (decision phase).** Resolve the 7 remaining design questions in `devlog/roadmap.md` (WORKTREE_DIR baking, compose overlay shape, Pi bind mounts, `--volumes-from`, `make apply` role, snapshot pipeline, migration flag). Work in the vocabulary of the two active design docs; mount delivery enablement (survey gaps G2a–G2c) is the first implementation target after the design session.

**Policy discussion candidate** (from mid-session findings): the acceptance-criteria machinery in `iteration_policy.md` fails in practice for doc-only interactive design sessions — Gates 1–2 never formally ran and ACs were retrofitted at close. Consider how the gates should behave for this session class.

**Conclusions from this session:** the tier model's ladder is explained by two axes (delivery × backing) with worktree requiring mount; the agent runs git in the reasoning layer, so repository-integrity controls are filesystem- and network-level, not layer isolation; a read-only `.git` mount cannot accept commits; security docs assert only implemented postures — proposals live in active design docs until audited; ADRs whose decisions were never implemented and are still being revised are design documents, not settled records.
