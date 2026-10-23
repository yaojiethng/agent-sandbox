---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - The judgement corpus, its signpost, and the communication links

## Objective

Make the judgement corpus match the authoring convention's `disable-model-invocation` rule, move the skill-name judgement into the skill-writing procedure so it is not loadable on its own, and link every communication principle where the provider layer lists it.

## Scope

The roadmap row **The judgement corpus disagrees with its own `disable-model-invocation` rule**, under M3.3.2, with two operator directives taken in the same unit.

Arm A of the row: the seven judgement skills lose the field, so the tree matches the stated rule. The two quality skills keep it, because the operator fires them deliberately. Item two is one of the seven: `principle-skill-signposting` is used only when a skill is written, so it becomes a pattern of `skill-scaffolder` rather than a loadable skill. Item three links the fourteen `communication-principle-*` skills in the provider `AGENTS.md`, in both the repository source and the installed copy.

Out of scope: the two quality skills' field, and the authoring convention's rule text, which needs no change once the corpus follows it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No judgement skill sets the field | the row's `grep`, filtered to `(communication-)?principle-`, returns nothing; the unfiltered grep returns the two quality skills only | Agent [x] |
| Signposting is not a loadable skill | `ls` fails on `src/reasoning/providers/pi/config/agent/skills/principle-skill-signposting` and on `$AGENT_HOME/agent/skills/principle-skill-signposting`; `skill-scaffolder` names the pattern in its nested-files table | Agent [x] |
| Every communication principle is a link in the provider layer | the link targets in `AGENTS.md` resolve to each of the fourteen `communication-principle-*` directories, in the repository and the installed copy | Agent [x] |
| The umbrella holds | `bash scripts/lint.sh` clean, `bash scripts/run_tests.sh` green | Agent [x] |

## Decisions

- **Arm A, on operator direction.** The convention's reason is that a writer reaches for a judgement mid-draft, and the field only hides a skill from automatic selection; the prompts cite these skills by path anyway.
- **Signposting belongs to the procedure that writes a skill.** The judgement answers a question that only arises while a skill's name and description are being written, so it is a pattern under `skill-scaffolder`, and no reader loads it outside that procedure.
- **The provider layer links the corpus it lists.** A name in a code span makes the reader construct a path; a link is the path.

## Decisions pending

None.

## Findings

- **The provider layer named the corpus without linking it.** Every communication principle sat in a code span, and a template line told the reader to build the path. The section now links each one, and the template line is gone because it had nothing left to name.

## Completed

| File | Change |
|---|---|
| six judgement skills | `disable-model-invocation: true` removed |
| `skill-scaffolder/patterns/signposting.md` | the signposting judgement, moved from the shipped corpus |
| [`skill-scaffolder/SKILL.md`](../../.agents/skills/skill-scaffolder/SKILL.md) | the pattern named where the frontmatter is drafted |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the fourteen communication principles linked |
| [`prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | the two citations retargeted |
| [`roadmap_future.md`](../roadmap_future.md) | the leading-word row retargeted |
| [`devlog/roadmap.md`](../roadmap.md) | the row ticked |
| `$AGENT_HOME/agent/` | the six field removals, the signposting removal and the linked `AGENTS.md` applied to the installed copy |
