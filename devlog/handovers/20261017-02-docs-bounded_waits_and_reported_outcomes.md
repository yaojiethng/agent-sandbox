---
date: 2026-10-17
milestone: T - Harness Development Tracks
type: Documentation
status: Closed
---

# Handover - bounded waits and reported outcomes in the bash conventions

## Objective

Record the two rules the stop path's forensics exposed: an external blocking call carries a bound, and a tolerated failure is not a success message.

## Scope

`docs/development/bash-coding-conventions.md`, section 1. Recorded from the findings of the stop path iteration, handover `20261017-01`, and released by the operator. The stop path's own code is out of scope, because its fix waits on the host-side matrix.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The conventions state a bound rule for external blocking calls | section 1.18, read in the file | Agent [x] |
| The tolerance section forbids a completion sentence after a tolerated failure | section 1.16, the second half | Agent [x] |
| The rule's own example passes the shell gate | `shellcheck -S warning` on the extracted snippet | Agent [x] |
| The document gates stay clean | `make lint` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Amend 1.16 rather than add a third rule | The failure is the same failure the rule already owns, and a reader who tolerates a return is exactly the reader who then prints a sentence | section 1.16 |
| New rule 1.18 rather than a note under 1.17 | A bound is a property of a call, not of a file's shell options, so it cannot live under the file-class table | section 1.18 |
| Repair the two apostrophes in 1.16 | `command"s` and `grep"s` are wrong characters in the sentence the amendment sits under; leaving them would have the section contradict the prose standard it belongs to | section 1.16 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The existing section 1.16 passed while `scripts/stop.sh:103` printed a completion sentence after a caught failure | code reading | A rule can hold and the defect still land, because the rule never named the sentence. The amendment names it. |
| The two apostrophe defects sat in a section in the format window with every gate green | measurement, lint | The gate checks ASCII and wrapping, not quotation marks. Not filed as a row, because the class is a spelling check the operator has not asked for. |

## Completed

| File | One-line change summary |
|---|---|
| `docs/development/bash-coding-conventions.md` | Adds 1.18 for a stated bound on a blocking call, extends 1.16 to forbid a completion sentence after a tolerated failure, and repairs two apostrophes |
