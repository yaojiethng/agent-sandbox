# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2 -- Draft workflow (host side)
**Type:** Fix
**Status:** Closed

## Objective
Fix the `make draft` completion printout: it suggested rebasing the draft branch onto itself and left `make confirm`'s TARGET unspecified.

## Scope
- `scripts/workflows/draft.sh`: print the branch-off branch (`SOURCE_BRANCH`, captured before the draft checkout) as the rebase base and as the suggested `make confirm TARGET`.

## Problem
After patch application HEAD sits on the draft branch, so the printed rebase command `git rebase -i <draft-branch>` rebases the draft branch onto its own tip (no-op). The TARGET placeholder `[TARGET=<target>]` gave the operator no usable value. `confirm.sh` already defaults `MERGE_TARGET` to the recorded source branch, so printing that branch explicitly matches actual behavior.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Printout names the branch-off branch for both the rebase and the TARGET suggestion | read | Agent -- pass |
| AC2 | Full test suite passes | suite | Agent -- pass (742/742) |

## Completed

| File | Change |
|---|---|
| [`scripts/workflows/draft.sh`](scripts/workflows/draft.sh) | Printout uses `SOURCE_BRANCH` for `git rebase -i` and `make confirm TARGET=`. |

## Deferred items
(none)
