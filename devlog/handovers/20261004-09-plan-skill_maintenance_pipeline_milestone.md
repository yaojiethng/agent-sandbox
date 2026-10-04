---
date: 2026-10-04
milestone: M3.3 - Instruction Surface
type: Plan
status: Closed
---

# Handover - Plan: the M3.3 instruction-surface milestone

## Objective

Open `M3.3 -- Instruction Surface` and fill it with the pool the operator named: the prompt, skill and `AGENTS.md` interaction contract, and the skill maintenance pipeline.

## Scope

A milestone-start session. The pool was audited across T1, T7, T8 and the future M8, graded on the axes [`gm.md`](../../workflow/coding-agent/prompts/gm.md) defines, and allocated to two sub-milestones. The operator fixed the numbering and the title.

| In | Out |
|---|---|
| `M3.3` as a new parent bin with an objective and a scope paragraph | Any milestone reorganization beyond M3.3 -- no other milestone was overfull |
| `M3.3.1` -- the prompt, skill and `AGENTS.md` interaction contract, active, with four moved T1 rows | The `M8 -- Skills / Templates` section, deleted as superseded |
| `M3.3.2` -- the skill maintenance pipeline, with five rows including the first pipeline test run | The T8 writing-conventions row, already resolved at handover `20260930-04` |
| The acceptance-criteria blocks on both sub-milestones | Task authoring within either sub-milestone |

## Acceptance criteria

- The Milestone Summary table carries rows for M3.3, M3.3.1 and M3.3.2; the M8 row is gone.
- The M3.3 section sits between the M3.2.3 `Not in scope` block and the T tracks.
- `grep -rn "M8" devlog/roadmap.md devlog/roadmap_future.md` returns only the M3.3 scope paragraph's supersession clause.

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the Milestone Summary rows, the M3.3 section and its two sub-milestones, and the rows removed from T1, T7 and T8 |
| [`devlog/roadmap_future.md`](roadmap_future.md) | the deleted M8 section |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The new milestone is `M3.3`, with `M3.3.1` the contract half and `M3.3.2` the pipeline half | the operator fixed the numbering after the agent proposed a top-level milestone; the contract is the design the pipeline reads, so it runs first | this handover; the M3.3 scope paragraph |
| M8 is deleted rather than kept as a superseded stub | its three rows are stale prose naming a loader the repository does not use, and M3.3.2 names the supersession | this handover; the M3.3 scope paragraph |
| The skill maintenance record states its adaptation as prose, not a diff | the operator's correction: a skill may draw on several upstreams, and an agent-directed partial rewrite has no diff to show | this handover; the M3.3.2 acceptance criteria |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The T8 row `Writing-conventions section extraction or subsume` is already `[x]`: the standard was subsumed as `## Communication Standards` in the provider-layer `AGENTS.md` at handover `20260930-04`. The operator named it for subsumption into the new milestone; it needs no work | record | this session | Triaged to: left in T8 as closed |

## Completed

| File | Change |
|---|---|
| [`roadmap.md`](../../devlog/roadmap.md) | the M3.3 summary rows; the M3.3 section with M3.3.1 and M3.3.2; the four T1 rows, the two T7 rows and the M8 row removed; pointer clauses added to T1 and T7 |
| [`roadmap_future.md`](../roadmap_future.md) | the M8 section deleted |

Verified: `bash scripts/lint.sh` clean across six gates; `bash scripts/run_tests.sh` reports 1052 passed and 0 failed across 72 files.

## Next

`M3.3.1` is the active sub-milestone. Its first row is the seeded-document dependency convention.
