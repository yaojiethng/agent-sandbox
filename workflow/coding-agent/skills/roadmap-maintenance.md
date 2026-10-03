---
name: roadmap-maintenance
description: "Maintains devlog/roadmap.md and leaves it correct. Use when the operator asks to check the roadmap against policy, verify compaction state, or prepare a compaction pass."
---

# roadmap-maintenance

<!-- Source: this skill subsumed workflow/coding-agent/audits/roadmap-audit.skill.md, now removed. Steps 1 to 4 carry that file's checks A to D unchanged; Step 5 carries the correction pass it deliberately lacked. -->

## Purpose

Maintains the three roadmap records: `devlog/roadmap.md`, `devlog/roadmap_future.md` and `devlog/changelog.md`. The run finds each defect, corrects it, and records what it changed, so the records are correct when the run ends. An audit only reports and leaves the defect in place. This runbook therefore corrects what it finds and holds back only what needs the operator's judgement.

The three files are one record: a milestone title, a status, or an anchor that disagrees across them is the same defect whichever side of the boundary it sits on. `devlog/roadmap.md` carries the active and upcoming milestones, `devlog/roadmap_future.md` the milestones staged for promotion, and `devlog/changelog.md` the milestones already closed.

The transition procedures live in [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) -- the compaction cascade and the top-level close -- and the milestone prompts invoke them. This runbook owns the coherence checks and the schedule that runs them; the policy owns the invariants those checks protect. A check stated here restates no rule the policy carries, and a rule the policy carries is never restated here.

The handover is not the subject. Handover content and handover chain maintenance belong to [`handover-maintenance.md`](handover-maintenance.md).

## When to run

The schedule follows access rather than a calendar: a run checks a record when a run reads it.

| Record | When it is checked |
|---|---|
| `devlog/roadmap.md` | Every iteration open and close, because an iteration reads and writes it. |
| `devlog/roadmap_future.md` | When a milestone promotion reads it to choose and move the next milestone, before the operator's promotion decision. |
| `devlog/changelog.md` | When a milestone close reads it to append its entry. |

The operator may also trigger a read of `devlog/roadmap_future.md` and `devlog/changelog.md` at any time, as a carve-out from the access rule, so a stale record never waits for a promotion that may not come.

Also run it:

- Before a compaction pass, to confirm the pass is safe (Step 4).
- When the operator asks to check the records against `roadmap_policy.md`.

Do not run it as a closed-history sweep over the records. A compacted roadmap has, by design, dropped the detail this runbook checks, and a closed changelog entry is a historical claim about what was true when its milestone closed.

## Procedure

### Step 1 - Format compliance

Run through every task entry in the active sub-milestone.

**1.1 Marker format.** Every item uses markdown task list syntax (`- [x]` or `- [ ]`), not an emoji checkmark and not a bold header alone. Convert an unconverted item.

**1.2 Nesting format.** Sub-items are indented `- [x]` and `- [ ]` bullets, not embedded in a prose paragraph. Restructure a prose-wrapped sub-item into bullets.

**1.3 Partial completion format.** For an item that has both done and pending sub-items, the parent item uses `- [ ]` and describes what is complete, the completed sub-items use `- [x]` indented under the parent, and the pending sub-items use `- [ ]` indented under the parent. An item is a defect when a done sub-item lacks its `- [x]` marker, or when the parent carries no completion context.

Completion criterion: no unconverted marker remains, no sub-item sits inside prose, and every partially complete parent describes what is complete.

### 1.4 A closed item carries no open work

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `## When the Roadmap Is Touched` owns the marker-nesting invariant. This check applies it.

**Check.** Walk every `- [x]` item and read its indented children. Report any open child and the parent that carries it.

**Correction.** Flip the parent to `- [ ]` and write the completion context the parent is missing, so a reader scanning task level sees what is still open.

**Why this exists.** The task list is scanned for `- [ ]` at the parent level, so a closed parent holding open work reads as done.

Completion criterion: 1.1 through 1.4 hold, and no `- [x]` item carries an open child.

### Step 2 - Compaction compliance

Run this step over each item in the active sub-milestone.

**2.1 Completion-state compaction.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) [Compaction cascading](../../../docs/operations/roadmap_policy.md#compaction-cascading) owns the procedure and is its single source. This check verifies its result: compact a fully completed group that still carries an expanded checklist.

**2.2 Outcome summary marker.** The `- [x]` marker survives the compaction. A compacted item without the marker is a defect.

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

A component that should survive and is gone, or one that should be removed and is present, is a defect in either direction.

**2.4 Multi-level compaction depth.** Step 2 of [Compaction cascading](../../../docs/operations/roadmap_policy.md#compaction-cascading) owns the upward pass. Compact a parent whose children are all done.

**2.5 Nested sub-group compaction.** The same step, read at sub-group grain. Compact an expanded sub-group inside a partially complete item.

Completion criterion: no expanded checklist survives under a fully completed group, and every compaction satisfies the survival table.

### Step 3 - Structural integrity

**3.1 Floating prose summaries.** Remove a manual summary such as "Prior completed items" that repeats the task list.

**3.2 Superseded items.** Remove an item that later work superseded.

**3.3 Empty sections.** Remove a section that Step 3.2 or Step 2 emptied. `roadmap_policy.md` requires removal rather than an empty heading.

**3.4 Redundant ordering blocks.** Remove a standalone "Implementation order" block that repeats information already carried by "Depends on" lines.

**3.5 Dangling dependencies.** Remove a "Depends on" line on an active item that points at a removed or compacted item, or repoint it at the surviving item.

**3.6 Landed narrative in a closed row.** Reduce a closed row to one line of what landed plus a handover link. The implementation narrative and the counts are in the handover, which already records them. A number in a closed row is true exactly once, so a suite count or a version literal recorded there goes stale at the next change.

**3.7 Related rows that are one task.** Merge rows that share an owner, a bar and a subject into one parent carrying them as subtasks, keeping each subtask's handover link. Two tell-tales: the same work described in different words, and one subject split across several rows with no owner distinguishing them.

**3.8 A row that restates a known entry.** Move it to the record that already holds the problem and keep only the delta. A row whose first half is already recorded elsewhere earns nothing unless it names what is new.

**3.9 A row bundling unrelated defects.** Split it. A row carrying its own priority order in its own text is a bucket, not a task.

**3.10 Mis-filed rows.** A row belongs in the milestone whose section blurb claims the work. If a blurb claims it and it sits elsewhere, move it. If no blurb claims it, the milestone scope is wrong, and that is an operator call, not a move.

### 3.11 The summary table agrees with the sections it names

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Summary table update` owns it; the check below applies it.

**Check.** For each row, read the linked heading and the status it declares. A row that says `Complete` whose section still carries open tasks is a finding; a row whose fragment matches no heading is a finding; two records naming one milestone differently are a finding.

**Correction.** Repoint the link, align the title, and set the status from the section. A milestone staged in `roadmap_future.md` takes its row there; a closed one takes a changelog link.

**Why this exists.** The table is what a reader consults instead of the sections, so a row that disagrees with its section is worse than no table.

### 3.12 No item is restated across the records

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Filing rules` owns it. This check adds the record-layer case that rule does not name.

**Check.** For each open row and each closed row in the active milestone, search the other file for the same subject. Two rows describing one piece of work, in different words or with different boundaries, are one finding: name the duplicate, keep one, and make the other name it.

**Correction.** Keep the copy that sits under the milestone whose blurb claims the work, and reduce the other to a named pointer. Two rows that share an owner, a bar and a subject merge into one parent carrying both as subtasks.

**Why this exists.** A copy in `changelog.md` of a row still open in a roadmap file slips past a check that reads only the two roadmap files.

### 3.13 A row states no fact the tree can falsify

**Rule.** A row names no line number, no row number in another file, and no version literal. Numbers that go stale are held in the record they belong to: the handover, the report, or the file itself. A row that must name a literal names the file that owns it, so a reader re-derives the value.

**Check.** Search each row for `\d+`, a `line \d+` or `row \d+` form, a version string, and a path that no longer exists. A row pointing at a sibling record by position rather than by name is a finding, because the position moves with every edit above it.

**Correction.** Replace the positional or literal reference with the record's name or path, and put the number in the record it describes. When the row's subject is a value that must be readable at a glance, say where the authoritative value lives.

**Why this exists.** A number in a record is true exactly once, and the pass that found these had two open rows pointing at roadmap rows that no longer held the work they named.

### 3.14 The write-back pairing is not this run's to state

Not a check. A landed row naming the handover that landed it is not a rule in any policy; `iteration_policy.md` `### Close invariants` (Unconditional write-back) and `handover-maintenance.md` Step 6 own the pairing, and they run commit-to-row. A row that repeats a handover id states a link `git log` already holds, so a run that reports one as a missing rule is reporting the wrong direction. When the pairing has failed, the finding belongs to the close that let it through.

### 3.15 The changelog section map is unambiguous

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Entry structure` and `## Corrections to Closed Roadmap and Changelog Entries` own the heading levels and the correction forms, including the two accepted forms and what each must carry.

**Check.** Read the `##` headings of `changelog.md` in order. Any `##` that is not `## M{n}` is a finding. Any summary link whose fragment names a correction block is a finding.

**Correction.** Move the correction block to the end of the section it corrects and demote it one level, keeping its date and its content.

### 3.16 A new entry states whether its capability still stands

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Writing guidance` and `## Corrections to Closed Roadmap and Changelog Entries` own it.

**Check.** For each entry written or amended in this run, read the summary row that links it. A row reading `Complete` for an entry that records removal is a finding.

**Correction.** Add the removal statement to the entry, and make the row name it.

**Scope.** Only the section this run wrote or amended. Entries closed earlier are historical claims about what was true when they closed, and this check does not reach them.

### 3.17 A new entry carries no fact the tree can falsify

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `### Writing guidance` owns it.

**Check.** For the section this run wrote, search for paths, version strings and line numbers.

**Correction.** Cut the path list and name the record that holds it.

**Scope.** Only the section this run wrote. An older entry that names a path which no longer exists is true history, and correcting it rewrites the past into the present tense.

### 3.18 A superseded entry says so where a reader will see it

**Rule.** [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) `## Corrections to Closed Roadmap and Changelog Entries` owns it. The anchor consequence is why the rule exists.

**Check.** For each entry whose capability a later milestone removed, read the entry's opening. A suffix on the milestone heading, or a supersession sentence with no date, is a finding.

**Correction.** Move the suffix into the entry as a `### Superseded` block naming the milestone and the date.

Completion criterion: no floating prose summary, superseded item, empty section, redundant ordering block, or dangling dependency remains in the active sub-milestone; every row passes 3.6 through 3.13; and every entry this run wrote passes 3.15 through 3.18.

### Step 4 - Pre-compaction readiness

This step changes nothing. It decides whether a compaction pass is safe to propose.

1. Every task in a group that is a compaction candidate is `- [x]`, not `- [ ]`.
2. No task was marked `- [x]` before the operator verified it. Check the handover for its Step 7 acceptance-criteria status.
3. The compaction proposal text is drafted and ready for operator review.

Completion criterion: all three hold, or the run stops with the failing condition named. A premature `- [x]` blocks the pass until the operator resolves it.

### Step 5 - Record the run

Report the changes per `roadmap_policy.md`. A correction that is purely mechanical is applied and reported. A correction that changes what a record asserts needs the operator's release first. Report it, mark it High severity, and stop.

Four rules bound what a run may write.

**Permission follows the trigger.** The trigger that started the run sets its ceiling. Operator approval of one correction never widens it: work past the ceiling is an inventory row, and the operator picks it as the next unit.

**A High finding carries its evidence.** Report the tree read that produced it -- the path, the grep, the count -- so the operator can check the claim without re-running the pass. A claim about the state of a record is a hypothesis until a command confirms it, and a reviewer's claim is a hypothesis until the command confirms it too. Disagreement resolves by command, not by another round.

**A correction is the smallest edit that clears the check.** A rewrite is proposed, never applied: [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md) requires a targeted change, not a full-file rewrite. When the check is satisfied by moving a row or flipping a marker, the run moves or flips and does not restate the row's prose, and it does not drop a row where a compaction is the correct correction: a deletion loses the design links the survival table in Step 2.3 requires.

**A correction never rewrites a claim the run has not re-read.** Every path, id, count and version a correction writes is read from the tree in the same run that writes it. Where the tree and the record disagree, the record is corrected and the finding says which one was wrong.

## Output shape

The report is one table, one row per correction or per defect left for the operator.

| Section / item | Change applied or held | Category | Severity |
|---|---|---|---|
| M2.7 pre-flight checks | Compacted a fully completed group that still carried a checklist | 2.1 | Medium |
| M2.7 summary line | Held a floating prose summary for operator release | 3.1 | High |

The report closes with the counts by category and the state of the Step 4 gate.

Severity routes the correction:

- **High** -- the defect is a policy violation that blocks a clean compaction, or it would make the next agent misread roadmap state. Hold it for the operator.
- **Medium** -- the defect is a format deviation that does not change what the roadmap asserts. Apply it.
- **Low** -- the defect is cosmetic or a legacy artifact. Apply it.

## Non-goals

- Does not check closed handovers or the handover chain. That is [`handover-maintenance.md`](handover-maintenance.md).
- Does not write policy. A check that no policy text covers is a gap to report, not a rule to add here.
- Does not open, re-scope, or close an iteration.
- Does not change a milestone's task set. Adding or removing a task is a roadmap decision, not a maintenance correction.

## Failure modes

- **A premature `- [x]` looks like a finished group.** Step 2 then compacts an unverified claim and the loss is permanent. Step 4 exists to catch it; when Step 4 fails, stop rather than compact.
- **Over-compaction drops surviving detail.** A compaction that removes a design link or a deferred tag loses information the policy keeps. Check the survival table before writing a summary.
- **Scope creep into task content.** Adding a task to make a format check pass turns maintenance into a roadmap decision. Report the need instead.
- **Interpretation of a policy gap.** When a finding needs a reading of `roadmap_policy.md` that the document does not settle, state the reading and ask for confirmation before flagging or fixing.
