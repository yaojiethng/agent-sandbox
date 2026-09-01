# Agent Handover

**Date:** 2026-05-28
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Impl (module boundary cleanup — redesign decided in chat)
**Status:** Closed

## Objective

Implement the first step of the agent-sandbox.sh control flow redesign — module boundary cleanup. Extract shared helpers, remove dead code, canonicalise duplicated routing logic, and establish per-file dependency ownership. No behaviour change.

## Scope

**Units (in order):**

- **Unit 1a** — Remove dead exports `draft_resolve_latest_export`, `draft_read_export_time` from `draft.sh`
- **Unit 1b** — Split `draft_state.sh` out of `draft.sh`: extract `draft_validate_branch`, `draft_read_state_from_branch`, `draft_write_state`, `draft_guard_no_collision`, `draft_parse_folder_name`, `draft_resolve_commit_message` into new file `src/libs/draft_state.sh`
- **Unit 1c** — Export `resolve_channel_base_dir()` from `routing.sh`; replace 3 inline case-statement copies (routing.sh ×2, interactive.sh, agent-sandbox.sh)
- **Unit 1d** — Per-file dependency ownership: `confirm.sh` and `reject.sh` source `draft_state.sh` instead of `draft.sh`; reduce top-level sources in `agent-sandbox.sh`

**Not in scope:**
- `parse_flags` extraction (deferred to dispatch refactor session)
- Interactive/non-interactive dispatch duplication (deferred)
- `draft_run` decomposition (deferred)
- `set -euo pipefail` cleanup (low priority, will naturally resolve during module work)
- `exec` inconsistency (P2, deferred)
- `require_run_args` naming (P2, deferred)
- Other M2.7 tasks

**Design questions:** None.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by |
|---|---|---|
| 1 | `draft_resolve_latest_export` and `draft_read_export_time` no longer defined anywhere | `grep -rn "draft_resolve_latest_export\|draft_read_export_time" scripts/ src/` returns 0 |
| 2 | `draft_state.sh` exists under `src/libs/` and contains `draft_validate_branch`, `draft_read_state_from_branch`, `draft_write_state`, `draft_guard_no_collision`, `draft_parse_folder_name`, `draft_resolve_commit_message` | Read `src/libs/draft_state.sh` — all 6 functions present |
| 3 | `draft.sh`'s first `source` line is `source "$AGENT_SANDBOX_REPO/src/libs/draft_state.sh"` (or the path equivalent) | `head -3 scripts/workflows/draft.sh` shows draft_state.sh sourced |
| 4 | `resolve_channel_base_dir` defined in `routing.sh`; the 3 inline case statements replaced with calls to it | `grep -c "case.*CHANNEL.*in" src/libs/routing.sh` = 0 before, 1 (the extracted function) after; `grep -c "resolve_channel_base_dir" scripts/workflows/interactive.sh scripts/agent-sandbox.sh` > 0 |
| 5 | `confirm.sh` sources `draft_state.sh` not `draft.sh` | `grep "^source" scripts/workflows/confirm.sh` shows draft_state.sh, not draft.sh |
| 6 | `reject.sh` sources `draft_state.sh` not `draft.sh` | `grep "^source" scripts/workflows/reject.sh` shows draft_state.sh, not draft.sh |
| 7 | No test regressions — existing tests still pass | `make test` passes (run after changes) |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/draft_state.sh`](../../src/libs/draft_state.sh) | New file — extracted draft-state helpers |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) | Remove dead exports; source draft_state.sh |
| [`scripts/workflows/confirm.sh`](../../scripts/workflows/confirm.sh) | Source draft_state.sh instead of draft.sh |
| [`scripts/workflows/reject.sh`](../../scripts/workflows/reject.sh) | Source draft_state.sh instead of draft.sh |
| [`src/libs/routing.sh`](../../src/libs/routing.sh) | Add `resolve_channel_base_dir`; replace inline cases |
| [`scripts/workflows/interactive.sh`](../../scripts/workflows/interactive.sh) | Replace inline case with `resolve_channel_base_dir` call |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Replace inline case with `resolve_channel_base_dir` call; reduce top-level sources |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Sequence: module cleanup → property tests → dispatch refactor | Tests against current messy boundaries would break on module split; tests after cleanup target stable interfaces | Chat (2026-05-28) |
| Per-file dependency ownership (Pattern B) over central registry | Each file responsible for its own deps; resilient to source reordering; already partially the pattern | Chat (2026-05-28) |
| Channel mapping belongs in routing.sh as `resolve_channel_base_dir()` | Routing layer already owns resolvers; mapping is a routing concept | Chat (2026-05-28) |
| Flag parsing deferred to dispatch refactor session | Would require test infrastructure and design work beyond module boundary scope | Chat (2026-05-28) |

## Mid-session findings

None.

## Completed this session

| File | Change summary |
|---|---|
| `src/libs/draft_state.sh` | New file — extracted 6 draft-state helpers (draft_parse_folder_name, draft_guard_no_collision, draft_write_state, draft_read_state_from_branch, draft_validate_branch, draft_resolve_commit_message) |
| `scripts/workflows/draft.sh` | Removed 2 dead exports (draft_resolve_latest_export, draft_read_export_time); removed 6 moved helpers; added source of draft_state.sh |
| `scripts/workflows/confirm.sh` | Changed source: draft.sh → draft_state.sh + guards.sh |
| `scripts/workflows/reject.sh` | Changed source: draft.sh → draft_state.sh + guards.sh |
| `src/libs/routing.sh` | Added resolve_channel_base_dir(); replaced 2 inline case statements with calls to it |
| `scripts/workflows/interactive.sh` | Replaced inline case in _resolve_channel_dir with call to resolve_channel_base_dir |
| `scripts/agent-sandbox.sh` | Removed 6 redundant top-level sources; moved workflow sources into case branches; replaced inline case with resolve_channel_base_dir call |

## Deferred items

Items deferred from the full redesign plan (future sessions):
- `parse_flags` extraction to `libs/flags.sh` (dispatch refactor)
- Interactive/non-interactive dispatch duplication removal
- `draft_run` decomposition
- `set -euo pipefail` cleanup
- `exec` inconsistency standardisation
- `require_run_args` naming consistency
- Property-based tests for clean interfaces
- Dispatch model refactor (Step 3)

## Next session

M2.7 — Session Identity and Harness Versioning — property-based tests against the now-clean module interfaces, then dispatch model refactor.

**Conclusions from this session:**
- All 7 findings from the control flow review triaged and prioritised (P0–P2)
- Three-phase remediation sequence agreed: module boundary cleanup → property tests → dispatch refactor
- 4 concrete units identified for the cleanup phase (1a–1d)
- Per-file dependency ownership convention established
- Channel mapping canonical home established in routing.sh
- Cleanup phase completed: dead exports removed, draft_state.sh extracted, resolve_channel_base_dir canonicalised, top-level sources reduced
