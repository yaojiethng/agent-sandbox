# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Command-shape refactor per roadmap "Start/serve/dry-run interface refactor": remove `agent-sandbox serve` as a first-class verb; serve becomes a toggle on `start`. Dry-run redesign explicitly OUT of scope -- deferred with options recorded on the roadmap.

## Operator decisions (this session)

1. `agent-sandbox serve` is removed outright -- no deprecation alias, no special-case message. Invoking it hits the generic unknown-command error + help.
2. Serve semantics belong under `start`; dry-run semantics differ (e2e probe, not a session start) -- separate top-level command stays.
3. Dry-run redesign deferred to its own iteration; roadmap records full-diet vs partial-diet options and a DRY constraint: any extraction must route shared logic through lib functions (extract compose-file-set assembly first), never copy entry-script orchestration.
4. Internal `MODE=serve` plumbing in run_agent.sh stays unchanged this iteration.

## Scope

| File | Change |
|---|---|
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Delete `serve)` dispatch case; usage text updated; `start` forwards `--serve` |
| [`scripts/start_agent.sh`](../../scripts/start_agent.sh) | Positional modes become standard\|dry-run; `--serve` flag sets MODE=serve internally (exclusive with dry-run); usage updated |
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | `serve:` target deleted; `SERVE_FLAG`; help text shows `make start ... SERVE=1` |
| [`src/build/compose.sh`](../../src/build/compose.sh) | Untouched unless it references serve targets |
| Tests: test_dispatch, test_start_agent (+ others found by grep) | Updated to new surface |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | start/serve sections |

Out of scope: dry-run behavior, run_agent.sh internals, wizard.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | `agent-sandbox serve` -> generic unknown-subcommand error + help | test_removed_serve_subcommand_is_unknown | accepted |
| AC2 | `agent-sandbox start --serve` reaches start_agent.sh and maps to MODE=serve | test_serve_mode + flag mapping in start_agent.sh | accepted |
| AC3 | Generated Makefile has no serve: target; `make start SERVE=1` wires the toggle | template review (SERVE_FLAG, help text) | accepted |
| AC4 | No stale references to the removed verb outside historical records/internal plumbing | repo grep: remaining `serve` mentions are run_agent.sh internals (in scope to keep), serve overlays, SERVE_PORT docs | accepted |
| AC5 | Suite green and deterministic x2 | 633 tests / 39 files / 0 failed x2; lint clean | accepted |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Dispatcher PASSTHROUGH already forwards arbitrary flags, so `--serve` needed no dispatcher parsing -- only deletion of the serve case plus start_agent.sh flag handling | simplification | Smaller diff than roadmap anticipated |
| Dry-run cost analysis for the deferral: full snapshot pipeline + identity machinery run before the mode fork; probes only need preflight + compose + probe scripts. Two diet options recorded on the new roadmap bullet with a DRY constraint (extract compose-file-set assembly into a lib first) | design input | Roadmap bullet added |

## Completed

| File | Change |
|---|---|
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | `serve)` dispatch case deleted; usage strings drop serve; help-routing list is now start\|dry-run |
| [`scripts/start_agent.sh`](../../scripts/start_agent.sh) | Positional modes standard\|dry-run; `--serve` flag maps standard->MODE=serve (conflict-checked); headers/usage updated |
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | `serve:` target removed; `SERVE_FLAG`; help text `make start PROVIDER=<p> [SERVE=1]` |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | serve-dispatch assertions rewritten for the toggle; new unknown-subcommand test for the removed verb; serve dropped from help-routing tables |
| [`tests/test_start_agent.sh`](../../tests/test_start_agent.sh) | Usage assertion checks `--serve` instead of positional serve |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | make serve section folded into make start (`SERVE=1`); mode table updated |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | Refactor bullet closed; dry-run redesign bullet added with options + DRY constraint |

## Deferred items

- Dry-run redesign (roadmap bullet: options a/b + DRY constraint).
