# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Fix
**Status:** Closed

## Objective

Close the four `code` rows the coverage campaign filed about its own findings: the `.draft-state` key injection (row 315) and three lines whose decision another mechanism already makes (rows 313, 314, 316).

## Scope

Four production files, two test files, the mutation-corpus note, the findings register, and the roadmap. No test-class row moves.

## Carried forward

| Item | From handover |
|---|---|
| Rows 313, 314 and 316 (dead lines the coverage campaign filed) and row 315 (the record key injection) | [20260925-21-test-config_cli_and_stub_pins](20260925-21-test-config_cli_and_stub_pins.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| A crafted `.draft-state` key cannot assign into the caller's scope | the three new `test_draft_state.sh` units and the reject guard | Agent [x] |
| The readers accept every field `draft_write_state` writes | `test_readers_emit_every_written_field` derives the list from the writer's own output | Agent [x] |
| The three redundant lines are removed and behaviour is unchanged | `bash scripts/run_tests.sh` at 980 units | Agent [x] |
| Every new unit is proven by a mutation that names a failing file | five bites, each restored byte-identical (`cmp`) | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/draft_state.sh`](../../src/libs/draft_state.sh) | the field allowlist and its use in both readers |
| [`scripts/workflows/reject.sh`](../../scripts/workflows/reject.sh) | the consumer of `draft_validate_branch`'s output; unchanged, but the defect's target |
| [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh) | the terminal `exit $?` |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) | the shadowed channel default and two terminal `exit $?` sites |
| [`scripts/resume_agent.sh`](../../scripts/resume_agent.sh) | the redundant picker guard |
| [`tests/test_draft_state.sh`](../../tests/test_draft_state.sh) | three units for the allowlist and the field contract |
| [`tests/test_reject_workflow.sh`](../../tests/test_reject_workflow.sh) | the poisoned-key guard replaces an absent-branch unit |
| [`tests/mutations/README.md`](../../tests/mutations/README.md) | two captures that now report NO-OP |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Allowlist the parsed keys instead of removing the `eval` | `reject_run` and `confirm_run` both consume the printed assignments; the writer already defines the field set, so the readers accept exactly that set | the allowlist and its docstring |
| Keep the terminal exit in apply.sh and draft.sh, drop only `$?` | the bite showed the exit is load-bearing: without it the non-interactive path runs a second apply on an already-applied tree and fails | the code comment and the register title for row 314 |
| Write no new unit for the interactive apply path | `tests/test_diff_workflow.sh` already pins the confirmed, aborted, and failed apply outcomes; the two units drafted here failed the same bites as the existing ones and were removed as duplicates | this handover |
| Replace the absent-branch unit rather than keep it | the unit reached the deletion guard's false arm only by injecting `CURRENT_BRANCH`; with the key rejected the arm is unreachable from the public path | register row 318 |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Row 314's diagnosis was half wrong. The terminal exit is load-bearing and was already pinned by `test_apply_script_interactive_confirms_and_applies`; deleting it makes the second `apply_run` fail on the dirty tree. | contradiction | the register title is corrected, and the mutation corpus records that A18 mutates a status that is always zero |
| `test_reject_skips_deletion_when_branch_absent` asserted an injected value as if it were a contract; it broke the moment the injection was closed, which is the correct outcome. | contradiction | replaced by the security guard |
| `draft_read_state_from_branch` has no production caller: only tests call it. | scope change | register row 319 |
| The deletion guard's false arm in `reject_run` is unreachable outside a race. | scope change | register row 318 |
| The surviving channel default in `resolve_source_for_draft` is pinned: removing it fails `test_draft_script_entry_creates_branch`. | steering | no row; the probe is recorded here |

## Completed

| File | Change |
|---|---|
| `src/libs/draft_state.sh` | the field allowlist, applied in both readers, replacing the identifier regex as the only gate |
| `scripts/workflows/apply.sh`, `scripts/workflows/draft.sh` | `exit $?` to `exit`, with the reason for the terminal exit stated once per site |
| `scripts/workflows/draft.sh` | main no longer repeats the channel default |
| `scripts/resume_agent.sh` | the picker call loses a guard that decides nothing |
| `tests/test_draft_state.sh` | three units: two allowlist units and the writer-to-reader field contract |
| `tests/test_reject_workflow.sh` | a poisoned `CURRENT_BRANCH` cannot redirect the deletion |
| `tests/mutations/README.md` | D38 and A18 recorded as NO-OP, with the provable replacement named |
| the register | rows 313-316 resolved; rows 318-319 new |
| `devlog/roadmap.md` | row 83 gains the F1 slice |

## Deferred items

None. Row 42, 129 and 161 remain the test-class rows; rows 318 and 319 are decisions for a later unit.

## What's Next

Test-class rows 42, 129 and 161; the code rows that remain open in the register; roadmap rows 84 (one verdict vocabulary), 86 (the mutation suite) and 101/103 (governance and the review-pass template).

Read at iteration start: this handover, the register rows 313-319, and `docs/development/testing-conventions.md` Anti-Patterns 6 and 9.

**Conclusions from this iteration:** the injection is closed at the key boundary rather than at the `eval`, so both consumers keep their interface; the three line removals are equivalences verified by the suite and, for the channel default, by a probe on the surviving default; and one of the four rows was mis-diagnosed by the campaign that filed it, which the bite method caught before the fix was written.
