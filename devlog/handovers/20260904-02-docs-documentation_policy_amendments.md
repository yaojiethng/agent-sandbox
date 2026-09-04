# Handover 20260904-02 — docs documentation policy amendments (F11–F14 + steering)

**Milestone:** M2.6 - Session Persistence
**Type:** docs
**Status:** Closed
**Date:** 2026-09-04
**Base:** `63ab666` (design: seed transport redesign; prior handover `20260904-01-design-start_resume_rsync_stall.md`, Closed)

## Objective

Apply the operator-approved documentation workflow changes from the previous iteration's steering. Scope confirmed by the operator at iteration open; content is the roadmap task "Documentation policy amendments (F11–F14 + STE100/skeleton-first)".

## Changes

| # | File | Change | Source finding |
|---|---|---|---|
| 1 | `docs/operations/adr_policy.md` | Requirements preamble (optional, between `Current:` and first entry); promotion cycle + failure-locus convention in Rejected alternatives; sub-headers permitted within entry fields | F13 |
| 2 | `docs/operations/documentation_policy.md` | Concept docs: standalone behavioral-contract explainers (content-complete, requirements restated conceptually, outbound links further-reading); interface-level descriptions, exact commands/values only for external interactions; defect history only in the ADR; no handover/session references | F14 |
| 3 | `docs/operations/documentation_policy.md` | Link-sparingly reword: "wherever possible" → link when the target changes what the reader does next | F11 |
| 4 | `docs/operations/documentation_policy.md` | STE100 quick rules added to the Simplified Technical English section (operational rules, not the full dictionary) | F8 |
| 5 | `AGENTS.md` + `documentation_policy.md` | Steering lines: "records state, not session history"; "skeleton-first drafting for record-layer documents" | F12, feedback entry 3 |
| 6 | `docs/operations/documentation_policy.md` | Regroup into five parts: Folder Structure / Enforcement Rules / Writing Rules / Document Types / Record Lifecycle. Pure section moves — prose-style rules (STE100, character set, line wrapping, numbering, all linking rules, depth/verbosity) consolidated under Writing Rules; production rules (folder placement, skeleton-first, records-state, header format, post-close corrections) under Record Lifecycle; document-type specs (roadmap, agent-facing, concepts) under Document Types | Operator steer at pre-close review |
| 7 | `workflow/coding-agent/documentation-pass.md` | Audit Checks section extracted from the policy into its own doc, marked **Status: stub** — home of a future documentation review pass; checklist content carried over unexpanded | Operator direction |
| 8 | `src/reasoning/providers/pi/config/agent/AGENTS.md` | New **Technical Writing Rules** section: the writing rules relevant to the pi agent's own output (STE100 delete-test, active voice, sentence length, one term one meaning, common verbs, no hedging, defined-noun-before-imperative, line wrapping, ASCII, link sparingly, records-state), with a pointer to the target repo's `documentation_policy.md` for the full policy | Operator direction |

## Acceptance Criteria

- AC1: All five changes applied; no rule duplicated without a single canonical owner (AGENTS.md lines stay one-liners, `documentation_policy.md` holds the detail). **Done, extended to seven** — regroup (6) and Audit Checks extraction (7) added at operator direction during pre-close review.
- AC2: The rewritten ADR (`sandbox_delivery_model.md`) and concept doc (`copy_delivery.md`) now conform to the amended policies with no further edits needed. **Done** — re-read against amended rules; no edits needed.
- AC3: Suite green, lint Clean. **Done** — 756/756, Clean. Also: policy section map verified (`grep -n "^##|^###"` returns the five-part structure); zero inbound references to the removed `## Audit Checks` section.

## Completed

| Task | Evidence |
|---|---|
| 1. adr_policy amendments | Structure block: Requirements preamble (optional, table, promoted entries marked), promotion cycle with failure-locus convention (intent / execution / neither), sub-headers permitted inside mandated fields |
| 2. Concept docs section | Standalone + content-complete; requirements restated as behavioral contracts (no seam vocabulary, no defer-by-link); interface-level descriptions, exact commands/values only for external interactions; defect history lives in the ADR; no handover/session references |
| 3. Link policy reworded | "Link sparingly, at points of use" — markdown links kept as the reference form; defect reframed per operator feedback: over-linking the *transient tier* (handovers, discussion docs, session exports), not a judgement about link volume |
| 4. STE100 quick rules | Added to Simplified Technical English: six operational rules (active voice, <20 words, one term one meaning, common verbs, no hedging, delete-test); stated as working subset, not the dictionary |
| 5. AGENTS.md + documentation_policy steering | Editing Guidelines gains "Records state, not session history" and "Skeleton first for record-layer documents"; AGENTS.md Documents bullet carries all three one-liners (incl. STE100) pointing at the policy for detail |

## Findings

| # | Finding | Status |
|---|---|---|
| F1 | The amended policies retroactively make the prior iteration's rewritten ADR and concept doc conforming — no edits needed to either (AC2 verified by re-read against the new rules: ADR has requirements preamble + promotion markers + failure loci; concept doc is standalone behavioral contract at interface level). | Confirmed |
| F2 | The policy did not follow its own STE100 rules. Full-document self-audit applied the delete-test and quick rules to every section: fixed one real character-set violation (em-dash) and two non-ASCII arrows in the header-format example; cut convoluted prose throughout ("purpose-specific", "operative test", "for context efficiency", "the rewrite costs the document", "the story of the failure", "makes no effort to", "It is not orientation to", "selectively inlining ... for context efficiency", "the scratch and log tier"). Document went 270 → 258 lines despite *adding* three new rule sections; every rule preserved. | Confirmed |

## Deferred

- None known.
