---
name: work-log
description: "agent-sandbox's work-log convention - the handover record, the exploration record (discussions) and the feedback record. Use when a workflow procedure reads or writes one of these records."
---

# work-log

This project's work log holds three records.

A record is not documentation and has no documentation mode. Its reader is a later session continuing the work, rather than a learner, a practitioner, an explainer or an index, so the four modes `project-documentation` states do not apply to it.

| Record | Path | Its shape |
|---|---|---|
| The handover record | `devlog/handovers/<track>/` | [`assets/handover.md`](assets/handover.md) |
| The exploration record | `devlog/discussions/` | one of four types, below |
| The agent-feedback and gotchas record | `devlog/AGENT_FEEDBACK.md` | stated below |

A workflow procedure that reads or writes a record hands off here for its structure. This file states the rules; the template states the shape.

## The handover record

One file per iteration, committed with the iteration's changes, retained for the life of the milestone. It is a log, not a document, so the drafting rules for `docs/` do not apply.

Write it from [`assets/handover.md`](assets/handover.md). The template carries the frontmatter block and the seven sections.

### Filename

```text
devlog/handovers/<track>/YYYYMMDD-NN-<shortform>-<slug>.md
```

| Component | Rule |
|---|---|
| `YYYYMMDD` | the date |
| `NN` | the record's identity within the day, taken from the track's reserved block (below); a track's first record on a date takes the block's first free number |
| `<shortform>` | the type shortform, from the vocabulary below |
| `<slug>` | the specific subject. Name the concrete thing, not a restatement of the type. Underscores for spaces; no other special character. A reader scanning a list of filenames distinguishes this iteration from others of its type without opening the file. |

Example: `devlog/handovers/M3.5.1/20260316-20-workflow-scope_gate_and_preclose_verification.md`

The folder is the track, and a record's `milestone` field names the same milestone. A track reserves a block of `NN` numbers when it opens, recorded as `ids: 20-39` in `devlog/handovers/<track>/README.md`, so two tracks writing on one date never collide.

The latest record is the tip of the track in git, not the highest filename. `scripts/worklog.sh latest` answers it, `active` answers the open record, and `reserve-id` answers the next identity. Earlier records are never overwritten.

### Vocabularies

The `type` vocabulary, with the commit type each maps to at close:

| Type | Shortform | Commit mapping |
|---|---|---|
| Implementation | `impl` | `feat`, `fix`, `refactor`, `test`, `build` |
| Discussion | `discussion` | `docs` |
| Design | `design` | `docs` |
| Plan | `plan` | `plan` |
| Documentation | `docs` | `docs` |
| Workflow | `workflow` | `workflow` |
| Housekeeping | `chore` | `chore` |
| Audit | `audit` | any |

The shortform appears in the filename. The commit type disambiguates an implementation's subclass at close. The deprecated types `story`, `study` and `spec` are retained for historical records only.

The `status` vocabulary is `Active` when the iteration opens the record, `Closed` at iteration end, and `Open` for a record created ahead of the iteration that writes it.

### Section roles

A procedure that checks a record names a section by role. The template carries the heading.

| Role | Heading |
|---|---|
| the objective | `## Objective` |
| the scope | `## Scope` |
| the acceptance criteria | `## Acceptance criteria` |
| the decisions | `## Decisions` |
| the pending decisions | `## Decisions pending` |
| the findings | `## Findings` |
| the completed work | `## Completed` |

The record carries no `Deferred`, `Carried forward` or `What's Next` section. An item deferred with a destination goes to the task list as an open row; an item ruled out of scope is one sentence in the scope section with its reason.

An empty nullable section carries its canonical marker and nothing else. Do not explain why the section is empty; a decision that affects it belongs in the decisions section.

| Section | Marker |
|---|---|
| Acceptance criteria | `Not yet defined.` |
| Decisions | `None.` |
| Decisions pending | `None.` |
| Findings | `None.` |
| Completed | `No file changes this iteration.` |

### The acceptance-criteria table

The acceptance-criteria table has three columns, one row per criterion:

| Criterion | Verification | Result |
|---|---|---|

The `Verification` cell names the command or the line range that settles the criterion. The `Result` cell carries the marking: `Operator` when only the operator can verify it, `Agent [x]` when it passes, and `Agent [ ]` when it fails in the pre-state as expected. The workflow presents the same table at the scope gate and at pre-close.

The table holds the criteria the iteration derives. What makes a criterion well-formed is the workflow's, not this convention's.

### The format window

`scripts/check_handover_format.sh` enforces the template's shape on every record dated 2026-10-01 or later, as a blocking gate. A record dated before that date is exempt, and stays exempt when it is amended. The gate changes a non-conforming record inside the window. The gate leaves a record outside the window unchanged.

A record with no frontmatter block is unreachable by the default scan, because the scan reads the block to find the date. Naming the file on the command line reaches it regardless of date, and is the only way to do so.

The `milestone` field names the task group the iteration belongs to. The task list states its value's format, in [`../task-list/SKILL.md`](../task-list/SKILL.md).

## The work-log tool

`scripts/worklog.sh` is the seam between the convention and the tree. It reads the layout declared once in `src/build/record-layout.json` through `src/build/record-layout.mjs`, and it answers the derived reads a procedure would otherwise compute by hand:

| Command | Answers |
|---|---|
| `worklog.sh latest [--track T]` | the tip record of the track, by git order |
| `worklog.sh active [--track T]` | the one `Active` record on the track |
| `worklog.sh track` | the track the caller is in |
| `worklog.sh reserve-id --track T` | the next free id in the track's block |
| `worklog.sh list [--track T]` | the track's records |
| `worklog.sh path handover` | the declared root |

A procedure calls the tool rather than listing the folder, grepping for `Status: Active`, or computing `max + 1`. The tool adds no rule of its own; this convention states what a record says.

## The exploration record

`devlog/discussions/` holds one record per line of enquiry, and this convention decides its life: the record is opened only while in-flight knowledge must outlive the iteration, and it is deleted when the roadmap row that names it closes, or re-pointed to an open row that inherits it. The ground is `principle-single-source-of-truth` -- once the ADR holds the subject in the same mode, the record is a second source. [`documentation_taxonomy.md`](../../../docs/reference/documentation_taxonomy.md) classifies the kind, and the [`decision-records`](../decision-records/SKILL.md) convention owns the ADR the evidence settles into, not the record.

Two gates hold the life: `scripts/check_record_names.sh` for the name and the state, and `scripts/check_record_lifecycle.sh` for the deletion and for the row that links a record. Each states the rule it applies when it fails.

### A discussion record's filename

```text
YYYYMMDD-{type}-{state}-{description}.md
```

| Component | Rule |
|---|---|
| `YYYYMMDD` | the date the record opens |
| `{type}` | one of `story`, `study`, `design`, `report` |
| `{state}` | one of the states below |
| `{description}` | `[a-z0-9][a-z0-9._-]*`: lowercase letters, digits, period, underscore and hyphen, with underscores for word spaces |

Hyphens delimit and underscores separate words. A name carries no emoji, no unicode, no space and no per-day index: that slot belongs to the handover record, and one date already holds both kinds of record.

A record keeps an old-format name until it is substantively edited. On that edit it is renamed to this convention, its inbound links are updated, and a state token the vocabulary has retired is brought into the current set.

A file under `docs/` is not a discussion record and does not take this name.

### Two facts, not one

What the enquiry has established, and whether the task that owns the record is still open, are independent. The first is the record's state, carried in its name and its `**Status:**` line. The second is its tenancy, read from the roadmap: a record is **owned** while at least one open row names it, and **orphaned** when none does.

| State | Meaning | Valid next states |
|---|---|---|
| `open` | the enquiry is in flight | `concluded`, `rejected` |
| `concluded` | the enquiry reached its result, and the record is evidence for it | -- |
| `rejected` | decided against | -- |

A record is deleted when it is `concluded` or `rejected` **and orphaned**: its row has closed, so the evidence has no task left to serve. Another open row may take the record over instead, which is a re-point rather than a new file, and the closed row strips its link. A record whose row is still open stays, whatever its state.

### The four types

| Type | The enquiry it carries | Its shape |
|---|---|---|
| `story` | the sub-milestone objective is clear but the approach is not | [`assets/story.md`](assets/story.md) |
| `study` | a story has two or more candidate approaches to compare | [`assets/study.md`](assets/study.md) |
| `design` | the iteration's design phase resolves trade-offs between options | [`assets/design.md`](assets/design.md) |
| `report` | a run's evidence, composed while the run is in flight | no fixed order, on the rules below |

**A story concludes** when the pain point is understood, the resolvable questions are answered, the approach is agreed with its rationale, and the tasks name a file and a nature of change. Write the task-list row first, then set the state to `concluded`. Tasks are not copied back into the story.

**A study links its parent story.** The study links back from the parent's `## Study Findings`, and its lifetime is the parent's: the record stays while that row is open.

**A design concludes into an ADR.** When the design settles an implementation decision, record the decision in `docs/adr/` per the [`decision-records`](../decision-records/SKILL.md) convention and set the state to `concluded`. The ADR is the authority and the durable seat; the record is the evidence, and it is deleted once its row closes.

**A report has no fixed section order.** Three rules bind it: it is `open` while its run is in flight and `concluded` when the run ends; it states the context, what came of it, and the artifacts it produced, each naming the artifact's source of truth; and it is deleted once its facts are in the handover or the ADR it justified.

## The feedback record

`devlog/AGENT_FEEDBACK.md`. It is append-only, one entry per topic. The agent records a recurrence on the existing entry, not as a new entry. Each entry carries a `state` and a `scoped` field in a fenced block, and a `mitigation` line.
