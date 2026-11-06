---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Capture the nested-pattern skill shape

## Objective

Write the skill shape the testing migration proved, a `SKILL.md` index over inline judgements and nested pattern files, as a skill-writing pattern under `skill-scaffolder`, and index it from the scaffolder's `SKILL.md`.

## Scope

Continues the interrupted iteration [`20261022-02-workflow-testing_policy_into_the_skill.md`](20261022-02-workflow-testing_policy_into_the_skill.md) at its pre-close gate.

An operator-directed sidequest. The testing migration split a 274-line policy into a skill whose `SKILL.md` carries four judgements and an index, with the code-bearing patterns under `patterns/` and a fill-in file under `assets/`. The shape worked, and it is a skill-writing pattern rather than a testing one. It belongs under `skill-scaffolder`, the skill that creates skills, so the next author meets it when shaping a new skill.

In scope: the pattern file under `skill-scaffolder`, and the index line and dispatch sentence in its `SKILL.md`.

Out of scope: the `testing` skill's content, the interrupted iteration's work, the `initialize` asset corpus, and any new gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The pattern states the index rule, the inline-versus-sibling split, the kind split, the size floor, naming and the lint facts | `grep -n '^## '` over the new file names each part | Agent [x] |
| The scaffolder names the pattern with its opening situation and dispatches from the content step | `grep -c 'patterns/nested-patterns.md' .agents/skills/skill-scaffolder/SKILL.md` prints 2 | Agent [x] |
| The worked example points at the `testing` skill | `grep -n 'testing'` on the new file names the link | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Nest the pattern under `skill-scaffolder` as a sibling, indexed from its `SKILL.md` | It is a skill-writing pattern, and the scaffolder is where a skill author starts; the sibling is the format's own dispatch | this record |
| The pattern records the shape, not the testing content | The testing examples are the worked instance; a skill-writing pattern outlives them | this record |
| No ADR and no roadmap row | The pattern's source of truth is the scaffolder skill, which is where a skill author starts; no milestone task claims it, and the write-back step states that as its outcome | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The scaffolder's body describes a single `SKILL.md` and no sibling files, so the nested shape it can now generate is stated nowhere | gap | an author following the scaffolder writes one long body and re-derives the split | fixed in this sidequest |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/skill-scaffolder/patterns/nested-patterns.md`](../../.agents/skills/skill-scaffolder/patterns/nested-patterns.md) | the skill-writing pattern: the index, the inline/sibling split, the size floor, naming and lint |
| [`.agents/skills/skill-scaffolder/SKILL.md`](../../.agents/skills/skill-scaffolder/SKILL.md) | the content-step dispatch and the `## Nested files` index |
