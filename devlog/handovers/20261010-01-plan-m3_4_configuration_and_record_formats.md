---
date: 2026-10-10
milestone: M3.4 - Configuration and Persisted Record Formats
type: Plan
status: Closed
---

# Handover - Plan: promote M3.4 and scope its first unit

## Objective

Promote the configuration and record-format work to M3.4 under the active milestone, and scope its first unit: one KV read/write pair behind every key-value record, with the environment load as the first reader.

## Scope

This iteration promotes a milestone and scopes one unit; it writes no harness code. It adds the M3.4 section to [`devlog/roadmap.md`](../../devlog/roadmap.md) with its objective, dependencies, acceptance criteria and first task; it moves the T10 `Environment: one load path` row and the T11 `Record shape` row into that task, leaving pointer entries in their tracks; and it adds the summary-table row.

The unit runs on the fork branch `feat/M_3-orchestration`. M3.4 owns `src/libs/`, the capability-layer record files and their tests. It conflicts with none of M3.1, M3.2 or M3.3, whose file sets are `scripts/`, the commit gates and test harness, `workflow/coding-agent/**`, the dispatch prompts, the `task-queue` extension and the instruction surfaces.

Named for later units, not in this one: the T10 resolution-ladder row and the T11 structured-format rows (JSON and the parser dependency, one timestamp format, one relative-time ladder, Note B).

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The M3.4 section is filed with an objective, a dependencies paragraph, an acceptance-criteria block and one task row | read of the section against `roadmap_policy.md` `### Record shape` | accepted |
| The two moved rows appear once, as the M3.4 task; their T10 and T11 entries are pointers that carry no row text | grep of both row titles across `devlog/roadmap.md` | accepted |
| The summary-table row's anchor resolves to the new section | `bash scripts/lint.sh` (the record-link gate) | accepted |
| The gates are clean after the edits | `bash scripts/lint.sh` | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | gains the M3.4 section, the summary row and the two track pointers |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| M3.4 nests under the active milestone M3 rather than a new top-level M6 | operator direction at the fork's scope gate; M6 stays unused and free for the mainline, and a M3.x child keeps the fork's numbering inside the active milestone tree | this handover |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the M3.4 section with objective, dependencies, acceptance criteria and first task; the summary-table row; the T10 and T11 rows replaced by pointers |
