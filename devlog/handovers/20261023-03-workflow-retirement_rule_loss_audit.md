---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - The retirement's rule-loss audit

## Objective

Walk the eight retired policies against the surfaces that absorbed them and end with every rule either present at its destination, restored, or recorded as a deliberate cut with the handover that cut it.

## Scope

Continues the M3.3.2 retirement from Handover `20261023-02`, which closed its last slice.

The task is the roadmap row **The retirement's rule-loss audit**. The policy-slice reviewer was meant to run on every retirement slice and never did, so eight deletions landed with no check that each rule survived at a destination. This iteration runs that check: one review pass per retired policy, through `skill-scaffolder`'s `runbook/review.md`, over the deleted source and against the destinations the design record's per-policy map names.

The walk is coverage, not judgement: for each section of each retired policy, either the rule is found at a destination, or it is restored there, or the slice handover records the cut as deliberate. The map is at section grain, so a section that straddles the line is resolved by the same subtraction in the section that reports it.

The census is one record under `devlog/discussions/`, one section per retired policy, so a reader can ask "was this rule checked?" after the close. The row's ending predicate is per-rule, so the handover's Findings table cannot hold it.

Out of scope: the review runbook itself, which is the method this iteration applies and is one iteration old; the lost-work recovery draft, an open row of its own; and any rule whose loss belongs to a surface a later roadmap row is redesigning, reported as a finding with that row named.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The census carries one section per retired policy, each naming its source as the slice received it and the destinations the map gives it | `grep -c '^## '` is 8; each section carries a `git show <sha>^:<path>` line and a slice handover id | Agent [x] |
| Every section of every retired policy has a disposition row, so no rule is skipped | per policy, the census states the source's line count, its `##` heading count and the rows walked, and names any difference. Amended at the pre-close: row-for-heading equality fails on a correct walk, because the ADR policy's template carries headings inside a fence and two seats split a section, so equality would have forced a wrong grain | Agent [x] (amended) |
| Every destination the census names exists, and every `present` row carries the phrase grepped at that destination | a script resolves each destination path in the census and greps each `present` row's phrase, finding at least one hit | Agent [x] |
| Every rule marked lost is restored at the mapped destination and greppable there, or marked `cut` with a handover whose file exists | each `restored` row's phrase greps at its destination, each cited handover id resolves under `devlog/handovers/`, and no restored rule is stated twice at one destination | Agent [x] |
| No rule is left undecided | the disposition column holds only `present`, `restored` and `cut`, and a grep for any other value returns nothing | Agent [x] |
| Each section records the pass that found it: the pair, one line per seat, and whether the seats agreed, a disagreement reported rather than averaged | each section carries the pair and an `agreement:` line, and `grep -c 'deepseek/deepseek-flash'` is 8 | Agent [x] |
| Every decision this iteration recorded is realized in the files | replay the Decisions table row by row | Agent [x] |
| The rule-loss row closes with the census link and this handover, and no other row changes state beyond the maintenance pass in Completed | `git diff devlog/roadmap.md` shows the marker flip, the landing note and the two maintenance edits only | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The census lands as a `devlog/discussions/` record, not as rows in this handover's Findings | Eight policies of section-grain rules exceed a findings table, and the row's ending predicate is coverage a later reader must be able to check after the close | this record |
| One unit, not eight | No slice delivers the row's outcome alone; the outcome is the census plus its restorations, and the row is one roadmap task | this record |
| Each policy's source is read as its slice received it, not at the deletion commit | `testing_policy` was emptied by its slice before the deletion commit, whose parent is an emptied stub, so the deletion-commit reading would walk no rules and report the slice clean | this record; the roadmap row |
| Each policy's pass runs as a dispatched reviewer pair, not an inline walk | The row exists because the review never ran on a slice, and an agent that will apply its own restorations cannot be its own counterparty. The runner takes the pair the call site resolved, so the two seats are one model twice, and their disagreement is what makes a report worth verifying | this record; the operator's release of 2026-10-23 |

## Decisions pending

None. The dispatch shape was answered at the scope gate: one pair per policy.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The roadmap row named the `testing_policy` deletion commit as the source, and that commit's parent is an emptied stub, so the row as filed would have reported the testing slice clean | Defect in the task | The audit's own premise fails on one of its eight slices | Fixed here: the row reads the source as the slice received it, and the census records `8dfeb9c2^` for that policy |
| Four destination paths in the briefs and in the scope proposal named the wrong home: `handover-maintenance`, `roadmap-maintenance` and `doc-maintenance` sit under `workflow/coding-agent/skills/`, and `record-correction` is a prompt, not a skill | Defect in the proposal | Both seats reported the missing path instead of skipping the destination, so no rule was lost to it | Triaged to this record: the census names the real path in every row, and the scratch briefs are not committed |
| The seats split the source at different grain (the ADR policy 16 rows against 14, documentation 14 against 10, handover 17 against 13, git 7 against 5), so an index-aligned comparison counts disagreement it cannot attribute to a section | Method limit | The eleven disagreements are a signal that the walk was checked twice; each was settled by command, and the census states the settled disposition, not a vote | Triaged to this record, under How the walk ran |
| A closed rule can survive only as prose nobody greps: five of the nine restored rules had been asserted by their retiring slice as "stated where it is enforced", which named no artifact | Process gap | The retirement's own recorded claim read as coverage and was not | Triaged to the roadmap row **Reviewer subagent as the compliance counterparty for gateless closes**, which already owns the missing-review case |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261023-report-retirement_rule_loss_audit.md`](../discussions/20261023-report-retirement_rule_loss_audit.md) | new census: eight walks, 109 rows, every source section with a disposition, phrase-verified |
| [`.agents/skills/work-log/SKILL.md`](../../.agents/skills/work-log/SKILL.md) | restores the handover's purpose, its brevity clauses, scope independence, the prior-record-is-Closed rule and the pending-decision rule; adds the `investigation` alias |
| [`.agents/skills/decision-records/SKILL.md`](../../.agents/skills/decision-records/SKILL.md) | restores when an ADR is written and the three subjects that call for one, and the two-or-three-candidate naming rule |
| [`.agents/skills/docs/SKILL.md`](../../.agents/skills/docs/SKILL.md) | restores the rule that a reference document keeps its code examples current |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes; the `roadmap-maintenance` pass is applied (see the Findings table for the two row defects it found) |
| this record | `Status: Closed`, criteria and completed set |
