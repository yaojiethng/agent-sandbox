---
name: work-log
description: "agent-sandbox's work-log convention - the work-unit record (handovers), the exploration record (discussions) and the feedback record. Use when a workflow procedure reads or writes one of these records."
---

# work-log

This project's work log holds three records.

| Record | Path | Its shape |
|---|---|---|
| The work-unit record | `devlog/handovers/` | [`assets/handover.md`](assets/handover.md) |
| The exploration record | `devlog/discussions/` | one of four types, below |
| The agent-feedback and gotchas record | `devlog/AGENT_FEEDBACK.md` | stated below |

A workflow procedure that reads or writes a record hands off here for its structure. This file states the rules; the template states the shape.

## The work-unit record

One file per iteration, committed with the iteration's changes, retained for the life of the milestone. It is a log, not a document, so the drafting rules for `docs/` do not apply.

Write it from [`assets/handover.md`](assets/handover.md). The template carries the frontmatter block and the seven sections.

### Filename

```text
YYYYMMDD-NN-<shortform>-<slug>.md
```

| Component | Rule |
|---|---|
| `YYYYMMDD` | the date |
| `NN` | the two-digit per-day index, reset daily: `max + 1` over the day's existing records, so the day's first is `01` |
| `<shortform>` | the type shortform, from the vocabulary below |
| `<slug>` | the specific subject. Name the concrete thing, not a restatement of the type. Underscores for spaces; no other special character. A reader scanning a list of filenames distinguishes this iteration from others of its type without opening the file. |

Example: `20260316-02-workflow-scope_gate_and_preclose_verification.md`

The record with the highest date and index is the latest record. Earlier records are never overwritten.

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

## The exploration record

`devlog/discussions/` holds one record per line of enquiry. The type decides what the record answers, its status path and its shape.

### A discussion record's filename

```text
YYYYMMDD-{type}-{status}-{description}.md
```

| Component | Rule |
|---|---|
| `YYYYMMDD` | the date the record opens |
| `{type}` | one of `story`, `study`, `design`, `report` |
| `{status}` | one of the statuses below |
| `{description}` | `[a-z0-9][a-z0-9._-]*`: lowercase letters, digits, period, underscore and hyphen, with underscores for word spaces |

Hyphens delimit and underscores separate words. A name carries no emoji, no unicode and no space.

A record keeps an old-format name until it is substantively edited. On that edit it is renamed to this convention and its inbound links are updated.

A file under `docs/` is not a discussion record and does not take this name.

### Statuses

| Status | Meaning | Valid next states |
|---|---|---|
| `draft` | First write, not yet reviewed | `active`, `rejected` |
| `active` | Under discussion or investigation | `settled`, `rejected` |
| `settled` | Discussion closed, decision reached | `superseded`, `archived` |
| `superseded` | Replaced by a newer record | `archived` |
| `rejected` | Decided against | `archived` |
| `archived` | Terminal, no active references | -- |

One vocabulary serves all four types, in the filename and in the `**Status:**` line. A report is the exception: it starts at `draft`, moves straight to `settled`, and never passes through `active`. A rejected report is deleted or archived at the operator's direction.

### The four types

| Type | Open one when | Its shape |
|---|---|---|
| `story` | the sub-milestone objective is clear but the approach is not | [`assets/story.md`](assets/story.md) |
| `study` | a story has two or more candidate approaches to compare | [`assets/study.md`](assets/study.md) |
| `design` | the iteration's design phase resolves trade-offs between options | [`assets/design.md`](assets/design.md) |
| `report` | an operation has finished and its record is composed after the fact | no fixed order, on the rules below |

**A story graduates** when the pain point is understood, the resolvable questions are answered, the approach is agreed with its rationale, and the tasks name a file and a nature of change. Write the task-list row first, then set the status to `settled`. Tasks are not copied back into the story.

**A closed study feeds its parent story.** The study links back from the parent's `## Study Findings`, and the agent does not delete a study record.

**A design settles into an ADR.** When the design settles an implementation decision, record the decision in `docs/adr/` per the [`decision-records`](../decision-records/SKILL.md) convention and set the design's status to `settled`. The design stays the exploration record; the ADR is the authority.

**A report has no fixed section order.** Three rules bind it: it is composed after the fact and is never a working record; it starts at `draft` and moves straight to `settled`; and it states the context, what came of it, and the artifacts it produced, each naming the artifact's source of truth.

## The feedback record

`devlog/AGENT_FEEDBACK.md`. It is append-only, one entry per topic. The agent records a recurrence on the existing entry, not as a new entry. Each entry carries a `state` and a `scoped` field in a fenced block, and a `mitigation` line.
