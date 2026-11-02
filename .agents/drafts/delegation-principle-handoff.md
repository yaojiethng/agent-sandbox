---
description: "Handoff - state the delegation judgement as a principle skill: a job a party already owns does not need a second answer, and the tell is a boundary that needs ring-fencing. The content is decided; the work is writing it to the shape the gate enforces."
argument-hint: "[scope note, e.g. extra cases to cover - optional]"
---

> $ARGUMENTS

# Handoff - state the delegation judgement as a principle

## What the next session is for

Write one principle skill, `principle-delegation-over-machinery`, with its maintenance record, in the provider skill root. The judgement was reached while unwinding a milestone that built a second provenance system for a per-project package list; the content below is settled and the work is to land it in the shape the gate accepts.

Delete this file when the task lands.

## Where things stand

No such skill exists. The provider skill root holds 30 skills and every one has a `MAINTENANCE.md`. The principle family is a settled shape, and `principle-justify-materialization-cost` is the closest cousin: it judges whether to store a derived result, where this one judges whether to build the thing that would produce it.

## The content, decided

- **Name:** `principle-delegation-over-machinery`. Bare `principle-` form, no domain prefix: the judgement holds wherever a task reaches for new machinery.
- **Leitwort:** delegation, not reuse. Reuse names an artifact; delegation names a responsibility, which is what the judgement turns on.
- **The claim:** a job a party already owns does not need a second answer, and the machinery built beside it is a copy of that party's guarantee that will drift.
- **The pattern:** name the party that already answers the question, hand the question to it, keep only what it cannot give. The supporting table maps what a task reaches for to who already answers it: a pin or lockfile to the package manager, a filter over installed bytes to the loader, a review of someone else's choice to the person who chose, a schema over bytes the tree does not hold to nobody, a restatement of a runbook to the runbook.
- **The tell:** a boundary that needs several rules solely to stop two systems using the same words for different things is a boundary between two things that should not both exist. This is the part of the judgement worth the most, and it comes from the milestone that produced it.
- **Three exceptions:** the owner decides but does not say so, so surface its decision rather than reimplement it; the owner's guarantee is weaker than the need, so extend it in the owner's layer; a record is owed to a party that will never read the tree, such as a licence notice that must travel with shipped bytes.
- **The test:** for each file, schema, gate or step, name the guarantee it provides that the owning party does not, and the failure it catches that the party's mechanism would miss. If both are empty, delete it. If the machinery is for bytes the tree does not hold, both are empty by construction.
- **Record:** `Source: home-grown.`, with the milestone that produced it and the four-part adaptation record.

## Suggested skills

| Skill | Why this session needs it |
|---|---|
| `skill-scaffolder` | the family's shape and the gate it must satisfy |
| `writing-for-agents` | the skill is an instruction document, and its reader is an agent |
| `communication-principle-maximize-conceptual-leverage` | one word carries the judgement, and it is chosen here |

## Done when

- `src/reasoning/providers/pi/config/agent/skills/principle-delegation-over-machinery/` holds `SKILL.md` and `MAINTENANCE.md`.
- `bash scripts/check_document_shape.sh` passes: the pattern paragraph leads, the named parts sit between `**Why.**` and `**The test.**`, and the test closes.
- `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean.

## A note on what not to add

Do not turn this into a list of code-writing rules. The seven-step ladder in the provider `AGENTS.md` already covers the code case, and half of it states this judgement in the order a coder reads it. A second prose statement of the same advice would be exactly the copy the principle warns about.
