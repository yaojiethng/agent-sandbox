---
name: instruction-authoring
description: "Writing or reviewing a prompt or a skill: settle its purpose and who must read it, its type and frontmatter, write the body, then the title and description a reader routes on. Use when authoring, reviewing or placing one."
---

# instruction-authoring

A prompt or a skill is written in one order, and this is it. Where a step needs more than a line, it names the file that holds the rest.

## Draft in this order

1. **Settle the purpose, the concern and the reach.** An artifact carrying two purposes is two artifacts, and `principle-own-the-scope-you-declare` with `communication-principle-keep-a-subject-near` holds that judgement. The purpose decides who must read it, and that decides the root: every session reads it, so it goes into the image, as the provider's config when it is the runtime's own or as a module's payload when a module's enablement should gate it; this project only, so `.agents/skills/`. Reach and delivery are two facts, per [`documentation_taxonomy.md`](../../../docs/reference/documentation_taxonomy.md#reach). Never `$AGENT_HOME/agent/skills/`, which the image reseeds at every start.

2. **Settle the type and the frontmatter.** A model must fire it without being named, or it must carry files beside its body: a skill, a directory. Neither, and it is a prompt, one file the operator starts by name, and the smaller format. A judgement that applies to any text makes it a principle skill, `principle-` in the name, with the six-part body at [`principle_skill_shape.md`](../../../docs/adr/principle_skill_shape.md). A skill only the operator fires carries `disable-model-invocation: true`, and a judgement skill never does, because a writer reaches for one mid-draft. A prompt taking an argument states its shape in `argument-hint` and forwards the text with `> $ARGUMENTS`. A leading word, when one earns it, is `metadata: leitwort:`, and `communication-principle-maximize-conceptual-leverage` chooses it.

3. **Write the body.** A prompt's rules are [`prompt-conventions.md`](references/prompt-conventions.md) and a skill's are [`skill-conventions.md`](references/skill-conventions.md). A body carrying more than one kind, or a code-bearing form, splits into siblings per [`nested-patterns.md`](patterns/nested-patterns.md), and the `SKILL.md` names each one, or nothing loads it. Where the clauses come from the operator, the meaning is theirs and the arrangement is the drafter's, per `communication-principle-rewrite-syntax-never-semantics`, and a check goes where its input first exists, per `principle-check-placement`. A document that reads or writes this project's records opens with `## Project conventions`.

4. **Write the title and the description last, from the body.** The description is the only text a model holds when it decides to load the rest, so it states what the body does and the words a reader would arrive with, per [`signposting.md`](patterns/signposting.md). A skill the model cannot fire has its description read from the operator's list, so that one is written for the operator. The title names the subject, not the mechanism.

5. **Review it.** [`review.md`](runbook/review.md), on the operator's word, and fix what it names before the work is called done.

## What this skill carries

| File | Holds | Open when |
|---|---|---|
| [`references/prompt-conventions.md`](references/prompt-conventions.md) | the rules a prompt follows | the artifact is a prompt |
| [`references/skill-conventions.md`](references/skill-conventions.md) | the rules a skill follows, and the shape a judgement one takes | the artifact is a skill |
| [`patterns/signposting.md`](patterns/signposting.md) | how to choose a name, a title and a description | step 4 |
| [`patterns/nested-patterns.md`](patterns/nested-patterns.md) | what stays inline and what earns a file | the body outgrows one |
| [`runbook/review.md`](runbook/review.md) | the rule-loss and length review | step 5 |

## The five kinds

The sentences an agent writes fall into five kinds, and the kind decides what the writer owes.

| Kind | What it means for the writer |
|---|---|
| `rule` | Clear, deterministic logic and a verifiable outcome. Where a machine can decide it, represent it as code or as a gate rather than as prose. |
| `fact` | Presented alongside its evidence. An assertion without evidence is a claim. |
| `judgement` | The instruction states the criteria and the handling method a gate would apply, and the agent is trusted to execute them. |
| `permission` | A suggestion - "usually we do this" - and whether to take it up is the agent's. Suggested practice and conventions read as permissions, not as rules. |
| `claim` | Verified before anything treats it as a fact. |

Nothing gates the choice: the five answer whether the mechanism fits the problem, and a reviewer who disagrees says so in prose. The definitions are [`terminology.md`](../../../docs/reference/terminology.md#modality), and the derivation is [`instruction_modality.md`](../../../docs/adr/instruction_modality.md).
