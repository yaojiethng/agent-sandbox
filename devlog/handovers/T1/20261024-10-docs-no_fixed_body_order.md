---
date: 2026-10-24
milestone: T1 - Workflow + Policy Organization
type: Documentation
status: Closed
---

# Handover - A workflow document has no fixed body order

## Objective

Keep the section-order guidance as a suggested shape and drop the requirement, and write down the argument placeholder the two runtimes share.

## Scope

The body-order paragraph and a new argument-placeholder paragraph in [`prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) `## Structure of a workflow document`, and the pointer in `skill-scaffolder`. The frontmatter paragraphs stay as they are, on the operator's direction, because the document-shape gate cites that section as the frontmatter rule's source. The `## Project conventions` block and the presentation paragraph stay.

The 23 prompt files that still carry `$@` are not rewritten here. The roadmap row **The argument placeholder unifies on `$ARGUMENTS`** owns that sweep, and this record states the rule the sweep follows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The order is a suggestion, not a requirement | `grep -c 'A common shape, not a requirement' docs/development/prompt-authoring-conventions.md` is 1 | Agent [x] |
| No mandate language survives | `grep -c 'follows a stable order' docs/development/prompt-authoring-conventions.md` is 0 | Agent [x] |
| The argument placeholder is written down with its reason | `grep -n 'OpenCode substitutes only' docs/development/prompt-authoring-conventions.md` prints one line | Agent [x] |
| The scaffolder no longer promises an order elsewhere | `grep -c "body's order is in" .agents/skills/skill-scaffolder/SKILL.md` is 0 | Agent [x] |
| The frontmatter rules are untouched | `git diff` shows no change to the Description, argument-hint or skill-frontmatter paragraphs | Agent [x] |
| The gates stay clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The seven parts stay, as "a common shape, not a requirement" | the parts are useful guidance and were never the defect; the defect was that a reviewer could cite them as a requirement | the convention |
| The parts are compressed to one line each | the previous text justified each part by naming a prompt as a model, and those examples were longer than the rule | the convention |
| `$ARGUMENTS` is the written form, not `$@` | pi substitutes both and OpenCode substitutes only `$ARGUMENTS`, so one spelling serves both runtimes from one file | the convention, citing [`instruction_surface_declaration.md`](../adr/instruction_surface_declaration.md) |
| The 23 `$@` files are left to their roadmap row | the rewrite is mechanical but it is a separate unit with its own scope gate | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The body order produced finding 12 in the `/scope` review, `[Low] The body has no ## Purpose`, and the reviewer's correction restored a section the operator had cut | defect | a document-wide shape rule overrode a directed compaction | fixed here: the order is guidance and the convention says so |
| The review brief named this document's body order as a bar, and the document is not shipped into the container | mechanism | a reviewer enforced a rule the shipped prompt cannot cite | fixed here: no bar to cite |
| 23 prompt files still open with `> $@`, which OpenCode does not substitute | defect | an OpenCode run receives the literal text instead of the operator's argument | the open roadmap row **The argument placeholder unifies on `$ARGUMENTS`**, which owns the sweep |

## Completed

| File | Change |
|---|---|
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | the required order becomes "a common shape, not a requirement" with the seven parts kept as one-line guidance; a new paragraph states `$ARGUMENTS` and why |
| [`.agents/skills/skill-scaffolder/SKILL.md`](../../.agents/skills/skill-scaffolder/SKILL.md) | `## The body's sections` states that no fixed order is mandated instead of pointing at one |
| [`devlog/handovers/20261024-10-docs-no_fixed_body_order.md`](20261024-10-docs-no_fixed_body_order.md) | this record |
