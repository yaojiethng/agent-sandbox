# Agent Handover

**Date:** 2026-05-21
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation
**Status:** Active

## Objective

Add two features to interactive mode in `make draft` / `make apply`: (1) output the equivalent non-interactive Makefile command after the picker completes, and (2) inject option 0 in the session picker when a `SESSION=` argument names a session outside the displayed list.

## Scope

Interactive mode extensions to `libs/interactive_session_select.sh` and its wiring in `scripts/agent-sandbox.sh`.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verification |
|---|---|---|
| 1 | `make draft --interactive` shows `Running: make draft CHANNEL=<x> SESSION=<y>` before existing draft output | Run with piped input, observe first line after selections |
| 2 | `make apply --interactive` (uncommitted) shows `Running: make apply CHANNEL=<x> SESSION=<y>` before existing apply output | Same |
| 3 | `make apply --interactive` (all-changes) shows `Running: make apply DIFF=<path>` before existing apply output | Same |
| 4 | `SESSION=<outside-session> make draft --interactive` — option 0 lists it, Enter selects it | Run with Enter input, verifies it resolves to the correct session |
| 5 | `SESSION=<visible-session> make draft --interactive` — session uses normal index | Verify via test |
| 6 | All existing + new tests pass | `./tests/test_interactive_session_select.sh` exits 0 |

## Hot files

| File | Why in scope |
|---|---|
| [`libs/interactive_session_select.sh`](../../libs/interactive_session_select.sh) | Option 0 injection in `interactive_select_session` |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Command-equivalent echo before `draft_run`/`apply_run` |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | Document new interactive mode behaviour |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Document new interactive mode behaviour |
| [`tests/test_interactive_session_select.sh`](../../tests/test_interactive_session_select.sh) | Tests for option 0 injection |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Option 0 for outside-display session | `SESSION=foo` outside display → option 0. If within display, normal index. Enter selects default (option 0 when injected). | Chat |
| Command output uses Makefile form | Consistent with existing `draft_workflow.sh` confirm hint | Chat |
| diff-type selection has no non-interactive equivalent | `make apply DIFF=<path>` is the only route for `all-changes.diff` outside interactive mode | Chat |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| No Makefile variable or CLI flag for diff type (`uncommitted.diff` vs `all-changes.diff`) — non-interactive `make apply` always resolves `uncommitted.diff`. `all-changes.diff` requires `make apply DIFF=<path>`. | interface gap | recorded; not blocking |

## Completed this session

| File | Change |
|---|---|
| [`libs/interactive_session_select.sh`](../../libs/interactive_session_select.sh) | Added option 0 injection in `interactive_select_session` |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Added `Running:` echo before `draft_run`/`apply_run` in all interactive branches |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | Documented command output and option 0 injection |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Same |
| [`tests/test_interactive_session_select.sh`](../../tests/test_interactive_session_select.sh) | Added 5 tests for option 0 injection |

## Deferred items

- n/p pagination — next session.
- M2.7 items — Context handover recorded in Next session.

## Next session

**Sub-milestone:** M2.7 — Session Identity and Harness Versioning

**Divergence note:** This session superseded the M2.7 implementation thread. The prior context is at `20260521-01-impl-fix_dry_run_rename.md` and earlier sessions. When resuming M2.7, start with the roadmap task list under Track A and Track B.

**Next task:** n/p pagination for interactive session picker.

**Conclusions from this session:** Option 0 injection pattern settled. n/p pagination deferred.
