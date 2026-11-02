---
name: instruction-authoring
description: "Writing or reviewing a prompt or a skill: where one is placed, named and given frontmatter, what its body may assume, and the five kinds a sentence can be with what each owes the writer. Use when authoring, reviewing or placing a prompt or a skill."
---

# instruction-authoring

An instruction in this repository is a prompt or a skill. Each carries one purpose and one concern: a draft that does two things is two documents. `principle-own-the-scope-you-declare` and `communication-principle-keep-a-subject-near` hold that judgement, and this skill supplies the vocabulary for the sentences inside.

## The five kinds

The sentences an agent writes fall into five kinds, and the kind decides what the writer owes.

| Kind | What it means for the writer |
|---|---|
| `rule` | Clear, deterministic logic and a verifiable outcome. Where a machine can decide it, represent it as code or as a gate rather than as prose. |
| `fact` | Presented alongside its evidence. An assertion without evidence is a claim. |
| `judgement` | The instruction states the criteria and the handling method a gate would apply, and the agent is trusted to execute them. |
| `permission` | A suggestion - "usually we do this" - and whether to take it up is the agent's. Suggested practice and conventions read as permissions, not as rules. |
| `claim` | Verified before anything treats it as a fact. |

The five are defined in the glossary, [`terminology.md`](../../../docs/reference/terminology.md#modality); how they are derived, and why nothing gates them, is [`instruction_modality.md`](../../../docs/adr/instruction_modality.md) and the citation it rests on.

## Which carrier you are writing

| You are writing | The shape | Its sheet |
|---|---|---|
| a file the operator or a model starts by name | a prompt: steps, reference or both, and frontmatter carrying `description` | [`references/prompt-conventions.md`](references/prompt-conventions.md) |
| a directory a reader opens by name | a `SKILL.md` plus the siblings it names | [`references/skill-conventions.md`](references/skill-conventions.md) |

A judgement that more than one document uses lives in a `principle-` skill, so one source serves them all, and that is the only case where a judgement leaves the document that produces it. Which document owns a rule is `principle-single-source-of-truth`'s to state.

## Draft in this order

1. Check that the draft carries one purpose and one concern; if it carries two, it is two documents.
2. Choose the carrier from the table, and open its sheet.
3. Write the body to that sheet's conventions, and name every sibling you create.
4. Where a sentence reads as the wrong kind of thing, name its kind from the five above and pay what that kind owes.
5. Send the result to [`runbook/review.md`](runbook/review.md) when the operator asks for the review.

## What this skill carries

| File | Open it when |
|---|---|
| [`references/prompt-conventions.md`](references/prompt-conventions.md) | the artifact is a prompt |
| [`references/skill-conventions.md`](references/skill-conventions.md) | the artifact is a skill |
| [`patterns/signposting.md`](patterns/signposting.md) | you are choosing a name and a `description` |
| [`patterns/nested-patterns.md`](patterns/nested-patterns.md) | you are deciding what stays inline, what earns a file, and what a `SKILL.md` must index |
| [`runbook/review.md`](runbook/review.md) | a prompt or skill was just written, and the operator asked for its review |

## The project conventions block

A document that reads or writes this project's records opens its body with `## Project conventions`: one sentence naming the path a convention is read at and what to do when one is missing or is still the seeded stub, then the conventions it runs, each as a code span. Name only those it runs - `task-list` and `work-log` for a procedure that marks tasks and records them, and nothing else - because a list of every convention teaches a reader that the list is decoration.

## Why this cannot be a gate

Nothing here is gated, because the five answer whether the mechanism fits the problem, and that is a judgement about the draft rather than a property a check can read. There is no ledger and no count: the five are applied by the writer, and a reviewer who disagrees says so in prose.
