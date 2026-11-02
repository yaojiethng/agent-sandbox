# Organization

This file is this convention's organization rule: the mode each corpus serves, the folder it sits in, and what it holds. The view of the tree is `docs/reference/documentation_taxonomy.md`, and the decision that adopted the frame is `docs/adr/documentation_quadrants.md`.

## Pick the mode first (Diataxis)

One document, one mode. Two questions pick it: does the content inform action (doing) or understanding (thinking), and does it serve learning or work?

- Action + learning: **tutorial**.
- Action + work: **how-to**.
- Understanding + work: **reference**.
- Understanding + learning: **explanation**.

Use the compass on a whole document or on one sentence.

## The corpora

Each mode is one of this repository's corpora, and each corpus is one folder except the how-to, which is not a folder at all.

| Mode | Folder | Holds |
|---|---|---|
| tutorial | `docs/development/` | contributor workflow and the conventions for changing the harness |
| how-to | the instruction surface | a procedure the agent runs |
| reference | `docs/reference/` | the harness as built: contracts, states and sequences, the interface index, and the glossary |
| explanation | `docs/adr/` | the rationale behind standing principles, interface shapes and contracts, with superseded or awaiting-review ADRs under `adr/archive/` |

A document lives in exactly one folder. Which folder holds what, and each type's durability, is `docs/reference/documentation_taxonomy.md`; that a document lands in exactly one of them is this convention's.

Two corpora sit outside the four. The `devlog/` records are read by a later session continuing the work, and `.agents/skills/work-log/SKILL.md` states why a record has no mode.

**Tutorial: learning by doing.** The learner's success is your job, not theirs. Open by saying what the learner will build, not what they will "learn". Every step produces a visible result, early and often. Tell them what they should see: the expected output, the prompt change, the log line. Cut explanation to one clause and a link. Stay concrete. Write as "we", in commands: "First, do x. Now, do y."

The tutorial mode is unused: the reader here holds the tree and needs a model of how to work in it rather than a first lesson, so the rules above apply whole if a tutorial is ever written.

**How-to: steps to a goal.** Solve a problem a person has, not an operation the machine can perform. Assume competence and skip teaching. Action only: no digressions, no background, no completeness for its own sake. Link those instead. Allow forks and judgment: "If you want x, do y." Name the guide by the task: "How to calibrate the radar array", not "Radar array calibration".

The how-to mode is not a document here: it exists as the instruction surface, which is dispatched to an agent. That surface is managed by the `skill-scaffolder` skill, a name this reference corrects at the rename and not before, and the procedures written in this mode work under the surface's scope, which `docs/development/instruction-surface-conventions.md` `## Scope` states.

**Reference: facts for lookup.** Only describe. No instruction, no persuasion, no opinion. Be dry, complete, and sure. State facts, options, limits, and errors with no hedging. Mirror the structure of the thing described, so code and docs can be navigated together. Put material where readers expect it. Generate from code where possible.

A reference document may state what a procedure must not break, which is why `docs/reference/iteration_protocol.md` is reference rather than a how-to.

**Explanation: understanding and why.** One bounded topic, readable away from the product. Each title should tolerate an implicit "About..." in front. Anchor on a real why question. Give context: design decisions, history, constraints, alternatives. Opinion is allowed here and nowhere else.

Don't mix modes: no reference tables inside a tutorial, no tutorial hand-holding inside reference, no arguing inside a how-to. Split and link instead.

Where a document needs two modes, split it: a convention-skill states the rule, and the ADR states why that rule beat its alternatives.

Source: Daniele Procida, *Diataxis: a systematic framework for technical documentation authoring*, `diataxis.fr`, read 2026-11-02, https://diataxis.fr/. The adaptation is `.agents/registry/citations/diataxis.json`.
