# Agent Handover

**Session date:** 2026-04-29
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Design → Implementation
**Status:** Active

## Objective

Add `--interactive` mode to `make apply` and `make draft` as an operator review step before changes are applied.

## Scope

Targets the Session B task group from `roadmap.md`:

- `interactive_select_sessions` utility for `draft` (table of recent sessions with availability indicators)
- Interactive confirmation prompt for `apply` (show resolved `uncommitted.diff` path, confirm/reject)
- Wire `--interactive` into `agent-sandbox.sh` for both `draft` and `apply`
- Support pre-filled default from `SESSION=<name>` in interactive mode
- Add `INTERACTIVE=1` Makefile flag; update `libs/_templates/Makefile.template`
- Test interactive mode for both commands: confirmation proceeds, rejection aborts without applying, file list matches resolved session

## Prerequisites

- Session A.1 (data model) is complete and committed
- Session A.2 (CLI contract) is complete and committed
- Session A.3 (documentation) is complete and committed

## Acceptance criteria

1. `scripts/run_tests.sh` exits 0
2. `make apply INTERACTIVE=1` shows resolved diff path and prompts confirm/reject; rejection aborts without applying
3. `make draft INTERACTIVE=1` shows session table and prompts selection; pre-filled when `SESSION=<name>` is also supplied
4. `agent-sandbox.sh` passes `--interactive` flag through to workflow functions
5. Non-interactive mode (no flag) behaviour is unchanged
6. Makefile template updated with `INTERACTIVE=1` mapping

## Risks & open questions

| Risk | Mitigation |
|---|---|
| Interactive prompts break in CI/automated environments | Only activate when `--interactive` or `INTERACTIVE=1` is explicitly set |
| TTY detection complexity | Use simple flag-based activation; do not auto-detect TTY |

## Decisions made this session

None yet.

## Mid-session findings

None yet.

## Completed this session

No file changes this session.

## Deferred items

| Item | Reason | Next destination |
|---|---|---|
| Router unit tests | Deferred from A.2 | Roadmap backlog |
| `changed-files/` separate operation | Deferred beyond A.3 per design | Roadmap backlog |

## Next session

TBD at session close.
