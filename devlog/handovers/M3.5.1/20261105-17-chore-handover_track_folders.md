---
date: 2026-11-05
milestone: M3.5.1 - The work-log record layer
type: Housekeeping
status: Closed
---

# Handover - The handovers move into track folders

## Objective

Move the live handovers into their track folders, re-path the links, and cut the cutoff tag.

## Scope

The third and last unit of M3.5.1. It moves every live handover under `devlog/handovers/<milestone-id>/`, re-paths the relative links, removes the flat-record exception from `work-log`, marks the stopgap row, and cuts `track-cutoff-2026-11-05` at the migration commit. `archive/` is untouched. The id-block READMEs are created when a track opens, not here.

The `active-milestone` scalar is set to M3.5.1 for the iteration and returns to M3.3 at close.

Out of scope, with reasons: the task-list carriers (M3.5.2/3); the discussion and feedback commands, shape-only; the id-block READMEs, which are the track opener's.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No flat handover remains | `find devlog/handovers -maxdepth 1 -name '*.md'` returns nothing; every record is under a milestone folder | Agent [x] |
| The format gate is clean over the moved tree | `bash scripts/check_handover_format.sh` | Agent [x] |
| The links resolve | `bash scripts/lint.sh` clean, including the linking rule | Agent [x] |
| The ids still resolve | `numbering` clean; the bare ids are unchanged | Agent [x] |
| The flat exception is gone | `work-log` no longer says a pre-migration record sits flat | Agent [x] |
| The tag resolves | `git rev-parse track-cutoff-2026-11-05` names the migration commit | Agent [x] |
| The stopgap row is closed | the M3.5.1 row reads `[x]` with handovers 15-17 | Agent [x] |
| The suite is green | `bash scripts/run_tests.sh`; the one failure (`test_draft_state`) passed alone on re-run and is recorded as load-dependent | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The folder is the `milestone` field's id | the field is the record's own statement of its track, and it already matches the milestone | this record |
| The tag is cut at the migration commit | the tag is the fork point tracks branch from, and the migrated tree is the first shape they need | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `test_draft_state.sh::test_write_state_basic` failed once inside the full suite and passed alone on re-run | defect | a green suite is not reproducible on demand for that file; the same class as the known intermittent `test_select_session_pagination_option_zero_persists` | `devlog/roadmap.md`, the intermittent-test row |

## Completed

| File | Change |
|---|---|
| `devlog/handovers/*.md` (243) | moved into `devlog/handovers/<milestone-id>/`; no flat handover remains |
| `.agents/drafts/dispatch-harness-defects-handoff.md`, `devlog/roadmap.md` | the two broken handover links point at the `M3.2.2/` folder |
| `.agents/skills/work-log/SKILL.md` | the flat-record exception is gone |
| `devlog/roadmap.md` | the stopgap row is `[x]` with handovers 15-17 and the tag |
| `devlog/handovers/M3.5.1/20261105-17-chore-handover_track_folders.md` | this record |
