---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the runbook directory has one spelling and one row

## Objective

Make the sibling table in `patterns/nested-patterns.md` name every directory kind the tree carries, so the table a writer consults can name the directory they need, and choose one spelling for the runbook directory across the five skills that carry one.

## Scope

In scope: the table's missing row, the spelling decision, the two directories that carried the other spelling, and every live reference to those paths.

Out of scope: the archived handovers that name the old spelling in a code span, which are records of the state they were written in; the same rename in the installed copy under `/opt/workflow/agent`, which the image build derives from this tree.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The table types every directory kind the tree uses | `sed -n '/What becomes a sibling/,/^$/p' .agents/skills/instruction-authoring/patterns/nested-patterns.md` names `patterns/`, `assets/`, `references/` and `runbooks/` | Agent [x] |
| One spelling across the five skills that carry one | `find .agents/skills workflow/coding-agent/skills -maxdepth 2 -name 'runbook*' -type d` returns five paths, all `runbooks` | Agent [x] |
| Every live reference resolves | `bash scripts/lint.sh`; the linking gate reads the eleven references the rename touched | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The spelling is `runbooks/`, plural | Three of the five already used it, and a directory names a collection, so the plural reads true whether it holds one procedure or five; the singular never meant "holds one", since `handover-maintenance` carried two files under it | `patterns/nested-patterns.md` |
| Both entry forms are named in the table, a file and a `SKILL.md` directory | Two of the five runbooks are invoked by name and carry frontmatter, and the other three are plain files a step opens; a table naming one form sends the writer to the wrong shape | `patterns/nested-patterns.md` |

## Decisions pending

None.

## Findings

- The row's counts held: two skills carried `runbook/` and three carried `runbooks/`.
- `iter.md` reaches the handover-maintenance runbooks by their image path, `/opt/workflow/agent/modules/coding-agent/skills/...`. The linking gate resolves that form against the image map, so the rename had to reach it too, and the gate stayed clean once it did.
- One closed handover, `20261023-17`, linked the old paths as Markdown links rather than code spans, so the rename would have broken the gate through a record; the record was re-pathed.

## Completed

| File | Change |
|---|---|
| `.agents/skills/instruction-authoring/patterns/nested-patterns.md` | the `runbooks/` row, and the sentence that fixes the spelling |
| `.agents/skills/instruction-authoring/runbooks/` | renamed from `runbook/`; its two citers re-pathed |
| `workflow/coding-agent/skills/handover-maintenance/runbooks/` | renamed from `runbook/`; its `SKILL.md` index re-pathed |
| `workflow/coding-agent/prompts/iter.md` | two image-path links re-pathed |
| `devlog/roadmap.md` | the row is closed |
