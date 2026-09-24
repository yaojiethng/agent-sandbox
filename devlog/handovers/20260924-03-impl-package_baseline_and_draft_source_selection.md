# Agent Handover

**Date:** 2026-09-24
**Milestone:** M3 -- workflow and harness ergonomics
**Type:** Implementation
**Status:** Closed

## Objective

Make the branch-point export contract real end to end: add `--baseline` support to `package_branch.sh`, stop `make draft` from silently selecting a source, and correct the command hints in the packaging prompts.

## Scope

Five tasks, confirmed at the scope gate.

1. **T1 -- baseline contract.** `package_branch.sh` accepts `--baseline=<sha>` and threads it through the diff layer; when absent the baseline is `git merge-base "$(init_sha)" HEAD`, which equals `init_sha` without a rebase and the branch point after one. `package_commits` gains the `SINCE_SHA` argument the sibling diff functions already take.
2. **T2 -- draft source safety.** Non-interactive `make draft` with no source errors and hints `INTERACTIVE=1`; no silent newest-bundle selection, no new parameter.
3. **T3 -- command hints.** The packaging script prints a concrete `BRANCH_SUMMARY` and `BRANCH_FROM=<baseline>`; the prompts use `BRANCH_FROM=` for make and `--baseline=` for the container script.
4. **T4 -- `confirm NEW=1`.** `TARGET_BRANCH` alone stays FF / conflict-free-rebase only. With `NEW=1`: require `TARGET_BRANCH`, error when it already exists, drop the `.draft-state` commit, create `TARGET_BRANCH` at the draft tip, delete the draft, and print the operator-run follow-up direction (`git switch <source_branch>` + `git reset --soft <TARGET_BRANCH>`) that moves the target onto the rebased series.
5. **T5 -- roadmap.** File the export/draft invocation seam as one named task under T1.

Deferred: the broader make-versus-CLI arg-parsing seam stays on the existing T4 roadmap row.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `package_branch.sh` accepts `--baseline=<sha>` and diffs from it; the flag no longer errors | `bash src/libs/package_branch.sh --to=/tmp/x --bundle-summary=s --baseline=8045ecc` exits 0 and writes patches | Agent [x] |
| 2 | With no `--baseline`, the export baseline is `git merge-base "$(init_sha)" HEAD`, so a rebased session records the branch point in `.export-status` INIT_SHA | run the script, grep `INIT_SHA` in `/tmp/x/.export-status` | Agent [x] |
| 3 | A non-interactive `make draft` with no source exits non-zero, prints an `INTERACTIVE=1` hint, and creates no branch | run `agent-sandbox draft` with no `--bundle` in a fixture; assert rc and stderr | Agent [x] |
| 4 | The packaging script's next-step hint names a concrete `BRANCH_SUMMARY` and `BRANCH_FROM=<baseline>` | grep the script's emitted hint | Agent [x] |
| 5 | `package-branch.md` and `package-rebase.md` use `BRANCH_FROM=` for make and `--baseline=` for the container script, with no `<slug>` placeholder | grep the two prompts | Agent [x] |
| 6 | `make confirm TARGET_BRANCH=<new> NEW=1` creates `<new>` at the draft tip, deletes the draft, and prints the `git switch` + `git reset --soft` direction without merging into an existing target | confirm-workflow test fixture | Agent [x] |
| 7 | `NEW=1` with an existing branch name exits non-zero and changes nothing | confirm-workflow test fixture | Agent [x] |
| 8 | `make confirm TARGET_BRANCH=<existing>` without `NEW` stays fast-forward / conflict-free-rebase only | confirm-workflow test fixture | Agent [x] |
| 9 | The in-scope docs describe the baseline default, the draft no-source error, and `confirm NEW=1` | grep the named docs | Agent [x] |
| 10 | Architecture documents in scope describe the system as built | read-through of the named architecture docs | Operator |
| 11 | `devlog/roadmap.md` carries the named task for the export/draft invocation seam under T1 | grep the roadmap | Agent [x] |

All criteria accepted at close; none pushed to the next iteration.

## Hot files

| File | Why in scope |
|---|---|
| `src/libs/package_branch.sh` | the `--baseline` argument and its diff-range threading |
| `src/libs/routing.sh` | draft source resolution: the newest-bundle auto-selection |
| `scripts/workflows/draft.sh` | draft entry point and its usage text |
| `scripts/templates/Makefile.template` | the draft and package-branch targets and their hints |
| `src/reasoning/agent/prompts/package-branch.md` | command hints |
| `src/reasoning/agent/prompts/package-rebase.md` | command hints and the explicit-baseline procedure |
| `scripts/workflows/confirm.sh` | the `NEW=1` soft-reset mode |
| `scripts/agent-sandbox.sh` | the `--new` flag and the package-branch help line |
| `tests/test_package_branch.sh` | baseline-argument coverage |
| `tests/test_draft_workflow.sh` | draft source-selection coverage |
| `tests/test_routing.sh` | source-resolution coverage |
| `docs/architecture/tool_interface.md` | the draft, confirm, and package-branch flag tables |
| `docs/concepts/sandbox_host_interface.md` | the `init_sha` lower-boundary and export-baseline statements |
| `docs/architecture/sandbox_lifecycle.md` | the draft and confirm workflow descriptions |
| `docs/adr/diff_packaging.md` | the `init_sha..HEAD` and `confirm` decision entries |
| `docs/development/interface-conventions.md` | the `package_branch.sh` usage example and the Makefile variable guard |
| `devlog/roadmap.md` | the named task for the export/draft invocation seam |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `package_branch.sh` gains `--baseline=<sha>`; the declared host/Makefile parameter is completed rather than a new one invented | the parameter was already declared in `agent-sandbox.sh` and the Makefile, and the diff layer already takes `SINCE_SHA`; only the container entry point did not wire it (operator ruling A) | chat; roadmap row |
| The default baseline is `git merge-base "$(init_sha)" HEAD`, not `init_sha` alone | the merge-base equals `init_sha` without a rebase and the branch point after one, so the agent never edits `SESSION_STATE`; verified `merge-base(host_head_sha, HEAD)` = `8045ecc` | chat |
| Non-interactive `make draft` with no source errors and points at the existing `INTERACTIVE=1` picker; no silent newest-bundle selection and no new parameter | operator ruling; the silent pick created a branch from a stale session | chat |
| `confirm` gains `NEW=1`: create a named branch at the draft tip, then print (not run) the soft-reset direction that moves the target onto the rebased series; `TARGET_BRANCH` without `NEW` stays FF-only | a rewritten target history cannot fast-forward, and the operator owns the move | chat |
| No new ADR; the `diff_packaging` ADR gains a dated entry so its `init_sha..HEAD` and `confirm` statements stop contradicting the build | operator ruling; ADR liveness still requires the existing file to match the system | chat |

## Findings

None.

## Completed

| File | Change |
|---|---|
| `src/libs/package_branch.sh` | `--baseline` accepted and threaded; default baseline `git merge-base init_sha HEAD`; `package_commits` takes `SINCE_SHA`; usage; hint carries concrete `BRANCH_SUMMARY` and `BRANCH_FROM` |
| `scripts/workflows/draft.sh` | non-interactive no-source guard with an `INTERACTIVE=1` hint; usage corrected to `BRANCH_FROM=` |
| `scripts/workflows/confirm.sh` | `NEW=1` soft-reset mode (`_confirm_into_new_branch`), `--new` flag, usage |
| `scripts/templates/Makefile.template` | `NEW ?=`, confirm passthrough, `NEW_BRANCH` misspelling guard, help rows |
| `scripts/agent-sandbox.sh` | `--new` in the confirm help line |
| `src/reasoning/agent/prompts/package-branch.md` | baseline default; `BRANCH_FROM=`; `NEW=1` apply note |
| `src/reasoning/agent/prompts/package-rebase.md` | baseline resolution and the `NEW=1` soft-reset procedure |
| `tests/test_package_branch.sh` | explicit-baseline and merge-base-default tests |
| `tests/test_draft_workflow.sh` | no-source guard test |
| `tests/test_confirm_workflow.sh` | three `NEW=1` tests |
| `docs/architecture/tool_interface.md` | draft, confirm, package-branch flag tables |
| `docs/concepts/sandbox_host_interface.md` | `init_sha` boundary, baseline, draft/confirm |
| `docs/architecture/sandbox_lifecycle.md` | SESSION_STATE bullet and draft/confirm workflow |
| `docs/adr/diff_packaging.md` | dated entry for the baseline and `NEW=1`; supersession note on the `init_sha..HEAD` line |
| `docs/development/interface-conventions.md` | `--baseline` in the `package_branch.sh` usage example |
| `devlog/roadmap.md` | T1 task for the export/draft invocation seam, landed |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Remove the empty-bundle auto-resolve branch from `resolve_source_for_draft` | the only caller (`draft.sh`) now requires an explicit bundle, so the branch is unreached | next iteration |
| Rebuild the images so the deployed `/opt/sandbox/lib/package_branch.sh` accepts `--baseline` | the deployed copy lags the repo until the image build; in-container verification used the repo copy | image rebuild |

## What's Next

M3 -- workflow and harness ergonomics.

No blocking design questions. Two watch-outs: the deployed `/opt/sandbox/lib/` copy of `package_branch.sh` lags the repo until the image rebuilds, and `resolve_source_for_draft` keeps an unreached auto-resolve branch (deferred).

**Conclusions from this iteration:** the export baseline is `git merge-base init_sha HEAD` -- `init_sha` without a rebase and the branch point after one -- so a rebased session no longer needs a `SESSION_STATE` edit. `make confirm TARGET_BRANCH=<new> NEW=1` is the rebased-apply path (new branch, printed soft-reset direction); `TARGET_BRANCH` alone stays fast-forward only. A make invocation names flags as `VAR=value` (`BRANCH_FROM=`, `BASELINE=`, `NEW=1`), never `--flag=value`.
