---
date: 2026-11-16
milestone: M3.7.2 - The change model and its refinements
type: Implementation
status: Closed
---

# Handover - one visible host-verb handoff

## Objective

Make `make draft` hand over to `make confirm` or `make reject` with the draft's state, its changed files and, on the rewritten path, the two commands that move the source onto the series.

## Scope

M3.7.2, the row **The host verbs are the user surface**, a continuation of **The branch-preparation surface is one host flow**.

The session-end hint already stops at the right boundary: resume or draft, nothing further. The draft output is where the next stage belongs. It counts the diffs but names no changed file, and on the rewritten path it says confirm will print the two move commands instead of printing them. It also offers `make apply` in the handoff, which is a separate entry point, not the next command for a drafted branch.

Out of scope: the event hooks, the verb mechanics, any new verb, and the other open M3.7.2 rows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `make draft` lists the changed files after applying the bundle. | `bash tests/test_draft_workflow.sh` (`test_draft_lists_changed_files`) | Agent [x] |
| The rewritten path prints `make confirm ... NEW=1`, `git switch <source>` and `git reset --soft <new-branch>`. | `bash tests/test_draft_workflow.sh` (extended route test) | Agent [x] |
| The handoff names `make confirm` and `make reject`, and does not name `make apply`. | the route tests assert no `make apply`; `docs/reference/tool_interface.md` keeps apply separate | Agent [x] |
| The row's flag attribution is corrected and the row carries its outcome. | `git diff -- devlog/roadmap.md` | Agent [x] |
| Every decision this iteration recorded is realized in the files. | the Decisions table against the file table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The session-end hint stays as it is: resume and draft only. | It hands over to the next command and stops; the stage that follows owns the stage after it. | this handover |
| `make draft` prints the changed files, then hands over to `make confirm` or `make reject`; the rewritten path prints `make confirm ... NEW=1`, `git switch <source>` and `git reset --soft <new-branch>`. | The reviewer needs the subject and the follow-up before acting; confirm should not be the place the move is learned. | this handover |
| Drop `make apply` from the draft handoff; it stays documented as the separate no-branch path. | Apply is an entry point, not the next command after a draft. | this handover |
| Add no test for the literal wording. Extend the existing route test for the rewritten path and add one unit for the changed-file list. | A hint test that asserts its own echoed string is a tautology. The existing tests already bind the two decisions: the draftability gate and the route. The changed-file list is the one new computation. | this handover; `tests/test_draft_workflow.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The session-end hint is already at the boundary; the earlier scope would have duplicated the draft stage inside it. | design | a second stage printed before the first is acted on | this iteration |
| `draft_print_confirm_hint` says confirm will print the two move commands, so the operator runs the action to learn the follow-up. | code | the follow-up arrives after the action it governs | this iteration |
| The draft output counts the diffs but names no changed file, so the reviewer has no visible subject. | code | the review step has no subject to review | this iteration |
| The draft handoff prints `make apply`, which is not the next command for a drafted branch. | code | the handoff points at a different entry point | this iteration |
| The existing hint tests bind the draftability gate and the route; their string expectations are change detectors, not evidence of the decision. | test | a literal assertion proves only that it ran | this handover |
| The row says `NEW=1` and `FORCE=1` deepen `confirm`; `FORCE=1` deepens `draft` and `apply`. | record | a reader learns the wrong flag on the verb | this iteration, the row text |

## Completed

| File | One-line change |
|---|---|
| `scripts/workflows/draft.sh` | Prints the changed files; hands over to confirm/reject; the rewritten path prints the move commands; `make apply` leaves the handoff |
| `tests/test_draft_workflow.sh` | The route tests assert the move and no apply; a new unit asserts the changed-file list |
| `docs/reference/tool_interface.md` | States what `make draft` prints and that apply is the separate path |
| `devlog/roadmap.md` | Corrects the flag attribution and marks the row |
| `devlog/handovers/M3.7.2/20261116-03-impl-host_verb_surface.md` | This record |
