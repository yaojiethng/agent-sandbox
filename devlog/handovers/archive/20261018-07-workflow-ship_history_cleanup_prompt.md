---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Ship the history-cleanup prompt with its checks corrected

## Objective

Ship the history-cleanup runbook with the two proofs that could not hold on its own required work replaced, and the detector failure that this repository has already hit written into the run.

## Scope

New runbook, `workflow/coding-agent/prompts/history-cleanup.md`, sourced from the operator's prompt and amended from one real run against `d366378c..f82d1a0d`, recorded at handover `20261018-06`.

Two of the amendments correct a contradiction inside the operator's text. Its mandate says the records are not the invariant, and its proof asked for `git rev-parse <old-tip>^{tree}` to equal the new tip's tree; that cannot hold once records merge. Its content proof asked for an unchanged sorted patch-id multiset, which is invariant under a reorder and false under a collapse, and the mandate requires collapses. Both are replaced with the invariant that survives a regroup: a per-blob comparison with the record paths excluded, and the record delta reported separately.

The rest of the amendments come from the run. A positive control on the detector, because the failure table's "the range is already clean" row is exactly what a broken detector produces and is unfalsifiable without one. Named costs for the cheap gate and the expensive suite, so the grain is a decision rather than a discovery. An input for content that did not exist in the old range. A rule for a failure that disappears on re-run. The record-merge rule that keeps the earlier number so outside citations resolve. And the marker-stripping defect in the detector, which produced a confident and wrong "none" during this repository's own run.

Ruled out of scope. The detector stays at `.agents/drafts/history-cleanup/inversions.mjs`; the runbook names it as a draft rather than moving it, because the skill pipeline that would own it is unbuilt. The other sixteen runbooks are untouched.

Roadmap write-back: none, under the sidequest invariant. Utility runbooks land without their own rows: `rebase.md` and `record-correction.md` have no filing row either, and are referenced only as mechanisms inside other rows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The prompt parses and its frontmatter names its triggers | `scripts/check_frontmatter.sh`, 89 files | Agent [x] |
| Every step ends on a completion criterion | every section closes with its own criterion line | Agent [x] |
| The two proofs hold on the work the mandate requires | content identity is a blob comparison with record paths excluded; patch-id is demoted to context | Agent [x] |
| The detector cannot be trusted without a control | the step requires a seeded two-commit fixture before a clean range is believed | Agent [x] |
| The two costs are named and the grain is the caller's | the rebuild step states the measured gate and suite costs | Agent [x] |
| A load-dependent failure has a stated response | `## Prove each commit stands`, and a failure-modes row | Agent [x] |
| Every gate passes | `scripts/lint.sh`, 10 gates | Agent [x] |
| The repository copy and the installed copy agree | `diff -q` on both paths | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Replace the tree-identity proof rather than delete it | The property it protects is real: the content a reviewer reads must not move. Excluding the record paths keeps the property and stops the check failing on the work the prompt requires. | the prompt `## Prove the series` |
| Demote patch-id to context, not to a pass condition | It is the only cheap check on whether a change was split and recombined, so it stays visible. It cannot be a gate under a collapse. | the prompt, same section |
| The positive control is a step, not a caution | A warning is skippable. A step with a completion criterion is not, and the criterion is that the control fires. | the prompt `## Detect the inversions` |
| Name the measured costs instead of presetting a grain | The caller owns whether to run the suite per commit, and the number is what makes that a decision. A preset would be wrong for the next repository. | the prompt `## Rebuild` |
| Ship the prompt with the detector elsewhere, named as a draft | The runbook is stable; the detector is not, and the pipeline that would own it is unbuilt. Naming it keeps the runbook usable without claiming a home it does not have. | the prompt; this record |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether the detector moves out of `.agents/drafts/` into a shipped home | The draft path inside a shipped runbook | leave it a draft until the skill pipeline lands; or promote it beside the prompt now |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Both defective proofs were in the operator's text, and both failed the same way: a check that cannot hold on the work the mandate requires | document defect | corrected; the prompt now states why patch-id cannot be a pass condition, so the next author does not restore it |
| An instrument that reports a clean result and an instrument that cannot match a line have identical output. Only a seeded case separates them | agent experience | the positive control is the first step of the detection section, and the failure table's clean-range row now depends on it |
| The run cost eleven minutes of suite time, of which five were wasted by capturing `tail`'s exit status instead of the suite's | process | written into the runbook, along with the `git add -A` trap that absorbed leftover files into the first commit |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/history-cleanup.md` | the runbook, with the proofs corrected, the positive control added, the costs named, and three failure-modes rows added |
| `/opt/workflow/agent/modules/coding-agent/prompts/history-cleanup.md` | installed copy, byte-identical to the source |
| `devlog/handovers/archive/20261018-07-workflow-ship_history_cleanup_prompt.md` | this record |
