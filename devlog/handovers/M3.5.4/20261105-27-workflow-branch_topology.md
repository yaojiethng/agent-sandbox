---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Workflow
status: Closed
---

# Handover - The branch topology, the track and the slice

## Objective

State the fractal branch tree, the track's lifecycle, the prepare obligation at every level, and the delivery commit and slice shape, so the topology is legal for parallel milestone work and the four remaining workflow bugs are fixed.

## Scope

The branch tree, the track, the trunk role, the prepare obligation, the delivery commit and slice shape, the three change runbooks, the design record's bug table, the roadmap, and the statechart's "track" wording.

Out of scope, with reasons: the ADR and reference the change model concludes into, which is the one remaining M3.5.4 row; the parallel-milestone rule, which M3.5.3 owns; a new parallelization sub-milestone, deferred to the replan that follows the unblock; a glossary entry for "track", a separate decision; a gate for the delivery-commit-and-handover condition, which is procedural for every delivery commit; the bare-`unit` sweep, filed as a roadmap row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The branch tree is fractal | `branching.md`'s branch tree | Agent [x] |
| The track states its lifetime and prepare obligation | `branching.md`'s track and prepare obligation | Agent [x] |
| The slice shape is stated | `git-discipline/SKILL.md`'s delivery commit and slice | Agent [x] |
| The prepare reads the delivery commit's handover | `prepare-rebase.md`'s obligation | Agent [x] |
| W3 to W6 are fixed | the design record's `W1` to `W6` table | Agent [x] |
| The gates are clean | `scripts/lint.sh`, `scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The three topology rows are one change | the same file set: `branching.md`, `git-discipline`, the change runbooks; splitting them makes branches trip | this record |
| The milestone tree is fractal, and a node may be collapsed | the branch tree mirrors the milestone tree; the current M3.5.4 is collapsed into the M3 track | `branching.md` |
| The track is the integration branch | the term names a role of the track, not a second branch model | `branching.md` |
| One branch carries one delivery commit, with one handover | the delivery commit is the landed change; the branch is its carrier; a slice is cut onto its own branch | `git-discipline/SKILL.md` |
| The new parallelization sub-milestone is deferred | unblock first; the replan chunks the state model for allocation | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The three rows shared one file set | defect | three branches would edit `branching.md` and the change runbooks | fixed: merged into one row and one change |
| The prepare said the branch carries a delivery commit while the accept uses the branch tip | defect | a slice as a sub-range would have landed the remainder too | fixed: one branch carries one delivery commit, and a slice is cut onto its own branch |
| The bare `unit` carried several senses and had no reserved-term entry | defect | the git docs called the branch the delivery commit, a further sense | fixed: `terminology.md`'s usage rule; the text names the delivery commit |
| The bare `unit` is still used across the shipped instruction text | gap | the mandate is rule-only until the sweep and the lint land | carried: the roadmap row |
| "track" names both the branch and the handover folder | defect | a reader can hold two meanings for one word | the statechart says "handover track"; a glossary entry is still owed |
| The branch diagram used underscores in the description | defect | the example violated the naming rule beside it | fixed |
| The W6 fix cancelled the removed assumption instead of removing it | defect | a clause answered a rule the file no longer holds | fixed: the clause and its counterpart in `git-discipline` are removed |

## Completed

| File | Change |
|---|---|
| `.agents/skills/git-discipline/references/branching.md` | the branch tree, the track, the trunk role, the prepare obligation, the lifecycle |
| `.agents/skills/git-discipline/SKILL.md` | the delivery commit and the slice; the branch-name pointer |
| `workflow/coding-agent/prompts/prepare-rebase.md` | the branch and the delivery commit |
| `workflow/coding-agent/prompts/merge-queue.md` | the moved-trunk branch leaves the queue |
| `workflow/coding-agent/prompts/accept-fast-forward.md` | the not-ready handoff includes a moved trunk |
| `devlog/discussions/20261105-design-open-change_flow.md` | the `W1` to `W6` index and statuses |
| `devlog/roadmap.md` | the topology row replaces three; the early-change and bug-census rows close |
| `docs/reference/workflow_statechart.md` | "one handover track" |
| `docs/reference/terminology.md` | the usage rule: unit is not a term |
| `devlog/handovers/M3.5.4/20261105-27-workflow-branch_topology.md` | this record |

[AMENDMENT -- 2026-11-06: the "Next session" section is removed; its items are held by the roadmap.]
