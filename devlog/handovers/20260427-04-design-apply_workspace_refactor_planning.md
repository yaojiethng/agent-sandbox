# Agent Handover

**Session date:** 2026-04-27
**Milestone:** — (ad-hoc design session, no active roadmap milestone)
**Session type:** Design
**Status:** Closed

## Objective

Diagnose the structural problems in `scripts/apply_workspace.sh` and its test surface, design a clean decomposition, and produce a spec ready for implementation.

## Scope

Ad-hoc. No roadmap task group. Scope was: read the current implementation, identify pain points, design a replacement structure, resolve all open questions, and produce an implementation-ready spec with atomic change sequencing.

## Carried forward

None.

## Acceptance criteria

- Spec produced and approved by operator. ✓
- All open questions resolved before spec was closed. ✓
- Atomic changes sequenced bottom-up with explicit preconditions and postconditions. ✓

## Hot files

| File | Why in scope |
|---|---|
| `scripts/apply_workspace.sh` | Primary subject of the refactor — read to understand current structure |
| `libs/draft.sh` | Sourced by `apply_workspace.sh` — read to understand existing extraction boundary |
| `libs/package_branch.sh` | Feeds the draft workflow — read to confirm interface |
| `libs/package_diff.sh` | Feeds the apply workflow — read to confirm interface |
| `agent-sandbox.sh` | Entry point — read to confirm flag parsing and delegation pattern |
| `tests/test_apply.sh` | Existing draft/confirm/reject test coverage — read to establish coverage baseline |
| `tests/test_apply_workspace.sh` | Existing workflow test coverage — read to establish coverage baseline |
| `tests/test_package_branch.sh` | Read to identify fixture duplication |
| `tests/test_package_diff.sh` | Read to identify fixture duplication |
| [`spec_apply_workspace_refactor.md`](spec_apply_workspace_refactor.md) | Output — implementation-ready spec produced this session |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete `scripts/apply_workspace.sh`; `agent-sandbox.sh` becomes sole entry point | Eliminates double flag-parse; every new flag currently requires two edits | Spec — Decision 1 |
| Makefile targets updated to call `agent-sandbox` directly; no shim | Makefile is under operator control; `agent-sandbox` already accepts the same flags | Spec — Decision 1 |
| `libs/draft.sh` absorbed into `libs/draft_workflow.sh` and deleted | Functions only called from draft workflow; no independent consumers justify a separate file | Spec — Decision 2 |
| New libs: `libs/session.sh`, `libs/draft_workflow.sh`, `libs/diff_workflow.sh` | Each file owns one coherent concern; naming follows workflow boundary not command name | Spec — Decision 2 |
| `confirm` and `reject` live in `libs/draft_workflow.sh` as `confirm_run` / `reject_run` | They are draft-branch lifecycle operations; all their dependencies are already in that file | Spec — Decision 2 |
| Session resolver uses string subpath arg, not a callback function | Bash function-reference callbacks are not idiomatic; a data argument is readable and greppable | Spec — Decision 3 |
| Draft auto-resolve (newest dir with `session/patches/*.diff`) stays in `draft_workflow.sh` | More specific than lexicographic-last; `session.sh` handles the common path only | Spec — File Specifications — `libs/session.sh` |
| `validate_project_dir` lives in `libs/session.sh` | Both workflows need it; session.sh is the natural shared infrastructure file | Spec — File Specifications — `libs/session.sh` |
| Tests split by workflow: `test_draft_workflow.sh` and `test_diff_workflow.sh` | Test files follow workflow boundary, not script boundary; eliminates overlap | Spec — Decision 4 |
| Shared fixtures extracted to `tests/libs/git_fixtures.sh` and `tests/libs/session_fixtures.sh` | Three variants of the same repo-setup helper exist across test files; consolidate once | Spec — Decision 4 |
| `tests/test_session.sh` is temporary; absorbed into workflow tests in Changes 3 and 4 | Session resolver is exercised end-to-end through the workflow tests; standalone unit file not needed permanently | Spec — Changes 3, 4, 7 |

## Completed this session

| File | Change |
|---|---|
| [`spec_apply_workspace_refactor.md`](spec_apply_workspace_refactor.md) | New — implementation-ready design spec for the apply_workspace refactor, including file specifications, resolved open questions, and 7 atomic changes with explicit preconditions and postconditions |

## Deferred items

None.

## Next session

No active milestone. The next session is an implementation session executing the spec produced this session.

The spec is at `spec_apply_workspace_refactor.md` — read it in full at session open. The atomic changes are the task list; execute them in order.

**First task: extract shared test fixtures.**

Grep all test files for local repo-setup helpers (`make_sandbox`, `make_project`, `make_committed_repo` or similar) and session-structure helpers (`make_export_with_diffs`, `make_diffs_session`, `make_changes_session` or similar). The function names in the spec were accurate at writing time but may have changed — use grep output as the definitive inventory.

Write `tests/libs/git_fixtures.sh` with one canonical `make_committed_repo` covering the union of all local variants. Write `tests/libs/session_fixtures.sh` with the session-structure helpers. Update `tests/test_package_branch.sh` and `tests/test_package_diff.sh` to source `git_fixtures.sh` and remove their local definitions. Run both test files after each edit — they must pass unchanged before proceeding.

**Watch-outs:**
- The local repo-setup variants may differ subtly in behaviour (branch naming, initial commit content, git config). Resolve differences to the most general form before consolidating — do not silently narrow.
- `tests/libs/` directory may not exist yet; create it.
- `test_apply_workspace.sh` also defines session-structure helpers — move them to `session_fixtures.sh` but do not modify any test logic in that file yet. That file is deleted in Change 7, not Change 1.
