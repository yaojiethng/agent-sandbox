# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: seed correctness)
**Type:** Design
**Status:** Closed

## Objective

Study, per the operator's direction from the stash-triage check-in item: confirm the mechanism that copies host stashes into the sandbox, and determine the prevention -- or whether dropping all stashes at sandbox initialization is the correct, simpler solution.

## Scope

Read-only investigation. Confirm the mechanism in `src/capability/seed_volume.sh`; assess risk; write the study doc `devlog/discussions/20260911-study-stash_copy_prevention.md` with a recommendation.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | The mechanism is confirmed in code (or refuted) with file and line evidence | read seed_volume.sh | Agent -- pass: `cp -a "$SRC/.git" "$DEST/.git"` carries `refs/stash` + `logs/refs/stash` |
| AC2 | Study doc exists with mechanism, options, and a recommendation | read | Agent -- pass |
| AC3 | Follow-up impl task recorded on the roadmap | grep roadmap | Agent -- pass |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `cp -a .git` copies the host stash stack into every fresh session volume; the design's status-parity self-verification does not see it (stashes are not working-tree state) | confirmation | Study doc |
| In-session `git stash pop` imports host WIP into the session working tree, which then flows back through the diff pipeline as agent output | risk | Study doc, risk assessment |
| The observed stale stashes are host state copies, not accumulation inside sessions; volumes are one-way and pruned | clarification | Study doc |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20260911-study-stash_copy_prevention.md`](devlog/discussions/20260911-study-stash_copy_prevention.md) | New study: mechanism confirmed, three options, recommendation = `git stash clear` in the seeder after the `.git` copy (Option A) |
| [`devlog/roadmap.md`](devlog/roadmap.md) | New open item: seeder stash-clear implementation referencing the study |

## Deferred items

Implementation of the stash-clear (new roadmap item) -- next iteration.

## What's Next

Implement the seeder stash-clear with its test, then close the study as adopted.
