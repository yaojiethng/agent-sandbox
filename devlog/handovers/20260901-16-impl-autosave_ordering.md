# Handover 20260901-16 — impl autosave channel ordering by last-saved time

**Milestone:** M2.6 - Session Persistence
**Type:** impl
**Status:** Closed
**Date:** 2026-09-01

## Objective

Operator field report: in `make draft INTERACTIVE=1`, the autosave channel lists entries in
session-id hash order (meaningless), while the session channel orders correctly by its embedded
`EXPORT_TIME`. Autosave directories are named `autosave/<SESSION_ID>` with no timestamp, so
name-sorting can never express recency. Operator asks: order by last-saved time and show it.

## Root cause

Three consumers order bundle dirs by name:
1. `interactive.sh _interactive_select_channel` — "newest: <name>" (hash for autosave)
2. `interactive.sh _interactive_select_bundle` — picker ordering (hash order for autosave)
3. `routing.sh resolve_latest_dir` — `sort | tail -1` (lexicographically-largest hash for autosave;
   used by non-interactive draft auto-resolve AND the entrypoint's autosave fallback)

The lexicographic contract of `resolve_latest_dir` is deliberately pinned by a test (name-embedded
timestamps are authoritative for session/bundles; mtime is not). The fix is therefore
autosave-specific: autosave dirs are `rm -rf`'d and rewritten every save cycle, so the directory
mtime is exactly "last saved".

## Acceptance Criteria

- AC1: `resolve_source_for_draft autosave` (empty bundle arg) resolves the most-recently-saved
  autosave dir (mtime), not the largest session id. Session/bundles resolution unchanged (pinned
  test stays green).
- AC2: Entrypoint autosave fallback picks the most-recently-saved autosave dir.
- AC3: Interactive bundle picker: autosave entries ordered by mtime desc, with a
  `last saved: <relative>` column (reuses `relative_time` from session_inventory.sh). Session and
  bundles pickers unchanged (name order, no extra column).
- AC4: Channel list shows autosave's newest as relative time ("newest: 5 minutes ago") instead of
  a bare session-id hash.
- AC5: New unit tests pin the autosave mtime resolution; full suite green, lint Clean.

## Completed

| Task | Evidence |
|---|---|
| `resolve_latest_dir_by_mtime` added to routing.sh (AC1/AC2) | autosave-specific mtime resolution; `resolve_latest_dir` lexicographic contract untouched (pinned test stays green) |
| `resolve_source_for_draft` autosave auto-resolve uses mtime (AC1) | unit test `test_resolve_draft_autosave_newest_by_mtime` (mtime wins over lexicographically-larger name) |
| Entrypoint autosave fallback uses mtime (AC2) | `src/capability/entrypoint.sh` session-export fallback path |
| Interactive picker: autosave ordered by mtime + `last saved:` column (AC3) | `scripts/workflows/interactive.sh`; reuses `relative_time` (session_inventory.sh) — same format as `resume --list` |
| Channel list: autosave newest shown as relative time (AC4) | `newest: 5 minutes ago` instead of a bare session-id hash |
| Tests + lint (AC5) | 761/761/0 (3 new tests); `check_lint.sh` Clean |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Autosave-specific mtime resolution; `resolve_latest_dir` contract unchanged | lexicographic ordering is correct and pinned for timestamped channels; mtime is only trustworthy as "last saved" for the overwritten autosave dir |
| D2 | Reuse `relative_time` (session_inventory.sh) for the column | same human format as `resume --list`; no new formatting code |

## Completed-in-error guard

None.

## Findings

(to be filled)

## Deferred

- Autosave dirs of past sessions accumulate (12 stale dirs observed). Pruning old autosave dirs is
  a separate lifecycle question (they are the fallback safety net after a failed session export).
