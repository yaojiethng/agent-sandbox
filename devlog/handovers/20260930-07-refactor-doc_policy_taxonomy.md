# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Refactor
**Status:** Closed

## Objective

Refactor `documentation_policy.md` into a clearer structure. The refactor extracts the fully-formed document-types / record-lifecycle / what-checks-it concern into a standalone concept document, `docs/concepts/documentation_taxonomy.md`, which is the unit of record: a single-source-of-truth index that orients fresh agents and dispatches to each document type's governing policy and governing ADR. The policy keeps the rules.

## Scope

The task is a refactor of the policy document. The concept doc is the record; the two subagent reports (the fresh context-free reorganization and its revision) are stepping stones that the concept doc subsumes. They are not committed artifacts.

The refactor reconciles the fresh-report findings against the concept-doc approach:

- A rule is authoritative only where a policy canonically states it; a concept or ADR describes and links, never binds. Decision recorded in `policy_declarative_framing.md` (2026-09-30).
- A statement that imposes an obligation is a rule and belongs in policy; a statement that describes the system as a consequence of earlier decisions is a model and belongs in a concept document.
- The document promotion topology -- discussion to ADR, ADR to concept, concept to architecture document -- is a view, not a rule; its edges are obligations that get single policy homes.

## Carried forward

The decision record in `policy_declarative_framing.md` (2026-09-30) and the roadmap reminder added under the Docs-and-ADR-consolidation group carry the principle into the refactor.

## Acceptance criteria

1. `docs/concepts/documentation-taxonomy.md` exists: a durable, standalone concept index that orients a fresh agent, states the taxonomy and durability, and dispatches to each type's policy and governing ADR. Accepted.
2. `documentation_policy.md` keeps the rules, gains the `Rule authority` principle under Document Types, and links to the concept doc for the taxonomy. Accepted.
3. Every obligation has exactly one policy home; no rule is re-specified across documents. Accepted.
4. The two subagent reports stay transient (not committed); the concept doc subsumes them. Accepted.
5. Lint clean; handover Closed. Accepted.

## Hot files

| File | Why in scope |
|---|---|
| `docs/concepts/documentation_taxonomy.md` | the unit of record; new concept index |
| `docs/operations/documentation_policy.md` | keeps the rules; gains `Rule authority`; links to the concept |
| `docs/adr/policy_declarative_framing.md` | records the 2026-09-30 authority decision |
| `devlog/roadmap.md` | holds the refactor reminder under the Docs-and-ADR-consolidation group |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | review-subagent model-verification hint (explicit session path) |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Model-verification: confirm the subagent's effective model from that subagent's explicit session file, never by mtime-sorting the session directory (the newest session is the primary's own, which stays freshest and yields a false fallback read) | operator | current iteration - explicit `--session` path hint added to Running Review Subagents |
| The document-types / record-lifecycle / tooling strand is one fully-formed unit that need not stay inside the policy document | operator | current iteration - extracted into the concept document |
| A rule is authoritative only where a policy states it; a concept or ADR describes but does not bind | operator | recorded as a decision - current iteration |

## Completed

| File | Change |
|---|---|
| `docs/concepts/documentation-taxonomy.md` (renamed `documentation_taxonomy.md`) | new concept index (the unit of record): taxonomy, durability, record-lifecycle view, promotion topology, boundary, audience dispatch; every obligation links to an owning policy |
| `docs/operations/documentation_policy.md` | slimmed the descriptive taxonomy into the concept doc; added `### Rule authority`; consolidated the skill/template authority claim to that one home; retargeted Records-state to the concept classification; dropped the five-parts sentence and the descriptive Document Types subsections |
| `docs/adr/policy_declarative_framing.md` | records the 2026-09-30 authority decision (rules are canonical only in policy; concepts and ADRs describe and link, never bind) |
| `devlog/roadmap.md` | refactor reminder under the Docs-and-ADR-consolidation group, closed this iteration |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | review-subagent model-verification hint (explicit `--session` path); mirrored to the installed copy |

## Evolution

- The two subagent reports (initial context-free reorganization and its revision) were stepping stones, not committed; the concept doc subsumes them. The report commit was reverted and the first report removed from the tree.
- The document taxonomy extraction supersedes the `20260930-06` placement of Durability in `## Document Types -- Durability`: durability is a classification (a model), so it now lives in the concept document, with the policies that depend on it linking back.
- A clean-eyes re-review surfaced defects the refactor introduced; the iteration was reopened and the defects folded into this delivery commit. See `## Reopened correction` below.

## Reopened correction (2026-09-30)

Closed iteration reopened at operator direction to fold in defects a clean-eyes re-review surfaced. The fixes fold into this iteration's delivery commit, not a new one, per the [`closed_record_corrections`](../adr/closed_record_corrections.md) discipline.

Fixed in the amend:

- Deduplicated the taxonomy dispatcher sentence (was verbatim in the preamble and the `## Document Types` opener; kept only in the preamble).
- Converted the taxonomy `## Boundary` from rule statements to classification with links: it no longer restates the skill-file authority rule or the handover jurisdiction rule; it names what is not a maintained document and links the owning policies.
- Resolved the handover self-contradiction to one position: a handover is a transient session record, not a maintained document. Removed the non-document "session log, tmp, chat" row from the inventory; that content lives in Boundary.
- Pointed the discussion-document row at [`discussion_policy.md`](../operations/discussion_policy.md), the real canonical owner, instead of `documentation_policy.md` where no discussion section exists.
- Added `story_` and study/investigation rows to the inventory, governed by `story_policy.md` and `study_policy.md`.
- Linked the Durability classification from the Post-close corrections principle; Records-state already carries the link.
- Renamed `documentation-taxonomy.md` to `documentation_taxonomy.md` to match the `concepts/*_*.md` underline convention; updated all references.
- Corrected the `Folder Structure` table: `development/` no longer claims "policy" (policy documents live in `docs/operations/`); the row now reads contributor workflow and development conventions.

Recorded as a finding, deferred (may need to deconflict with `discussion_policy.md`):

- The `Folder Structure` table covers only `docs/` yet claims "Each document belongs to exactly one of the following categories" for all documents; `devlog/` (roadmap, changelog, handover, discussion, story, study) is unseen by it.

## Deferred -- next iteration

Pre-existing `documentation_policy.md` structural defects, not introduced by the refactor, to handle in a following iteration:

- `### Rule authority` is buried under a mis-titled `## Document Types`; the rule-vs-model premise precedes three sections that depend on it.
- `## Record Lifecycle` is a catch-all (placement, skeleton, records-state, header format, corrections, missing-documents) rather than a lifecycle.
- `## Enforcement Rules` and `## Communication Standards` are grab-bags of unlike concerns and granularities.
- Headings that do not name their content: `### Read pass economics` (grep-ability), `### Document depth and verbosity` (rule locality).
- `### Markdown lint gate` cites a roadmap iteration (`M3.1 roadmap, iteration 20260921-11`), self-violating the durable-record and durable-link rules; provenance should cite a durable record or be dropped.

The deferred `Folder Structure` / `devlog/` deconflict (see `## Reopened correction`) also lands here when `discussion_policy.md` is reconciled.

## What's Next

This iteration closes the reopened correction. The next documentation-policy structural pass handles the `## Deferred -- next iteration` list. Next pending roadmap items under the Docs-and-ADR-consolidation group: the loop-documentation structure decision and the `autonomous_agent_loop.md` concept-doc offload. Beyond the group, M3.2.2 Audit and Review Workflow Cleanup.

The provider-layer AGENTS shadow bullets that reflect the merged `### References` remain aligned; no further pass needed unless desired.
