# Agent Handover

**Date:** 2026-10-01
**Milestone:** M3 -- T1 Workflow and Policy Organization
**Type:** Workflow
**Status:** Closed

## Objective

Add a `Decisions pending` record to the handover format, replay it at the gates that can surface a question, and resolve it at close, so the operator is never surprised by a decision the agent has been holding.

## Scope

The `Decisions pending` content section in `handover_policy.md`, its replay in `iter.md` at the scope gate and the pre-close summary, its resolution as a new close step in `wrapup.md`, and the structural-completeness rule in `audit.skill.md` that enumerates the required sections.

Filed under the general M3 T1 track: this is workflow and policy organization, not dispatch-surface curation.

Unit 2 of a two-unit split confirmed at the scope gate. Unit 1 -- the `/backlog-triage` prompt -- is handover `20261001-03` and lands separately under M3.2.3. The file sets are disjoint.

Not in scope: retroactive amendment of handovers closed before this section existed. The operator directed forward-only at the gate; a closed handover is amended only by correction under the handover policy.

## Carried forward

None. The prior handover (`20261001-02`) closed with one deferred item, a determination rule for `superseded` in `discussion_policy.md`, which this iteration does not pick up.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `Decisions pending` is a content section between `Decisions` and `Findings` in the handover Format, with a three-column table | `grep -n "^## " docs/operations/handover_policy.md` | Agent [x] |
| 2 | The null-marker table carries the `Decisions pending` row | `grep -n "Decisions pending \| .None." docs/operations/handover_policy.md` | Agent [x] |
| 3 | `iter.md` presents the table at the scope gate | `grep -n "Present the handover's .Decisions pending. table with the scope" workflow/coding-agent/prompts/iter.md` | Agent [x] |
| 4 | The pre-close summary declares five sections and its fifth replays the table | `grep -n "five sections\|5. \*\*Decisions pending\*\*" workflow/coding-agent/prompts/iter.md` | Agent [x] |
| 5 | `wrapup.md` carries B1-B10 with B7 the pending-decision resolution, and `iter.md` references B9 not B8 | `grep -n "^### B" workflow/coding-agent/prompts/wrapup.md` | Agent [x] |
| 6 | `audit.skill.md` enumerates `Decisions pending` and scopes it forward from `20261001-03` | `grep -n "Decisions pending" workflow/coding-agent/audits/audit.skill.md` | Agent [x] |
| 7 | `roadmap.md` carries the filed T1 row for this record | `grep -c "Decisions pending" devlog/roadmap.md` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/handover_policy.md`](../../docs/operations/handover_policy.md) | New `Decisions pending` content section and null-marker row |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | Replays the table at the scope gate and the pre-close summary |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | New B7 resolves it at close; the tail renumbers to B10 |
| [`workflow/coding-agent/audits/audit.skill.md`](../../workflow/coding-agent/audits/audit.skill.md) | Structural-completeness rule enumerates the required sections |
| [`devlog/roadmap.md`](../roadmap.md) | The filed T1 row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Add a `Decisions pending` section rather than widen the existing `Decisions` table | `Decisions` records decisions made, with a rationale and a home. A question has none of those three properties, and folding it in would leave a row whose columns do not describe it | `docs/operations/handover_policy.md` |
| Write the entry the moment the agent is blocked, not at the gate where the block is felt | The operator must see a design question while there is still time to redirect the iteration | `docs/operations/handover_policy.md` |
| Require one question with options, per entry | A row that only states a decision is needed sends the operator back to the records to find the question the agent should have found | `docs/operations/handover_policy.md` |
| Apply the section forward only | Amending every closed handover is a correction sweep the operator declined; a closed record is amended only at their direction | `workflow/coding-agent/audits/audit.skill.md` |
| Put the resolution in `/wrapup` as its own step, not in each calling prompt | The close steps live once in the shared close runbook; a second caller restating the rule breaks one-rule-one-owner | `workflow/coding-agent/prompts/wrapup.md` |
| Split the two automations into two units | They share no file and serve no common outcome; one roadmap task per iteration, and two different milestone owners | This handover, Scope |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `audit.skill.md` structural-completeness enumerated the required handover sections without the new one, so the check would have fired on every conforming handover. The propagation sweep that authored the section searched the prompt tree and the policy tree, not the audit surface. | scope change | current iteration. Triaged to: `AGENT_FEEDBACK` `[A]` 2026-09-21 "Close-milestone and iteration record discipline", recorded as a recurrence in its `legacy:` line rather than opened as a new entry |

## Completed

| Work | Result |
|---|---|
| `Decisions pending` section added to `handover_policy.md` | Content section between `Decisions` and `Findings`; `Question \| Blocks \| Options` table; three rules on when to write an entry and how it closes; `None.` null-marker row |
| Scope-gate replay added to `iter.md` | The table is presented with the scope, so a design question is answered in the same reply that releases the gate; a null-marker table is reported in one line rather than shown empty |
| Pre-close replay added to `iter.md` | Fifth section of the summary; every entry must be resolved, cited, or pushed to Deferred items before the gate releases. The "four sections" count corrected to five |
| Close step added to `wrapup.md` | New B7 with three exits (answered, cited, deferred); B7-B9 renumbered to B8-B10; the `iter.md` reference corrected from B8 to B9 |
| Audit surface fixed | The structural-completeness rule carries the new section, scoped forward from `20261001-03` so closed handovers are not flagged |
| Installed mirror refreshed | `iter.md` and `wrapup.md` copied to `/opt/workflow/agent/prompts/`, byte-identical |
| Roadmap row filed | T1 task row naming the record, its three exits, and the two prompts that replay it |

## Deferred items

None.

## What's Next

`fanout.md`'s rename and doc pass, named by handover `20261001-02`, is unstarted and independent. The `superseded` determination rule in `discussion_policy.md` remains deferred from the same handover. The M3 T1 track also holds an open row on how `roadmap_policy.md` records a follow-on to a landed row, which this iteration's two filed rows do not settle.
