---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - One Home for the Propagation Discipline

## Objective

Give the propagation discipline one home in a harness skill, delete the prompt that carries it today, and leave the project layer with the trigger line the measured behaviour runs off.

## Scope

No roadmap row names this unit; the operator directed it at the close of handover `20261005-05` ("before we unbundle we need a lot of skill cleanup"), and it is a prerequisite for the M3.3.1 goal row.

Measured before touching anything, across the 565 sessions under `$AGENT_HOME/agent/sessions/`:

| Measure | Count |
|---|---|
| Sessions that produced a propagation checklist | 292 |
| Sessions that cite "the propagation discipline" -- the project layer's section -- as the source | 68 |
| Sessions that read `propagation-check.md` | ~15 |
| Sessions that invoked it as a command | 0 |

The practice is thriving and the prompt is not the reason: the always-loaded section is. The file's *content* is used as a reference; its *form* -- a prompt taking `<change description>` -- never was. So the content moves to a skill, where pi injects the name and description at startup and loads the body on demand, which is the observed behaviour with discovery in place of a pointer.

Four items:

1. **The skill.** `src/reasoning/agent/skills/propagation-check/SKILL.md`, in the portable shape, carrying the rule (when a checklist is required, its format, the update rules, the completion criteria, the rename case, the output-contract clause) and the audit procedure from the prompt. The prompt is deleted.
2. **Conditional repository clauses.** The skill ships to projects that keep no roadmap and no `docs/` tree, so every clause that assumes one is stated as a condition -- the deferred-gap write-back, the knowledge-test coverage, the `docs/` targets.
3. **The project layer keeps the trigger.** `AGENTS.md` `## Propagation Discipline` shrinks to the trigger: a multi-file change, the trigger language, or an output-contract change requires a checklist, and the `propagation-check` skill states the rule and the procedure. The long section leaves. The trigger stays because pi's own documentation warns that a model may fail to load a relevant skill, and the measurement above shows the always-loaded instruction is what drives the practice.
4. **`defer.md`'s project assumption, ruled out.** Measured while implementing: its whole purpose is parking an item as a roadmap row, and by the operator's taxonomy it sits in the harness utility cell, where a shortcut for working with agent-sandbox is expected to name the roadmap. The propagation case differs because it is generic behaviour shipping into projects that need no record layer.

The three pointer sites that name the old section follow: `document.md`, `plan.md`, `testing-conventions.md`.

Ruled out and filed instead: the repository-specific skill cell at `.agents/skills/`, and the machine-readable interface specification that retires the `CONTEXT.md` files. Both are their own rows under M3.3.1, and their order is C then A.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The discipline lives in one skill, holding the rule and the procedure | read `src/reasoning/agent/skills/propagation-check/SKILL.md` | Agent [ ] |
| Every clause that assumes a roadmap, a `devlog/` tree or a `docs/` tree is stated as a condition | read the skill; no clause assumes the record layer | Agent [ ] |
| The prompt is gone, and no live file cites `AGENTS.md` for the discipline | `grep -rn` the prompt path and the section name across the tree, `devlog/` archives excluded | Agent [ ] |
| The project layer carries the trigger and no procedure | read `AGENTS.md`; the section is short and points at the skill | Agent [ ] |
| The three pointer sites name the skill | read `document.md`, `plan.md`, `testing-conventions.md` | Agent [ ] |
| `defer.md` states its roadmap write-back as a condition | dropped: measured, the prompt's purpose is the roadmap write-back | Agent [x] |
| The new skill parses, with a name and a description | `bash scripts/check_prompt_frontmatter.sh` | Agent [ ] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | both commands | Agent [ ] |
| The skill's shape and the trigger line are accepted | operator acceptance at the release gate | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `src/reasoning/agent/skills/propagation-check/SKILL.md` | the discipline's new home |
| [`src/reasoning/agent/prompts/propagation-check.md`](../../src/reasoning/agent/prompts/propagation-check.md) | deleted |
| [`AGENTS.md`](../../AGENTS.md) | the section shrinks to the trigger |
| [`workflow/coding-agent/prompts/document.md`](../../workflow/coding-agent/prompts/document.md) | points at the old section |
| [`workflow/coding-agent/prompts/plan.md`](../../workflow/coding-agent/prompts/plan.md) | points at the old prompt |
| [`docs/development/testing-conventions.md`](../docs/development/testing-conventions.md) | points at `AGENTS.md` for the checklist |
| [`src/reasoning/agent/prompts/defer.md`](../../src/reasoning/agent/prompts/defer.md) | measured and left alone: the roadmap framing is the prompt's function, in the harness utility cell |
| [`devlog/roadmap.md`](../devlog/roadmap.md) | the two filed rows, and this row's write-back |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The discipline becomes a harness skill, and the prompt is deleted | measured: 292 sessions produced a checklist, 68 cite the discipline, ~15 read the file, none invoked it. The content is used as a reference and the command contract never was, so the skill form matches the behaviour, and its description is injected at startup. Operator ruling. | the skill |
| The project layer keeps one hard trigger line | the measurement shows the always-loaded instruction drives the practice, and pi documents that a model may fail to load a relevant skill: a description is a suggestion, the layer's sentence is an instruction | `AGENTS.md` |
| The skill's repository clauses are conditional | the skill ships into projects that keep no roadmap and no `docs/` tree, and a seeded surface that assumes the record layer is the defect this unit exists to remove | the skill |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `defer.md` was carried in this unit's scope as a seeded surface assuming the record layer, and the measurement says otherwise: parking an item as a roadmap row is its purpose, and its cell is the harness utility set, where that is expected. The criterion is marked dropped rather than satisfied, so the unit is one item smaller than the scope gate released. | scope change | current iteration | Triaged to: this handover's Scope item 4, and the row is left unchanged |
| The skill's frontmatter `description` is now the trigger surface: pi injects it at startup where the prompt's body used to be read. A future edit to that field changes what the agent sees every session, and no gate reads its wording. | steering | next iteration | Triaged to: `src/reasoning/agent/skills/propagation-check/SKILL.md`; recorded here, since no gate can hold it yet |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/skills/propagation-check/SKILL.md` | new: the discipline's home -- the rule, the trigger list, the rename case, the audit, and the record-layer clauses as conditions |
| [`src/reasoning/agent/prompts/propagation-check.md`](../../src/reasoning/agent/prompts/propagation-check.md) | deleted |
| [`AGENTS.md`](../../AGENTS.md) | `## Propagation Discipline` shrinks from a 25-line section to three sentences and a link to the skill |
| [`workflow/coding-agent/prompts/document.md`](../../workflow/coding-agent/prompts/document.md), [`plan.md`](../../workflow/coding-agent/prompts/plan.md) | name the skill at its image path |
| [`docs/development/testing-conventions.md`](../docs/development/testing-conventions.md) | names the skill at its repository path |
| [`devlog/roadmap.md`](../devlog/roadmap.md) | this unit's row, and the two filed rows for the units that follow |
