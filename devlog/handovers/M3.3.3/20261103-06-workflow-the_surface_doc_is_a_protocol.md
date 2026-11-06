---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the surface contract reads the tree

## Objective

Stop `docs/development/instruction-surface-conventions.md` carrying facts that go stale, by making it a protocol over the tree: a question resolves to a command, a rule states what no script can, and every artifact it names says whether a provisioned project receives it.

## Scope

The document itself, raised by the operator at the close of `20261103-05`: the previous unit added a sentence to it restating the seeded corpus, which is the failure mode the document has.

Readers verified before editing, so the rewrite could not break a gate: `scripts/check_instruction_surfaces.sh` parses the subject table only, `scripts/lint/code-snippets.baseline` tracks the two fenced snippets, and no other file reads the document mechanically.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A data-held fact is a command, not prose | `## Reading the surface from the tree`, four questions each with one command | Agent [x] |
| The document says what a provisioned project receives and what only this repository holds | the table under `## Scope` | Agent [x] |
| No section restates a gate's finding list | `## The gates` states one rule per script and defers the rest to the script's header | Agent [x] |
| A shipped file does not depend on a repository-only document | `initialize/SKILL.md` states the stub contract itself and names the fuller one as this repository's | Agent [x] |
| The gates still pass | `bash scripts/lint.sh` clean across 20; `bash scripts/run_tests.sh` green apart from two deadline flakes that pass in isolation | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The gates section states one rule per script and defers the findings to the script's header | The old text enumerated each gate's findings, so a gate edit made the document wrong; every script header already states its rule and the document that owns it | `## The gates` |
| Reach is stated as a property of the reader | The document describes shipped artifacts while being repository-only, and the corpus question came from exactly that confusion | the table under `## Scope` |
| A shipped file whose procedure depends on a repository-only document states the rule itself | `initialize` told a provisioned project to read this document, which that reader cannot open; the gate passes because the reference is a name, not a link | `initialize/SKILL.md`, the new rule |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The gates section restated each script's findings, so every gate edit left the contract wrong | defect | the document drifted on a change to code rather than to policy | fixed in this unit |
| `initialize/SKILL.md` sent a provisioned project to `docs/development/instruction-surface-conventions.md`, which the image does not carry | defect | a shipped procedure with an unopenable dependency, passing the linking gate because the reference is a name | fixed: the stub contract is stated in the skill, and the document is named as this repository's |
| `docs/development/prompt-authoring-conventions.md` carries the same shape: prose describing schemes and gates | open | the same drift will appear there | not filed; named here so the next reader has the pointer |

## Completed

| File | Change |
|---|---|
| `docs/development/instruction-surface-conventions.md` | the two-reaches table, `## Reading the surface from the tree`, and `## The gates` reduced to one rule per script |
| `workflow/coding-agent/skills/initialize/SKILL.md` | the stub's contract stated in the skill; the fuller contract named as this repository's own |
| `devlog/roadmap.md` | the row for this unit |
