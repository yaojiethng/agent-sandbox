---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Housekeeping
status: Closed
---

# Handover - The two dispatch surfaces get one destination

## Objective

Give the worker dispatch and the review dispatch a single destination row, and clean the two retired names out of the places a reader still meets them, so the consolidation has one owner instead of two drafting sessions.

## Scope

The roadmap row **One dispatch surface for the worker and the reviewer** under M3.2.2, the stale example in the M3.6.5 transport row, and the installed agent home.

The question that produced the row: are `pair` and `backend` the last holdovers, or is there holdover logic too? The answer is both, and the logic is the larger part. The review dispatch is a second launch mechanism, `review-dispatch.sh`, allowlisted by the launch-site gate as the one fixed run. It exists because the entrypoint cannot express a seat count, while the reserved terms already define one in `terminology.md` `## role` and `## role line`: a request names a role and the number of distinct models it needs, seat n takes entry n, and a seat is never filled by duplicating a model. The runner runs two seats of one assignment instead, and the role-table ADR records that as deliberate. `dispatch.md` names no seat at all, because the mechanism has none.

Out of scope: building the seat path, retiring the runner and porting its test. Those are the row's work, and the row needs a design step because two live records disagree about what a second seat is. Also out of scope: the installed `bin/review-dispatch.sh` stays, because the shipped `AGENTS.md` section still instructs it and deleting it here would break review dispatch in this container before its replacement exists.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The consolidation has one open row, and it names the seat contradiction | `grep -n "One dispatch surface for the worker and the reviewer" devlog/roadmap.md` prints the row under M3.2.2 | Agent [x] |
| The row records that the seat contract is stated and unbuilt | the row cites `terminology.md` `## role` and says `dispatch.md` names no seat | Agent [x] |
| No open row names a retired skill as part of a live set | `grep -n pi-reviewer-dispatch devlog/roadmap.md` reaches only the new row's history clause and a closed row | Agent [x] |
| The installed agent home holds `dispatch` and neither retired name | `ls ~/.pi/agent/skills \| grep -c dispatch` prints 1, and neither `opencode-dispatch` nor `pi-reviewer-dispatch` is there | Agent [x] |
| The installed copies mirror the tree | `diff -q` over the skill, the runner and `AGENTS.md` prints nothing | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The consolidation files under M3.2.2 | the operator's direction, and that sub-milestone already owns the review payload consolidation this runner serves | the roadmap row |
| The row carries the seat contradiction rather than a fix | the reserved terms and the runner disagree about what a second seat is, and settling that is a design decision the row owns; a silently chosen side would leave the loser in the tree | the row, and the F2 finding below |
| `dispatch.md` keeps naming no seat | it describes the mechanism as built, and a requirement the code does not hold is a forecast in a reference document | this record |
| The installed home is synced now rather than at provisioning | the running agent loads the home every session, so a container without the rebuild would keep handing itself the retired skill and the pre-rename runner | this record, `## Completed` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether a second seat is a second distinct assignment or a repeat of the first | the row's design step, and whether the reviewer keeps its two-family contract | distinct per `terminology.md`; a repeat per the runner and the role-table ADR |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The reserved vocabulary states a seat contract the mechanism does not implement: `terminology.md` `## role` and `## role line` say a k-seat request resolves the first k distinct entries, and no code mentions a seat | record | a reader of the vocabulary expects a capability the entrypoint lacks, which is why the reviewer needed a second script | the M3.2.2 row **One dispatch surface for the worker and the reviewer**, which owns building it |
| Two live records contradict each other about a second seat: the reserved terms say distinct models and no duplication, while the role-table ADR's 2026-10-22 entry and the shipped reviewer section say both seats run one assignment and a second seat is a repeat | record | the tree cannot satisfy both, so whichever the row builds, the other record needs correcting | the same row, whose decision-pending entry states the choice |
| The M3.6.5 transport row listed `pi-bump` and `pi-reviewer-dispatch` in the set an unfiltered cell hands a worker, and neither is a skill in that cell | record | a reader measured the defect from an example list that had drifted | fixed here: the list names the skills the cell holds |
| The installed agent home still carried `opencode-dispatch` and `pi-reviewer-dispatch`, and its `bin/review-dispatch.sh` predated the assignment rename | environment | the running container loaded two retired skills and a stale runner while the tree held neither | fixed here: both directories removed, `dispatch` and the runner installed, and all three mirrors verified |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the M3.2.2 row for the single dispatch surface; the M3.6.5 transport row's example list corrected |
| `~/.pi/agent/skills/` | `opencode-dispatch` and `pi-reviewer-dispatch` removed; `dispatch` installed from the tree |
| `~/.pi/agent/bin/review-dispatch.sh` | synced to the tree's post-rename runner |
| `~/.pi/agent/AGENTS.md` | synced to the tree's provider layer |
