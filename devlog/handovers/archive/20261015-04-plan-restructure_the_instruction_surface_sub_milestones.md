---
date: 2026-10-15
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Plan
status: Closed
---

# Handover - restructure the instruction-surface sub-milestones

## Objective

Split the settled contract from its execution, so M3.3.1 closes on the contract alone and the policy-form retirement becomes its own sub-milestone.

## Scope

The M3.3 sub-milestone structure. A triage of M3.3.1's nineteen open rows found the milestone was two milestones in one container: its own blurb calls it the design half, while acceptance criterion 2 required the execution that follows the design. Continues handover `20261015-03`.

Three moves. Split `Retire the policy form`, `Declare the maintenance surface` and `Drop the policy bundle` into a new M3.3.2, because the two facts depend on where the retired content lands. Renumber the skill maintenance pipeline from M3.3.2 to M3.3.3, which puts the retirement before the pipeline that reads the prose standards it moves. Rehome seven rows that name a record rule, a convention or a workflow vocabulary rather than the instruction-surface contract.

Out of scope: closing M3.3.1, which waits on its one remaining row, the instruction-root reference gate. The closed handover `20261004-09` keeps its account, because it recorded the numbering at the time.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| M3.3.1 carries one open row | `sed -n '184,211p' devlog/roadmap.md \| grep -c '^- \[ \]'` returns 1, the instruction-root reference gate | Agent [x] |
| M3.3.2 carries the retirement, its slices and the two dependent facts | `sed -n '219,240p' devlog/roadmap.md` shows the parent, nine slices, the maintenance-surface row with its dispatcher sub-row, and the bundle drop | Agent [x] |
| M3.3.3 is the skill pipeline and names both predecessors | the heading reads M3.3.3 and its dependency line names M3.3.1 and M3.3.2 | Agent [x] |
| The rehomed rows sit in their new homes | `grep -n` each row; four in T1, two in M3.3.3, one merged as the maintenance-surface sub-row | Agent [x] |
| `bash scripts/lint.sh` is clean | run it, eight gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Split the policy-form retirement from M3.3.1 | the retirement executes a settled design, and keeping it gated M3.3.3, M3.5 and M3.6 on work they do not need; the milestone blurb already called M3.3.1 the design half | `devlog/roadmap.md` M3.3 |
| Renumber the retirement to M3.3.2 and the pipeline to M3.3.3 | dependency order; the pipeline reads the prose standards the retirement moves, a dependency the old numbering hid | `devlog/roadmap.md` M3.3 |
| `Declare the maintenance surface` moves with the retirement | its `scope` field must be re-sited once the policies stop carrying it, so it is retirement work | `devlog/roadmap.md` M3.3.2 |
| The two remaining handover content checks merge into the maintenance-surface row | the missing thing is a dispatcher, and the maintenance surface is the dispatcher map | `devlog/roadmap.md` M3.3.2 |
| Seven rows rehome to T1, M3.3.3 or the parked set | none names the instruction-surface contract; each names a record rule, a convention or a workflow vocabulary | `devlog/roadmap.md` T1 and M3.3.3 |
| M3.3.1 acceptance criterion 2 drops the retirement end state | it required M3.3.2's outcome; it now states the reference-resolution rule alone | `devlog/roadmap.md` M3.3.1 |
| The closed handover `20261004-09` keeps its numbering | a record states what was true when it was written | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The pipeline's dependency on `documentation_policy` was implicit in the old numbering. It reads the prose standards the retirement moves, so the pipeline always had to follow the retirement. Triaged to: `devlog/roadmap.md` M3.3.3's dependency line. | steering | roadmap |
| Nineteen open rows ran under one sub-milestone, and seven named no instruction-surface subject. Triaged to: `devlog/roadmap.md` T1 and M3.3.3, each row marked as moved from M3.3.1. | scope change | roadmap |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../../devlog/roadmap.md) | the M3.3 split, the M3.3.2 and M3.3.3 sections, the M3.3.1 acceptance-criterion amendment, the rehomed rows, the summary table and the T7 pointer |
| [`docs/adr/coding_agent_project_bindings.md`](../../../docs/adr/coding_agent_project_bindings.md) | the in-development note names M3.3.2 for the structural moves |
| [`devlog/handovers/archive/20261015-04-plan-restructure_the_instruction_surface_sub_milestones.md`](20261015-04-plan-restructure_the_instruction_surface_sub_milestones.md) | this record |
