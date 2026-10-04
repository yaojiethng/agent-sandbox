---
name: check-in
description: "Runs the /gm check-in: surveys project state, returns the work inventory, and, on the thoroughness argument, dispatches the two record auditors and applies their report. Operator-invoked by the /gm prompt; the model does not fire it on its own."
disable-model-invocation: true
---

# check-in - the survey and the work inventory

## Purpose

A check-in surveys project state and hands the operator an inventory of open work with a starting direction. It is not an iteration. Its intensive half, the record audit, runs only when the operator asks for it, so the default check-in stays short and its task list carries work rather than record housekeeping.

The prompt `/gm` owns the command name and parses its arguments. This skill owns everything else: the survey, the inventory, its axes, the output rules, the report contract, and the commit.

## When to use

Run this when the operator wants to know what is open and where to start. Four cases it is not for, and what replaces it:

- **One task, already chosen.** Open the iteration with `/iter`. A check-in named the task in an earlier turn.
- **A record audit on its own.** Dispatch [`roadmap-maintenance`](../roadmap-maintenance.md) or [`handover-maintenance`](../handover-maintenance.md) directly. This skill runs both only on the thoroughness argument.
- **Which work runs without the operator.** [`/backlog-triage.md`](../../prompts/backlog-triage.md) answers that narrower question. This skill reports what is open, not what is dispatchable.
- **A milestone boundary.** `/milestone-start` and `/milestone-close` own those.

## Scope

The only record change a check-in may make is a fix whose correct form the tree or the policy determines. It applies those, aggregates them into a single `chore:` commit, and opens no handover. Every other change waits for the operator to pick the next task.

## Arguments

Two are read from the prompt's `$@`.

- **Thoroughness.** The words `be thorough`, `deep dive` and `full audit` are one argument with three spellings. It turns on the exhaustive check.
- **Intent.** Any other argument filters the inventory.

Without a thoroughness word this skill never opens the auditor references and never dispatches an auditor. With it, the exhaustive check runs before the inventory is presented.

## Survey

The survey reads state; it does not repair it. Apply the repository's read discipline: grep to locate, then read the needed sections. Do not open files wholesale beyond what the survey needs.

- Handover chain: the latest file in `devlog/handovers/` -- highest date and index in the filename. Read its status, findings and deferred items.
- Roadmap: `devlog/roadmap.md`. Read the `active-milestone` frontmatter field, that milestone's section, and its open items. Check done items for forward-looking text left behind.
- Recent git history (`git log --oneline -20`): what landed, and the time gap since the last iteration.
- Open entries in `devlog/AGENT_FEEDBACK.md` -- states `open` and `probation`, both `[A]` (agent-raised) and `[O]` (operator-raised) tags.
- Stale-state sweep: `git status`, `git stash list`, `git branch` -- uncommitted changes, stashes, leftover branches.
- Settled design docs in `devlog/discussions/` with no implementation handover referencing them yet.

Surface discrepancies, do not fix them: an open roadmap item whose work already landed on disk; a done item still carrying forward-looking text; a finding marked open whose fix landed; a feedback entry describing files that no longer exist; a test suite whose last recorded run is red or stale. Each becomes an inventory row or a finding, never a silent correction.

The fixes this skill may apply are the ones the exhaustive check returns with a `fix-now` recommendation, plus any determinable record fix the survey itself turns up. Everything else is surfaced and waits.

## Inventory

One row per open work item.

| Item | Type | Size | Progress | Impact | Verification |
|---|---|---|---|---|---|
| `<work item>` -- `<roadmap entry, handover, or feedback entry that names it>` | impl | small | deferred, no pickup date | degrading | offline `make test` |

The axes below are this skill's to define. `/milestone-start` grades its audited pool on the same axes, and reads them here.

- Item -- the work, plus the record that names it (roadmap entry, handover, feedback entry).
- Type -- impl (build or fix code), design, chore (housekeeping), investigation, doc.
- Size -- how much of one iteration it fills: small, medium, large.
- Progress -- where it sits in the work sequence: closes the active sub-milestone / gates other planned tasks / urgent housekeeping (misleads or blocks others until fixed) / write-back (record text is stale vs the tree) / deferred, no pickup date.
- Impact -- the severity axis: how bad the consequence of leaving the work undone. `blocking` -- correctness, security or data loss, or a gate that lets a break through, so the cost of delay is a wrong action taken now. `degrading` -- drift, recurring pain, or cost that grows with delay: the record misleads, the workaround spreads. `cosmetic` -- wording, layout, or record text with no effect on a decision or an action.
- Verification -- how its acceptance is checked: offline `make test` / needs docker / needs operator involvement.

Fill every field from the records already read during the survey. If a field cannot be filled without new investigation, write `unclear` and add the investigation itself as an inventory row. Do not run investigations during a check-in.

**A record defect is not a row.** A row whose Progress is `write-back` or whose Impact is `cosmetic` names a record defect, not work, so it does not become a row. The check-in counts them in one line and reports that count without listing them.

## The exhaustive check

Run this only when the thoroughness argument is present.

1. Dispatch `roadmap-maintenance` and `handover-maintenance` as subagents, using the template in [`auditor-invocation.md`](auditor-invocation.md). Each returns one JSONL report at the path the template sets, outside the repository tree.
2. Aggregate the two files. Read every line and validate it against [`report-schema.md`](report-schema.md): the required fields, the value sets, and the `deferTo` requirement on a `defer`.
3. Inspect each finding before acting on it, as `no-comments` step 2 inspects a `comment-sicko` report. Reject a finding that misstates the record, a `defer` that names no existing roadmap unit, and a flag that names nothing. Do not restore a finding the auditor got right to reject.
4. Apply the `fix-now` findings.

A rejected finding is reported, not silently dropped.

## Applying findings

The auditor recommends; this skill disposes. The report names no commit, no message and no fold, and this skill decides how each fix lands.

| `recommendation` | Meaning | Action |
|---|---|---|
| `fix-now` | determinable from the tree or the policy, and bounded to a record edit | apply it; it rides the single `chore:` commit |
| `defer` | determinable, and an existing roadmap unit already names the broader task this belongs to | nothing. The named unit owns it; clearing it ahead of that pass is premature. A `defer` entry with no named unit is rejected. |
| `escalate` | two sources disagree, or a value cannot be re-derived | present it as a point below the table, never as a row |

A compaction carries the survival table [`roadmap_policy.md`](../../../../docs/operations/roadmap_policy.md#compaction-cascading) names. A closed record's fix carries the `[CORRECTION]` block its policy requires. Folding a fix does not license dropping the form that fix must take.

This skill makes the one `chore:` commit, in the main tree, after the auditors return -- never a subagent, and never one commit per finding. Neither auditor is told to commit.

## Output rules

- No inventory row carries Progress `write-back` or Impact `cosmetic`.
- A `defer` finding adds no row and no point.
- The three closing suggestions draw only from work items. A record defect is never one of them.

## State summary

Two or three lines before the inventory: the active milestone, the time gap since the last iteration and what landed during it, and whether the tree is at a clean stopping point. After a break, name the big changes the operator has not seen.

## Close

If an intent was provided, filter the inventory by it, recommend one starting task, and say why it fits. If the argument already fixes a specific task, say the direction is set and the next step is opening the iteration.

If no intent was provided, do not assume one. Suggest work along the intents actually present in the inventory:

- easiest start -- smallest Size, offline Verification; re-entry after a break.
- highest leverage -- Progress `gates other planned tasks`: the least complex task that unblocks the most downstream work. When a large task needs prefactors, suggest the prefactor, not the large task: tasks land in sequence, and the prefactor comes first.
- most urgent -- Impact `blocking`, or `degrading` where the cost grows with delay.

A record defect carries no Impact grade and is never one of the three. Severity on a record finding is expressed as its recommendation: a severe finding escalates.

Recommendations respect landing order in every case: a prefactor is suggested before the task that needs it.

Present the `escalate` points apart from the table, each naming what the record asserts, what the tree shows, and what has to be chosen.

Then ask which direction to take. Stop there; no work begins before the operator picks a scope.

## Non-goals

- Does not open, re-scope or close an iteration.
- Does not open a handover.
- Does not apply a fix whose correct form neither the tree nor the policy determines.
- Does not restate the report schema or the auditors' checks. Both are owned elsewhere: the schema here in its reference, the checks in the auditors.

## Failure modes

- **A missing report reads as a clean record.** An auditor that returned no file, an empty file, or a non-conforming line has failed its dispatch. Report the failure with the auditor named; never treat a missing report as a clean run.
- **A `defer` with no named unit becomes a row.** The recommendation exists so the dispatcher writes nothing back. Reject a `defer` that names no existing roadmap unit rather than turning it into a task.
- **A folded fix drops the form its policy requires.** A compaction without its survival table, or a closed record's fix without its `[CORRECTION]` block, leaves the record worse than the finding did. The policy, not the fold, decides the form.
- **An auditor's finding is applied unchecked.** A reporter can be confidently wrong, and a folded fix asserts a fact into a record. Inspect each entry first.
- **The intents are graded from memory.** Every field is filled from a record read this run. A field that needs new investigation becomes an inventory row, not a guess.
