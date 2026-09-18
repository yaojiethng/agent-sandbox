# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

When `make start` ends, the session-end output carries a resume hint. Add a sibling draft hint that names the exact session save, on both session-end surfaces that print the resume hint.

## Scope

Operator-requested ad-hoc task (not a roadmap item): extend the session-end hint pair in `scripts/run_agent.sh` (`_session_cleanup`) and `scripts/stop.sh`. Confirmed decisions (Gate 1): (1) one shared hint function prints both hints, used by both surfaces; (2) the draft hint is suppress-on-absent - printed only when a draftable session export directory exists for the session. The draft hint must pin the exact session export bundle (`make draft BUNDLE=<EXPORT_TIME>-<SESSION_ID>`), not the auto-resolved newest bundle.

Record correction (operator-steered, Gate 1): mount delivery DOES write the session export. `_session_export` in `src/capability/entrypoint.sh` has no delivery branch; the EXIT trap fires identically for copy and mount, landing `$CHANGES_DIR/session/<EXPORT_TIME>-<SESSION_ID>/` in both. The earlier proposal claim that mount writes no export was wrong.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `Resume this session later` appears once, in `src/libs/session_hints.sh` only; `run_agent.sh` and `stop.sh` call the shared function, no inline copies remain | git grep | done |
| 2 | `make start` (standard) shutdown output with a draftable export dir carries both `make resume SESSION_ID=test01` and `make draft BUNDLE=<dir>` | trace test | done |
| 3 | Same output with no export dir carries the resume hint but not the draft hint (suppress-on-absent) | trace test | done |
| 4 | `make stop --session-id=<id>` output carries the same hint pair, with the same suppress rule | trace test | done |
| 5 | `execution_model.md` and `quickstart.md` document the hint pair (draft + resume) at session end | grep | done |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/session_hints.sh`](src/libs/session_hints.sh) | New shared library: one function prints the resume + draft hint pair; sourced by both surfaces |
| [`scripts/run_agent.sh`](scripts/run_agent.sh) | `_session_cleanup` replaces its inline resume hint with the shared function |
| [`scripts/stop.sh`](scripts/stop.sh) | Same replacement on the `make stop` surface |
| [`tests/test_trace_start.sh`](tests/test_trace_start.sh) | Trace test asserting the shutdown output; extend with the draft hint |
| [`tests/test_trace_stop.sh`](tests/test_trace_stop.sh) | Trace test for `make stop`; extend with the draft hint |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Documents the teardown resume hint; update for the draft hint |
| [`docs/development/quickstart.md`](docs/development/quickstart.md) | Documents `make stop` printing the resume command; update for the hint pair |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One shared hint function prints both hints; both surfaces call it | The two hints are one operator-facing message pair; a shared function keeps the wording and the suppress rule in one place | this handover |
| Draft hint is suppress-on-absent (draftable export dir must exist) | A hint naming a non-existent or non-draftable bundle would mislead | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Scope-question answer (operator-queried, no change made): the session-save dir structure (`session/<EXPORT_TIME>-<SESSION_ID>/`) is a consumed contract - `draft_parse_folder_name` parses it, `resolve_latest_dir` relies on name-sort recency, resume maps session ids from it. Restructuring would be a cross-boundary contract change; the deferred interface-contract thread (roadmap M2.6, `20260901-02`) is its natural home. The hint solves discoverability without restructuring. | steering | next iteration |
| Mount delivery DOES write the session export: `_session_export` has no delivery branch; the EXIT trap fires identically for copy and mount. The proposal's contrary claim (Gate 1) was corrected. | steering | record |

## Completed

| File | Change |
|---|---|
| `src/libs/session_hints.sh` | New library: `session_end_hints SANDBOX_DIR SESSION_ID` prints the resume + draft hint pair; draft hint names the newest `*-SESSION_ID` export dir, gated on draftability (patches/ or uncommitted.diff) |
| `scripts/run_agent.sh` | `_session_cleanup` sources and calls the shared function; inline resume echo deleted |
| `scripts/stop.sh` | Same replacement on the `make stop` surface |
| `tests/test_trace_start.sh` | Three tests: hint pair with draftable export; suppress-on-absent (no export); suppress-on-empty-export |
| `tests/test_trace_stop.sh` | Two tests: hint pair with `--session-id` + export dir; suppress-on-absent |
| `docs/architecture/execution_model.md` | Teardown paragraph documents the hint pair |
| `docs/development/quickstart.md` | `make stop` line documents the hint pair |

## Deferred items

None.

## What's Next

<Sub-milestone: M2.6 - Session Persistence>

**Conclusions from this iteration:** the hint pair is one shared function on both session-end surfaces; draft hint is suppress-on-absent with the draftability gate; mount delivery writes session exports (no delivery branch in `_session_export`); the save-dir structure stays unchanged (consumed contract, deferred thread is its home for any rework).

**Verification:** suite 854/854 rc=0 (7 new assertions); lint 5 warnings = baseline (none in changed files); `bash -n` clean.