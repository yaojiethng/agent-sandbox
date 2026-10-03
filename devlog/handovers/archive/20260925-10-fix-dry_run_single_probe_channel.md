# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Close the "Dry-run harness: one probe, one channel" roadmap row: the capability marker must not survive a successful dry run, and the two probes must carry one preamble instead of two copies. Rows 294 and 300.

## Scope

The two dry-run probes (`scripts/dry_run_capability.sh`, `scripts/dry_run_reasoning.sh`) and the harness they share (`src/libs/dry_run_harness.sh`), plus the probe test and the two records the row lives in. The fix lane had already landed the row's neighbours (rows 292, 293, 295 to 299); this unit takes the two that remained.

## Carried forward

None.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| A successful reasoning probe leaves no capability marker behind | `test_marker_is_consumed_by_the_reader` | Agent [x] |
| A wrong marker stays in place for diagnosis | the same unit, second half | Agent [x] |
| The two probes share one preamble | `dry_run_bootstrap` in the harness, called by both | Agent [x] |
| The shared bootstrap's fallback is exercised | `test_probe_bootstrap_resolves_channels_from_root` | Agent [x] |
| The new units bite | three mutations against the full suite, each PROVEN with a named failing file | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |
| Suite green | `bash scripts/run_tests.sh` | Agent [x] - 783 units, 62 files, 0 failed |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/dry_run_harness.sh`](../../src/libs/dry_run_harness.sh) | new `dry_run_bootstrap` |
| [`scripts/dry_run_capability.sh`](../../scripts/dry_run_capability.sh) | preamble replaced by the bootstrap call |
| [`scripts/dry_run_reasoning.sh`](../../scripts/dry_run_reasoning.sh) | same, plus the marker consume |
| [`tests/test_dry_run_probe.sh`](../../tests/test_dry_run_probe.sh) | two new units, a record-path argument, an own deadline |
| [`devlog/roadmap.md`](../roadmap.md) | the row is closed |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | rows 294 and 300 move to `resolved` |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | the per-file deadline entry |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The reader consumes the marker, rather than the writer cleaning up after its run | the marker is a handshake token between two containers, and only the reader knows the read succeeded; consuming it there also removes the stale-marker path that could pass the check without a live capability layer | this handover and the probe's comment |
| The failure branch keeps the marker | diagnosis needs the evidence, and the writer's message names the content it rejected | the probe's comment |
| The shared preamble lives in `dry_run_bootstrap` (path defaults plus the `dirs_resolve` fallback) | bite B7 survived because nothing ran the fallback; one function gives it one home, and the new unit gives it one consumer | this handover |
| The probes keep their own `set -o pipefail` and their comment on the deliberate absence of `set -e`/`set -u` | a sourced library must not change its caller's shell options, and each probe owns that choice for itself | this handover |
| The dry-run probe test declares its own 10s deadline | it runs 20+ probe invocations, it timed out at the 5s default once, and a timeout drops the file's whole unit report from the aggregate | the file header and [`docs/development/test_harness_mechanism.md`](../../docs/development/test_harness_mechanism.md) |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `tests/test_dry_run_probe.sh` reported `TIMEOUT test_dry_run_probe.sh (exceeded 5s deadline)` once during a bite run, and the aggregate then read 764 units against a 783-unit baseline, because a timed-out file contributes no unit report at all. Two clean re-runs and a standalone reproduction did not repeat it. | flake | the deadline is declared in the file; the aggregate's silent loss of a timed-out file's units is an observation for the mutation-suite row, which reads the aggregate to judge a survivor |
| `tests/test_start_agent.sh` measured 5.7s, `test_runner_selftest.sh` 5.8s and `test_dry_run_probe.sh` 5.4s standalone on this container. The figures are load-inflated (the suite is green), but they put three harness files in the same class as the two that now declare a budget. | latency budget | a candidate row: measure the heavy files' honest runtimes and declare a budget where the 5s default has no headroom |
| The capability probe's other rows (292, 293, 295, 296, 297, 298) and the reasoning probe's marker path (299) are `resolved` in the register, landed by the fix lane. | record | none; recorded so the neighbours are not re-opened |
| The reasoning probe carried a dead comment for the record writer that had moved to the harness. | comment drift | removed in this unit, since the harness now owns the writer by name |

## Completed

| File | Change |
|---|---|
| `src/libs/dry_run_harness.sh` | new `dry_run_bootstrap`: sources `session_state.sh`, defaults `ROOT`, resolves the four probe paths, and runs the `dirs_resolve` fallback |
| `scripts/dry_run_capability.sh` | the preamble is three lines: locate the harness, call the bootstrap, source its own two libs |
| `scripts/dry_run_reasoning.sh` | the same preamble, and the marker is removed after a successful read |
| `tests/test_dry_run_probe.sh` | `test_probe_bootstrap_resolves_channels_from_root` and `test_marker_is_consumed_by_the_reader`; a record-path argument for a probe that resolves its own paths; a declared 10s deadline |
| `devlog/roadmap.md` | the dry-run harness row is closed |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | rows 294 and 300 are `resolved` |
| `devlog/AGENT_FEEDBACK.md` | a `[A]` entry records the per-file deadline class |

## Deferred items

| Item | Reason | Where it goes |
|---|---|---|
| Measure the heavy test files' honest runtimes and declare deadlines where the default has no headroom | the unit owns one file's budget, not the suite's | the operator's row choice, and the mutation-suite row's runtime budget |
| Make a timed-out file's lost unit count visible in the aggregate | the runner's result protocol, not the dry-run harness | the failure-signalling row or the mutation-suite row |

## What's Next

The conventions edit and the first rectification slice follow in this iteration. The mutation-suite row now owns both the captured corpus and the aggregate's behaviour under a timeout.

Read at iteration start: this handover, the M3.1 dry-run row, and the probe test's header.

**Conclusions from this iteration:** the dry-run channel no longer accumulates handshake litter, and the check behind it can no longer pass on a stale token. The probes' shared preamble has one home, which turned a surviving mutation into a pinned unit. The mechanism that fixed the capture's lint deadline in the previous unit also fixed this unit's own test file, which is the sign that the per-file budget was a real gap rather than a local patch.
