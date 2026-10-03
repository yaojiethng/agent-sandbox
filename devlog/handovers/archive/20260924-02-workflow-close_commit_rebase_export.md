# Agent Handover

**Date:** 2026-09-24
**Milestone:** M3 -- governance (iteration close); M3.1 branch history; host export seam
**Type:** Workflow
**Status:** Closed

## Objective

Re-align iteration close to the one-commit rule in `iteration_policy.md`, fix the historical `docs: close` commits by rebase, and document the branch-point export stopgap for bringing rebased history back to the host.

## Scope

Three target areas, per operator direction:

1. Governance: prescribe the correct close behavior so a `docs:` commit never exists solely to flip the handover Status; `iteration_policy.md` is the source of truth, `wrapup.md` adjusted only where it is inconsistent or silent.
2. History repair: fold the existing `docs: close` commits into their delivery commits via rebase, so each iteration is one commit + handover.
3. Export seam: document the package-branch-explicit-branch-point stopgap and make workflow changes so the rebased history can be ported back into the host worktree.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `git_policy.md` carries the unified transient-commits rule (wip, corrections, close-edit one family) | `grep \"Transient commits fold into the delivery commit\"` | Agent [x] |
| 2 | `iteration_policy.md` Step 8-9 states close-produces-one-commit and points to git_policy | grep the heading | Agent [x] |
| 3 | `wrapup.md` is absent from `src/reasoning/agent/prompts/` and the surface-area report marks it removed | `test ! -f` + grep | Agent [x] |
| 4 | `src/reasoning/agent/prompts/package-rebase.md` exists and documents the branch-point baseline procedure | `test -f` | Agent [x] |
| 5 | `make draft` and package-branch hints carry branch-from/baseline defaults | grep usage | Agent [x] |
| 6 | no `docs: close` commit remains in history; each delivery commit carries its Closed handover | `git log` grep == 0 | Agent [x] |
| 7 | lint Clean, 714 tests green on the rebased tree | `make lint`, `make test` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md) | source of truth for the close/is-the-commit rule |
| [`src/reasoning/agent/prompts/wrapup.md`](src/reasoning/agent/prompts/wrapup.md) | consistency check vs iteration_policy |
| `workflow/coding-agent/prompts/package-branch.md` | branch-point export guidance, command hints |
| `scripts/workflows/draft.sh` | `make draft` branch-point default argument |
| `scripts/package_branch.sh` (`/opt/sandbox/lib/`) | baseline/branch-point support |
| devlog/handovers/ | the 6 historical `docs: close` commits to rebase-fold |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `iteration_policy.md` is the source of truth for close sequencing; wrapup.md only gains text where it is silent or inconsistent | operator direction, follow-up point 2 | chat |
| Fixes are drafted positively (imperative that names the object and action), per documentation_policy | ASD-STE100 literal-reader test | chat |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `wrapup.md` was not actually loaded in the prior close; the superfluous commit came from following `iteration_policy` Step 8-9 after the work commit already carried the handover | contradiction | current iteration |
| Prohibition-style phrasing violates documentation_policy; redraft positively | policy | current iteration |
| The `docs: close` commit defect (a commit whose only change is the handover Status flip or roadmap write-back) resurfaced; governor fix landed this session but is unverified (special-case close), so it is recorded on the reopened `[O] 2026-08-09` entry as probation | bug | next iteration |

## Completed

| File | Change |
|---|---|
| `docs/operations/git_policy.md` | add the transient-commits subsection (wip-squash + close-edit one family) |
| `docs/operations/iteration_policy.md` | Step 8-9 restated as close-produces-one-commit, pointer to git_policy |
| `src/reasoning/agent/prompts/wrapup.md` | removed (deployed copy regenerates at image build) |
| `workflow/coding-agent/audits/surface-area-report.md` | wrapup row marked removed/superseded |
| `src/reasoning/agent/prompts/package-rebase.md` | new: branch-point export stopgap durable home |
| `src/reasoning/agent/prompts/package-branch.md` | host hints carry the baseline by default; /package-rebase pointer |
| `scripts/workflows/draft.sh` | usage text: branch-from always named |
| `scripts/templates/Makefile.template` | help adds BRANCH_FROM/BASELINE as default args |
| git history | rebase-folded the 6 `docs: close` commits into their delivery commits (5813029, 0fccf81, 499fb5f, f1c3883, 2b98c2c, 923e982) via `git rebase -i`; each handover now shows Closed within its delivery commit |
| `devlog/AGENT_FEEDBACK.md` | reopened `[O] 2026-08-09` as probation (the resurfaced `docs: close` defect + governance fix, unverified due to the special-case close); removed the sibling `[A]` entry |

## Deferred items

None.

## What's Next

M3 -- close-commit discipline and branch history hygiene.

**Conclusions from this iteration:** the `docs: close` commit pattern is drift from the recorded one-commit rule; the fix is a positive prescription plus a rebase.
