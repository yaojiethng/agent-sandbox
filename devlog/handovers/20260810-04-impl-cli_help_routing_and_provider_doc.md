# Agent Handover

**Date:** 2026-08-10
**Milestone:** (none — cross-cutting CLI/UX bug fix; not tied to M2.6)
**Type:** Implementation (commit type: fix)
**Status:** Closed

## Objective
Make the agent-sandbox CLI help surfaces truthful and usable, and give agents
correct direction for where run/lifecycle commands live. Three concrete defects
tracked:
1. The repo-root Makefile gives no pointer to the per-sandbox generated Makefile
   where `start`/`stop`/`prune` actually live, so agents look in the wrong place.
2. `scripts/start_agent.sh` line 18 notarizes a stale `(default: opencode)` for
   `--provider` — the provider default was deliberately removed (handover
   `20260325-04`), and the current harness uses `pi`. The docstring lies.
3. Both `--help` surfaces for start/serve/dry-run are broken:
   - `agent-sandbox start --help` trips the CLI's own `require_base_args`
     before dispatch (never reaches the script).
   - `agent-sandbox help start` dispatches to `start_agent.sh --help`, but
     `start_agent.sh` does not implement the shared `usage()` + `--help|-h`
     convention from `src/libs/common.sh` (unlike `stop.sh`/`prune.sh` and the
     workflow scripts) — it errors `Unknown flag: --help`.

## Scope
- **Operator-confirmed scope (reproduced exactly):**
 - Item 1 — Add a header comment + `help` section pointer in the repo-root
   `Makefile` directing to `scripts/templates/Makefile.template` as the canonical
   home of run/lifecycle commands. No stubbed no-op targets.
 - Item 2 — Fix the `start_agent.sh` line 18 docstring: drop `(default:
   opencode)`, document `--provider` as required. No code behavior change —
   the no-default behavior is intentional.
 - Item 3 — Give `start_agent.sh` a real `usage()` (full help string: modes
   `standard|serve|dry-run`, all args + meanings, `--provider` required) and
   handle `--help|-h` before mode validation. Route the CLI so both
   `agent-sandbox start --help` and `agent-sandbox help start` reach it.
 - Item 4 (operator-added) — Include the `--help` flag and `make help` shape in
   tests as far as possible.
- **Not in scope:** adding a provider default (explicitly rejected by operator);
  prune-stale-regardless-of-age semantics (deferred to M2.6.6); any M2.6 mount
  work.
- **Deferred mid-session (per operator, at close):** the root-cause fixes for
  Mid-session Findings A-C (unify `--help`, de-landmine `SCRIPT_DIR`). This
  session ships only the stable partial fix; the A-C work is recorded for the
  next session. The operator requested the session close with the findings
  recorded in sufficient detail and the root-cause work tackled later.

## Carried forward
| Item | From |
|---|---|
| (none — fresh operator-directed session) | -- |

## Acceptance criteria
| # | Criterion | Status | Verifiable by |
|---|---|---|---|
| 1 | Repo-root `Makefile` help + header pointer to the sandbox Makefile template | done | read the file |
| 2 | `start_agent.sh` `--provider` docstring no longer claims a default; states required | done | grep for `default: opencode` — zero live hits |
| 3 | `agent-sandbox start --help`, `--help` on serve/dry-run, and `agent-sandbox help start` all print the full usage string without error | done | run CLI |
| 4 | `start_agent.sh` handles `--help|-h` via `usage()` before mode validation | done | run script |
| 5 | New/updated tests cover `--help` flag + `make help` shape; full suite green | done | `make test` (run via `bash scripts/run_tests.sh`) |
| 6 | Zero stale `default: opencode` notarizations remain in live docs/scripts | done | grep |

## Hot files
| File | Why in scope |
|---|---|
| [Makefile](../../Makefile) | header comment + help pointer to template |
| [scripts/templates/Makefile.template](../../scripts/templates/Makefile.template) | canonical home of run/lifecycle commands (reference for pointer) |
| [scripts/start_agent.sh](../../scripts/start_agent.sh) | docstring fix + `usage()` + `--help|-h` handling |
| [scripts/agent-sandbox.sh](../../scripts/agent-sandbox.sh) | CLI routing of `--help` for start/serve/dry-run |
| [tests/test_dispatch.sh](../../tests/test_dispatch.sh) | dispatch oracle tests for `--help` routing |
| [tests/test_common_lib.sh](../../tests/test_common_lib.sh) | shared help-flag convention tests (reference) |

## Decisions made this session
| # | Decision | Notes |
|---|---|---|
| 1 | No provider default — `--provider` is always required; only the docs are fixed | Operator-directed; deliberate, matches handover `20260325-04` |
| 2 | Root Makefile gets a pointer, not stubbed no-op targets | Avoids a false "works here" surface in the repo root |
| 3 | `start_agent.sh` adopts the shared `usage()` + `parse_help_flag` convention from `src/libs/common.sh` | Source `common.sh` (same pattern as `stop.sh`/`prune.sh`); use `parse_help_flag` for `--help|-h`; the dispatcher keeps a local `wants_help` predicate because it must delegate to `start_agent.sh --help` rather than print usage itself |
| 4 | Help surface tested via `test_dispatch.sh` (routing) + `test_start_agent.sh` (`usage()` output) | Operator: "include in tests as far as possible" |
| 5 | CLI help guard is a pure `wants_help` predicate (no side effects), not a helper that runs/returns | Thermo-nuclear review: dropped dead `mode` param + `|| true`/`return 1` contract |
| 6 | Test names avoid encoding syntax (no `dashdash`/`short_dash_h`); routing tests loop over modes | Operator naming feedback; matches existing `test_serve_mode`/`test_help_apply` conventions |
| 7 | Reuse `parse_help_flag` in `start_agent.sh` rather than a hand-rolled `--help` loop | Operator: Option A — source `common.sh`, use the canonical helper so all three routing scripts follow one pattern |
| 8 | "SCRIPT_DIR clobber" is benign for start_agent.sh today but is a latent landmine | Empirically verified immediate behavior is safe (BASH_SOURCE[1] resolves to same scripts/ value), but the clobber is coincidental, not contractual — see Mid-session Finding B; fix deferred |

## Mid-session findings
Recorded for a subsequent session; the root-cause fixes are **deferred**, not implemented here. This session ships only the stable partial fix.

**Finding A — `--help` is broken for *every* subcommand, not just start (systemic CLI bug).**
The dispatcher validates required args before delegating to the child script. Each leaf script (`stop.sh`, `prune.sh`) follows the convention `parse_help_flag "$@"` **before** `check_base_flags`, so the child *would* handle `--help` cleanly — but never gets control, because the CLI rejects on missing required args first. Verified empirically:
```
agent-sandbox stop --help    → fail  ("Error: --name and --sandbox are required")
agent-sandbox build --help   → fail
agent-sandbox apply --help   → fail
agent-sandbox prune --help   → fail
```
The `wants_help` predicate added this session fixes the symptom for 3 of 11 subcommands (start/serve/dry-run) and leaves the other 8 broken. This is a workaround for the systemic bug, not the root cause.
**Root-cause fix (deferred):** handle `--help|-h` once at the top of the dispatcher, before ALL per-case arg checks, by routing to the child's own help — mirroring the leaf convention. Extract the help routing currently inlined in the `help` subcommand into one `route_help()` function, call it from both a top-of-dispatch `--help` guard and the `help <sub>` subcommand, and delete `wants_help`. This fixes `--help` uniformly for all subcommands.

**Finding B — `common.sh` clobbers `SCRIPT_DIR` as a source-time side effect (landmine).**
Two unrelated conventions produce the same-named `SCRIPT_DIR`:
- Self-derived: `SCRIPT_DIR="$(dirname ${BASH_SOURCE[0]})"` — used by `start_agent.sh`, `run_agent.sh`, `onboard.sh`, `run_tests.sh`, `check_test_coverage.sh`.
- Caller-derived side-effect: `common.sh` assigns `SCRIPT_DIR="$(dirname ${BASH_SOURCE[1]})"` when sourced — `stop.sh`, `prune.sh`.
Whether sourcing `common.sh` clobbers a caller's `SCRIPT_DIR` beneficially or destructively is *coincidental* — it works only because `BASH_SOURCE[1]` happens to resolve to the same directory under the current file layout. A source that mutates a caller-owned variable is not discoverable, not guaranteed, and silently corrupts what the sourcing script already set. Verified empirically that for `start_agent.sh` it resolves to the same scripts/ value, so the immediate clobber is benign — but that is luck, not contract.
**Root-cause fix (deferred):** make `common.sh` not reassign a caller-owned variable — e.g. only set when unset (`SCRIPT_DIR="${SCRIPT_DIR:-...}"`), or stop having `common.sh` own `SCRIPT_DIR` entirely (accept it as a parameter / derive in the caller).

**Finding C — the start-family was architecturally the odd route in the dispatcher.**
The start/serve/dry-run cases are the only ones where the CLI intercepts `--help` itself (`wants_help`) instead of delegating to the child. This inconsistency predates this patch (it exists in the `help <sub>` route) and was compounded by adding `wants_help`. The uniform shape is: `--help|-h` delegates to the child's help before any arg validation, for every subcommand. Folded into Finding A's fix.

## Status of Finding A/C workaround shipped this session
`scripts/agent-sandbox.sh` carries `wants_help` as the interim, functional partial fix for start/serve/dry-run only. It is stable and tested; it is NOT the root-cause fix and should be replaced by the Finding A unification in a subsequent session.

## Completed this session
| File | Change |
|---|---|
| [scripts/start_agent.sh](../../scripts/start_agent.sh) | `--provider` docstring: dropped `(default: opencode)` → required; added full `usage()`; added clear required-provider diagnostic (no default, behaviour unchanged); sources `common.sh` and uses `parse_help_flag` for `--help|-h` (reuses canonical helper instead of hand-rolled loop) |
| [scripts/agent-sandbox.sh](../../scripts/agent-sandbox.sh) | `wants_help` predicate: `start`/`serve`/`dry-run --help|-h` route to `start_agent.sh --help` before `require_base_args` (replaces an earlier dead-parameter `help_or_run_start_agent` wrapper) |
| [Makefile](../../Makefile) | Header comment + help section pointing to `scripts/templates/Makefile.template` as canonical home of run/lifecycle commands |
| [tests/test_dispatch.sh](../../tests/test_dispatch.sh) | Tests: `help_flag_routes_run_modes_to_start_agent` (loop over 3 modes), `help_start_subcommand`; collapses earlier triplicated routing tests |
| [tests/test_start_agent.sh](../../tests/test_start_agent.sh) | Tests: `help_flag_prints_full_usage` functional, `help_short_flag` functional, `no_default_provider` doc check; deduplicated duplicated `run_test` block; dropped brittle "no default" prose assertion |

## Deferred items
| # | Item | Reason / next home |
|---|---|---|
| 1 | **Root-cause: unify `--help` handling across all subcommands** (`route_help`, delete `wants_help`) | Mid-session Finding A/C — systemic: `--help` broken for stop/build/apply/prune/draft/confirm/reject/package-branch too |
| 2 | **Root-cause: make `common.sh` not clobber `SCRIPT_DIR`** | Mid-session Finding B — latent landmine; current behavior coincidentally benign |
| 3 | Prune stale containers regardless of start time | Semantic change to `prune.sh`, entangled with M2.6.6 snapshot/volume rework |
| 4 | Stale `default: opencode` in historical docs (e.g. handover `20260318-08` free-text) | Historical record — not corrected per documentation policy (corrections only for live docs) |
| 5 | Unified `make help` in the generated sandbox Makefile | Nice-to-have UX polish; not part of this bug fix |

## Next session
Two root-cause fixes, both grounded in this session's Mid-session findings:
1. **Finding A/C — unify `--help` handling in `scripts/agent-sandbox.sh`.** Extract a `route_help()` from the `help` subcommand; handle `--help|-h` once at the top of dispatch (before all arg checks) so `agent-sandbox <sub> --help` works for every subcommand; delete `wants_help`. Fix the latent broken `--help` for stop/build/apply/prune/draft/confirm/reject/package-branch.
2. **Finding B — de-landmine `src/libs/common.sh`'s `SCRIPT_DIR` side effect.** Make it not reassign a caller-owned variable (set-if-unset or stop owning `SCRIPT_DIR`).
Also still open: M2.6.6 Mount Model (Not started; resolve the seven design questions in `devlog/discussions/20260730-design-settled-mount_model.md`), and the deferred Deferred-table items 3-5. **No carried-forward items from this session beyond the A-C root-cause work.**
