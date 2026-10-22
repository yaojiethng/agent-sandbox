---
name: roadmap-maintenance
description: "Checks devlog/roadmap.md, devlog/roadmap_future.md and devlog/changelog.md against the task-list convention and the transition procedures below, and reports the violations. Use when the operator asks to check the roadmap against the convention or verify compaction state. Writes nothing."
---

# roadmap-maintenance

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `task-list` - the task list and its companions.

## Purpose

Checks the task list -- `devlog/roadmap.md`, `devlog/roadmap_future.md` and `devlog/changelog.md` -- and reports the violations of the project's `task-list` convention and of the transition procedures below.

## When to run

The dispatcher sets the moment: `/iter`, `/wrapup`, `/milestone-close` and `/milestone-start` each run this advisor at the step that reads the record, and the operator may invoke it at any time. Run it before a compaction pass, to report whether the pass is safe (Step 4). Do not run it as a closed-history sweep; report that exclusion as a skip with the clause named, never as a finding.

## Who runs the procedures these checks protect

| Grain | Procedure | Owner |
|---|---|---|
| Task | when every sub-row of a task is resolved, the task item compacts to an outcome summary | [`/wrapup`](/opt/workflow/agent/modules/coding-agent/prompts/wrapup.md), at the iteration close |
| Sub-milestone and above | the sub-milestone compacts to a paragraph, the cascade travels upward, the summary table updates, and a full top-level close writes the changelog entry and promotes the next milestone | [`/milestone-close`](/opt/workflow/agent/modules/coding-agent/prompts/milestone-close.md) |

A check below names the owner it tests and restates none of them.

## Procedure

### Step 1 - Format compliance

Run through every task entry in the active sub-milestone.

**1.1 Marker format.** Every item uses markdown task list syntax (`- [x]` or `- [ ]`), not an emoji checkmark and not a bold header alone. Report an unconverted item.

**1.2 Nesting format.** Sub-items are indented `- [x]` and `- [ ]` bullets, not embedded in a prose paragraph. Report a prose-wrapped sub-item.

**1.3 Partial completion format.** For an item with both done and pending sub-items, the parent uses `- [ ]` and describes what is complete, and the done (`- [x]`) and pending (`- [ ]`) sub-items sit indented under it. Report a done sub-item without its `- [x]` marker, or a parent that carries no completion context.

**1.4 A closed item carries no open work.** Walk every `- [x]` item's indented children. Report any open child and the parent that carries it, naming the completion context the parent is missing. The project's `task-list` convention, The record's shape, owns the marker-nesting invariant.

Completion criterion: 1.1 through 1.4 hold.

### Step 2 - Compaction compliance

Run this step over each item in the active sub-milestone.

**2.1 Completion-state compaction.** The `/milestone-close` compaction procedure owns the rule; this check verifies its result. A fully completed group that still carries an expanded checklist is uncompacted and is reported.

**2.2 Outcome summary marker.** The `- [x]` marker survives the compaction. Report a compacted item without the marker.

**2.3 Survival table.** Verify each compacted task group against the keep and remove lists in the `/milestone-close` compaction procedure, step 1, component by component.

| Component | Expected | Check |
|---|---|---|
| Design document links | Survive | Present when the item had one |
| Not-in-scope and deferred tags | Survive | Present when the item had them |
| File lists in parentheses after the item name | Removed | Absent from the header |
| Implementation notes and partial specs | Removed | Absent from the summary |
| Sub-item checklists and task breakdowns | Removed | Absent from the summary |
| "Depends on" pointing at a now-completed item | Removed | Absent from the summary |
| "Prerequisite for" | Removed | Absent from the summary |

A component that should survive and is gone, or one that should be removed and is present, is a violation. A compaction reported under 2.1 names this table as the form the edit must take.

**2.4 Multi-level compaction depth.** Step 2 of the `/milestone-close` compaction procedure owns the upward pass. Report a parent whose children are all done and that is not compacted.

**2.5 Nested sub-group compaction.** The same step, read at sub-group grain. Report an expanded sub-group inside a partially complete item.

### Step 3 - Structural integrity

**3.1 Floating prose summaries.** Report a manual summary such as "Prior completed items" that repeats the task list.

**3.2 Superseded items.** Report an item that later work superseded and that still stands.

**3.3 Empty sections.** Report a section that 3.2 or Step 2 emptied. The `task-list` convention requires removal rather than an empty heading.

**3.4 Redundant ordering blocks.** Report a standalone "Implementation order" block that repeats information already carried by "Depends on" lines.

**3.5 Dangling dependencies.** Report a "Depends on" line on an active item that points at a removed or compacted item.

**3.6 Landed narrative in a closed row.** Report a closed row that has not been reduced to one line of what landed plus a handover link. The implementation narrative and the counts live in the handover. A number in a closed row is true exactly once, so a suite count or version literal there goes stale at the next change.

**3.7 Related rows that are one task.** Report rows that share an owner, a bar and a subject, keeping each subtask's handover link. Tell-tales: the same work described in different words, and one subject split across several rows with no owner distinguishing them.

**3.8 A row that restates a known entry.** Report a row whose first half is already recorded elsewhere, unless it names what is new.

**3.9 A row bundling unrelated defects.** Report a row carrying its own priority order in its own text -- a bucket, not a task.

**3.10 Mis-filed rows.** A row lands in the active sub-milestone's task list unless the operator directs otherwise. The project's `task-list` convention, Filing rules, `**Roadmap task placement**`, owns the default. Report a row that sits elsewhere, and report the operator direction when one exists; a track's blurb is not a direction, and the subject of a track claims no row.

**3.11 The summary table agrees with the sections it names.** For each row, read the linked heading and the status it declares. A row that says `Complete` whose section still carries open tasks is a finding; a row whose fragment matches no heading is a finding; two records naming one milestone differently are a finding. The `/milestone-close` `## Update the records` step 1 owns that rule.

**3.12 No item is restated across the records.** For each open row and each closed row in the active milestone, search the other file for the same subject. Two rows describing one piece of work, in different words or with different boundaries, are one finding: name the duplicate and the copy that the placement default does not claim. The project's `task-list` convention, Filing rules, owns that rule. A copy of a row still open, in another record, is the case that rule does not name.

**3.13 A row states no fact the tree can falsify.** Search each row for `\d+`, a `line \d+` or `row \d+` form, a version string, and a path that no longer exists; a row names no line number, no row number in another file, and no version literal. Numbers that go stale live in the record they belong to -- the handover, the report, or the file itself. A row pointing at a sibling record by position rather than by name is a finding, because the position moves with every edit above it. A row that must name a literal names the file that owns it, so a reader re-derives the value.

**3.15 The changelog reads clean.** Read `devlog/changelog.md` once and report:

1. **The section map is unambiguous.** Read the `##` headings in order. A `##` that is not `## M{n}` is a finding, and so is a summary link whose fragment names a correction block.
2. **An entry written this run states whether its capability still stands.** Read the summary row that links it. A row reading `Complete` for an entry that records removal is a finding.
3. **An entry written this run carries no fact the tree can falsify.** Search for paths, version strings and line numbers.
4. **A superseded entry says so where a reader will see it.** For each entry whose capability a later milestone removed, read the entry's opening. A suffix on the milestone heading, or a supersession sentence with no date, is a finding.

Parts 2 and 3 read only the section this run wrote or amended; an entry closed earlier is a historical claim about what was true when it closed. The project's `task-list` convention, The changelog entry and Corrections to a closed entry, own these rules.

### Step 4 - Pre-compaction readiness

1. Every task in a group that is a compaction candidate is `- [x]`, not `- [ ]`.
2. No task was marked `- [x]` before the operator verified it. Read the handover's Step 7 acceptance-criteria status.
3. The compaction proposal text is drafted and ready for operator review.

Completion criterion: all three hold, or the report names the failing condition. A premature `- [x]` blocks the pass until the operator resolves it, and is reported as an escalation.

### Step 5 - Report the run

Write the report as JSONL at the path the dispatcher set, in the schema [`check-in/report-schema.md`](/opt/workflow/agent/modules/coding-agent/skills/check-in/report-schema.md) owns. One line per finding; one line per check that produced no finding, with `result` and `reason`. Four rules bound what a run may report.

**A finding is the smallest statement that clears the check.** Name the locus, the rule, and what the record asserts against what the tree or the convention shows. Do not propose the whole rewrite: the dispatcher reads the rule for the form, and a compaction is reported against the survival table, not as replacement text.

**A finding carries its evidence.** Report the tree read that produced it -- the path, the grep, the count -- so the operator can check the claim without re-running the pass. A claim about the state of a record is a hypothesis until a command confirms it, and a reviewer's claim too. Disagreement resolves by command, not by another round.

**A finding names only facts this run re-read.** Every path, id, count and version in a report is read from the tree in the same run that reports it. Where the tree and the record disagree, the finding says which one is wrong.

**The recommendation follows the check, not the size of the edit.** A violation whose correct form the convention or the `/milestone-close` procedures determine is fixable now, however many rows it touches. A violation under a broader roadmap unit already in flight names that unit and waits for it. A violation where two sources disagree, or where a value cannot be re-derived, is an escalation: no record in this set settles it. The schema passed with this dispatch carries the values and their conditions.

Report each check with no finding as a skip, and a check that did not run as a skip with that reason: silence reads as a clean record.

Completion criterion: the report is written at the dispatcher's path, and every check carries a line with either a finding or a skip.

## Output shape

Print a one-line summary to stdout when the run ends: the findings count, the skip count, and the path. A finding count of zero is reported as zero, never as silence.

## Non-goals

- Does not write a record, apply a correction, or commit. The dispatcher applies the report.
- Does not check handovers or the handover chain. That is [`handover-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/handover-maintenance/SKILL.md).
- Does not write policy. A check that no policy text covers is a gap to report, not a rule to add here.
- Does not open, re-scope, or close an iteration.
- Does not change a milestone's task set. Adding or removing a task is a roadmap decision, not a maintenance finding.
- Does not choose a commit shape, a message, or a fold. The report carries no field for one.

## Failure modes

Every failure mode is a rule already stated in Steps 4 and 5 or in Non-goals. Report it; do not restate it.
