---
date: 2026-11-08
milestone: T7 - Harness Specialization / Sandbox Persistence
type: Implementation
status: Closed
---

# Handover - Draft forks at the package branch point

## Objective

Make `make draft` fork at the branch point recorded in the bundle's `.branch-point` when `BRANCH_FROM` is absent, and make both confirm-hint routes state that branch point.

## Scope

This iteration works the first sub-row of **Git boundary and repository state**: **Draft consumes the package fork point; the hint is unconditional**. It continues the plan record [`20261108-01`](20261108-01-plan-draft_branch_record.md). The second sub-row, **Replace `.draft-state` with the branch-local draft record**, is out of scope: `.draft-state` stays, and `confirm` and `reject` keep their current record handling. `package_branch` already prints one hint carrying the branch point, so this iteration confirms that half and changes the draft consumer.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A bundle whose `.branch-point` names an ancestor forks there, not at `HEAD`. | New `test_draft_forks_from_branch_point_not_head` in `tests/test_draft_workflow.sh`. | Agent [x] |
| A bundle with no `.branch-point` and no `BRANCH_FROM` is refused, and the message names `BRANCH_FROM`. | New `test_missing_branch_point_refused`. | Agent [x] |
| A malformed `.branch-point` is refused when no explicit `BRANCH_FROM` is given. | New `test_branch_point_missing_key_refused` and `test_branch_point_non_commit_refused`. | Agent [x] |
| `.branch-point` wins over `.export-status` `INIT_SHA`; the old divergence warning does not fire for that case. | New `test_branch_point_wins_over_init_sha`. | Agent [x] |
| Explicit `BRANCH_FROM` overrides a valid but different `.branch-point`, with a warning naming both. | New `test_explicit_branch_from_overrides_branch_point`. | Agent [x] |
| Explicit `BRANCH_FROM` succeeds when `.branch-point` is malformed, reports a non-commit package point as ignored, and forks at the explicit value. | New `test_explicit_branch_from_survives_malformed_branch_point`. | Agent [x] |
| Both confirm-hint routes print `Branch point: <sha7>`. | Updated `test_draft_hint_routes_to_fast_forward_when_ancestor` and `test_draft_hint_routes_to_soft_reset_when_not_fast_forwardable`. | Agent [x] |
| The Makefile help, CLI usage, `/package-branch` prompt, and both reference docs state `.branch-point` as the default and `BRANCH_FROM` as the override. | `rg` over those five files after the edit. | Agent [x] |
| Every decision this iteration recorded is realized in the files. | Read the delivery diff against the handover's `## Decisions` table. | Agent [x] |
| Architecture documents in scope describe the system as built. | Read the two reference documents against `draft.sh` after the change. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `.branch-point` is the only default fork point. When no explicit `BRANCH_FROM` is given, a missing or malformed record fails closed and names `BRANCH_FROM`; there is no fallback to `.export-status` `INIT_SHA` or `HEAD`. | `INIT_SHA` is the patch-generation point, which is wrong after a rebase, and `HEAD` is the default that produced the original fork-point failure. | This handover |
| An explicit `BRANCH_FROM` is validated on its own and wins even when `.branch-point` is malformed. A valid but different package point produces a warning; a malformed one is ignored and the explicit value is attempted. | The operator owns the override, so malformed package metadata must not outrank a real value. The warning keeps a usable package fact visible. | This handover |
| The confirm hint keeps its ancestry routing and always prints the branch point; `NEW=1` remains the non-ancestor fallback. | `make confirm` fast-forwards only when the target is an ancestor, while the branch point is a fact both routes can state. | This handover |
| `package_branch` needs no code change. | It already prints one `make draft` hint carrying `BRANCH_FROM=<branch point>`. | This handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The `make_real_session` fixture wrote the sandbox baseline into `.branch-point`, but that commit exists only in the sandbox repository, not the host project. | test fixture | The draft refused a bundle whose package point was not in the project. | Fixed in `tests/test_draft_workflow.sh`: the package point is the project HEAD; the sandbox baseline stays the patch-generation point. |

## Completed

| File | Change |
|---|---|
| `scripts/workflows/draft.sh` | Reads `.branch-point`, fails closed without it, keeps explicit `BRANCH_FROM` authoritative, warns on override, and prints the branch point in both hint routes. |
| `tests/libs/session_fixtures.sh` | Writes `.branch-point` for draft fixtures; the fork point is a parameter. |
| `tests/test_draft_workflow.sh` | Adds selection, refusal and override tests, and updates the hint assertions. |
| `tests/test_confirm_workflow.sh` | Passes a project branch point into its direct session fixture. |
| `scripts/templates/Makefile.template` | Describes `BRANCH_FROM` as the override. |
| `src/reasoning/agent/prompts/package-branch.md` | States that `draft` reads `.branch-point` and `BRANCH_FROM` overrides it. |
| `docs/reference/sandbox_host_interface.md` | Replaces the `HEAD` default with the package branch point. |
| `docs/reference/tool_interface.md` | Adds the draft fork-point and refusal behaviour. |
| `devlog/roadmap.md` | Marks the fork-point sub-row landed with the handover link. |
| `devlog/handovers/T7/20261108-02-impl-draft_fork_point.md` | This handover. |
