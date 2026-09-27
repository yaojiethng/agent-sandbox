# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Settle and apply the failure-signalling family (roadmap row 84): a check returns pass or fail; a run where the capability could not produce the answer is a fail with a distinguishing key, never aliased to "nothing to report". The iteration lands rule 3.5 (the convention), fixes the enumerated presuming-success pipes and reason-key rows, retires the production-check "probe" terminology, and records the follow-up.

## Scope

- `docs/development/bash-coding-conventions.md` -- rule 3.5.
- `src/libs/diff.sh`, `src/build/compose.sh`, `scripts/prune.sh`, `src/libs/package_branch.sh` -- the fixes.
- `tests/test_diff_helpers.sh`, `tests/test_prune.sh`, `tests/test_package_branch.sh` -- the units.
- The read-through docs (`20260924-design-active-test_suite_readthrough.md`, `20260925-design-draft-readthrough_process_review.md`) and the workflow prompt (`read-through-run.md`) -- the terminology reword.
- `devlog/roadmap.md`, the read-through register jsonl, this handover.

## Carried forward

The `/auto` run closed rows 42, 129, 161 (handovers 03-05). This iteration resolves rows 60, 84, 96, 139, 150 within the failure-signalling family. Row 85 (compact the read-through + fold evidence into the register) is a new future task raised by the operator during this iteration.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| Rule 3.5: a check fails closed, reads its failure key, never presumes a predecessor succeeded, never a bare double-pipe true to absorb a check, and never aliases "could not run" to "nothing to report" | review of `bash-coding-conventions.md` | Agent [x] |
| Row 60: a broken repo fails `write_uncommitted_diff`/`write_all_changes_diff` closed, naming git; no partial diff remains | `tests/test_diff_helpers.sh` | Agent [x] |
| Row 96: the merge verdict reads `PIPESTATUS[0]`, not the caller's pipefail; a failed merge unlinks its partial file | `tests/test_trace_compose_gen.sh` | Agent [x] |
| Row 139: an underivable cutoff fails closed instead of pruning everything | `tests/test_prune.sh` | Agent [x] |
| Row 150: an unreadable timestamp keeps the record instead of pruning it as oldest | `tests/test_prune.sh` | Agent [x] |
| Row 84: the refuse-state guard probes the object store (`git fsck --no-dangling`) not just the index | `tests/test_package_branch.sh` | Agent [x] |
| Terminology: production-check "probe" is retired to "check" in the three named docs; sense 1 (method term) and sense 2 (dry-run probes) are kept and recorded | grep across the three docs | Agent [x] |
| A mutation that removes each fix fails its unit (bites) | the four bites | Agent [x] |
| Suite green, lint clean | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Agent [x] -- 993 tests across 65 files, 0 failed; 3 gates, 0 findings |
| Roadmap row 84 checked, row 85 added; register rows resolved | `git log` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| No design note, no ADR, no new linter | the family is a coding-convention restatement (fail-closed + failure keys + no-presuming-success pipes), not a design; conformance is read-by-review, the fixes are enumerated | this handover |
| Indeterminate is not a third outcome | "unknown" is a fail with a distinguishing key; a distinct exit code would re-import the magnitude-into-code anti-pattern of rule 3.2 | rule 3.5 |
| The caller owns fail-open (via a named, opt-in override); fail-closed is the default | the same probe is fail-closed for one operation and tolerated for another, so policy is an operation property, not a probe property | rule 3.5, this handover |
| "probe" retired only in the production-check sense | the method term (`probe-verified`) and the dry-run-probes proper noun (a docker term) are distinct; eviscerating all would rewrite a settled investigation record | the read-through's terminology note |
| The markdown evidence table is kept (not deleted) | it is the evidence store; the jsonl is the terse register. The future task is to move the evidence into the jsonl | roadmap row 85 |
| The terminology note belongs in the settled record docs, not the prompt | the read-through design doc and process review are durable records and keep the note; `read-through-run.md` is active context for subagents and carries no note, and no reword, because its only `probe` token is the sense-1 glossary term | the three files |
| Row 84 is fixed, not narrowed | a real object-store probe (`git fsck --no-dangling`) refuses a truncated blob before the diff degrades | this handover, the unit |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The read-through's markdown table is not redundant with the jsonl -- the table holds the bite/probe evidence the one-line titles reference | record | the table stays; the evidence-move is the future task |
| `set -euo pipefail` does not propagate a failure through `mapfile < <(...)`; the refusal would have been silently eaten | correctness | the caller now routes `rule1_selected_records` through a temp file and checks the exit |
| `_diff_restore_untracked` runs after `_write_git_diff` and returned 0, masking the refusal | correctness | both diff callers now capture and propagate the git status |
| Row 139 was previously "resolved" by a unit that pinned the destructive bypass | record | the unit was rewritten to fail-closed and the resolution stands on the correct behaviour |

## Completed

| File | Change |
|---|---|
| `docs/development/bash-coding-conventions.md` | rule 3.5 added |
| `src/libs/diff.sh` | fail-closed git diff; both callers propagate the status |
| `src/build/compose.sh` | `PIPESTATUS[0]`; unlink partial merge output on failure |
| `scripts/prune.sh` | fail-closed cutoff; unreadable timestamp keeps the record; the selection call checks its exit via a temp file |
| `src/libs/package_branch.sh` | `git fsck --no-dangling` object-store probe |
| `tests/test_diff_helpers.sh` | `test_uncommitted_refuses_broken_repo` |
| `tests/test_prune.sh` | `test_rule1_empty_cutoff_refuses_instead_of_pruning_all`, `test_rule1_unreadable_ts_keeps_record` |
| `tests/test_package_branch.sh` | `test_dispatcher_refuses_unreadable_object_store` |
| the read-through docs + workflow prompt | production-check "probe" to "check"; terminology note (3 senses) |
| `devlog/roadmap.md` | row 84 checked and rewritten to the family; row 85 (compact + evidence-move) added |
| the read-through register | rows 60, 84, 96, 139, 150 resolved |
| this handover | written at close |

## Deferred items

- Row 85: compact the read-through record and fold its evidence into the register (future task, owned by the operator's 2026-09-26 raise).
- The remaining failure-signalling evidence rows not fixed here (88 reason-key tuning, 122 exit-versus-return, 253 side-effect-vs-policy, 278 dependency-precondition, 214, 234, 255, 256, 203 and the row 88/150-adjacent gaps) land per their own dispositions; the family note and rule 3.5 are their governor, not their executor.
- Row 86 (mutation suite) and the M3.1 close review gate.

## What's Next

Row 85 (compact + evidence-move) is the named follow-up. Otherwise the M3.1 open work continues toward its close gate.

Read at iteration start: this handover, rule 3.5, the read-through's terminology note, and the registration it records.

**Conclusions from this iteration:** the "one verdict vocabulary" framing was an overbroad abstraction; the family is a handful of presuming-success pipes and reason-key gaps, kept small on purpose because bash's `$( )` channel makes empty-output-sentinel honest most of the time. The grill (grill-me skill) resolved the vocabulary, the scope split, the policy-ownership, and the termination sense before a line was written -- the design tree converged to an implementation scope, which is why this handover changed type from the draft.
