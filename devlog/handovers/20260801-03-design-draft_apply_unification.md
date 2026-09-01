# Agent Handover

**Date:** 2026-08-01
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Type:** Design — Unify make draft and make apply
**Status:** Active

## Objective

Remove the redundant `package-diff` skill and consolidate all diff packaging into `package-branch`. Produce a design document that supersedes `story_diff_pipeline_unification.md` and `design_unified_path_derivation.md`.

## Scope

Design session. Produced [`design_remove_package_diff.md`](../../devlog/discussions/design_remove_package_diff.md) which supersedes `story_diff_pipeline_unification.md` and `design_unified_path_derivation.md`. Implementation deferred to next session.

In scope:
- Delete `package_diff.sh`, `package-diff.md` prompt, `test_package_diff.sh`
- Remove `package-diff` from CLI dispatch, preflights, AGENTS.md, Makefile template
- Remove `diffs` channel from routing
- Clean all references from docs and knowledge tests

Deferred:
- Channel-mode removal from `make apply`
- Interactive picker file-selection improvement

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) | Draft branch workflow (470 lines) |
| [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh) | Diff apply workflow (234 lines) |
| [`devlog/discussions/story_diff_pipeline_unification.md`](../../devlog/discussions/story_diff_pipeline_unification.md) | Prior art — resolved story |
| [`devlog/discussions/design_unified_path_derivation.md`](../../devlog/discussions/design_unified_path_derivation.md) | Prior art — implemented design |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Remove `package-diff` entirely, keep only `package-branch` | `package-branch` is a strict superset; two tools producing identical artefacts is redundant | [`design_remove_package_diff.md`](../../devlog/discussions/design_remove_package_diff.md) |
| Defer channel-mode removal from `make apply` | Separate concern; this session removes `package-diff` only | [`design_remove_package_diff.md`](../../devlog/discussions/design_remove_package_diff.md) |
| Defer interactive picker file-selection improvement | Separate UX session | [`design_remove_package_diff.md`](../../devlog/discussions/design_remove_package_diff.md) |

## Mid-session findings

None.

## Completed this session

No file changes this session.

## Deferred items

None.

## Next session

**Sub-milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox (cleanup)

**Conclusions from this session:** TBD
