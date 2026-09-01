# Agent Handover

**Date:** 2026-05-28
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation (bug fix + refactor)
**Status:** Closed

## Objective

Fix the sha256sum digest computation in the build pipeline — it breaks on filenames with spaces because `find ... | sort | xargs sha256sum` doesn't use null separators. Extract the duplicated digest logic into a shared function.

## Scope

**In scope (proposed):**
- Extract `context_digest()` function into `src/build/context.sh` with null-safe `find -print0 | sort -z | xargs -0 sha256sum` pattern
- Update `scripts/build.sh` `build_image()` to call the shared function
- Update `tests/test_build_context.sh` `digest_of_context()` to call the shared function
- Fix the space-in-filename bug in all call sites

**Not in scope:**
- `worktree_id_derive()` in `image.sh` (different pattern — single string hash, not file listing; not affected by this bug)
- Other build pipeline changes from M2.7 roadmap

## Hot files

| File | Why in scope |
|---|---|
| `src/build/context.sh` | Add shared `context_digest()` function |
| `scripts/build.sh` | Replace inline digest with shared function call |
| `tests/test_build_context.sh` | Replace inline digest with shared function call |

## Acceptance criteria

- `context_digest()` handles filenames with spaces (null-safe find/sort/xargs)
- All 3 call sites produce identical digest output for space-free filenames
- Tests pass
- No behavioural change for non-space filenames
