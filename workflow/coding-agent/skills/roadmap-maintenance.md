---
name: roadmap-maintenance
description: "Checks devlog/roadmap.md, devlog/roadmap_future.md and devlog/changelog.md against roadmap_policy.md and reports the violations. Use when the operator asks to check the roadmap against policy or verify compaction state. Writes nothing."
---

# roadmap-maintenance

<!-- Source: this skill subsumed workflow/coding-agent/audits/roadmap-audit.skill.md, now removed. Steps 1 to 4 carry that file's checks A to D unchanged, and Step 5 reports the run. The skill was made report-only by handover 20261004-10, which took back the part of commit c1bc00e that made a maintenance run write its corrections: the checks stay, the write authority leaves, and no audit file is restored. -->

## Purpose

Checks the three roadmap records -- `devlog/roadmap.md`, `devlog/roadmap_future.md` and `devlog/changelog.md` -- and reports the violations of [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md). The run finds each violation and reports it in the form the dispatcher consumes. It writes no record, applies no correction, and invents no fact.

The three files are one record: a milestone title, a status, or an anchor that disagrees across them is the same violation whichever side of the boundary it sits on. `devlog/roadmap.md` carries the active and upcoming milestones, `devlog/roadmap_future.md` the milestones staged for promotion, and `devlog/changelog.md` the milestones already closed.

The transition procedures live in [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) -- the compaction cascade and the top-level close. This runbook owns the checks and the schedule that runs them; the policy owns the invariants those checks protect. A check stated here restates no rule the policy carries, and a rule the policy carries is never restated here.

The handover is not the subject. Handover content and handover chain checks belong to [`handover-maintenance.md`](handover-maintenance.md).

## When to run

The schedule follows access rather than a calendar: a run checks a record when a run reads it.

| Record | When it is checked |
|---|---|
| `devlog/roadmap.md` | Every iteration open and close, because an iteration reads and writes it. |
| `devlog/roadmap_future.md` | When a milestone promotion reads it to choose and move the next milestone, before the operator's promotion decision. |
| `devlog/changelog.md` | When a milestone close reads it to append its entry. |

The operator may also trigger a read of `devlog/roadmap_future.md` and `devlog/changelog.md` at any time, as a carve-out from the access rule, so a stale record never waits for a promotion that may not come.

Also run it:

- Before a compaction pass, to report whether the pass is safe (Step 4).
- When the operator asks to check the records against `roadmap_policy.md`.

Do not run it as a closed-history sweep over the records. A compacted roadmap has, by design, dropped the detail this runbook checks, and a closed changelog entry is a historical claim about what was true when its milestone closed. That exclusion is an exception clause: report it as a skip with the clause named, never as a finding.

## Procedure

### Step 1 - Format compliance

Run through every task entry in the active sub-milestone.

**1.1 Marker format.** Every item uses markdown task list syntax (`- [x]` or `- [ ]`), not an emoji checkmark and not a bold header alone. Report an unconverted item.

**1.2 Nesting format.** Sub-items are indented `- [x]` and `- [ ]` bullets, not embedded in a prose paragraph. Report a prose-wrapped sub-item.

**1.3 Partial completion format.** For an item that has both done and pending sub-items, the parent item uses `- [ ]` and describes what is complete, the completed sub-items use `- [x]` indented under the parent, and the pending sub-items use `- [ ]` indented under the parent. An item is a violation when a done sub-item lacks its `- [x]` marker, or when the parent carries no completion context.

Completion criterion: no unconverted marker was found, no sub-item sits inside prose, and every partially complete parent describes what is complete.

### 1.4 A closed item carries no open work

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `## When the Roadmap Is Touched` owns the marker-nesting invariant. This check applies it.

**Check.** Walk every `- [x]` item and read its indented children. Report any open child and the parent that carries it, naming the completion context the parent is missing.

**Why this exists.** The task list is scanned for `- [ ]` at the parent level, so a closed parent holding open work reads as done.

Completion criterion: 1.1 through 1.4 hold, and no `- [x]` item carries an open child.

### Step 2 - Compaction compliance

Run this step over each item in the active sub-milestone.

**2.1 Completion-state compaction.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) [Compaction cascading](../../../docs/operations/roadmap_policy.md#compaction-cascading) owns the procedure and is its single source. This check verifies its result: a fully completed group that still carries an expanded checklist is uncompacted, and is reported.

**2.2 Outcome summary marker.** The `- [x]` marker survives the compaction. A compacted item without the marker is reported.

**2.3 Survival table.** Verify each compacted task group against the keep and remove lists in [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) [Compaction cascading](../../../docs/operations/roadmap_policy.md#compaction-cascading) step 1, component by component.

| Component | Expected | Check |
|---|---|---|
| Design document links | Survive | Present when the item had one |
| Not-in-scope and deferred tags | Survive | Present when the item had them |
| File lists in parentheses after the item name | Removed | Absent from the header |
| Implementation notes and partial specs | Removed | Absent from the summary |
| Sub-item checklists and task breakdowns | Removed | Absent from the summary |
| "Depends on" pointing at a now-completed item | Removed | Absent from the summary |
| "Prerequisite for" | Removed | Absent from the summary |

A component that should survive and is gone, or one that should be removed and is present, is a violation in either direction. A compaction reported under 2.1 names this table as the form the edit must take.

**2.4 Multi-level compaction depth.** Step 2 of [Compaction cascading](../../../docs/operations/roadmap_policy.md#compaction-cascading) owns the upward pass. A parent whose children are all done and that is not compacted is reported.

**2.5 Nested sub-group compaction.** The same step, read at sub-group grain. An expanded sub-group inside a partially complete item is reported.

Completion criterion: no expanded checklist survives under a fully completed group, and every compaction satisfies the survival table.

### Step 3 - Structural integrity

**3.1 Floating prose summaries.** Report a manual summary such as "Prior completed items" that repeats the task list.

**3.2 Superseded items.** Report an item that later work superseded and that still stands.

**3.3 Empty sections.** Report a section that Step 3.2 or Step 2 emptied. `roadmap_policy.md` requires removal rather than an empty heading.

**3.4 Redundant ordering blocks.** Report a standalone "Implementation order" block that repeats information already carried by "Depends on" lines.

**3.5 Dangling dependencies.** Report a "Depends on" line on an active item that points at a removed or compacted item.

**3.6 Landed narrative in a closed row.** Report a closed row that has not been reduced to one line of what landed plus a handover link. The implementation narrative and the counts are in the handover, which already records them. A number in a closed row is true exactly once, so a suite count or a version literal recorded there goes stale at the next change.

**3.7 Related rows that are one task.** Report rows that share an owner, a bar and a subject, keeping each subtask's handover link. Two tell-tales: the same work described in different words, and one subject split across several rows with no owner distinguishing them.

**3.8 A row that restates a known entry.** Report a row whose first half is already recorded elsewhere, unless it names what is new.

**3.9 A row bundling unrelated defects.** Report a row carrying its own priority order in its own text -- a bucket, not a task.

**3.10 Mis-filed rows.** A row belongs in the milestone whose section blurb claims the work. Report a row that sits elsewhere while a blurb claims it. When no blurb claims it, the milestone scope is wrong, and that is an operator call: report it as an escalation, not a move.

### 3.11 The summary table agrees with the sections it names

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Summary table update` owns it; the check below applies it.

**Check.** For each row, read the linked heading and the status it declares. A row that says `Complete` whose section still carries open tasks is a finding; a row whose fragment matches no heading is a finding; two records naming one milestone differently are a finding.

**Why this exists.** The table is what a reader consults instead of the sections, so a row that disagrees with its section is worse than no table.

### 3.12 No item is restated across the records

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Filing rules` owns it. This check adds the record-layer case that rule does not name.

**Check.** For each open row and each closed row in the active milestone, search the other file for the same subject. Two rows describing one piece of work, in different words or with different boundaries, are one finding: name the duplicate and name the copy that sits under the milestone whose blurb claims the work.

**Why this exists.** A copy in `changelog.md` of a row still open in a roadmap file slips past a check that reads only the two roadmap files.

### 3.13 A row states no fact the tree can falsify

**Rule.** A row names no line number, no row number in another file, and no version literal. Numbers that go stale are held in the record they belong to: the handover, the report, or the file itself. A row that must name a literal names the file that owns it, so a reader re-derives the value.

**Check.** Search each row for `\d+`, a `line \d+` or `row \d+` form, a version string, and a path that no longer exists. A row pointing at a sibling record by position rather than by name is a finding, because the position moves with every edit above it.

**Why this exists.** A number in a record is true exactly once, and the pass that found these had two open rows pointing at roadmap rows that no longer held the work they named.

### 3.14 The write-back pairing is not this run's to state

Not a check. A landed row naming the handover that landed it is not a rule in any policy; `iteration_policy.md` `### Close invariants` owns the write-back step. When a landed claim is not reflected in its row, the finding belongs to the close that let it through.

### 3.15 The changelog section map is unambiguous

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Entry structure` and `## Corrections to Closed Roadmap and Changelog Entries` own the heading levels and the correction forms.

**Check.** Read the `##` headings of `changelog.md` in order. Any `##` that is not `## M{n}` is a finding. Any summary link whose fragment names a correction block is a finding.

### 3.16 A new entry states whether its capability still stands

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Writing guidance` and `## Corrections to Closed Roadmap and Changelog Entries` own it.

**Check.** For each entry written or amended in this run, read the summary row that links it. A row reading `Complete` for an entry that records removal is a finding.

**Scope.** Only the section this run wrote or amended. Entries closed earlier are historical claims about what was true when they closed, and this check does not reach them.

### 3.17 A new entry carries no fact the tree can falsify

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Writing guidance` owns it.

**Check.** For the section this run wrote, search for paths, version strings and line numbers.

**Scope.** Only the section this run wrote. An older entry that names a path which no longer exists is true history, and correcting it rewrites the past into the present tense.

### 3.18 A superseded entry says so where a reader will see it

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `## Corrections to Closed Roadmap and Changelog Entries` owns it. The anchor consequence is why the rule exists.

**Check.** For each entry whose capability a later milestone removed, read the entry's opening. A suffix on the milestone heading, or a supersession sentence with no date, is a finding.

**Why this exists.** The marker is what a reader consults, so a supersession recorded only in prose is invisible at the milestone heading.

Completion criterion: every violation of 3.1 through 3.13 and 3.15 through 3.18 is reported, and no report restates a rule the policy carries.

### Step 4 - Pre-compaction readiness

This step reports whether a compaction pass is safe to propose.

1. Every task in a group that is a compaction candidate is `- [x]`, not `- [ ]`.
2. No task was marked `- [x]` before the operator verified it. Read the handover's Step 7 acceptance-criteria status.
3. The compaction proposal text is drafted and ready for operator review.

Completion criterion: all three hold, or the report names the failing condition. A premature `- [x]` blocks the pass until the operator resolves it, and is reported as an escalation.

### Step 5 - Report the run

Write the report as JSONL at the path the dispatcher set, in the schema [`workflow/coding-agent/skills/check-in/report-schema.md`](check-in/report-schema.md) owns. One line per finding; one line per check that produced no finding, with `result` and `reason`.

Four rules bound what a run may report.

**A finding is the smallest statement that clears the check.** Name the locus, the rule, and what the record asserts against what the tree or the policy shows. Do not restate the record's prose, and do not propose the whole rewrite: the dispatcher reads the policy rule for the form, and a compaction is reported against the survival table rather than as replacement text.

**A finding carries its evidence.** Report the tree read that produced it -- the path, the grep, the count -- so the operator can check the claim without re-running the pass. A claim about the state of a record is a hypothesis until a command confirms it, and a reviewer's claim is a hypothesis until the command confirms it too. Disagreement resolves by command, not by another round.

**A finding names only facts this run re-read.** Every path, id, count and version in a report is read from the tree in the same run that reports it. Where the tree and the record disagree, the finding says which one is wrong.

**The recommendation follows the check, not the size of the edit.** A violation whose correct form the policy determines is fixable now, however many rows it touches. A violation that falls under a broader roadmap unit already in flight names that unit and waits for it. A violation where two sources disagree, or where a value cannot be re-derived, is one no record settles. The schema passed with this dispatch carries the values and their conditions.

Report the checks that produced no finding as skips. A check that did not run is reported as a skip with that reason: silence reads as a clean record.

## Output shape

The report is the JSONL file described in [`workflow/coding-agent/skills/check-in/report-schema.md`](check-in/report-schema.md), written at the path the dispatcher sets, outside the repository tree. It is never committed.

Print a one-line summary to stdout when the run ends: the findings count, the skip count, and the path. A finding count of zero is reported as zero, never as silence.

## Non-goals

- Does not write a record, apply a correction, or commit. The dispatcher applies the report.
- Does not check handovers or the handover chain. That is [`handover-maintenance.md`](handover-maintenance.md).
- Does not write policy. A check that no policy text covers is a gap to report, not a rule to add here.
- Does not open, re-scope, or close an iteration.
- Does not change a milestone's task set. Adding or removing a task is a roadmap decision, not a maintenance finding.
- Does not choose a commit shape, a message, or a fold. The report carries no field for one.

## Failure modes

- **A passed check reported as silence.** A run that reports no skip for a check it did not run reads as a clean record. Report the skip.
- **A premature `- [x]` reads as a finished group.** Step 4 reports it as an escalation; a compaction proposal resting on it is unsafe until the operator resolves it.
- **A finding that drops surviving detail.** A compaction reported without the survival table loses the guard the policy keeps. Name the table.
- **Scope creep into task content.** A finding that would add a task turns maintenance into a roadmap decision. Report the need as an escalation instead.
- **Interpretation of a policy gap.** When a finding needs a reading of `roadmap_policy.md` that the document does not settle, state the reading and report it as an escalation rather than choosing for the operator.
