---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Housekeeping
status: Closed
---

# Handover - The close-decisions row becomes a probation entry

## Objective

Move the landed close-decisions change out of the roadmap and into the feedback record's probation state, where a change awaiting an observation belongs.

## Scope

This iteration continues the milestone's cheap-row pass from handover `20261023-14`, and works the roadmap row **The close decisions move to the release gate**. The change itself landed on 2026-10-20 and is not re-opened; only its record changes. The operator named the disposition on 2026-10-23: the row is an observation, not a task.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The roadmap carries no close-decisions row | `grep -c 'close decisions move' devlog/roadmap.md` prints `0` | Accepted: prints `0` |
| The feedback record carries the entry in probation | `grep -n 'close decision that waits' -A4 devlog/AGENT_FEEDBACK.md` shows the heading and `state: probation` | Accepted: line 819 names the heading and line 821 reads `state: probation` |
| The entry names the observation that clears it | read the entry's closing paragraph | Accepted: the paragraph names a close whose delivery commit changes no record the gate confirmed |
| The umbrella is clean | `bash scripts/lint.sh` | Accepted: clean across 11 gates |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The entry is `[O]` | The operator raised the disposition in this session; the underlying finding was the agent's and is carried in the entry's body | the feedback entry |
| The entry carries no mitigation | The fix is landed, not a workaround, so the field states `none` and the body states what the gate now does | the feedback entry |
| The row is deleted rather than marked closed | A closed task that never had its ending condition met would read as delivered work; probation states the actual position | the feedback entry |

## Decisions pending

None.

## Findings

None.

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the close-decisions row is removed |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | the entry is added in probation, with the observation that clears it |
