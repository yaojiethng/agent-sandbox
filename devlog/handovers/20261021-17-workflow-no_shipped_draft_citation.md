---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - No shipped document cites a draft

## Objective

Remove the last place where a shipped document depends on an unreviewed draft, so that every rule a shipped document states is reviewable where it is read.

## Scope

The roadmap row **A shipped rule's definition lives in an unreviewed draft**, and the filing of the two rows that belong to another record.

The row named two pointers and predicted two definitions to inline. Neither definition needed inlining. `docs/policies/iteration_policy.md` stated the work-unit table's columns in the clause before the pointer, so the pointer carried no definition and deleting it lost nothing. `workflow/coding-agent/prompts/history-cleanup.md` cited a 76-line draft script for the detector's algorithm, and the paragraph above the pointer already named the four inversion kinds; the algorithm is now one sentence in the prompt, so the prompt states a method rather than delegating to a file the reader cannot open.

Two rows left the milestone. The record-check backlog moved to `T5 - Archival`, which holds the record repair the backlog needs. The wiki unit is permanently deferred in `devlog/roadmap_future.md`, because its subject is a provider-tree restructuring and not a prose standard.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No shipped document cites a draft file | `grep -rn "\.agents/drafts/" docs/policies/ docs/reference/ workflow/` prints one hit, `scope.md`, which states where a brief is written | Agent [x] |
| The policy still defines the work-unit table | `grep -n "work-unit table" docs/policies/iteration_policy.md` shows the columns at the clause that carries them | Agent [x] |
| The prompt still states the detector's method | `grep -n "The detector reads" workflow/coding-agent/prompts/history-cleanup.md` prints the sentence | Agent [x] |
| The milestone lists no row another record owns | `awk '/^## M3.3.4/,/^## /' devlog/roadmap.md`'s open rows name the rendering row and the ship-set row only | Agent [x] |
| The umbrella and the suite are clean | `bash scripts/lint.sh` prints `Lint: clean`; `bash scripts/run_tests.sh` prints `1273 passed, 0 failed` | Agent [x] |

## Decisions

A prompt that states a method does not depend on the script that runs it. The alternative was to ship `inversions.mjs` under `scripts/`, which would make a shipped prompt depend on this repository's tooling directory and put a detector there that no runbook invokes.

Project-scoped citations of drafts stay. `docs/adr/coding_agent_loop_workflow.md` and `docs/development/testing_policy.md` both cite drafts, and both are read only in this project, which is the arrangement `prompt-authoring-conventions.md` `## Draft status and the switch-over gate` defines. The row was about shipped documents, and it is closed against that scope rather than the wider one.

The record-check backlog went to `T5 - Archival` by the operator's filing, and the wiki unit is permanently deferred rather than opened later, so `devlog/roadmap_future.md` now carries the reasoning the milestone would have restated.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row predicted two definitions to inline and neither existed, so a row's stated cost is a claim about files that a read before scoping would have corrected | result | the unit was two deletions. The lesson is the one the row itself carried: a definition cited from a draft is often stated twice, once where it is read and once where it is drafted | no new row; the pattern is `principle-single-source-of-truth` applied to a pointer |
| `workflow/coding-agent/prompts/scope.md` sends the reader to `.agents/drafts/` as a destination, and a grep for a draft citation reads it as one | noise | the hit is a writing rule, not a citation, so a later sweep that greps for this pattern must read the hits rather than count them | recorded here |

## Completed

| File | Change |
|---|---|
| [`docs/policies/iteration_policy.md`](../../docs/policies/iteration_policy.md) | the pointer to `.agents/drafts/sequential-work.md` removed; the table's columns stay at the clause that states them |
| [`workflow/coding-agent/prompts/history-cleanup.md`](../../workflow/coding-agent/prompts/history-cleanup.md) | the draft script pointer replaced by the one sentence that states the algorithm |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed; the record-check backlog filed under `T5 - Archival`; the `Sequencing:` line updated |
| [`devlog/roadmap_future.md`](../roadmap_future.md) | the wiki unit permanently deferred under `## Deferred (Unplanned)` |
