# 20260919-11-impl-save_and_autosave_noop_guard

- **Handover:** 20260919-11
- **Type:** Implementation
- **Milestone:** M2.6 / M2.6.7 (Interface Contract Compatibility)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Adds a guard so session save and autosave produce nothing at all when there is
nothing to save.

## Save condition

A save triggers whenever there are uncommitted changes. It is skipped ONLY when
the working tree is completely clean AND `HEAD` is unchanged from the last save.
The guarantee: an uncommitted change is never dropped; the guard only avoids
byte-identical empty bundles.

Baseline resolution: the previous save's `.export-status HEAD=<sha>` line, else
`init_sha` from `SESSION_STATE`. No new tracking files are introduced; the
baseline reuses `init_sha` and the last-saved `HEAD`. The baseline is read
BEFORE the autosave wipe (`rm -rf`), so ordering is handled at the call site,
not inside `package_branch`. A FAILed export is not a baseline. A skip produces
nothing at all -- autosave writes nothing, and a session export creates no
session directory.

## Files in scope

- `src/libs/export_status.sh` -- `_write_export_status` accepts optional 6th
  arg and writes `HEAD=<sha>`.
- `src/libs/diff_export.sh` -- `diff_export` stamps current `HEAD` on success;
  `session_save_needed` (0 = save, 1 = skip) and `_save_baseline`.
- `src/capability/entrypoint.sh` -- autosave loop and `_session_export` resolve
  the baseline before the wipe and skip when nothing changed.
- `tests/test_session_save_guard.sh` -- new; 12 tests covering dirty, untracked,
  clean-at-baseline skip, clean-past-baseline save, baseline resolution, FAIL
  fallback, HEAD stamping.
- `tests/stubs/libs/diff_export.sh` -- extended so the mount entrypoint test
  exercises the guard.
- `docs/architecture/sandbox_lifecycle.md`, `docs/adr/diff_packaging.md` --
  document the no-op guard and the save-trigger rule.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | Uncommitted changes always trigger a save (never dropped) |
| AC2 | A clean tree with `HEAD` equal to the last save baseline triggers NO save and produces no artefact |
| AC3 | A clean tree with `HEAD` past the last save baseline triggers a save |
| AC4 | Baseline resolves from `.export-status HEAD=` on SUCCESS, else `init_sha` |
| AC5 | No new tracking files are introduced; the baseline reuses `init_sha` / last-saved `HEAD` |
| AC6 | Suite green (904/904 across 52 files) |

## Notes

The save-trigger decision is recorded in the diff-packaging ADR as the
2026-09-19 "Save only when there is a change to save" entry, extended in place
alongside the existing export-mechanism entry.
