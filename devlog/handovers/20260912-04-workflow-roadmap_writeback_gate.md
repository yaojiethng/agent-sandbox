# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (cross-cutting: process/records quality)
**Type:** Workflow
**Status:** Closed

## Objective
Implement proposal v3 from audit `20260912-03-workflow-roadmap_maintenance_audit.md`: force the roadmap write-back at the pre-close gate via one prompt amendment, consolidate the roadmap-maintenance timing rule to a single canonical phrasing, thin the AGENTS.md layers to pointers, and clean the roadmap defects the audit surfaced.

## Scope
Changes are proposed one at a time in chat for operator approval before any write. Queue revised after operator steering (restated paragraphs in AGENTS.md are not value-add; delegate instead):
1. `docs/operations/iteration_policy.md` Step 7: add the mandatory "Roadmap write-back" row to the pre-close summary (canonical home of the gate).
2. `AGENTS.md`: collapse the four restating paragraphs (Commit when the handover closes / Confirm scope / Confirm acceptance / Plan before executing) into one delegation paragraph + pointers to iteration_policy.md.
3. `docs/operations/roadmap_policy.md`: collapse the timing-rule phrasings to one canonical wording (GOTCHAS 2026-08-31 wording); retire the "During the iteration" variant.
4. Roadmap cleanup: compact the six stale `[x]` items out of the general track `Open:` list; add the M2.6.6 `**Acceptance criteria:**` block; reword the runnability row to "wired but unverified" (shared-machinery terms, no artefact name).
5. GOTCHAS 2026-08-31: note the gate row as the durable fix, move to probation.

## Out of scope
- pi-layer AGENTS.md (lives outside the repo; recorded as deferred).
- Any script, test, or structured-fields change (withdrawn in the audit).
- wrapup.md prompt changes.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Each AGENTS.md/policy change presented individually and approved before writing | read | Agent -- pass (5 proposals, each approved in chat before writing) |
| AC2 | One canonical timing phrasing; duplicates reduced to pointers | grep | Agent -- pass (roadmap_policy single rule; iteration_policy/handover_policy/AGENTS.md point; zero stale-anchor grep) |
| AC3 | General track `Open:` list carries only open items; M2.6.6 has an acceptance-criteria block | read | Agent -- pass (4 open rows; AC block added) |
| AC4 | Full test suite passes (record files only; suite expected green) | suite | Agent -- pass (742/742) |

## Completed

| File | Change |
|---|---|
| [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md) | Step 7 restructured: pre-close summary defined as three named sections (Acceptance criteria / Roadmap write-back / Propagation replay); write-back section links to roadmap_policy#when-the-roadmap-is-touched; "apply it verbatim" replaced by "write the approved row changes to the roadmap". Approved by operator. |
| [`AGENTS.md`](../../AGENTS.md) | Collaboration Protocol collapsed: seven iteration-mechanics paragraphs (Handover first / Keep the handover current / Commit when the handover closes / Confirm scope / Confirm acceptance / Plan before executing / Roadmap as sole task list) replaced by one "Iteration lifecycle" delegation paragraph pointing at iteration_policy, handover_policy, roadmap_policy, git_policy. Approved by operator. "Keep tests green docs up-to-date" stays as a principle (testing_policy has no section to receive the delegation -- flagged). |
| [`docs/operations/roadmap_policy.md`](docs/operations/roadmap_policy.md) | Timing rule consolidated: "During the iteration" section deleted, absorbed into one canonical rule (GOTCHAS 2026-08-31 wording: mark `[x]` in the same iteration the resolving handover closes; revert on rejection); Step 7 description now points to iteration_policy Step 7 instead of re-describing the summary. Approved by operator. |
| [`devlog/roadmap.md`](devlog/roadmap.md) | General track `Open:` list reduced to the 4 open items; 7 completed rows compacted into the completed list (1-2 sentence contract summaries, handover refs kept); "Copy delivery" row's forward-looking sentence ("Being replaced by the helper-container seed") removed; M2.6.5 gains the final seed-transport mechanism row (helper seeder + stash clear + object-store prune); M2.6.6 gains the Acceptance criteria block and the runnability row reworded to "wired but unverified". Approved by operator. |
| [`devlog/GOTCHAS.md`](devlog/GOTCHAS.md) | Entry 2026-08-31 rewritten and halved (16 -> 9 lines, one paragraph per physical line): state to probation, rule points to roadmap_policy as canonical, durable fix records the Step 7 gate row, escalation condition stated. Approved by operator. |
| [`docs/operations/roadmap_policy.md`](docs/operations/roadmap_policy.md) | Full reorganization to the operator's invoke -> invariants -> procedure pattern (approved skeleton): Role statement; "When the Roadmap Is Touched" moved before procedures; Bookkeeping and merged Milestone Promotion (check + transport subsections) as the procedure block; "Structure and Filing Rules" as the single home of record-shape invariants and filing rules; deduplicated: "Milestone numbering" rule (was a full restatement of the fractal section), "Completed milestones" and "Completed task groups" rules (owned by Top-level milestone close / Compaction cascading), the "Milestone promotion check"/"Milestone Promotion" near-duplicate headings. Anchors `#when-the-roadmap-is-touched`, `#post-close-bookkeeping`, `#top-level-milestone-close`, `#carry-forward-escalation`, `#iteration-end-steps-8-9`, `#corrections-...` preserved; `#rules` retargeted in iteration_policy to `#structure-and-filing-rules`. Approved by operator. |
| [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md) | Two `#rules` anchor links retargeted to `roadmap_policy.md#structure-and-filing-rules`. |
| [`docs/operations/handover_policy.md`](docs/operations/handover_policy.md) | What's Next duplicate timing sentence ("When an iteration generates tasks, update the roadmap at iteration end.") replaced by a pointer to roadmap_policy. Approved by operator. |
| [`AGENTS.md`](../../AGENTS.md) | "Iteration lifecycle" paragraph moved from Collaboration Protocol to its own `## Iteration Lifecycle` section (operator-edited placement, above `## Iteration Start`); seven stale iteration-mechanics paragraphs removed. Approved by operator. |

AC4: full suite 742/742 (record files only; no test changes). Historical note: the 20260819-12 dual-anchor finding (roadmap_policy#session-close-steps-8-9 vs iteration_policy#steps-89-close-and-seed) is now moot for roadmap_policy -- the anchor no longer exists; iteration_policy's own steps-89 anchor remains the single close/seed anchor.

## Findings

| # | Finding | Triaged to |
|---|---|---|
| F1 | (open) | |

## Deferred items
pi-layer AGENTS.md thinning (file lives outside the repo; needs a provider-image change).
