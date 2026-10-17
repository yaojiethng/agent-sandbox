---
date: 2026-10-16
milestone: M3.6 - Cost-Aware Dispatch
type: Plan
status: Closed
---

# Handover - The reasoning image refactor sub-milestone

## Objective

Move the reasoning-image build work out of M3.6.1 into a sub-milestone of its own, so M3.6.1 closes on the outcome it was created for, which is a working OpenCode dispatch path, and the build refactor is planned and delivered as one subject rather than as stragglers in a closed milestone.

## Goal

Create the sub-milestone that follows M3.6.1 and move four items into it: the host build probe, the pin sweep, the build-skip removal, and the tier-change brief with the T7 row `Evaluation of stage construction`. Then close M3.6.1 on its remaining row, the dispatch script's correction pass.

## Problem

M3.6.1 has delivered its outcome. The OpenCode runtime reaches the free tier through the real CLI, the runner seam has two backends with a proof run at rc 0, the install is pinned and gated, the layer install design is settled, and the seam's CLI run path is tested. What remains in it is four rows of build-quality work: a changed image shape, a pin sweep, the removal of the reuse rule, and a `.dockerignore`. None of those produce dispatch capability, and three of them touch the same Dockerfiles, so they are one subject stranded in a milestone whose subject is a different one.

The cost of leaving them is measurable in the record rather than in the build. A reader asking what M3.6.1 delivered meets five rows about image layering and one about a dispatch script, and the milestone blurb's own last sentence claims the durable install as its scope, so the rows and the blurb agree with each other and disagree with the operator's intent to close on dispatch alone.

## Scope

The M3.6 sub-milestone structure and the rows filed under it. Specifically:

- Create the new sub-milestone and give it an objective, a dependency line, and a sequence position.
- Move `The host build probe` from M3.6.2, `Pin every build input` and `The build-skip mechanism is removed` from M3.6.1, and the tier-change work from M3.6.1.
- Move the T7 row `Evaluation of stage construction` into the new sub-milestone or record why it stays in T7.
- Amend M3.6.1's blurb, whose last sentence claims a pin, a layer design and a cache model that the restructure moves out.
- State the sequence among M3.6.1, the new sub-milestone, M3.6.2, M3.6.3 and M3.6.5, and state the dependency of M3.6.5 on the new sub-milestone at the row grain rather than the sub-milestone grain.
- Decide whether the new sub-milestone reuses the retired number M3.6.4 or takes a fresh one.

Deliverables, pending the scope gate: the roadmap restructure, and a design record or ADR amendment only if a decision needs one.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| M3.6.4 exists with an objective, a dependency line and a sequence position | the M3.6.4 section in [`devlog/roadmap.md`](../roadmap.md) | Agent [x] |
| The four named items moved into it, and the T7 row with them | the rows under M3.6.4 | Agent [x] |
| M3.6.1 is left with one open row | a count of its unchecked rows returns 1 | Agent [x] |
| M3.6.1 records that its build work was analysis and design | its blurb and the `The build work moves to M3.6.4` row | Agent [x] |
| M3.6.5's dependency is stated at the row grain | M3.6.5's `Depends on` line | Agent [x] |
| The superseded implementation increment is withdrawn | `git log` shows the payload-and-tools commit dropped and HEAD at `0b3fa06c`; the suite is green | Agent [x] |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates; 1174 tests across 83 files | Agent [x] |

## Decisions

| Decision | Reason | Source |
|---|---|---|
| The build work leaves M3.6.1 | M3.6.1's outcome is a dispatch path, and the build rows produce no dispatch capability | operator, 2026-10-16 |
| M3.6.4 reuses the retired number | the slot is free, the live record carries no reference to the retired meaning, and a fresh number would sort after M3.6.5 while sequencing before it | operator, 2026-10-16 |
| `Evaluation of stage construction` moves from T7 into M3.6.4 | T7 holds only work no milestone blurb claims, and M3.6.4's blurb claims the image build | operator, 2026-10-16 |
| M3.6.5's dependency is per row, not per sub-milestone | a blanket dependency parks eight rows that nothing gates | agent lean, accepted at the scope gate |
| The tier brief does not grow to cover M3.6.4 | a brief is one run with one check, and the three other rows have separate checks | agent lean, accepted at the scope gate |
| M3.6.4 depends on M3.6.1 but need not precede M3.6.2 or M3.6.3 | those two are the milestone's routing payoff and the refactor is infrastructure | agent lean, accepted at the scope gate |
| The superseded increment is withdrawn rather than superseded in place | it is inert, nothing consumed either image, and it is the only commit in the series with no handover | operator, 2026-10-16 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Destination |
|---|---|---|---|
| M3.6.1's blurb claims the durable install as its scope: "a pinned and gated `opencode-ai`, and a layer design that keeps the build reproducible and correctly cached" | propagation | moving the rows out leaves the blurb claiming work the milestone no longer carries | the restructure amends the blurb, or M3.6.1 closes with its own scope unmet |
| The number M3.6.4 was removed in `7e398ab2` and carried different content in `ffd084e6` | fact | the number is free in the roadmap and ambiguous in the git log | the identifier decision above |
| The T7 row `Evaluation of stage construction` is the existing home of the manifest-driven layout idea, and the tier-change brief defers to it rather than subsuming it | correction | the proposal's word "subsuming" would lose the row | the T7 decision above |
| M3.6.5 has ten rows and the image refactor gates about two of them | fact | a sub-milestone-wide dependency blocks the OpenCode surface rows | the dependency-grain decision above |
| The tier-change brief at `.agents/drafts/harness-tier-unification-run.md` is a draft and has never been released | fact | it moves with its subject and is filed under the new sub-milestone | the brief names its new home in its Origin line at the write-back |

## Record defects corrected in place

| Finding | Type | Correction |
|---|---|---|
| The active sub-milestone M3.6.1 carried no `**Acceptance criteria:**` block, which the convention requires of the active sub-milestone | record defect | added, with three operator checks |
| M3.6.5 read `In progress` while `active-milestone` names M3.6.1, and it carries no acceptance-criteria block, so it is not an active sub-milestone | record defect | its summary cell set to `Not started` |
| The convention names four milestone states, `shaped`, `active`, `closing` and `closed`, while the summary table's cells read `Not started`, `In progress` and `Complete` | fact | flagged, not fixed: the mapping is unstated, so a reader cannot tell which vocabulary a cell carries |

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | M3.6.4 created; the three build rows and the host build probe moved into it; the T7 layout row moved with them; M3.6.1 reduced to one open row, with its blurb split and its acceptance criteria added; M3.6.5's dependency re-grained; the summary table, the sequence line and the not-in-scope bullet updated |
| [`.agents/drafts/harness-tier-unification-run.md`](../../.agents/drafts/harness-tier-unification-run.md) | the tier-change brief, written this session and amended to the three rulings; it files under M3.6.4 |
| this handover | the plan-session record |
