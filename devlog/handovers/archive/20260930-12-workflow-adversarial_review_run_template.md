# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 -- Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Author the adversarial novel-bug review run template and the class-scoped collateral hunters, and close the third child of the `task-queue` review-hardening row.

## Scope

One sub-task: the adversarial novel-bug review row under the `task-queue` review-hardening parent. The template is a `-run` main-agent prompt; the parent row and its two sibling children (mutation gate, BDD-lite invariant report) were already landed and are recorded here only because the parent's completion state changed.

The work was done in a session on 2026-09-30 that mined the pi session logs for the original review phrasing, drafted the prompt, and updated the roadmap. It never opened a handover. This record is backfilled from that session's transcript; see Findings.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | The prompt carries the six-step run template and its three embedded briefs | `grep -c "^## " workflow/coding-agent/prompts/adversarial-review-run.md` | Agent [x] |
| 2 | The reviewer brief is fenced at four backticks so the inner `bash` fence cannot terminate it | `grep -n '^````' workflow/coding-agent/prompts/adversarial-review-run.md` | Agent [x] |
| 3 | Each embedded brief is one paragraph per line, unwrapped | `awk 'length>100' workflow/coding-agent/prompts/adversarial-review-run.md \| wc -l` | Agent [x] 48 lines |
| 4 | The adversarial row is `[x]` with a Landed note | `grep -n "Adversarial novel-bug review" devlog/roadmap.md` | Agent [x] |
| 5 | The parent row is `[x]` and carries no forward-looking text | `sed -n '101p' devlog/roadmap.md` | Agent [x] |
| 6 | The file is committed | `git ls-files --error-unmatch workflow/coding-agent/prompts/adversarial-review-run.md` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/adversarial-review-run.md`](../../workflow/coding-agent/prompts/adversarial-review-run.md) | The run template this iteration produced |
| [`devlog/roadmap.md`](../roadmap.md) | The adversarial row and its parent row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The reviewer brief is one prompt that dispatches subagents, so it embeds both its own instructions and the worker's brief | The operator identified the shape: this is a subagent that dispatches a subagent | `workflow/coding-agent/prompts/adversarial-review-run.md` Step 2 |
| The review stays one focused reviewer; only the collateral hunt fans out | The coupled judgement does not decompose, while one hunter per finding class does. The operator's earlier framing on 2026-09-29 | `devlog/roadmap.md` adversarial row |
| Unwrap the embedded briefs, leave the surrounding prose alone | The surrounding prose already matched house style at 511 characters against `parallel-work.md` at 730; only the three briefs had been hard-wrapped at 75 columns | This handover |
| Mark the row landed on the strength of a template existing, not a review having run | The Landed note says so explicitly, and the operator left the call open rather than reverting | `devlog/roadmap.md` adversarial row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| This iteration produced a file and a roadmap row flip but no handover and no commit. The file was written at 14:32 and the row flipped in the same session; the commit landed 30 minutes later in a different session whose only content was the row flip, carrying a subject naming unrelated T6 work. The row read `[x] Landed` for two days with no artifact in any ref. | record defect | current iteration. Triaged to: `AGENT_FEEDBACK` `[A]` 2026-09-21 "Close-milestone and iteration record discipline" |
| The commit subject named T6 session-identity env tasks, but the commit contained only the adversarial row flip and no T6 row exists anywhere in the roadmap. The subject described work that was never filed. | record defect | current iteration. Triaged to: the commit message, amended in this iteration |
| The 2026-09-30 work ran with no iteration open, so no close invariant executed. The invariant that would have caught this -- one commit carrying the work, the handover, and the write-back -- has no trigger when no iteration was ever opened. | governance gap | current iteration. Triaged to: `AGENT_FEEDBACK` `[A]` 2026-09-21, third `legacy:` line |

## Completed

| Work | Result |
|---|---|
| Prompt authored from the mined session logs | `Adversarial Novel-Bug Review - Run (Main-Agent Template)`, six steps: run the gates, write the reviewer brief, dispatch one focused reviewer, derive the classes, fan out the hunters, confirm convergence |
| Three worker briefs embedded | The reviewer brief (what the gates already cover, the contract to hold the code to, seven places to look hardest), the class-scoped collateral hunter brief, and the confirmation brief |
| Line wrap fixed | The three briefs unwrapped to one paragraph per line, 48 lines now over 100 characters. The reviewer's `git diff` line had been flattened flush-left by the unwrap and was restored as a `bash` fence, which forced the outer fence to four backticks per the `roadmap_policy.md:144` precedent |
| Adversarial row closed | Row 104 flipped to `[x]` with a Landed note naming the template, its six steps, and the limit: primitive-agnostic, not yet run against this extension |
| Parent row closed | Row 101 flipped to `[x]` because all three children are complete, and its "the adversarial novel-bug review and the class-scoped collateral hunters remain" text was removed -- a completed row carrying forward-looking text is a record bug the `gm` check-in already names |

## Deferred items

| Item | Reason |
|---|---|
| Run the template once against the task-queue extension | The Landed note records the limit explicitly: the template is primitive-agnostic and has not been exercised. The first live run is what tests the class decomposition |

## What's Next

The row that opens this session's parent is closed; the `task-queue` review-hardening parent has no open children. `/plan` and `/milestone-start`/`/milestone-close` per-prompt quality passes are the next unchecked rows in M3.2.1. Running the new template against the extension is deferred above and is the natural way to exercise it.
