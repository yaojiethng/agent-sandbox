# Agent Handover

**Session date:** 2026-04-20
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Chore + Test Fix
**Status:** Complete

## Objective

1. Rename the capability layer diff output channel from `changes/` to `session-diffs/` across all code, configuration, and documentation (Spec 1 naming refinement).
2. Fix fixture state pollution bugs in `tests/test_apply.sh` that caused 14 tests to fail when run in sequence.
3. Create `docs/development/testing_policy.md` documenting test isolation patterns extracted from the fixes.

## Scope

- **Path rename:** `CHANGES_DIR_NAME` default value changed from `workspace/changes` to `workspace/session-diffs` in all authoritative files
- **Test fixes:** `make_project()` and `make_session()` helpers in `tests/test_apply.sh` fixed to properly isolate fixtures
- **New documentation:** `docs/development/testing_policy.md` — testing standards and anti-patterns
- **Packaging:** Session output packaged to `/home/agentuser/workspace/output/` for operator review

Explicitly out of scope:
- Historical handover documents in `docs/devlog/handovers/` — preserved as-is
- Superseded discussion doc `docs/devlog/discussions/design_git_workflow_improvements.md` — left unchanged

## Carried forward

None.

## Acceptance criteria

- [x] `CHANGES_DIR_NAME` default is `workspace/session-diffs` in `libs/dirs.sh`
- [x] Container mount path updated to `/home/agentuser/workspace/session-diffs` in `libs/docker-compose.yml`
- [x] All shell scripts reference `session-diffs` in default paths and comments
- [x] All documentation files updated with path references (excluding handovers and superseded doc)
- [x] `grep -rn "\.workspace/changes" .` returns no results outside excluded files
- [x] `tests/test_diff.sh` — 39 passed, 0 failed
- [x] `tests/test_apply_workspace.sh` — 22 passed, 0 failed
- [x] `tests/test_apply.sh` — 35 passed, 0 failed (was 22 passed, 14 failed before fixes)
- [x] `docs/development/testing_policy.md` created with patterns, anti-patterns, and templates
- [x] Session packaged with migration guide to workspace output mount

## Hot files

| File | Why in scope | Status |
|---|---|---|
| [`libs/dirs.sh`](libs/dirs.sh) | Primary `CHANGES_DIR_NAME` default definition | ✓ Updated |
| [`libs/docker-compose.yml`](libs/docker-compose.yml) | Container mount path and env var default | ✓ Updated |
| [`scripts/onboard.sh`](scripts/onboard.sh) | Directory creation and .env generation | ✓ Updated |
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | `CHANGES_DIR` path reference | ✓ Updated |
| [`tests/test_apply.sh`](tests/test_apply.sh) | Path updates + fixture isolation fixes | ✓ Fixed (35 tests) |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | Path updates | ✓ Updated (22 tests) |
| [`tests/test_capability_layer.sh`](tests/test_capability_layer.sh) | Path and mount point updates | ✓ Updated |
| [`docs/development/testing_policy.md`](docs/development/testing_policy.md) | New document — test isolation standards | ✓ Created |
| [`docs/devlog/roadmap.md`](docs/devlog/roadmap.md) | Change 2 description updated with rename note | ✓ Updated |

## Decisions made this session

**Variable naming:** `CHANGES_DIR` variable name retained (semantic meaning: "the directory containing changes"). Only the default value changed from `workspace/changes` to `workspace/session-diffs`. Rationale: the variable represents a capability/concept, not a literal path. Renaming to `SESSION_DIFFS_DIR` would be redundant with the value.

**Documentation annotations:** First occurrence of `session-diffs` in authoritative docs includes comment `# renamed from changes/ in M2.3` for future reference.

**Test fixture paths:** Helper functions now use `$SANDBOX_DIR/sandbox-work` (unique per test) instead of `$FIXTURE_DIR/sandbox-${SESSION}` (shared across tests with same session name).

## Completed this session

### Path rename (81 occurrences)
- Core libs: `dirs.sh`, `sandbox-entrypoint.sh`, `docker-compose.yml`
- Scripts: `onboard.sh`, `apply_workspace.sh`
- Tests: `test_apply.sh`, `test_apply_workspace.sh`, `test_capability_layer.sh`
- Architecture docs: `sandbox_lifecycle.md`, `execution_model.md`, `tool_interface.md`, `security.md`
- Devlog docs: `roadmap.md`, `design_apply_workflow_and_baseline_advancement.md`, 6 discussion docs
- Provider docs: `opencode/quickstart.md`, `hermes/quickstart.md`

### Test isolation fixes
**Root cause:** `make_session()` deleted `$SANDBOX_DIR/.workspace` after creating session files, destroying state it had just created. Tests calling `make_session()` multiple times (e.g., `test_draft_explicit_session_selection`) had earlier sessions deleted.

**Fixes applied:**
1. `make_project()` — added `rm -rf "$DIR"` at start to ensure clean state
2. `make_session()` — changed sandbox path from shared to unique per `SANDBOX_DIR`
3. `make_session()` — removed destructive `rm -rf "$SANDBOX_DIR/.workspace"`, now only cleans specific session directory

**Result:** All 35 tests in `test_apply.sh` now pass reliably in sequence.

### New documentation
Created `docs/development/testing_policy.md` (366 lines) covering:
- 3 core principles (isolation, cleanup, no shared state)
- 3 fixture management patterns
- 3 common anti-patterns with before/after examples
- Test structure template
- Debugging procedures for isolation failures
- Pre-commit checklist for new tests

### Packaging
Session output packaged to:
```
/home/agentuser/workspace/output/20260420141948-rename_changes_to_session_diffs_and_fix_test_isolation/
├── changes.diff (2050 lines, 87KB)
├── changed-files/ (30 files)
└── migration-guide.md (6.6KB)
```

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Next task:** Change 5 — container naming redesign + Docker labels + `scripts/checkpoint.sh`.

**Files to upload:**
- This handover
- `roadmap.md`
- `design_apply_workflow_and_baseline_advancement.md`
- `docs/development/testing_policy.md` (new)
- `libs/dirs.sh` (updated)
- `libs/docker-compose.yml` (updated)
- `scripts/apply_workspace.sh` (updated)
- `tests/test_apply.sh` (fixed)
- Migration guide and diff from workspace output mount
