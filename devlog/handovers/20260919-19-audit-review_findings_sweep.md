# Agent Handover

**Date:** 2026-09-19
**Milestone:** M2.6 -- Session Persistence (general track)
**Type:** Audit
**Status:** Closed

## Objective

Resolve the findings from the thermo-nuclear review pass over `b1aac61..HEAD`, run by `deepseek-v4-flash` (xhigh) and `glm-5.3-flash` (high). Two silent-failure defects, one duplicate-parser cluster, and the review's structural cleanups land as typed commits. Review tranches verify the result before close.

This iteration is review-driven and converges in tranches: each tranche runs review rounds against the committed state, and the surviving findings feed the next tranche. The close therefore produces several typed commits, one per change class, not one commit.

The `audit` type permits any commit type, because a review sweep lands whatever its findings call for: governance edits, restructures, behaviour fixes, and cleanup in one iteration.

## Scope

- [x] Fix the two silent-failure defects: the ShellCheck gate fails open when `shellcheck` is absent; `session_save_needed` reports "nothing to save" when git cannot read the repository.
- [x] Delete the duplicate `SESSION_STATE` parser and the duplicate `.export-status` readers; give each format one canonical reader.
- [x] Move the container interface-contract check into a library function; delete the two dead test seams and the `sed`+`eval` extraction.
- [x] Delete the `_resume_branch_age` identity wrapper and its dead fallback.
- [x] Make `require_clean_working_tree` return a verdict and print nothing; callers own their messages.
- [x] Replace the `stamp_contract` truthiness sentinel with a named flag.
- [x] Correct the `confirm.sh` make-style hint to name `TARGET_BRANCH`; extend the regression pin to the variable name.
- [x] Delete the four finished migration tools under `scripts/lint/`; keep the `doc-ascii` gate rule.
- [x] Re-word the stale test header in `tests/test_interface_contract.sh`.
- [x] Unify the container library path spelling in the reasoning entrypoint.
- [x] Make the test stubs source the production libraries instead of forking their logic.
- [x] Land the exit-code convention section in `docs/development/bash-coding-conventions.md`.
- [x] Run the review tranches and reach `VERDICT: APPROVE`, or report the open blockers to the operator.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The ShellCheck gate fails closed when `shellcheck` is absent, a source directory is missing, the file set is empty, or the tool could not run | `bash tests/test_lint_umbrella.sh` | accepted |
| AC2 | `session_save_needed` distinguishes "save", "skip", and "cannot determine"; `save_decision` owns the dispatch and prints both diagnostics | `bash tests/test_session_save_guard.sh` | accepted |
| AC3 | One `SESSION_STATE` parser remains in `src/libs/`; `record_contract_version` is gone; the container check is a library function | `git grep record_contract_version`, suite | accepted |
| AC4 | `.export-status` has canonical reader functions in `export_status.sh`; no inline `grep '^KEY='` reader remains outside that file | `git grep "export-status" scripts/` | accepted |
| AC5 | `_resume_branch_age` is deleted and the picker calls `project_branch_age` directly | `git grep _resume_branch_age` | accepted |
| AC6 | `require_clean_working_tree` returns a three-valued verdict and prints nothing; each caller prints its own message per case; `apply --force` does not print an error on a path it continues | `bash tests/test_draft_workflow.sh`, `bash tests/test_apply_count.sh` | accepted |
| AC7 | The `stamp_contract` sentinel is replaced by a `contract_label` value carrying the real contract version | `git grep stamp_contract scripts/build.sh` | accepted |
| AC8 | Both `confirm` hints name `TARGET_BRANCH`; a tree-wide guard rejects any live `make confirm TARGET=` | `bash tests/test_dispatch.sh` | accepted |
| AC9 | The four finished migration tools are deleted; `doc-ascii.mjs` remains and the gate stays at zero findings | `bash scripts/lint.sh` | accepted |
| AC10 | Each entrypoint resolves its library directory from one variable; the `CONTRACT_LIB` and `SANDBOX_ROOT` seams are gone; `_source_lib` and `lib_preflight` are shared | `git grep CONTRACT_LIB SANDBOX_ROOT`, suite | accepted |
| AC11 | Test stubs source the production library and override only the docker-facing function | operator read, suite | accepted |
| AC12 | `bash-coding-conventions.md` carries the exit-code verdict rule, the undeterminable-status rule, the single-dispatch allowance, and the test-harness exemption | operator read | accepted |
| AC13 | Full suite green; ShellCheck and Markdown gates clean | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | accepted |
| AC14 | The review tranches reach `VERDICT: APPROVE` from both models on the same commit | review reports | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/check_shell.sh`](scripts/check_shell.sh) | Fail-open defect |
| [`scripts/lint.sh`](scripts/lint.sh) | Count-as-status composition |
| [`tests/test_lint_umbrella.sh`](tests/test_lint_umbrella.sh) | Pins the count-as-status convention |
| [`src/libs/diff_export.sh`](src/libs/diff_export.sh) | Save-guard status collapse; `.export-status` reader |
| [`src/capability/entrypoint.sh`](src/capability/entrypoint.sh) | Save-guard caller |
| [`src/libs/interface_contract.sh`](src/libs/interface_contract.sh) | Duplicate K/V parser |
| [`src/libs/session_state.sh`](src/libs/session_state.sh) | Canonical K/V parser owner |
| [`src/libs/export_status.sh`](src/libs/export_status.sh) | `.export-status` format owner, reader absent |
| [`scripts/workflows/interactive.sh`](scripts/workflows/interactive.sh) | Inline `.export-status` readers |
| [`scripts/workflows/draft.sh`](scripts/workflows/draft.sh) | Inline reader; guard message duplicate |
| [`scripts/workflows/apply.sh`](scripts/workflows/apply.sh) | Guard message; error-then-continue |
| [`scripts/guards.sh`](scripts/guards.sh) | Guard prints and decides |
| [`scripts/workflows/confirm.sh`](scripts/workflows/confirm.sh) | Wrong Makefile variable in the hint |
| [`scripts/build.sh`](scripts/build.sh) | `stamp_contract` sentinel |
| [`src/libs/resume_list.sh`](src/libs/resume_list.sh) | Identity wrapper, dead fallback |
| [`src/reasoning/entrypoint.sh`](src/reasoning/entrypoint.sh) | Library path spelling, dead seams |
| [`scripts/lint/`](scripts/lint/) | Finished migration tools |
| [`tests/stubs/`](tests/stubs/) | Stub forks production logic |
| [`docs/development/bash-coding-conventions.md`](docs/development/bash-coding-conventions.md) | New exit-code convention |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The close produces multiple typed commits, one per change class: governance, structural refactor, behaviour fixes, housekeeping | The change classes are distinct; one commit would misreport the dominant type for three of them | this handover |
| Review runs in tranches of up to three rounds, with an operator continue/stop decision after each tranche | A single long tranche hides whether the fixes are converging or masking a structural problem | this handover |
| The exit-code table (distinct documented codes, one per named condition) is deferred to its own iteration with its own ADR | A documented code table is a contract, not a fix; it is substantial enough to own an iteration | this handover |
| The gate fix in this iteration is fail-closed only, using code `1`, with the finding count still emitted | Restores the blocking contract without inventing the code table this iteration does not own | this handover |
| The container contract check becomes a library function in `session_state.sh` | That lib owns the record reader the check needs and already sources the contract accessor; the move deletes the duplicate parser, both dead test seams, and the `sed`+`eval` extraction | this handover |
| `require_clean_working_tree` returns a verdict and prints nothing | The current form mixes decision with presentation, so callers suppress or duplicate the text | this handover |
| `tests/test_draft_workflow.sh` stays unsplit this iteration | Operator decision: the split widens the diff without serving the fix | this handover |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `check_shell.sh` fails open: a missing `shellcheck` yields "0 warnings / Clean" and exit 0 on a blocking gate | bug | current iteration | AC1 |
| `session_save_needed` returns the same status for "clean tree" and "unreadable repository"; the caller prints a success message and skips the export | bug | current iteration | AC2 |
| `record_contract_version` duplicates the canonical `session_state_read` loop and omits its file guard; the omission is the documented `set -e` abort in `AGENT_FEEDBACK.md` | bug | current iteration | AC3 |
| `.export-status` gained two more inline readers; the format owner has no reader | duplication | current iteration | AC4 |
| `_resume_branch_age` is a pass-through with a dead fallback at its only call site | duplication | current iteration | AC5 |
| `require_clean_working_tree` prints an error that `apply --force` then ignores, and that `draft` suppresses and rewrites | coupling | current iteration | AC6 |
| The `confirm` make-style hint names `TARGET`, which the confirm target ignores; the regression pin cannot catch it | bug | current iteration | AC8 |
| `stamp_contract` carries the literal `"1"`, a leftover of the container-sig removal | legibility | current iteration | AC7 |
| Four finished migration tools remain in the gate directory; two hardcode an image-only npm path | dead code | current iteration | AC9 |
| The reasoning entrypoint spells its library directory three ways and carries two dead test seams | legibility | current iteration | AC10 |
| The Markdown gate exits 127 for a missing tool, which is indistinguishable from a finding count of 127; the shell gate has the opposite posture | bug | next iteration | exit-code table + ADR |
| `tests/test_draft_workflow.sh` is the repository's only file over 1000 lines and grew this range | size | deferred | operator decision: not this iteration |
| The review's `deepseek` and `glm` legs disagreed on `session_save_needed`: one reported it, one ruled it out. Reproduction confirmed the defect | steering | current iteration | AC2 |
| Round-1 blocker: `apply --force` printed `Error:` on the path it continues | bug | current iteration | fixed, AC6 |
| Round-1 blocker: a test comment whose first token was `shellcheck` parsed as a directive and failed the gate | bug | current iteration | fixed; the gate now diagnoses the class from the tool's own output |
| Round-1/2/3 blocker: `make confirm` hints naming `TARGET` instead of `TARGET_BRANCH` drifted across four documents in three successive rounds | propagation | current iteration | fixed; `tests/test_dispatch.sh` now guards the whole tree |
| Round-2 blocker: the autosave staging directory sat inside the channel its readers enumerate, so an interrupted cycle could leave a partial bundle that `make draft` would select | bug | current iteration | fixed; staged outside the channel, with a routing test |
| Round-2: the autosave write-ordering contract was documented as wipe-first in five documents while the code built-then-swapped | propagation | current iteration | fixed |
| Round-2: rule 3.2 contradicted the test harness's count-as-exit-code, which the same repository documents | governance | current iteration | fixed with a stated exemption |
| Round-2: `tests/stubs/libs/dry_run_harness.sh` was a byte-identical 93-line fork of the production library | duplication | current iteration | fixed; it sources the production file |
| Round-3: a missing library aborted with a raw bash error instead of the stale-image diagnostic | diagnostic | current iteration | fixed; `_source_lib` covers every unconditional source |

## Review history

Two tranches of the `review-pass-run` loop, fresh subagent each round, both models per round (`deepseek-v4-flash` xhigh, `glm-5.3-flash` high). The loop stops when both reviewers approve the same tree.

| Tranche / round | deepseek | glm | Outcome |
|---|---|---|---|
| 1 / 1 | BLOCK | BLOCK | Fixed: apply `--force` error-then-continue; the ShellCheck directive trap; `TARGET` doc drift. |
| 1 / 2 | APPROVE | APPROVE | Eight follow-ons folded anyway (gate tool-failure path, tri-state dispatch helper, guard fails closed, ADR/doc drift, tests). |
| 1 / 3 | BLOCK | APPROVE | Fixed the last `TARGET` sentence plus a tree-wide guard; replaced the approximated directive pre-scan with a diagnosis derived from the tool's output. |
| 2 / 1 | APPROVE | APPROVE | Four should-fixes and three nits folded (atomic checkpoint staging, fixture sandbox in the entrypoint test, lib-source diagnostics, ADR marker form). |
| 2 / 2 | BLOCK | APPROVE | Fixed the blocker: the staging path sat inside the reader-enumerated channel. Also corrected the autosave doc contract, the missing-directory gate guard, `_source_lib` coverage, and the rule 3.2 exemption. |
| 2 / 3 | BLOCK | APPROVE | Fixed: `mv` into a channel that was never created (the swap's parent), the stale write-order docs, the missing-directory gate guard, and the split registration block. |
| 2 / 4 | APPROVE | APPROVE | The last stub fork (`routing.sh`) sourced; the singular lint count read; `_no_sessions` returns instead of exiting; baseline resolution folded into `save_decision`. |
| 2 / 5 | APPROVE | APPROVE | Fixed: the directive diagnosis matched a generic parse code and misreported any syntax error; the ADR's stale `save_decision` signature; two more write-order docs; the untested autosave loop. |
| 2 / 6 | BLOCK | BLOCK | Fixed: extracting `autosave_tick` dropped `$SANDBOX_DIR`, so autosave wrote no checkpoint in production. Also passed the channel layout in, guarded the exit-trap session id, and split the tool-failure diagnosis from the empty-set one. |
| 2 / 7 | BLOCK | APPROVE | Fixed: the autosave guards transcribed the entrypoint instead of driving it. The cycle now supplies the export's arguments and `autosave_loop` is extracted, with a fresh-shell `set -e` probe because the test harness suppresses `set -e`. |
| 2 / 8 | APPROVE | APPROVE | Confirmation round on the final tree. |

Ten rounds across two tranches. The recurring class was propagation: a fix that stopped one file short of its consumers, and a guard that tested a copy of the mechanism rather than the mechanism. The last two blockers were both of the second kind -- the argument-order test transcribed the call, and the status-absorption test could not observe an abort because `run_test`'s `$1 || true` suppresses `set -e` for everything the test spawns. Mechanical guards now cover the worst offenders: the tree-wide make-hint guard, the gate's derived diagnosis, an argument-position assertion, and the fresh-shell `set -e` probe.

## Completed

| File | Change |
|---|---|
| [`docs/development/bash-coding-conventions.md`](docs/development/bash-coding-conventions.md) | New 3.2: an exit code carries a verdict, never a magnitude; an undeterminable answer must not share a status with a determined negative; one helper may own the dispatch. Sections 3.3/3.4 renumbered. |
| [`docs/operations/handover_policy.md`](docs/operations/handover_policy.md) | The `audit` row permits any commit type, because a review sweep lands whatever its findings call for. |
| [`scripts/check_shell.sh`](scripts/check_shell.sh) | Fails closed on a missing tool, an empty file set, and a tool that fails without emitting findings; the finding count is printed, never encoded. |
| [`scripts/check_markdown.sh`](scripts/check_markdown.sh) | Missing tool exits 1 (was 127); count is printed, never encoded. |
| [`scripts/lint.sh`](scripts/lint.sh) | Verdict-only exit (0 clean, 1 failed); the first-failure code dance and the count-as-status are gone. |
| [`tests/test_lint_umbrella.sh`](tests/test_lint_umbrella.sh) | Asserts the verdict-only contract and a real missing-tool case. |
| [`src/libs/session_save_policy.sh`](src/libs/session_save_policy.sh) | New module: `session_save_needed` tri-state (0 save, 1 skip, 2 undeterminable), `save_decision` owns the dispatch and diagnostics, `_save_baseline` resolves the comparison point. |
| [`src/libs/diff_export.sh`](src/libs/diff_export.sh) | The save decision moved to the policy module; sources it. |
| [`src/capability/entrypoint.sh`](src/capability/entrypoint.sh) | Both save call sites use `save_decision`; preflight list names the new dependency. |
| [`src/libs/export_status.sh`](src/libs/export_status.sh) | Canonical readers `export_status_read` and `export_status_is_success` beside the writer. |
| [`src/libs/session_state.sh`](src/libs/session_state.sh) | `container_contract_check` owns the record comparison and the K/V read; the duplicate parser is gone. |
| [`src/libs/interface_contract.sh`](src/libs/interface_contract.sh) | `record_contract_version` deleted. |
| [`src/reasoning/entrypoint.sh`](src/reasoning/entrypoint.sh) | One `SANDBOX_LIB_DIR`; the check sources the library; the `CONTRACT_LIB` and `SANDBOX_ROOT` seams and the inlined function are gone. |
| [`scripts/guards.sh`](scripts/guards.sh) | `require_clean_working_tree` returns a verdict, prints nothing, and fails closed on an unreadable tree; new shared `clean_tree_hint`. |
| [`scripts/workflows/apply.sh`](scripts/workflows/apply.sh) | Owns its message; the refusal text is inside the refusal branch, so `--force` prints only a warning. |
| [`scripts/workflows/draft.sh`](scripts/workflows/draft.sh) | Owns its message via `clean_tree_hint`; reads `.export-status` through the canonical reader; the post-draft hint names `TARGET_BRANCH`. |
| [`scripts/workflows/confirm.sh`](scripts/workflows/confirm.sh) | Both hints name `TARGET_BRANCH`, the variable the confirm target consumes. |
| [`scripts/workflows/interactive.sh`](scripts/workflows/interactive.sh) | Bundle metadata read through the canonical reader. |
| [`src/libs/resume_list.sh`](src/libs/resume_list.sh) | `_resume_branch_age` and its dead fallback deleted. |
| [`scripts/build.sh`](scripts/build.sh) | The `stamp_contract` sentinel becomes a `contract_label` value; the literal `"1"` is gone. |
| [`scripts/dry_run_capability.sh`](scripts/dry_run_capability.sh) | The `.export-status` SUCCESS probe uses the canonical reader. |
| [`scripts/lint/`](scripts/lint/) | The four finished migration tools deleted; `doc-ascii.mjs` remains the gate rule. |
| [`tests/`](tests/) | `test_reasoner_container_contract.sh` sources the library (no extraction, no seams); stubs source the production libraries; tri-state and `save_decision` tests; the apply-force test asserts no `Error:` on a continued path; the dispatch pin names `TARGET_BRANCH`. |
| [`docs/adr/diff_packaging.md`](docs/adr/diff_packaging.md), [`docs/architecture/sandbox_lifecycle.md`](docs/architecture/sandbox_lifecycle.md), [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md), [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md), [`docs/concepts/sandbox_host_interface.md`](docs/concepts/sandbox_host_interface.md), [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md) | Doc-contract drift corrected: tri-state save contract, guard signature, `.export-status` fields, `TARGET_BRANCH`, and the lint command for a `make`-less host. |
| [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) | New entry: a prose comment whose first token is `shellcheck` parses as a directive and fails the gate. |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Split `tests/test_draft_workflow.sh` | Operator decision this iteration | M3 backpressure group |

## What's Next

The lint-gate exit-code contract was codified in an ADR folded into the gate-box commit after close (see `docs/adr/lint_gate_exit_codes.md`). M2.6 is complete. The remaining deferred item is splitting `tests/test_draft_workflow.sh` (M3 backpressure group).
