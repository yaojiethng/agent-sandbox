---
date: 2026-10-26
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - A record written before the gate, presented as a diff

## Objective

Make both close write-backs happen when the work happens and not after the release, so the gate reads a diff rather than a description: the roadmap row and the handover's `## Findings` table are written as the work lands and as the finding surfaces, and the pre-close summary shows what changed.

## Scope

In scope: the carriers of the timing rule -- `iter.md` Step 7 and its record invariants, `wrapup.md` B4 and B6, the `task-list` invariant, `AGENT_FEEDBACK.md`'s header, and the iteration protocol's principle.

Out of scope: changing the close's commit shape, which still lands the write-back inside the delivery commit; and any new gate, since the evidence is a diff the operator already reads.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `iter.md` presents the roadmap write-back as a diff, with the base defined | `sed -n '/Roadmap write-back/p'` names `git diff <iteration-base>`, the two cases of the base, and the `Completed` mapping | Agent [x] |
| `iter.md` presents the findings as a diff of the feedback record plus the changed-path set | `sed -n '/Findings and record checks/p'` names `git diff <iteration-base> -- devlog/AGENT_FEEDBACK.md` and `git status --short` | Agent [x] |
| A finding is written in the same turn it is found | two carriers, each with a different job: `iter.md` supplies the trigger at discovery, `iteration_protocol.md` the judgement and the destination allowance | Agent [x] |
| The mark rides the commit that lands its artifact | `grep -n "rides the commit" .agents/skills/task-list/SKILL.md` prints 1 | Agent [x] |
| A feedback entry is written when the experience happens | `grep -n "rather than at the session's close" devlog/AGENT_FEEDBACK.md` prints 1 | Agent [x] |
| `/wrapup` confirms rather than applies | B4 and B6 both read as confirmation, and neither says it applies a released change | Agent [x] |
| No rule is stated twice | the timing rule is stated once as a judgement and once as a trigger; `work-log` keeps only its section-roles table; `wrapup` cites the gate's decision rather than restating the diff rule | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` across 12 gates; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| No prompt states a count of anything it does not own | a count of the protocol's record invariants had to be edited when this unit added one, and it was already wrong once the fifth landed. The sentence that carried it also narrated the list it preceded, so both left together | this handover |
| The record invariants' timing is stated per bullet, not summarised | each bullet names its own moment -- as it is made, when you make it, before the next commit, in the same turn it is found -- so a sentence saying they fire during production repeated the list rather than adding to it | this handover |
| One statement per layer: the judgement in the protocol, the trigger in the prompt, neither in the convention | the convention's job is the record's shape, which its section-roles table already states; a paragraph there made a third copy of a rule whose only unique clause was the destination allowance | this handover |
| The write happens before the gate and the gate presents the diff | a gate that reads a description cannot see an omission: the description is true of the intent and says nothing about whether the file changed. A diff either carries the line or shows its absence | this handover |
| A new file is shown by `git status --short`, not by the diff | `git diff <base>` reports neither untracked files nor an unborn path, and the handover is new in the iteration that writes it, so the changed-path set is the evidence for it | this handover |
| A finding is written in the same turn it is found, before it is mentioned in chat | the gate reads the record. An observation held in the conversation is not presented at all, and an empty `## Findings` table cannot be told apart from a clean unit | this handover |
| The `Triaged to:` cell may be filled later, but the row may not wait | the destination is often the gate's to decide, while the finding itself is already known; separating the two keeps the row from being deferred for a reason that does not apply to it | this handover |
| A feedback entry is written when the experience happens | the file's own rule is to grep for a recurrence before writing a new entry, which is impossible while the first occurrence exists only in the session | this handover |
| `/wrapup` B4 and B6 change character from applying to confirming | the rows exist before the gate, so the close's job is to confirm the released set is the set on disk and to land what the gate decided after the write | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The T1 row filed for this defect named only the roadmap marker, while the same mechanism governs the findings row and the feedback entry | corpus | a reader fixing the roadmap half would leave the findings half standing | fixed in this unit: the row is retitled and its tail names both write-backs |
| `git diff` cannot show the handover, because the iteration creates it | mechanism | a presentation that showed only the diff would omit the record the gate is reading | this handover: the changed-path set is shown beside it |
| The close still lands the write-back inside the delivery commit, so a row edited after the gate ships in the same commit as the work | process | a late edit is still possible, and the diff is what makes it visible rather than impossible | accepted, stated in the scope |
| The first cut stated the timing rule in three carriers and added 361 words across six files | corpus | one rule read three times, and a convention paragraph that repeated a prompt | fixed in this unit: the `work-log` paragraph is removed and its one unique clause, that the destination may lag, joined the principle. Net +232 words over five files |
| `iter.md` said the protocol holds "Four of them" about records, which the new principle made five | corpus | a count in a prompt goes stale the moment a principle is added, and nothing reports it | fixed in this unit |

## Completed

| File | Change |
|---|---|
| [`iter.md`](../../workflow/coding-agent/prompts/iter.md) | the discovery rule writes to Findings in the same turn; Step 7 items 2 and 6 present diffs and the changed-path set; the count of record invariants and the sentence summarising their timing are gone |
| [`wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | B4 confirms the released rows are on disk; B6 confirms destinations and lands only what the gate decided after the write |
| [`task-list/SKILL.md`](../../.agents/skills/task-list/SKILL.md) | the mark rides the commit that lands its artifact, so a reverted completion takes the marker with it |
| [`AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | an entry is written when the experience happens, not at the close |
| [`iteration_protocol.md`](../../docs/reference/iteration_protocol.md) | the principle: record a finding when it is found, because an empty table cannot be told apart from a clean unit. It states the judgement only; the artifact and the trigger are the prompt's and the convention's to name |
| [`roadmap.md`](../roadmap.md) | the T1 row is retitled, ticks, and its tail names both write-backs and this handover |
