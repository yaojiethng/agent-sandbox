# The retirement carry-over: handover_policy and roadmap_policy

**Status:** settled

## Context

M3.3.2 retired `docs/policies/handover_policy.md` and `docs/policies/roadmap_policy.md` by subtraction. Each retirement record names a landing for every section, and spot checks agreed at the time. No section-by-section reconciliation ran, so a rule lost in either slice is not excluded. This report produces that reconciliation: one row per section of each retired document, with its fate, its carrier, and a verdict.

The method is a read of the retired text against the current carriers. A section is **landed** when its content is present in the named carrier, **transformed** when the content survives in a changed form, and **dropped** when the content is gone, with the reason it did not need to survive.

## Retired: `docs/policies/handover_policy.md`

The record is at `75deaa0d^:docs/policies/handover_policy.md`. Its carrier set is `.agents/skills/work-log/`, `.agents/skills/task-list/`, `.agents/skills/work-log/assets/handover.md`, `workflow/coding-agent/prompts/iter.md`, `workflow/coding-agent/prompts/wrapup.md`, `workflow/coding-agent/prompts/record-correction.md`, `workflow/coding-agent/skills/handover-maintenance/`, and `workflow/coding-agent/skills/check-in/`.

| Retired section | Fate | Carrier | Verdict |
|---|---|---|---|
| `## Purpose` | transformed | the template's section guidance and the loop prompts state what the record orients | the rationale is distributed; no rule is lost, because Purpose stated why, not what |
| `## Brevity` | transformed | `.agents/skills/work-log/assets/handover.md` carries the `Completed` table as one line per file and `Acceptance criteria` as one row per criterion | landed; the one-line-per-file and one-delta-per-criterion rules survive as the template's shape |
| `## File Naming Standard` | landed | `.agents/skills/work-log/SKILL.md` `### Filename` | landed |
| `## Types` | landed | `.agents/skills/work-log/SKILL.md` `### Vocabularies` | landed |
| `## Lifecycle` | landed | `iter.md` (create, set `Active`), `wrapup.md` B9 (`Closed`), `handover-maintenance` (read) | landed; the contract is distributed per the design, no artifact states it whole |
| `## Format` | landed | `.agents/skills/work-log/assets/handover.md` and `### Section roles` | landed |
| `## The Format Window` | landed | `.agents/skills/work-log/SKILL.md` `### The format window` | landed |
| `## Canonical Null Markers` | landed | `.agents/skills/work-log/SKILL.md` `### Section roles` marker table | landed |
| `## Corrections to Closed Handovers` (`### When to apply`, `### Procedure`, `### What this is not`) | landed | `record-correction.md` `## Correcting a record`, `handover-maintenance` Step 8 | landed |
| "never edit a closed record autonomously" (remainder) | landed | `documentation_policy.md` `## Record maintenance`, `handover-maintenance` Step 8, `record-correction.md` | landed; the rule is stated where the correction runs |

## Retired: `docs/policies/roadmap_policy.md`

The record is at `89d0059c^:docs/policies/roadmap_policy.md`. Its carrier set is `.agents/skills/task-list/SKILL.md`, `workflow/coding-agent/prompts/milestone-close.md`, `workflow/coding-agent/prompts/milestone-start.md`, `workflow/coding-agent/prompts/iter.md`, `workflow/coding-agent/prompts/wrapup.md`, and `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md`.

| Retired section | Fate | Carrier | Verdict |
|---|---|---|---|
| `**One record**` (preamble) | landed | `.agents/skills/task-list/SKILL.md` opening paragraph | landed |
| `## When the Roadmap Is Touched` | transformed | the invariant to `.agents/skills/task-list/SKILL.md` `## Marking a task done`; the timing to `wrapup.md` B4 | landed; the timing moved to the procedure that enforces it, per the retirement decision |
| `## Roadmap maintenance` (`### Compaction cascading`, `### Top-level milestone close`, `### Summary table update`) | landed | `milestone-close.md` `## Compact the task list` and `## Update the records` | landed |
| `## Milestone Promotion` (`### Promotion invariant`) | landed | `milestone-close.md` `## Update the records` step 3; `milestone-start.md` and `iter.md` at their own moments | landed |
| `## Milestone States` | landed | `.agents/skills/task-list/SKILL.md` `## Milestone states` | landed |
| `## Structure and Filing Rules` (`### Fractal Milestone Numbering`, `### Record shape`, `### Filing rules`) | landed | `.agents/skills/task-list/SKILL.md` `## Milestone numbering`, `## The record's shape`, `## Filing rules` | landed |
| `## Changelog Format` (`### Entry structure`, `### Writing guidance`) | landed | `.agents/skills/task-list/SKILL.md` `## The changelog entry` | landed |
| `## Corrections to Closed Roadmap and Changelog Entries` | transformed | marker forms to `.agents/skills/task-list/SKILL.md` `## Corrections to a closed entry`; the shared principle to `documentation_policy.md` `### Post-close document corrections`; the checks to `roadmap-maintenance` | landed; the straddling section resolved by subtraction |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Every section of both retired policies resolves to a live carrier, a transformed form, or a stated drop. No rule is unaccounted for. | result | the reconciliation excludes a lost rule for these two slices |
| The `## Brevity` bullets survive only as the template's shape, not as named rules. A reader who opens `work-log/SKILL.md` meets the shape and not the rule. | observation | acceptable; the template is the form the writer fills, so the shape is the rule |
| The remainder rules of both policies ("never edit a closed record autonomously", the one-record invariant) are stated where they are enforced rather than in one home. | observation | by design; the policy-form retirement moved a remainder to the procedure that enforces it |

## Final output artifacts

This report is the sole artifact. It resolves the roadmap sub-row **Reconcile the two closed retirements, section by section** and supplies the sub-row's evidence to the lead row **Settle the split criterion and prove the template**.

## Records this supersedes

None. This report supplements the two retirement records `20261014-09` and `20261014-12`; neither is corrected.
