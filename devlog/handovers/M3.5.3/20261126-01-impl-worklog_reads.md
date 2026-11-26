---
date: 2026-11-26
milestone: M3.5.3 - The unified record layer
type: Implementation
status: Closed
---

# Handover - The work-log reads demand a track, and every error says how to fix it

## Objective

Make the work-log reads answer on a track the caller names or is in, offer `--all` for a caller with no track of its own, and make every failure name the flag and the live tracks that resolve it.

## Scope

The scope rule and the diagnostics for `latest` and `active`, a usage string that states every read, the module's comments removed in favour of those strings, five tests, and the two documents that state what each command answers.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `latest` and `active` demand `--track`, `--all`, or a caller's live track. | `bash scripts/worklog.sh latest` on this branch exits 1 | Agent [x] |
| An error names the live tracks and both fixes. | the same run prints the thirteen track names and `--track`/`--all` | Agent [x] |
| `--all` answers across tracks. | `bash scripts/worklog.sh latest --all` prints a path | Agent [x] |
| `--help` states every read and its flags. | `bash scripts/worklog.sh --help` | Agent [x] |
| The tests fail on the previous code. | `git stash push src/build/record-layout.mjs`, then the suite | Agent [x] |
| The gates and the suite pass. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `latest` and `active` answer only on a named, requested or caller's live track. | A global answer returns another track's record, which reads as a right one; a silent empty answer is honest but unfixable. Neither is acceptable, so the read refuses and says why. | `record-layout.mjs`; the usage string |
| `--all` is the explicit override for a caller with no track, such as triage. | The operator asked for the override rather than a default, so the broad answer is always a stated one. | `record-layout.mjs` |
| The module's comments are gone; the usage and error strings carry what they said. | The code is clear enough to read alone, and a string reaches the caller at the moment it is needed. A comment reaches only the reader of the source. | `record-layout.mjs`; `scripts/worklog.sh` |
| `list` still enumerates across tracks with no flag. | An enumeration is a set a reader filters; it has no ambiguity to resolve. | `record-layout.mjs` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The failure was in the branch, not only the lookup: `feat/M3_5_1-work-log-cleanup` names a milestone closed hours earlier, and every default read inherited it. | tool | a branch outlives its milestone, and the read followed it into a retired folder | this record |
| The first fix answered across every track and returned a `T12` record to a caller working `M3.5.3`. | tool | a confident wrong answer is worse than a silent one; the operator caught it before it shipped | this record |
| The suite held 1,755 green tests while the tool answered nothing, because every existing test passed `--track`. | test | the default scope had no coverage at all | the five tests added here |
| The error for an unknown kind read `record-layout: no root for kind nope`, which names neither the file nor the kinds that exist. | tool | an error a caller cannot act on is a second defect | `spec()` in `record-layout.mjs` |

## Completed

`src/build/record-layout.mjs` resolves the track, offers `--all`, and answers every failure with the live tracks and the flag that fixes it; its comments became the usage string it prints. `scripts/worklog.sh` is four lines and points at `--help`. `tests/test_worklog_tool.sh` gains the retired-track, named-track, all-tracks, live-track-list and help cases. `work-log` and `docs/adr/work_log_record_seam.md` state `--all`.
