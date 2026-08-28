# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence (operator-directed test-quality campaign; not a roadmap task)
**Type:** Implementation
**Status:** Closed

> Close note: scope deviation (audit → fix-and-harden) accepted by operator
> mid-iteration; delivery commit includes this handover, all test changes,
> and AGENT_FEEDBACK entries. Production dockerfiles found dirty on arrival
> are excluded from the commit.

## Objective
Eliminate the test suite's silent-failure blind spots and replace no-assertion / source-string tests with behavioral contract tests — production code untouched.

## Scope
Full `tests/` tree plus the shared harness (`tests/libs/test_common.sh`). Staging artifacts (TODO, COVERAGE, INVARIANTS, FLAKY_AND_BAD_TESTS, PROGRESS, raw logs) live on the output mount under `workspace/output/`.

Scope deviation, accepted by operator mid-iteration: the task opened as an audit-only pass; it became fix-and-harden once the first finding (a structurally unfailable test) made clear that leaving the class in place would preserve false confidence. Operator: "given that, i think its justified."

## Carried forward

| Item | From handover |
|---|---|
| None — 20260821-12 closed with no deferred items | — |

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | A test function completing without pass/fail/skip counts as FAIL | Probe run caught the real zombie (`test_apply_diff_empty_file_rejected`) and an undefined-at-call-time bug introduced during the campaign itself | accepted |
| AC2 | Runner failure counts match file exit codes (single `  FAIL:` marker) | Reproduced mismatch during AC1 probe (`504 passed, 0 failed` + RC=1); green after fix | accepted |
| AC3 | Empty-diff apply contract pinned: non-zero exit, repo untouched | `test_apply_empty_diff_rejected_without_touching_repo` green | accepted |
| AC4 | start pipeline asserted behaviorally (docker trace + persisted compose), not by grepping source | 7 new stub-run tests green: default never builds; `--refresh` builds w/o `--no-cache`; `--rebuild` builds with it; removed flag rejected; missing `--provider` fails fast; compose fully substituted with concrete container names + session labels | accepted |
| AC5 | Direct contracts for previously untested pure/public functions | image names (5), `apply_preview` (3), `env_field` (5), `validate_wsl_path` (2), `resolve_latest_dir` (3), `template_version` (3) — all green | accepted |
| AC6 | Fixture dedup: `test_diff_rename.sh` uses shared `libs/git_fixtures.sh` | Local `_make_repo`/`_write_session_state` clones gone; suite green | accepted |
| AC7 | Suite deterministic | 524/524 × 3 consecutive full runs, RC=0 each (~22s/run) | accepted |
| AC8 | No production code changes by this campaign | `git status`: all modifications under `tests/`; the two dirty `src/reasoning/providers/pi/*.dockerfile` files predate the session (mtimes 15:20–15:22 vs first campaign write 15:44) | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/libs/test_common.sh`](../../tests/libs/test_common.sh) | Harness: no-assertion guard in `run_test`; `FAIL:` prefix single-sourcing in `test_done`; shellcheck fixes |
| [`tests/test_diff_workflow.sh`](../../tests/test_diff_workflow.sh) | Zombie rewrite (empty-diff contract); `apply_preview` contracts |
| [`tests/test_start_agent.sh`](../../tests/test_start_agent.sh) | 9 string-grep/layout tests → 7 behavioral stub-run tests; WSL path pins |
| [`tests/test_image_names.sh`](../../tests/test_image_names.sh) | New: image-name derivation contracts |
| [`tests/test_prune.sh`](../../tests/test_prune.sh) | `env_field` parser contracts (bounded-extraction seam) |
| [`tests/test_routing.sh`](../../tests/test_routing.sh) | `resolve_latest_dir` selection rules |
| [`tests/test_onboard.sh`](../../tests/test_onboard.sh) | `template_version` pins incl. shipped-template guard |
| [`tests/test_diff_rename.sh`](../../tests/test_diff_rename.sh) | Fixture dedup to shared lib |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Pin actual behavior, never idealize (`agent_image_name` provider case, empty-diff rejection, `C:`-without-backslash accepted) | Tests document the system as it is; desired-but-unimplemented behavior belongs in findings, not assertions | INVARIANTS.md C2/C4/C8 |
| Harden `run_test` instead of adding a coverage framework | Converts the whole silent-test class into failures for ~8 lines; function-mapping gives better signal than line coverage in bash | FLAKY_AND_BAD_TESTS.md H1, COVERAGE.md |
| Bounded-extraction seams for auto-executing scripts (`prune.sh`, `onboard.sh`, `start_agent.sh`) | Scripts have no main guard; sourcing runs them. Extraction fails loudly if the function moves | test_prune/test_onboard/test_start_agent comments |

## Findings

| Finding | Type | Impact |
|---|---|---|
| F1: empty `uncommitted.diff` hard-fails `apply` ("No valid patches in input") — zero-change sessions produce exactly this artifact | bug | next iteration — needs product decision (skip vs `--allow-empty`); do not paper over in tests |
| F2: `src/build/image.sh` header claims `(lowercased)` but `agent_image_name` does not lowercase the provider | contradiction | current — one-line comment fix (or code change if provider case should be lowered); behavior pinned as-is by test |
| Two pi provider dockerfiles carry uncommitted modifications predating the session (removal of `RUN pi install npm:pi-opencode-provider`) | scope note | operator-owned: commit or revert deliberately |
| Mid-file `run_test` calls between function definitions are a latent no-op hazard (127 swallowed) | gotcha candidate | propose routing to `devlog/GOTCHAS.md` |
| F3: `_session_export` (src/capability/entrypoint.sh, `set -euo pipefail`) calls `wait_git_lockfile` bare; the function prints "proceeding anyway" then returns 1 on timeout — under `set -e` the caller dies instead of proceeding. Message contradicts control flow. | bug | next iteration — caller needs explicit `\|\| true` + fallback semantics, or the function should not return 1 after declaring proceed |
| F4: `apply_run` computes `FILES_CHANGED=$(grep -c ... \|\| echo "0")` — on zero matches grep prints `0` AND the `\|\| echo` fires, yielding `0\n0`. bash-conventions rule 4.3 documents this exact pitfall. Cosmetic today (display only) but a live trap. | bug | current — one-line fix in production, flagged not applied |
| Conventions compliance gap: rule 1.11/rule 3.2 dual-use guards absent on prune/onboard/start_agent; rule 3.1 "return never exit" violated by `validate_wsl_path`. The rules exist; three scripts predate them. | contradiction | next iteration — adding guards is behavior-preserving and deletes the test extraction seams |
| Testing-policy gaps: no rule banning source-text assertions (the removed string-grep class), no assertion-helper requirement (`cmd && pass` anti-pattern), no shellcheck gate for test files, no runner self-test, no rot-detection for knowledge tests | policy gap | operator review — see AGENT_FEEDBACK entries + HARNESS_ASSESSMENT on output mount |

## Completed

| File | Change |
|---|---|
| `tests/libs/test_common.sh` | `run_test` fails assertion-less tests; `test_done` emits runner-parseable `FAIL:` lines; shellcheck clean |
| `tests/test_diff_workflow.sh` | Unfailable zombie → real empty-diff contract test; +3 `apply_preview` tests |
| `tests/test_start_agent.sh` | −9 string/layout greps, +7 behavioral stub-run tests, +2 WSL-path pins, helper `run_start_session` |
| `tests/test_image_names.sh` | New file, 5 naming-contract tests |
| `tests/test_prune.sh` | +5 `env_field` parser tests |
| `tests/test_routing.sh` | +3 `resolve_latest_dir` tests |
| `tests/test_onboard.sh` | +3 `template_version` tests |
| `tests/test_diff_rename.sh` | Fixture clones replaced by shared `libs/git_fixtures.sh` |
| `devlog/AGENT_FEEDBACK.md` | 3 entries: missing dual-use guards block unit seams; marker-counting blind spot (mitigated); knowledge-test rot |

Net: 504 inflated passes → 524 real tests, deterministic ×3, zero skips.

## Deferred items

| Item | Reason | Goes next |
|---|---|---|
| Replace grep-based `scripts/check_test_coverage.sh` | Deliberately left: superseded by function-mapping method; replacement tooling is a product choice | Operator call — not scheduled |
| F1/F2 production fixes | Audit rules: no production changes; both flagged with proposed directions | Next impl iteration on operator decision |

## What's Next
M2.6 — Session Persistence continues per roadmap. If F1 is taken up, pair the production fix with flipping `test_apply_empty_diff_rejected_without_touching_repo` deliberately.
