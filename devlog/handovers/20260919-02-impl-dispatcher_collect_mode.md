# Agent Handover

**Date:** 2026-09-19
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Close the ADR exception for the agent-sandbox.sh dispatcher: convert its hand-rolled PASSTHROUGH collect loop onto the canonical `cli.sh` parser via a new collect mode. Parity contract confirmed by the operator: the front door behaves byte-identically before and after. Also record the 20260918-12 operator-optional item 2 disposition (decided-leave).

## Scope

- `src/libs/cli.sh` - extract the spec-compile machinery from `parse_args`; add `parse_args_collect USAGE_FN SINK_VAR spec... -- args...` (spec flags route into vars, unmatched args appended in order to the sink array, never errors, --help exits 2).
- `scripts/agent-sandbox.sh` - `parse_flags` becomes one collect call with a 4-flag spec (`--env`, `--name`, `--project`, `--sandbox`); `parse_base_flags` call retired from the dispatcher only; help scan and all dispatch cases untouched.
- `docs/adr/command_flag_parsing.md` - new 2026-09-19 entry superseding the 2026-09-18 rejection of the dispatcher conversion; `Current:` pointer updated.
- `tests/test_cli_lib.sh` (new) - unit coverage for `parse_args_collect`; first direct unit coverage of `parse_args`.
- `tests/test_dispatch.sh` - one new oracle case: unknown leaf flag forwarded verbatim; existing cases green unchanged = the parity proof.

Operator decisions at Gate 1: parity contract (refactor, not feat); item 2 (fold 114 assertion blocks) marked leave - not carried, reason recorded.

Design decisions made: nameref sink (bash 5.2); identity flags through the spec like the leaves; collect mode is a separate function, not a knob on `parse_args`; stay on branch `feat/M2_6_mount_model_redesign`.

## Carried forward

- (20260918-12 item 2, decision: leave) Fold the 114 residual multi-condition assertion blocks into compound asserts - not carried. Reason: the suite treats them as bespoke by design; per-block review cost exceeds the uniformity benefit; no observed pain. Confirmed by the operator at Gate 1 of 20260919-02.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `parse_args_collect` exists in cli.sh; `parse_args` behavior unchanged | unit tests (first direct `parse_args` units) | accepted (Agent: 5 parse_args + 8 collect units green) |
| 2 | Dispatcher front door byte-identical: dispatch oracle green unchanged | `tests/test_dispatch.sh` | accepted (Agent: existing cases green untouched) |
| 3 | Identity via the cli.sh spec; `parse_base_flags` retired from the dispatcher only | grep + dispatch env cases | accepted (Agent) |
| 4 | Unknown flags + positionals forwarded in order, never erroring | oracle case + unit | accepted (Agent: new case green) |
| 5 | ADR superseding entry + `Current:` pointer; no stale contradiction | read-back | accepted (Agent presence; Operator read-back) |
| 6 | Full suite green | `bash scripts/run_tests.sh` | accepted (Agent: 876/876, 49 files; baseline 854) |
| 7 | Routes/help: help scan + all dispatch cases untouched | diff review | accepted (Agent) |
| 8 | Item 2 (fold 114 assertion blocks) recorded as decided-leave | handover | accepted (Agent) |

## Hot files

| File | Reason |
|---|---|
| [`src/libs/cli.sh`](../../src/libs/cli.sh) | parse_args_collect added; spec-compile extracted and shared |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | dispatcher collects via the canonical parser |
| [`docs/adr/command_flag_parsing.md`](../../docs/adr/command_flag_parsing.md) | superseding entry; Current pointer |
| [`tests/test_cli_lib.sh`](../../tests/test_cli_lib.sh) | new unit file |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | +1 oracle case |

## Decisions

| Decision | Rationale |
|---|---|
| Parity contract: front door byte-identical (refactor) | operator Gate 1 |
| Collect mode is a separate `parse_args_collect`, sharing the compiled-spec machinery | parse_args behavior stays untouched; no knob creep |
| Identity flags enter through the cli.sh spec (like the leaves); `parse_base_flags` retired from the dispatcher | R3 (shared identity vars + check_base_flags validation) intact |
| Nameref sink | bash 5.2; no eval; no shadow trap (PASSTHROUGH resets are global writes) |
| Item 2 (114 assertion blocks): leave | operator Gate 1; not carried |
| Gate-3 review directive absorbed: one parsing implementation, local-only state, no guard accumulation | operator review; empty-spec + registry + `-g` quirks were symptoms of split logic; the core keeps all state per-call |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| Gate-3 review: the empty-spec guard, the per-parse registry reset, and `declare -g` were symptoms of split logic and module-level state; redesign absorbed them - `_cli_parse` is the single implementation with a per-call local registry; `parse_args` / `parse_args_collect` are policy wrappers | design (operator review) | this iteration | implemented in-tree; ADR entry updated; 876/876 |
| `declare -A` at a lib top-level is function-scoped when the lib is sourced inside a function: the dispatcher harness sources cli.sh via `source_harness()`, so the spec registry died at function exit and the first string-subscript write silently created an indexed array (`_cli_specs["--env"]` then evaluated `--env` as arithmetic, raising `env: unbound variable`) | agent mistake (class B proposed) | record | proposed as GOTCHAS entry: "array-attribute declarations in a sourced lib need `declare -g`, or keep the state local to a call" - pending operator confirmation |
| `\"${SPECS[@]:-}\"` on an empty array degrades to one empty-string argument; the original inline compile never hit it because leaves always pass specs | latent edge | absorbed | `_cli_parse` iterates `\"${arr[@]-}\"` with a uniform empty-skip; the degenerate case cannot arise |
| Module-level spec registry was never cleared between parses; repeated parses could match stale entries | latent edge | absorbed | registry is a per-call local; isolation pinned by `test_collect_has_no_stale_registry` |

## Verification

- Suite baseline 854/854 (pre-change); final 876/876 across 49 files (post-change): +21 cli units, +1 oracle case.
- `tests/test_cli_lib.sh`: 21 passed, 0 failed (5 parse_args, 9 collect - no-error, order, bare-value, help-passthrough, registry isolation).
- `tests/test_dispatch.sh`: 52 passed, 0 failed - the pre-existing oracle suite green and unchanged is the parity proof.
- Parity sweeps: zero `parse_flags` references remain; `parse_base_flags` still used by its other consumers only.

## Completed

| `src/libs/cli.sh` | single implementation `_cli_parse` (MODE error/drop/collect; per-call local registry; no module state); `parse_args` / `parse_args_collect` are policy wrappers |
| `scripts/agent-sandbox.sh` | `parse_flags` removed; cli.sh sourced; identity + `--env` parse through the canonical spec; rest collected in order |
| `docs/adr/command_flag_parsing.md` | 2026-09-19 entry (collect mode joined the parser; supersedes the dispatcher rejection); `Current:` pointer; 2026-09-18 bullet annotated superseded |
| `tests/test_cli_lib.sh` (new) | 13 unit cases |
| `tests/test_dispatch.sh` | +1 oracle case (order + unknown forms passthrough) |
| `devlog/handovers/20260919-02-impl-dispatcher_collect_mode.md` | this handover |

## What's Next

Sub-milestone: M2.6 - Session Persistence.

Prior iteration: `20260919-01` (workflow) closed the correspondence verification: mechanism verified delivery- and flatten-agnostic; git-based port-back retired; mount-worktree roadmap row closed; DRY candidates landed; suite 854/854.

Open operator-optional item from `20260918-12` disposition: item 1 (dispatcher collect mode) is THIS iteration; item 2 decided-leave (see Carried forward).

Roadmap open rows: interface-contract compatibility (`20260901-02`) only.
