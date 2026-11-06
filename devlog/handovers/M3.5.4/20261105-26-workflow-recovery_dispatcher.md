---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Workflow
status: Closed
---

# Handover - One `/recovery` entry, and correction is not recovery

## Objective

Give recovery one operator entry that classifies the operator's description and routes to a runbook, and separate recovery from correction in the reference and the statechart.

## Scope

The `/recovery` prompt, the `recovery` skill and its two runbooks, the `recovery` and `correction` references, the `git-discipline` runbook table, the statechart's Recovery and Correction regions and command table, and the two roadmap rows.

Out of scope, with reasons: the `/correct` umbrella, because the correction family has two entries and one normal use; the mergeability path; the reference's further relocation; a gate for one-property-per-machine.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `/recovery` is the only recovery entry | `workflow/coding-agent/prompts/recovery.md` | Agent [x] |
| The skill is operator-only | `disable-model-invocation: true`; frontmatter gate | Agent [x] |
| The router routes and redirects | the case statement, the two runbooks, the three redirects | Agent [x] |
| The reference splits honestly | `recovery.md` has no correction procedure; `correction.md` has no lost-work procedure | Agent [x] |
| The statechart separates the families | `check_statechart.sh`; `cor_*` is not in Recovery | Agent [x] |
| Every prompt is covered | `Command coverage` | Agent [x] |
| The old row leaves T1 | no `Recovery is not git work` row; the rewritten row is under M3.5.4 | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One operator entry, hidden skill | the operator owns the start; the agent owns the route | `SKILL.md`; this record |
| Recovery is partial and absent only | correction is a directed change to work the repository holds | `correction.md` |
| The router redirects a mis-filed description | naming the right command is the handoff, not a refusal | `SKILL.md` |
| `history-cleanup` stays standalone | it also runs before packaging, which is not recovery | `correction.md` |
| The old T1 row moves to M3.5.4 and closes | the skill is the procedure's home; the reference keeps the model | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The old recovery reference held two families | defect | a directed rewrite was filed as a repair | fixed: `recovery.md` and `correction.md` |
| A skill may not link a prompt outside its layer root | defect | the skill-layer gate blocked the redirect links | fixed: the redirects name the commands |
| The T1 row's concern was resolved by the skill, not by a move | defect | an open row described a home that now exists | fixed: moved to M3.5.4, rewritten, closed |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/recovery.md` | the operator entry |
| `workflow/coding-agent/skills/recovery/SKILL.md` | the hidden router |
| `workflow/coding-agent/skills/recovery/runbooks/partial.md` | the partial runbook |
| `workflow/coding-agent/skills/recovery/runbooks/absent.md` | the absent runbook, the rebuild moved |
| `.agents/skills/git-discipline/references/recovery.md` | the model only |
| `.agents/skills/git-discipline/references/correction.md` | the correction model |
| `.agents/skills/git-discipline/SKILL.md` | the runbook table |
| `docs/reference/workflow_statechart.md` | the Recovery and Correction regions, the command table, the stories |
| `devlog/roadmap.md` | the new row and the moved, rewritten, closed row |
| `devlog/handovers/M3.5.4/20261105-26-workflow-recovery_dispatcher.md` | this record |
