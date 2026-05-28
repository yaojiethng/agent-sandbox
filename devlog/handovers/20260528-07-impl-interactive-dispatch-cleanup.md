# Agent Handover

**Session date:** 2026-05-28
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Impl
**Status:** Closed

## Objective

Move interactive picker logic from the dispatch layer (`agent-sandbox.sh`) into each workflow script's `main()`. Eliminates the dual sourcing/exec strategy where apply/draft interactive paths sourced workflow files while non-interactive paths used `exec`. After this change, both paths use `exec` — the dispatch layer is a flat routing table.

## Scope

- **apply.sh**: Added `--interactive` flag to `main()`. When set, sources `interactive.sh`, runs channel/session/diff_type picker (or confirm-and-go if `--diff` provided), calls `apply_run`.
- **draft.sh**: Added `--interactive` flag to `main()`. When set, sources `interactive.sh`, runs channel/session picker with patch-list confirm (or skip if both `--channel`+`--session` given), calls `draft_run`.
- **agent-sandbox.sh**: `apply` and `draft` cases simplified to pure `exec` — removed all inline `if INTERACTIVE` branches, sourcing of workflow files, and picker logic.

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

- `scripts/workflows/apply.sh`
- `scripts/workflows/draft.sh`
- `scripts/agent-sandbox.sh`

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change summary |
|---|---|
| `scripts/workflows/apply.sh` | Moved interactive picker logic into `main()` under `--interactive` flag |
| `scripts/workflows/draft.sh` | Moved interactive picker logic into `main()` under `--interactive` flag |
| `scripts/agent-sandbox.sh` | `apply`/`draft` cases reduced to pure `exec` — dispatch layer is now a flat routing table |

## Deferred items

- `draft_run` decomposition
- `set -euo pipefail` cleanup
- `require_run_args` naming consistency

## Next session

M2.7 — remaining cleanup from deferred list.
