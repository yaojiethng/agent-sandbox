# Agent Handover

**Type:** workflow -- iteration_policy rewrite after the workflow refactor
**Date:** 2026-09-28
**Unit:** U5 of M3.2.1 (loop-to-workflow migration holdover)
**Intent:** gives `docs/operations/iteration_policy.md` a full consolidation pass and a staleness pass after the migration moved the loop procedures into the `workflow/` prompts, completing option B across the whole policy (not just the close and major-loop sections).
**Status:** Closed

## Objective

The migration moved the minor-loop step procedure into `/iter`. A glm subagent already applied a first option-B strip to `iteration_policy.md` (uncommitted: 31 insertions, 106 deletions). This iteration completes that work: drop the leftover session-history precedent, consolidate the whole policy (one rule, one owner, no restatement per `policy_declarative_framing.md`), and remove stale references. The result is a policy that holds rules the prompts must not break, with prompts linked.

## Carried forward

None. (U4 closed cleanly; this iteration opens on the uncommitted glm strip.)

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `iteration_policy.md` is fully option-B: every minor-loop step- and gate-procedure that `/iter` carries is stripped to a rules-holding policy, leaving no step-by-step motion walkthrough in the policy | read the policy sections against `/iter` | Agent [x] accepted |
| AC2 | The session-history precedent sentence (M2.7 / M3.1 `plan` closes) is removed from the one-commit paragraph | grep the phrase | Agent [x] accepted |
| AC3 | The policy is internally de-duplicated: no rule appears in both Principles and a step section (e.g. observable-delta AC, gate release); the surviving echoes are pointers, not duplicates | read; grep duplicate phrases | Agent [x] accepted: Principles is owner (line 41); the rules-list and gate-release echoes are one-line pointers |
| AC4 | The ownership split is stated: general rules -> AGENTS.md, iteration-variant -> `/iter`, roadmap/tests -> owning policies, during-iteration communication canonical in the policy echoed by `/iter`; the iter-agnostic rule/runbook principle is in the loops ADR | read the pointer block, iter Step 6, and the ADR | Agent [x] accepted |
| AC5 | Heading anchors `#step-1-open-handover`, `#step-7--pre-close-verification`, `#steps-89-close-and-seed` preserved; external links still resolve | `grep -rn "iteration_policy.md#"` + external-link check | Agent [x] accepted: anchors present, roadmap_policy/handover_policy/AGENTS.md/iter links resolve |
| AC6 | Lint clean | `scripts/lint.sh` | Agent [x] accepted: 0 findings |
| AC7 | Landed as one `workflow:` commit, handover `Status: Closed` | `git log` | Agent [x] accepted |

## Hot files

| File | Why in scope |
|---|---|
| `docs/operations/iteration_policy.md` | the rewrite: consolidation + staleness passes |
| `workflow/coding-agent/prompts/iter.md` | echoes for AGENTS.md proposals; write-back runbook chains to the policy canonical |
| `docs/adr/coding_agent_loop_workflow.md` | iter-agnostic rule/runbook principle |
| `docs/operations/roadmap_policy.md` | Roadmap-reflects-reality owner (already owns it; no change) |
| `docs/development/testing_policy.md` | non-trivial-logic-gets-tests canonical added |
| `devlog/roadmap.md` | M3.2.1 U5 row mark + write-back |
| `devlog/handovers/20260928-10-workflow-iteration_policy_rewrite.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| This is a `workflow:` commit and iteration per the operator's instruction | the holdover completes the M3.2.1 loop-to-workflow migration, not a docs cleanup | this handover; git policy Active Types |
| A rule has one owner; a prompt's procedural restatement is the runbook around the rule, not a second owner | the migration's "no restatement" tension resolves by duty: policy states the invariant, prompt runs it as checks; the iter-agnostic principle belongs in the loops ADR | loops ADR + this handover |
| General collaboration rules are owned by the project `AGENTS.md`; iteration-variant rules by `/iter`; roadmap/tests rules by their policies | the operator's placement: general -> AGENTS.md (all-outputs-are-proposals), workflow-specific application -> the prompt that applies it (`/plan` uses a different open-questions variant), domain rules -> owning policy | this handover |
| During-iteration communication is canonical in `iteration_policy` and echoed as a runbook by `/iter` Step 6 | it is iteration governance, not cross-loop protocol; policy states the rules, the prompt walks through them | this handover |
| The glm first-pass strip is retained and reviewed as the base; this iteration consolidates beyond it | the operator confirmed the glm strip and asked for a full consolidation + staleness pass | this handover |
| Drop the M2.7/M3.1 `plan`-close sentence from the one-commit paragraph | it is session history, not state; records state not session | this handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| glm-5.3-flash `high` dispatch of the first option-B strip on `iteration_policy.md`: stripped the minor-loop step/gate procedure to rules+links (31+/106-), preserved all external anchors, flagged the M2.7/M3.1 sentence as borderline session history | work dispatch | base for this rewrite | Triaged to: Completed (retained as the base; this iteration added consolidation + staleness) |
| The operator's placement model: general collaboration rules -> project AGENTS.md; workflow-variant rules -> the prompt that applies them; domain rules -> owning policy; during-iteration communication canonical in the policy, echoed as a runbook by the prompt; the iter-agnostic rule/runbook principle in the ADR | steering | governance model for the whole migration | Triaged to: Decisions table + ADR + Completed |

## Completed

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | full consolidation + staleness pass: Principles stripped to cadence rules + owner pointers; During-the-iteration is the canonical communication-rule block; duplicate gate-release and observable-delta-AC rules de-duplicated; M2.7/M3.1 sentence dropped; minor-loop procedure stripped |
| `workflow/coding-agent/prompts/iter.md` | echoes AGENTS.md proposals rule in Gate 1; Step 6 intro chains the write-back runbook to the policy canonical |
| `docs/adr/coding_agent_loop_workflow.md` | iter-agnostic rule/runbook principle added (one owner per rule; runbook is not a second owner; variant-by-workflow rules owned by the workflow) |
| `docs/development/testing_policy.md` | non-trivial-logic-gets-tests canonical added |
| `docs/operations/roadmap_policy.md` | confirmed as Roadmap-reflects-reality owner; no change needed |
| `devlog/roadmap.md` | M3.2.1 U5 row marked `[x]` and reworded to delivered design |

## Deferred items

None.

## What's Next

The M3.2.1 migration continues; the `Four per-prompt quality passes` row is the successor after the migration lands.
