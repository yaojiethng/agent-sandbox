---
date: 2026-10-04
milestone: M3.3 - Instruction Surface
type: Plan
status: Closed
---

# Handover - Plan: activate M3.3.1, and let the frontmatter name a sub-milestone

## Objective

Make `M3.3.1` the active milestone, move the one T1 row its acceptance criteria already cover into it, and amend the frontmatter rule so a milestone start may name a sub-milestone.

## Scope

A milestone-start session over the M3.3.1 pool.

| In | Out |
|---|---|
| The pool audit and the three task categories, graded on the [`check-in` skill](../../../workflow/coding-agent/skills/check-in/SKILL.md) axes | Any other milestone reorganization -- nothing was stale and nothing was overfull |
| Variant 1, the operator's decision: M3.3.1 keeps its five rows whole | Variants 2 and 3, the split of the link work and the step up to M3.3 |
| The T1 row `A shipped prompt reaches a repository path by a form that resolves`, moved into M3.3.1 | The T1 rows `Skill and prompt eval infrastructure` and `drafts/maintenance.md`, which stay in T1 |
| `roadmap_policy.md` `### Record shape` `**Frontmatter**`, and `milestone-start.md` `## Promote and record`, amended together | `milestone-close.md` step 2, which already matches the amended rule |

## Acceptance criteria

- `active-milestone` reads `M3.3.1`, and the rule that governs it says the field carries the level the work sits at.
- The M3.3.1 summary row reads `In progress`; the M3.3.2 row reads `Not started` and its section carries an objective paragraph only.
- `grep -n "shipped prompt" devlog/roadmap.md` returns one row, inside M3.3.1.

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | the frontmatter, the two summary rows, the moved T1 row, and the M3.3.2 demotion |
| [`docs/operations/roadmap_policy.md`](../../docs/operations/roadmap_policy.md) | the `**Frontmatter**` rule |
| [`workflow/coding-agent/prompts/milestone-start.md`](../../../workflow/coding-agent/prompts/milestone-start.md) | the bullet that set the field to the major milestone |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `active-milestone` names a sub-milestone when one is selected | the old rule left `/milestone-start` unable to record a sub-milestone activation, so the field lagged the summary row by one level; a close still sets it to the parent | `roadmap_policy.md` `### Record shape` `**Frontmatter**`; `milestone-start.md` `## Promote and record` |
| M3.3.1 keeps the whole pool rather than splitting the link work out | the shipped-prompt row is the dependency convention applied to the shipped set, and M3.3.1's acceptance criteria already name the link check over the seeded trees | the M3.3.1 section; this handover |
| M3.3.2 drops to an objective paragraph | it has not started, and it reads the contract M3.3.1 settles | the M3.3.2 section |

## Decisions pending

None.

## Findings

- The T1 row and the M3.3.1 seeded-document row are one defect from two ends: the convention says how a prompt names a repository file, and the T1 row applies it to the shipped set. Separated, each row had half the answer.

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | frontmatter set to M3.3.1; M3.3.1 row `In progress`; M3.3.2 row `Not started` and demoted to an objective; the T1 shipped-prompt row moved into M3.3.1; the M3.3 scope paragraph names it |
| [`docs/operations/roadmap_policy.md`](../../docs/operations/roadmap_policy.md) | `**Frontmatter**` states that the field carries the level the work sits at and that a start sets it |
| [`workflow/coding-agent/prompts/milestone-start.md`](../../../workflow/coding-agent/prompts/milestone-start.md) | the promote bullet sets the field to the active milestone at the level the operator selected |
