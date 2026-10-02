# Handover - The record-correction prompt

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

[CORRECTION -- 2026-10-02: The record carried no Date, Milestone, Type or Status field and stated its status as `Complete.` under a `## Status` heading. The metadata block above carries the values the record already stated.]

## Objective

Give the main agent a runbook for folding a correction into a closed commit that is not HEAD, an operation no existing prompt covered.

## Why

`/rebase` covers porting a stale branch onto a target. It does not cover folding a correction into a commit already on the current branch, which is the operation `docs/adr/closed_record_corrections.md` mandates. Two wrong turns during one session showed the gap. `git rebase --autosquash` exited zero having matched nothing, because the target's subject had already changed and the `fixup!` prefix pointed at text no commit held. The replacement sequence editor then appended the fixup at the end of the todo rather than after its target, so the correction folded into the wrong commit. Both failures were silent, and both would have shipped unnoticed had the runbook's verification step not been run by hand.

## Decisions

- The prompt is `record-correction.md`, beside `rebase.md` and `merge.md`, not an agent skill. The two-command git dance is a tool the main agent performs; `src/reasoning/agent/skills/` holds container-level procedures such as `pi-bump`.
- Verification is mandatory and reads the corrected content out of the target commit with `git show <target>:<path>`, not from the working tree. Only that catches a fixup that survived a successful rebase.
- A correction that changes what kind of commit the target is does not fold. It becomes its own commit with its own iteration and handover. Folding is for a correction that belongs to the commit it names.
- The three silent causes of a non-matching autosquash are enumerated, since none reports an error.

## Changes

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/record-correction.md` | new runbook |
| `devlog/handovers/20261002-14-workflow-record_correction_prompt.md` | this handover |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The prompt parses as valid frontmatter and lints clean | `bash scripts/lint.sh`; `node scripts/lint/prompt-frontmatter.mjs` | pass |
| 2 | The prompt names the three silent causes of a non-matching autosquash | read `## Fold it` | pass |
| 3 | Verification reads the content out of the target commit | read `## Verify the fold` | pass |
| 4 | The fold-versus-own-commit test is stated before the fold runs | read `## Test whether the correction folds` | pass |
| 5 | Suite green | `bash scripts/run_tests.sh` | pass |

## Findings

- `git rebase --autosquash` reporting success over a fixup that matched nothing is not documented behaviour anywhere in the repository, and it is the single most dangerous property of the command for a runbook to omit.
- `GIT_SEQUENCE_EDITOR` is unset in this environment, so a bare `git rebase -i` fails with "cannot run editor" rather than waiting for input. Every rebase in a runbook needs the variable set explicitly.

## Deferred

- The doc-wrap registration. Enabling the rule under the repository config yields 1891 findings across 626 files, concentrated in `devlog/handovers`, `devlog/discussions` and `docs/adr`. The exemption seam matches by suffix only, so grandfathering the record layer needs a seam that accepts a path prefix. That is a `workflow:` change with its own iteration, and it is a separate decision from this prompt.
- A lint-rules skill for adding, wiring and retiring a custom lint rule. The gap this prompt closes is procedural and narrow; the lint-rules gap is broader and is not yet scoped.
