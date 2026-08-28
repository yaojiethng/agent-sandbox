# Agent Handover

**Session date:** 2026-08-10
**Milestone:** M2.6 — Session Persistence (general CLI refactor track)
**Session type:** Implementation (commit type: refactor)
**Status:** Closed

## Objective
Session 3 of the 3-session refactor split (per operator) — Finding A/C: unify
`--help` handling across every subcommand in `scripts/agent-sandbox.sh`.
Extracts the help-routing from the `help` subcommand into one `route_help()`,
adds a top-of-dispatch `--help|-h` guard (before ALL per-case arg checks), and
deletes the `wants_help` predicate and the three start/serve/dry-run `--help`
short-circuits.

This fixes the **latent Finding-A bug**: `--help` was broken for every
subcommand (stop/build/apply/prune/draft/confirm/reject/package-branch) because
the dispatcher validated required args before delegating. After this change,
`agent-sandbox <sub> --help` works uniformly for all 12 subcommands, delegating
to the child's own help before any arg validation — mirroring the leaf
convention (`parse_help_flag` runs before `check_base_flags`).

## Scope
1. `scripts/agent-sandbox.sh`:
   - Extract `route_help()` (the case currently inlined in the `help`
     subcommand) to a function before dispatch.
   - Add a top-of-dispatch `--help|-h` guard that calls `route_help`
     "$SUBCOMMAND" (exec) when a `--help`/`-h` flag is present, skipped for the
     `help` subcommand itself. **Revised (operator): help is NOT special-cased —
     `route_help help` prints the subcommand list (help's own page), so there is
     no recursion.**
   - Change the `help` subcommand to reuse `route_help`, and treat
     `help --help`/`help -h` as "show the subcommand list" (unify with bare
     `help`).
   - Delete `wants_help` and the three per-case start/serve/dry-run `--help`
     short-circuits.
2. `tests/test_dispatch.sh`:
   - Update `test_help_flag_routes_run_modes_to_start_agent` to the unified
     `exec bash ... start_agent.sh --help` form.
   - Add coverage that `--help` fires before arg validation for EVERY subcommand
     (the latent Finding-A bug) — a loop over all subcommands asserting the
     dispatch routes to the right child help.
   - Confirm `test_help_*` subcommand tests still pass with `route_help`.

**Not in scope:** provider default (stays required); prune-stale semantics;
M2.6 mount work; any further CLI behavior beyond help routing.

## Out-of-scope addition (operator-directed)
The doc `docs/development/cli-standards.md` is renamed to
`docs/development/cli-conventions.md` and re-framed as a LIST OF INTERFACE
CONVENTIONS the commands promise to respect (not "standards"). The new preamble
states this promise frame in one STE sentence. Historical references to the old
filename (handovers, discussions, AGENT_FEEDBACK) are corrected in-place with a
`[CORRECTION -- date]` block each per the post-close correction policy
(operator-authorized). The single live reference in
tools/tool_interface.md is updated.

## Decisions made this session (final)
| # | Decision | Notes |
|---|---|---|
| 1 | `route_help()` is the single help router, used by both the top-of-dispatch `--help` guard and the `help` subcommand | uniform `--help` for all subcommands + dedupe |
| 2 | `help` is not special-cased — `route_help help` prints the subcommand list and `exit 0` | operator-corrected: help is a subcommand with its own page; no recursion because it never re-dispatches |
| 3 | `--help`/`-h` on the dispatcher delegates to the child before any arg validation (Finding A/C root fix) | fixes stop/build/apply/prune/draft/confirm/reject/package-branch |
| 3b | **start/serve/dry-run normal dispatch now `exec` (review Finding 1)** | closes the residual Finding-C asymmetry; all 12 subcommands uniformly exec per cli-conventions rule 9 |
| 3c | **All 12 normal-dispatch paths now `exec bash` (review follow-up)** | onboard/stop/prune/start-family used bare `exec` while build/workflows/package-branch and the help path used `exec bash`; unified to `exec bash` everywhere, matching cli-conventions rule 9's documented form |
| 4 | `onboard.sh` `usage` made a pure reporter; error callers `exit 1` explicitly; `--help` exits 0 | `onboard --help` was exiting 1 (usage was an exit-1 printer); aligned with the leaf convention |
| 5 | `cli-standards.md` → `cli-conventions.md` (STE framing: conventions not standards) | operator-approved; new promise preamble |

## Carried forward
| Item | From |
|---|---|
| Root-cause fix for Mid-session Finding A/C (`route_help`) | handover `20260810-04`, Deferred item 1 |
| (done) Finding B + descriptive rename | `24d6ebc`, `f191889` |

## Completed this session
| File | Change |
|---|---|
| [scripts/agent-sandbox.sh](../../scripts/agent-sandbox.sh) | extracted `route_help()` + `print_subcommand_list()`; top-of-dispatch `--help/-h` guard routes any subcommand's help to the child BEFORE arg validation; `help` subcommand reuses `route_help`; `help --help/-h` shows the list; deleted `wants_help` + 3 inline short-circuits; unknown-subcommand case uses the shared list. Review-driven: start/serve/dry-run now `exec`, all 12 dispatch paths `exec bash`; hoisted `parse_flags "$@"` once before dispatch; consolidated validation into `require_name_sandbox()`/`require_project_sandbox()` alongside `require_base_args()`. Dispatcher reads "parse once, validate per branch, exec" |
| [scripts/onboard.sh](../../scripts/onboard.sh) | `--help` printed usage then continued to a failing path (rc 1). `usage` was an exit-1 printer; refactored to a pure reporter with explicit `exit 1` at the three error callers, and `-h|--help` now `usage; exit 0`. `onboard --help` now exits 0, consistent with every other subcommand |
| [tests/test_dispatch.sh](../../tests/test_dispatch.sh) | updated `test_help_flag_routes_run_modes_to_start_agent` to the unified `exec bash ... --help` form; added `test_help_every_subcommand_no_base_args` (all 12 subcommands) and `test_help_flag_shows_list` (help's own page); updated start-family normal-path assertions to the `exec ... start_agent.sh <mode>` form (review Finding 1) |
| [docs/development/cli-conventions.md](../../docs/development/cli-conventions.md) | renamed from cli-standards.md; new promise-framing preamble (conventions not standards); rule 4 gained a dispatcher-level help contract subsection |
| [docs/architecture/tool_interface.md](../../docs/architecture/tool_interface.md) | updated reference to cli-conventions.md |
| devlog handovers/discussions/AGENT_FEEDBACK | [CORRECTION--date] blocks + in-place rename of cli-standards → cli-conventions (operator-authorized) |

## Verification
- Finding-A fix confirmed: all 12 subcommands `--help` return rc 0 (were broken for stop/build/apply/prune/draft/confirm/reject/package-branch/onboard)
- `help`, `help --help`, `help -h` all show the subcommand list
- Leaf direct invocation `scripts/<sub>.sh --help` exits 0 for stop/prune/start_agent/onboard
- Real runs still validate required args (start/apply/stop without required args error rc 1)
- Full suite: 458 tests, 452 passed, 0 failed (13 new tests added)
- parse_flags hoisted to 1 call (was 12); validation consolidated into 3 helpers (was 6 inline if-blocks)
