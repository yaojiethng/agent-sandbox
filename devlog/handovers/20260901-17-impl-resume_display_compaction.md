# Handover 20260901-17 — impl resume inventory display compaction + work/state columns

**Milestone:** M2.6 - Session Persistence
**Type:** impl
**Status:** Closed
**Date:** 2026-09-01

## Objective

Operator field feedback on `make resume --list / --interactive` output (long, messy). Requested
changes:
1. Column headers in the interactive picker (list already has them).
2. Drop the `(image-sig)` brackets after the provider.
3. Truncate branch names to 16 chars + `...`.
4. Compact relative times: `55m ago`, `7h ago`, `1D ago`, `1M ago`.
5. A work/state column in the spirit of the draft picker: patches count + uncommitted indicator,
   plus the container state.

## Design

- **Work column (host-side proxy, no docker):** the newest checkpoint for the session id under
  `session-diffs/` -- autosave dir if present, else the newest `session/<export>-<sid>` entry.
  Renders `<N>c` plus `+u` when `uncommitted.diff` is non-empty (e.g. `2c+u`); `--` when the
  session never exported. This is the same data the draft picker shows, so the two views agree.
  Volume-truth (commits inside the sandbox) would cost one docker run per session -- the same
  per-session docker cost class already rejected for list-time staleness; not pursued.
- **State column (cheap docker):** one `docker ps -a --filter label=agent-sandbox.session-id`
  call for the whole table (running/stopped); `-` when docker is absent or the container is gone.
- **Image-sig dropped from the row; `[IMAGE_STALE]` / `[SANDBOX_STALE]` markers kept** (exact
  words -- pinned by tests; they are the actionable warnings). The sig value is diagnostic only.
- **`relative_time_compact`** added to session_inventory.sh (`55m ago` / `7h ago` / `1D ago` /
  `1M ago`); verbose `relative_time` untouched (pinned by test_session_log.sh; autosave picker
  column switches to compact for consistency).
- **Picker headers:** `interactive_pick` gains an optional HEADER arg (printed under the title on
  every page); resume passes a column header line.
- `test_list_shows_image_sig_short` is updated (contract change is operator-directed); header and
  marker tests keep passing unchanged.

## Acceptance Criteria

- AC1: `relative_time_compact` added + unit-tested; `relative_time` verbose format unchanged.
- AC2: `--list` renders: compact times, 16-char truncated branch, no image-sig, work + state
  columns, headers. Marker words `[SANDBOX_STALE]` / `[IMAGE_STALE]` preserved.
- AC3: Interactive picker shows a per-page header line and the same row shape; confirm prompt
  updated accordingly.
- AC4: Work/state columns derived per the design above; graceful `-` when docker is absent.
- AC5: Suite green, lint Clean.

## Completed

| Task | Evidence |
|---|---|
| `relative_time_compact` (AC1) | `55m/7h/1D/1M ago` + `just now`/`---`; unit-tested in test_session_log.sh; verbose `relative_time` untouched |
| Row rework (AC2) | shared `_resume_render_rows` for `--list` + picker: no image-sig, branch truncated to 16 chars + `...`, compact times, `[SANDBOX_STALE]`/`[IMAGE_STALE]` markers kept (pinned words) |
| Work column (AC4) | host-side proxy: newest autosave dir, else newest `session/<export>-<sid>`; `<N>c` + `+u`; `--` when never exported |
| State column (AC4) | one `docker ps -a` label-filtered call; `-` when docker absent |
| Picker headers (AC3) | `interactive_pick` optional HEADER arg, rendered under the title on every page; resume passes the column header |
| Tests + lint (AC5) | 767/767/0 (compact-time tests; sig-display test updated to the new contract); lint Clean |
| Tests + lint (AC5) | 767/767/0 (compact-time tests; sig-display test updated to the new contract); lint Clean |
| Fixes found by the suite | associative-array subscript arithmetic under `set -u`; `--list` stdout contract restored; interactive mode must hand the picker ALL entries (picker paginates itself) |
| STATE cell consolidation (operator follow-up, same iteration) | STARTED + STATE + LAST USED merged into one STATE cell = the LAST lifecycle event from the session log (start/stop are linearizable; timestamps lexicographically comparable); docker overrides the verb when the log disagrees (crash) — `started 55m ago` / `stopped 29m ago` / `-`. Creation time stays on the record + confirm prompt (`created:`). Covered by `test_list_state_cell_from_log` (both orderings). Registration gap fixed: the provider-without-sig test had lost its run_test line in the rename; now registered. Final: 770/770/0 |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Work column from session-diffs (host-side), not volume git state | per-session docker runs are the cost class already rejected at list time; host proxy agrees with the draft picker |
| D2 | Image-sig value dropped, staleness markers kept | value is diagnostic clutter; markers are the actionable signal (operator-directed) |
| D3 | New `relative_time_compact` instead of changing `relative_time` | verbose format is pinned by test_session_log.sh and used by the confirm prompt |

## Findings

(to be filled)

## Deferred

- Volume-truth commits/unstaged per session (needs per-session docker run) -- revisit only if the
  host-side proxy proves insufficient.
