---
date: 2026-10-28
milestone: M3.3.6 - The instruction corpus
type: Workflow
status: Closed
---

# Handover - the materialization principle is renamed for its judgement

## Objective

Make the principle findable: name its judgement, front-load the leading word, and anchor the body around the storage decision rather than the taxonomy it produces.

## Scope

In scope: `principle-guard-derived-state` renamed to `principle-justify-materialization-cost`, its description and body rewritten around `materialization`, and the five live carriers retargeted. Out of scope: the installed `$AGENT_HOME` copy, which the image seeds at every start, and the settled discussion `20261023-design-settled-derived_artifacts.md`, which keeps the release name as history.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The directory and `name:` agree on the new handle | the directory and the frontmatter | Agent [x] |
| The description is a signpost: the decision, then the situation | read the description; it names no procedure | Agent [x] |
| The body leads with the stake and states the three questions | read the body | Agent [x] |
| `materialization` repeats in the description, the body and the table | `grep -c materializ` | Agent [x] |
| No live carrier names the old handle | `grep -rn 'guard-derived-state'` outside history | Agent [x] |
| The gates pass | markdown, link, lint, handover format | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `materialization` is the leitwort | it holds in both domains the principle covers: dbt's `view`/`ephemeral` versus `table`/`incremental`, and Bazel materializing build outputs | this record |
| The name states the judgement, not the two options | the burden is asymmetric: a materialized copy must justify its cost, and derivation does not | the principle's name |
| The table stays as it is | dbt's materializations are implementations of the same two axes; borrowing them would add a second taxonomy, and the refresh-timing dimension is not this decision | this record |
| The prose under the table is cut | it restated the table's rows, and the examples column already carries the boundary cases | the principle's body |
| The test prices derivation against the cost of upkeep, not against cheapness | an impossible re-derivation is an unmeasurable cost, and cheapness was never the question | the principle's body |

## Decisions pending

None.

## Findings

- **The old name had two defects, and the description was the larger one.** `guard` names an authority rather than an act, and the trigger sentence listed artifact types: catalog, index, registry, lockfile, snapshot, none of which an agent holds in mind when it is about to write a result to a file.
- **The body's three "filters" read as failures.** "Reproducibility: the derivation is bound to point-in-time state" named a property by its absence, so the reader had to invert each one. They are now three questions with the verdict inside them.

## Completed

| Artifact | What changed |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-justify-materialization-cost/SKILL.md` | renamed and rewritten: the stake, three questions, the materialized axis, the cut restatement, the cost-priced test |
| `docs/development/prompt-authoring-conventions.md` | the `source`-claim trio names the new handle |
| `devlog/roadmap_future.md` | the derived-artifacts row links the new handle |
| `workflow/coding-agent/prompts/scope.md` | the raw-material question names the new handle |
| `src/reasoning/agent/skills/writing-for-agents/SKILL.md` | the environment-as-source pointer names the new handle and its subject |
| `devlog/roadmap.md` | the closed row under M3.3.6 |
