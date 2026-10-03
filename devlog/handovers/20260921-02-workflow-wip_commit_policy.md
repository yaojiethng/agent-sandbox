# Handover - WIP Commit Policy

**Type:** Workflow
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Date:** 2026-09-21
**Status:** Closed
**Iteration:** 20260921-02
**Branch:** feat/M_3-orchestration

## Problem statement

The roadmap T1 row `WIP-commit policy` asks for a documented rule, in `docs/operations/git_policy.md` and the provider-layer `AGENTS.md`, covering when mid-iteration WIP commits are acceptable and that the delivery commit still carries a type prefix. The immediate driver is this planning iteration's own WIP pattern: the M3 track-organization iteration produced 13 intermediate commits (WIP-style work sliced into `plan:` and `chore:` commits) later squashed into one `plan:` delivery commit.

## Existing coverage

- `docs/operations/git_policy.md` `Checkpointing` already uses `wip:` as a **prefix** for end-of-iteration incomplete work and states `wip` is *not a commit type*.
- `workflow/coding-agent/prompts/review-pass-run.md` uses WIP as **standard practice**: each unit of significant work is one `WIP:` commit, squashed into a single typed delivery commit once work completes.
- The two sources disagree in vocabulary (`wip:` vs `WIP:`) and in framing (git_policy treats it as an end-of-iteration fallback; review-pass-run treats it as the normal mid-iteration checkpoint).

## Goal

Propose a WIP-policy write that reconciles the two sources and documents:

1. `wip:` is accepted as an additional commit prefix, but a WIP commit is **always eventually squashed** into the typed delivery commit -- it never reaches `main` as-is.
2. When `wip:` is acceptable:
   - The current task is far-reaching and needs a checkpoint.
   - At operator discretion.
   - At the agent's suggestion, with operator acceptance.

## Accepted design

- Canonical prefix is `wip:` (lowercase), matching the `type:` convention.
- A `wip:` commit always squashes into the typed delivery commit; it never reaches `main` as-is.
- When `wip:` is acceptable: far-reaching refactor or audit-type change needing checkpoints; operator directs; agent proposes and operator accepts.
- Correction commits fix an earlier commit in the same iteration. Folding a fix into a non-HEAD commit uses `git commit --fixup=<hash>` + `git rebase -i --autosquash`.
- Autosquash was evaluated for fit and kept as a procedural note, not a policy carveout: wip commits squash upward into the delivery commit; cross-iteration corrections use the `[CORRECTION]` tag. The fit case is the rare two-typed-commit iteration.

## Completed

| File | Change |
|---|---|
| `docs/operations/git_policy.md` | added `WIP Commits` section (canonical `wip:`, squash mandate, three acceptable conditions); extended the `Amending` bullet with the same-iteration boundary and non-HEAD fold; aligned prose `WIP` to `wip` |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | rephrased the mid-iteration commit bullet with the squash mandate and the `--fixup`/`--autosquash` recipe |
| `AGENTS.md` (root) | aligned the free-form sentence to `wip:` and the squash clause |
| `workflow/coding-agent/prompts/review-pass-run.md` | aligned `WIP` to `wip` (4 prose occurrences) |
| `devlog/roadmap.md` | marked the T1 WIP-commit-policy row done |

## Acceptance criteria

- [x] `wip:` documented as an accepted commit prefix that always squashes into the typed delivery commit
- [x] Three acceptable conditions for `wip:` enumerated in git_policy
- [x] Correction procedure named (same-iteration boundary; `--fixup`/`--autosquash` for non-HEAD targets)
- [x] Provider-layer and root `AGENTS.md` carry the squash mandate
- [x] `review-pass-run.md` aligned to canonical `wip:` spelling
- [x] Lint gate clean

## Reference

The operator drew the WIP policy from [`workflow/coding-agent/prompts/review-pass-run.md`](../../workflow/coding-agent/prompts/review-pass-run.md) -- each unit of significant work is one `wip:` commit, with the intention to squash into a single typed commit once the work is done.

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| _none_ |  |  |

## What's Next

None -- the roadmap row is done and this iteration is closed.
