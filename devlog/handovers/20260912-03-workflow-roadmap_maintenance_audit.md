# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (cross-cutting: process/records quality)
**Type:** Workflow
**Status:** Closed

## Objective

Audit the roadmap-maintenance process end to end -- every instruction that governs when and how the roadmap is updated, across all layers and policy files -- to find the root cause of recurring roadmap staleness (most recently: the sed-probe row left open after its work landed) and produce a targeted, validated proposal for resolving it. Explicitly validate or reject the operator's hypothesis that the instructions are too scattered (causing inconsistent context-loading) and that consolidation-and-linking is the right shape of fix. No policy text changes in this iteration.

## Scope

- Inventory every roadmap-maintenance instruction in: the pi-layer AGENTS.md, the sandbox AGENTS.md, `docs/operations/roadmap_policy.md`, `docs/operations/iteration_policy.md`, `docs/operations/handover_policy.md`, `docs/operations/documentation_policy.md`, and `docs/operations/git_policy.md`; map which task moment each instruction is load-bearing for (iteration start / during / close).
- Audit the actual roadmap against those rules: filing questions (operator raised: M2.6.6 rows referencing `baseline.tar`, a copy-delivery artefact), stale open rows, done items with forward-looking text, and close-time update gaps in recent handovers.
- Cross-check `devlog/AGENT_FEEDBACK.md` and `devlog/GOTCHAS.md` for entries in the same problem class (e.g. GOTCHAS "Roadmap open-item status can go stale against closed handovers"; feedback on tracked-backlog proliferation and findings discipline).
- Deliver: findings with evidence, a validated/rejected statement of the scatter hypothesis, and a targeted root-cause resolution proposal (consolidation, linking, timing change, or whatever the evidence supports).
- Answer the operator's filing question (baseline.tar under M2.6.6) from the records.

## Out of scope

- Applying any policy or roadmap restructure (follow-up iteration, only after the operator picks a proposal).
- Fixing individual roadmap rows beyond what the audit needs as evidence.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Instruction inventory: every roadmap-maintenance instruction, its file, and the task moment it governs | read | Agent -- pass |
| AC2 | Roadmap defect audit with concrete evidence (rows, handovers, commits) | read | Agent -- pass |
| AC3 | Scatter hypothesis explicitly validated or rejected, with evidence | read | Agent -- pass (partially validated; root cause is chat-time write-back, not scatter alone) |
| AC4 | Targeted root-cause proposal stated, with its own acceptance criteria for a follow-up iteration | read | Agent -- pass |

## Findings

| # | Finding | Triaged to |
|---|---|---|
| F1 | gm survey error correction: the sed-probe roadmap row is `[x]` (line 109, done `20260911-04`); the gm survey reported it as an open write-back. Cause: the general track's `Open:` list mixes done and open items, and the survey read it as a live task list. | Recorded here; input to AC2 |
| F2 | Filing correction (operator): the general cross-cutting track is not mount-only. "Remove legacy seed transport" (`cfa9caa`) is a copy-mode change serving the delivery this session itself runs in; the shared snapshot primitive minus `baseline.tar` is used by both deliveries. The M2.6.6 rows referencing `baseline.tar` therefore name shared machinery, not foreign vocabulary. Revised defect statement: the rows are filed correctly; the runnability row's remaining defect is only that it does not say "wired but unverified" in shared-machinery terms. The proposed "no foreign delivery-model artefact names" lint rule is WITHDRAWN -- it would flag legitimate shared-machinery references. | AC2 revised |
| F7 | Operator pushback on the lint (roadmap_lint.sh): it would be a whole-repo state lint plus a commit-parity check across close commits -- real maintenance surface, bash wrangling of loosely-structured markdown; benefit/maintenance ratio rejected. Structured fields are NOT proposed. Lighter hand requested: force the write-back in chat time by amending the close-stage prompt. Discovery: `src/reasoning/agent/prompts/wrapup.md` already exists as a close prompt containing "Roadmap and index update (Step 8): mark completed tasks `[x]` in roadmap.md" -- the mechanism was attempted and exists, but was not invoked in any of the three 2026-09-12 closes. Adoption gap, not absence. | Proposal v3 (see AC4 revision below) |
| F3 | Scatter hypothesis: partially validated. Scatter exists but is not the primary root cause; see AC3 verdict in Completed. | AC3 |
| F4 | The three 2026-09-12 handovers (01-03) omit the handover-policy skeleton's mandatory sections (Carried forward, Hot files, Findings, What's Next, canonical null markers). The full Step 1-9 machinery was not run; operator flow was lightweight confirm/release. This divergence is itself root-cause evidence. | AC3, proposal input |
| F5 | The general track's `Open:` list carries six `[x]` done items; compaction rules exist but are not being applied to cross-cutting lists. | AC2, proposal input |

## Completed

| File | Change |
|---|---|
| [`devlog/handovers/20260912-03-workflow-roadmap_maintenance_audit.md`](devlog/handovers/20260912-03-workflow-roadmap_maintenance_audit.md) | This audit. No other files changed (out of scope by design). |

### AC1 -- Instruction inventory (where roadmap-maintenance rules live)

| Location | Loaded when | What it says |
|---|---|---|
| pi-layer AGENTS.md, Handover rules | every session | "Every iteration updates the roadmap checkboxes for completed tasks" |
| pi-layer AGENTS.md, Feedback and Gotchas | every session | "Roadmap as sole task list. When an iteration generates a task, update the roadmap at iteration end" + link to roadmap_policy#when-the-roadmap-is-touched |
| sandbox AGENTS.md, Roadmap as sole task list | every session | same rule restated, link to roadmap_policy |
| sandbox AGENTS.md, Iteration Start table | every session | read roadmap.md at start; roadmap_policy "before any roadmap update" |
| `docs/operations/roadmap_policy.md` | before a roadmap update | the full contract: timing rule (end of iteration), during-iteration checkbox marking, post-close bookkeeping (compaction cascading, milestone close, promotion, carry-forward escalation), compaction format, open-item rules |
| `docs/operations/iteration_policy.md` | iteration start/end | principle "Roadmap reflects reality"; Step 1 recovery check (verify roadmap vs prior handover); Step 7 write-back rows (completed work + generated tasks); Steps 8-9 apply write-back + post-close bookkeeping + carry-forward gate |
| `docs/operations/handover_policy.md` | iteration start/end | skeleton mandates Carried forward / Hot files / Findings / What's Next; "When an iteration generates tasks, update the roadmap at iteration end" |
| `devlog/GOTCHAS.md` 2026-08-31 | when gotchas are read at iteration start | "a roadmap task must be marked `[x]` in the same iteration its resolving handover closes ... cross-check every `[ ]` entry against its referenced handover's Status" |
| `devlog/AGENT_FEEDBACK.md` (Tracked-backlog proliferation; Findings discipline; did-the-write-land) | on surfacing | adjacent rules: rely on the roadmap as sole list; verify writes landed |

Five durable locations + two memory records govern one maintenance action. The always-loaded layers carry a one-line summary; the mechanical detail (recovery check, write-back rows, compaction, carry-forward gate, gotcha cross-check) lives only in files that are conditionally loaded.

### AC2 -- Roadmap defect audit (evidence)

| Defect | Evidence |
|---|---|
| Mixed open/done list | roadmap.md general track `Open:` list: 6 `[x]` done items (freshness reset, harness version identity, sed-probe, testing-policy, stash-clear, seed transport, arch sweep) alongside 4 genuinely open ones. Compaction per roadmap_policy is not applied to this list. Directly caused F1 (this session's own survey misread). |
| Stale-open class (the operator's trigger) | GOTCHAS 2026-08-31 documents the same class from 2026-08-31; the record prescribes a manual cross-check but no mechanical enforcement exists. |
| Missing acceptance criteria block | M2.6.6 (the active sub-milestone) has Objective + Security posture + task list but no `**Acceptance criteria:**` block, which roadmap_policy requires for the active sub-milestone. |
| Misfiled wording (not misfiled work) | M2.6.6 runnability row names `baseline.tar`, a copy-model artefact, inside a mount-model task; the wiring row uses it as a negative reference. Filing is correct; vocabulary violates the granularity rule ("omit implementation detail"). |
| Forward-looking text in done items | several `[x]` items still carry recommendation/pending language from their study phase (e.g. stash-clear row retains "recommendation adopted pending impl" in its title). Cosmetic but recurring. |

### AC3 -- Scatter hypothesis: verdict

**Partially validated -- scatter is real but secondary.** Evidence for: the maintenance contract is split across 5 policy locations + 2 memory records with three different phrasings of the timing rule ("during the iteration" / "at iteration end" / "in the same iteration the handover closes"); the operator-visible summary layers carry only the one-liner. Evidence against scatter as the root cause: the canonical file (roadmap_policy.md) is complete, internally consistent, and linked from both AGENTS.md layers at the correct moment ("before any roadmap update"); consolidation alone would not have prevented the failures because the failures occurred at a different point -- **the close**. F4 shows the full Step 1-9 machinery (which carries the recovery check, write-back rows, compaction, and carry-forward gate) was not run in any of today's three lightweight iterations; the operator's confirm/release flow does not traverse the policy docs, and the always-loaded one-liner has no mechanical hook. The root cause is that the roadmap write-back lives in a **chat-time step** (Step 7/8) rather than in a persisted artifact, so under a lightweight flow it depends entirely on agent recall -- and recall is exactly what GOTCHAS 2026-08-31 already flagged.

### AC4 -- Targeted root-cause proposal, v1/v2 (superseded -- retained as decision history; see v3 below)

Three coordinated changes, each addressing a distinct failure point:

1. **Persist the write-back in the artifact (highest leverage).** Add a `## Roadmap write-back` section to the handover skeleton (handover_policy.md format block) between Completed and Deferred items: at close, the agent must state, per task touched, the exact row change (mark `[x]`, new named entry, or `none`). The close commit then contains both the handover claim and the roadmap edit -- a stale claim becomes a visible diff inconsistency instead of an invisible omission. The lightweight flow keeps working because the write-back travels with the artifact the operator already reviews.
2. **Make the close-time check mechanical (revised per F6: script, not test).** New `scripts/checks/roadmap_lint.sh` (read-only check script, sibling convention to `scripts/manual/`; `scripts/checks/` becomes the home for future codebase-record mechanical checks, with a make target). It lints the committed state: (a) no `[x]` item inside a section titled `Open`/`Open:`; (b) every `[x]` item carries a `done \`YYYYMMDD-NN\`` reference to an existing handover file whose Status is `Closed`; (c) the active sub-milestone has an`**Acceptance criteria:**` block. Runs offline at close. Not wired into `make test` -- the test suite stays behavioural; record lint is a check.

### AC4 -- Targeted root-cause proposal, v3 (lightest hand; code changes withdrawn)

Rejected from v2: `scripts/checks/roadmap_lint.sh`. It bundles two checks -- a whole-repo state lint over roadmap + all handovers, and a claim-to-diff parity check across close commits. Both add code maintenance to the administrative side for a loosely-structured markdown corpus; the parity check especially (commit diffing) outweighs the benefit. Structured fields are not proposed. The script is withdrawn.

v3 -- one prompt amendment, zero code:

**Amend the pre-close gate (sandbox AGENTS.md, "Confirm acceptance before closing")** to require one additional row in the pre-close table the agent already presents for operator release:

> | Roadmap write-back | per task touched this iteration: the exact checkbox/entry change (or `none worked this iteration`) -- applied verbatim in the close commit |

This forces consideration at the exact chat-time moment (the release gate), travels through the review the operator already performs, and produces the roadmap edit without any parsing. The distinction "marked this session vs not yet done" remains a judgment call at release -- by design; the row just makes the claim explicit and reviewable before the commit exists, rather than reconstructable after it.

Existing adjacent mechanisms, left as-is:

- `wrapup.md` prompt already contains the Step 8 roadmap-marking instruction; it is the heavier invocation of the same step and stays optional.
- GOTCHAS 2026-08-31 keeps its monitoring role; if the row is skipped again after the amendment, that resurfacing is the recorded trigger for escalating to the artifact-section variant (a mandatory `## Roadmap write-back` section in the handover skeleton).

Also in scope for the follow-up iteration (unchanged from v1/v2): consolidation sweep (collapse the three timing phrasings to the GOTCHAS wording; thin AGENTS.md layers to pointers), the stale-row cleanup (compact the six `[x]` items out of the `Open:` list), M2.6.6 acceptance-criteria block, and the runnability row rewording. Verification: offline reads + `make test` untouched.
3. **Consolidate and thin the scatter (the operator's instinct -- do it last, not first).** Reduce the timing rule to one canonical phrasing in roadmap_policy.md; the two AGENTS.md layers keep only "roadmap is the sole task list; the close-time write-back is mandatory -- see roadmap_policy". Remove the "during the iteration" checkbox phrasing in favor of the GOTCHAS wording (same iteration as the resolving handover closes), eliminating the three-way ambiguity. This is worthwhile but would not have prevented any of the observed defects on its own.

Proposed acceptance criteria for the follow-up implementation iteration: handover skeleton gains the section (with canonical `None.` marker); `scripts/checks/roadmap_lint.sh` exists with a make target and passes on the current roadmap after the six stale `[x]` items are compacted out of the `Open:` list; parity checks operate on the close commit; M2.6.6 gains its acceptance-criteria block; the three timing phrasings collapse to one. Verification: offline script run + `make test` (no test additions).

## Deferred items

Implementation of the chosen proposal -- follow-up iteration after operator review.
