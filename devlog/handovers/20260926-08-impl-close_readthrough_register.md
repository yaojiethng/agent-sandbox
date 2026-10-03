# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Close the read-through register: give every finding a disposition, add an `assigned` status that routes a row to its roadmap owner, land the remaining isolated dead-code fixes, and record the design contracts the grill settled. The register ends at 319 rows with zero left open.

## Scope

- `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` -- the register: the `assigned`/`assigned_to` format amendment, the 37-row reassignment, the failure-signalling routing, the diff-pipeline cluster, and the final row dispositions.
- `devlog/discussions/20260925-design-draft-findings_register_format.md` -- the seven-value status and the `assigned_to` field.
- The code fixes: `src/libs/diff.sh`, `src/libs/draft_state.sh`, `src/libs/resume_list.sh`, `scripts/prune.sh`, `scripts/run_agent.sh`, `scripts/onboard.sh`, `scripts/install.sh`, `scripts/macos_bootstrap.sh`, `scripts/start_agent.sh`, `scripts/workflows/draft.sh`.
- The units: `tests/test_draft_state.sh`, `tests/test_resume_list.sh`, `tests/test_start_agent.sh`.
- Two design-contract notes (`diff_workflow_invariants.md` item 8, `interactive_command_contract.md` item 5) and the `read-through-run.md` prompt.
- `devlog/roadmap.md`, this handover.

## Carried forward

The prior iteration (handover `20260926-07-impl-failure_signalling_family.md`) settled the failure-signalling family and left row 85 (compact the read-through + fold evidence into the register) as the named follow-up. This iteration does not rewrite that future task; it closes the register's live rows.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Register format: `assigned` is the seventh status value and carries an integer `assigned_to` naming the roadmap row; the schema note and the workflow prompt state the same seven values | read the jsonl + both docs | Agent [x] |
| 2 | The register has zero `open` rows, all 319 rows carry a disposition, and the jsonl parses clean | `node` parse + count over the jsonl | Agent [x] |
| 3 | Reassigned findings point at a real roadmap row (37 rows keyed to 20 targets) with correct `assigned_to` | `node` cross-check of `assigned_to` against roadmap ids | Agent [x] |
| 4 | Row 319: `draft_read_state_from_branch` deleted; its shared escaping/allowlist behaviour still covered by `draft_validate_branch` | `bash tests/test_draft_state.sh` | Agent [x] |
| 5 | Row 175: the unreachable delivery `""` arm gone; Row 149: the always-true `-n "$AGE_DAYS"` guard gone | `bash tests/test_prune.sh`, `bash tests/test_run_agent.sh` | Agent [x] |
| 6 | The resolved code rows have landed fixes present in-tree (audit of all 51 upfront, plus the capability/runner/interactive/Makefile families) | grep the current source + full suite | Agent [x] |
| 7 | Roadmap gained the M3.1 runner-subset row 88; the `_CLI_TOLERANT` cleanup is scoped onto roadmap 189 | read `devlog/roadmap.md` | Agent [x] |
| 8 | Suite green, lint clean | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Agent [x] -- 989 tests, 0 failed; shellcheck 0 across 193 files |
| 9 | Resolved register `action_text` fields state their landed fix, not a deferral catch-phrase | grep the jsonl for `through the` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Add `assigned` as a seventh status with an `assigned_to` roadmap-row field | a finding that a concrete roadmap row owns is not `resolved`, and inventing values at write time is disallowed from the format note | findings-register-format note, this handover |
| `fix now` means "fix during the grill"; deferrals route to `assigned`, never to a silently-closed `resolved` row | the semantic shift the operator flagged; a forward-looking `resolved` row is a record defect | this handover |
| Row 88 split into two failure keys (docker-unreachable vs image-absent), both hard errors | each names its own remedy against a distinguishing reason | the failure-signalling routing |
| Savepoint = the draft atomicity boundary; "atomic" means fail-safe ordering with asserted checkpoints, not a transaction | git has no transaction over tag-create, branch-create, apply and reset | diff_workflow_invariants.md item 8 |
| Picker input state machine: a valid number / injected `0` / empty-Enter-with-default selects; `q`/`Q` and true EOF abort; empty-Enter retries only with no default; EOF is a terminal, never a retry | end of input is an abort by the existing `interactive_pick` contract | interactive_command_contract.md item 5 |
| `_CLI_TOLERANT` is a migration holdover; delete the knob and make prune strict | only prune uses the tolerant mode, and a destructive command must not drop unknown flags | roadmap 189, the register |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The register carried no timing metadata, so a "resolved" row's fix could only be verified against the tree, not against the session that set it | record | verification of all 51 code rows against current source; larded phrasing rewritten |
| Some `resolved` `action_text` fields read as deferrals ("through the X item") while the fix had landed | record | 26 rows reworded to state their landed fix |
| `AGE_DAYS` is defaulted at prune line 53, so its later `-n` guard is always true; the second dead condition had already been refactored away | correctness | row 149 fix |
| `draft_read_state_from_branch` had no production caller; only tests exercised it | correctness | row 319 delete instead of spec-fix |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | `assigned` + `assigned_to`; 37-row reassignment; routing; final row dispositions (0 open); 26 reworded `action_text` fields |
| `devlog/discussions/20260925-design-draft-findings_register_format.md` | seven-value status + `assigned_to` field |
| `src/libs/draft_state.sh` | deleted `draft_read_state_from_branch` (row 319) |
| `tests/test_draft_state.sh` | removed the dead reader's tests; folded its shared-cover into `draft_validate_branch` |
| `scripts/prune.sh` | removed the always-true `-n $AGE_DAYS` guard (row 149) |
| `scripts/run_agent.sh` | removed the unreachable delivery `""` arm (row 175) |
| `src/libs/diff.sh`, `src/libs/resume_list.sh`, `scripts/onboard.sh`, `scripts/install.sh`, `scripts/macos_bootstrap.sh`, `scripts/start_agent.sh`, `scripts/workflows/draft.sh` | the code fixes for rows 61, 80, 126, 152, 165, 222 and the bash-floor/runner-supports |
| `tests/test_resume_list.sh`, `tests/test_start_agent.sh` | the units pinning rows 80, 222, 126 |
| `devlog/discussions/20260925-design-draft-diff_workflow_invariants.md` | item 8 (savepoint atomicity) |
| `devlog/discussions/20260925-design-draft-interactive_command_contract.md` | item 5 (picker state machine) |
| `workflow/coding-agent/prompts/read-through-run.md` | `assigned` in the fixed-status list |
| `devlog/roadmap.md` | M3.1 runner-subset row 88 added; `_CLI_TOLERANT` cleanup scoped onto row 189 |
| this handover | written at close |

## Deferred items

- Row 85: compact the read-through record and fold its evidence into the register (unchanged future task).
- The 61 `assigned` rows: owned by their `assigned_to` roadmap rows (155/157/176/189/191/192/135/136/182/88 etc.); they transition when that row is worked.
- Row 86 (mutation suite), the M3.1 close review gate, and the remaining non-assigned residuals (2 needs-decision, 3 blocked, 1 stale) stay as they are.

## What's Next

The register is closed. M3.1 continues toward its close gate; row 85 (compact + evidence-move) and the runner-subset row 88 are the named open work. The next iteration reads `devlog/roadmap.md` for the active rows.

**Conclusions from this iteration:** a "resolved" register row is only trustworthy when the fix is present in the tree -- the register keeps no timing, so verification is against source, not against the session that marked the row. The `assigned` status exists because deferral is a real state distinct from done. The path-adjustor / runner-subset / Makefile-surface contracts were routed to their notes as open design questions rather than presumed.
