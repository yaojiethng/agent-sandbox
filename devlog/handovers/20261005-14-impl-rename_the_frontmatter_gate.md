---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Implementation
status: Closed
---

# Handover - Rename the Frontmatter Gate

## Objective

Give the frontmatter gate a name that covers what it scans: every prompt, every skill, and every policy file.

## Scope

The gate scans three sets and its name names one of them. It was `check_prompt_frontmatter.sh` when prompts were all it read; it now also parses the frontmatter of every skill under the instruction roots and of every `docs/**/*_policy.md`. Its own header has described the wider set since the scan widened -- "Frontmatter parse gate over every prompt, skill and policy in the tree" -- so the name is the only part left behind.

The name is `check_frontmatter.sh`, with `scripts/lint/frontmatter.mjs` beside it and the test seam `FRONTMATTER_SCAN_ROOT` in place of `PROMPT_FRONTMATTER_SCAN_ROOT`. The scan set is not obvious from any short name, and the header states it; what the name must not do is name one subject of three. The handover gate keeps its own name because its subject is the handover frontmatter, which this gate does not read.

1. **Rename the gate and its helper.** `git mv scripts/check_prompt_frontmatter.sh scripts/check_frontmatter.sh` and `git mv scripts/lint/prompt-frontmatter.mjs scripts/lint/frontmatter.mjs`, with the header path and the helper reference inside the gate updated.
2. **Rename the seam.** `PROMPT_FRONTMATTER_SCAN_ROOT` becomes `FRONTMATTER_SCAN_ROOT` in the gate, in `scripts/lint/frontmatter.mjs`, and at every use in `tests/test_lint_umbrella.sh`.
3. **Follow the wiring.** The `GATES` array and the header comment in `scripts/lint.sh`; the ten mentions in `tests/test_lint_umbrella.sh`; the phrase in `docs/development/prompt-authoring-conventions.md` `## Drafts`; and the gate list in `workflow/coding-agent/drafts/precommit-gate-runbook.md`.
4. **Check the tree for stragglers.** `grep -rn "prompt_frontmatter\|prompt-frontmatter\|PROMPT_FRONTMATTER"` must return only the closed handovers and the roadmap row that records this rename.
5. **Record the outcome.** Roadmap row written back, handover closed, one commit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The gate runs under its new name and reports the same finding count | `bash scripts/check_frontmatter.sh`; the line reads 44 prompt, skill and policy files at this head, four more than the 40 the row's own reading counted, because two later sessions landed two scanned files | Agent [ ] |
| The seam works under its new name | `bash scripts/lint.sh`; the umbrella test's seam cases | Agent [ ] |
| No reference to the old names survives outside the records | `grep -rn "prompt_frontmatter\|prompt-frontmatter\|PROMPT_FRONTMATTER"` | Agent [ ] |
| The gate still fails on a bad frontmatter block | the umbrella test's negative cases; a direct fixture run | Agent [ ] |
| `bash scripts/lint.sh` is clean | the command | Agent [ ] |
| `bash scripts/run_tests.sh` is clean | the command | Agent [ ] |
| The row is written back and the handover closes | `devlog/roadmap.md`; this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/check_prompt_frontmatter.sh` | renamed to `check_frontmatter.sh`; header path and helper reference |
| `scripts/lint/prompt-frontmatter.mjs` | renamed to `scripts/lint/frontmatter.mjs`; the seam read |
| `scripts/lint.sh` | the `GATES` entry and the header comment |
| `tests/test_lint_umbrella.sh` | ten mentions: invocations, comments, case names, the seam |
| `docs/development/prompt-authoring-conventions.md` | the phrase in `## Drafts` |
| `workflow/coding-agent/drafts/precommit-gate-runbook.md` | the gate list |
| `devlog/roadmap.md` | this row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The name is `check_frontmatter.sh` | the gate's subject is the frontmatter block of every file whose frontmatter a tool reads; the scan set is three kinds and no short name carries them, so the header does | this handover; the gate's own header |
| The helper follows the gate: `scripts/lint/frontmatter.mjs` | the pair reads as one subject, and the seam keeps the same stem | this handover |
| The seam is `FRONTMATTER_SCAN_ROOT` | a seam whose name keeps a retired subject invites the reader to scope the fixture to prompts | this handover |
| The handover gate is not renamed | its subject is the handover frontmatter, which this gate does not read | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `tests/test_eval_harness.sh`, from a later session's commit `workflow: hold the commit body to one sentence`, called its seven test functions bare instead of through `run_test`, so none of them ran and the liveness gate failed the suite. The file is not this iteration's work: the operator directed the fix into that commit itself, with a `[CORRECTION]` block in handover `20261005-12`, whose first acceptance criterion reports "16 passed" that no run produced. | defect, silent | closed iteration, corrected at the operator's direction | Triaged to: that commit and handover `20261005-12`, folded on the operator's release |
| The repository advanced four commits while this iteration was open: the behaviour eval skill, the placement-check correction, the commit-body hillclimb and the hillclimb playbook, with handovers `20261005-10` to `20261005-13`. One of them tightened `git_policy.md`'s commit-body rule to a single sentence, so this iteration's own commit follows the new shape. None touches the frontmatter gate. Commits are named by subject here: the fold below rewrote their hashes. | context | current iteration | Triaged to: this handover, and the commit-body rule is obeyed in the delivery commit |
| This handover was first numbered `20261005-10`, which a later session had already taken. It is now `20261005-14`. The naming rule is `YYYYMMDD-NN-slug` and nothing checks the sequence, so a collision is silent: two handovers sort under one number and only a reader notices. | defect, silent | current iteration | Triaged to: the renumber; whether the sequence earns a check is a row of its own, filed in this iteration's write-back |
| The scan count moved from 40, the figure the row's reading recorded, to 44, because the eval skill added `SKILL.md` and a playbook the scanner recurses into. The pass criterion is therefore the count at this head, not the number in the row. | evidence | current iteration | Triaged to: the acceptance table above |

## Completed

No file changes this iteration.
