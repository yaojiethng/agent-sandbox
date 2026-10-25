---
name: skill-scaffolder
description: Automates the creation of a new agent Skill by generating directories and SKILL.md templates, and reviews a skill against the bars it was written to. Use when the user asks to create, scaffold, or clone a skill, or to review one for rule loss and length.
---

# Skill Scaffolder Workflow

You are an expert at creating reusable agent Skills. When the user asks to create or execute a "create skill" workflow, execute these exact steps.

## Workflow Steps

1. **Clarify Intent:** Ask the user what specific workflow, constraints, or task they want the new skill to specialize in. When the new skill wraps a script or a command, read [`patterns/prose-entrypoint.md`](patterns/prose-entrypoint.md): the skill turns an underspecified intent into a call and stops at the command line; the script owns the call.
2. **Determine Target Path:** Ask where the skill is delivered from.
   - Every session, from the config home: `src/reasoning/providers/pi/config/agent/skills/<kebab-case-name>/SKILL.md`. The image seeds it to `$AGENT_HOME/agent/skills/` at every start.
   - Every session, from a module's payload: `workflow/<module>/skills/<kebab-case-name>/SKILL.md`.
   - This project only: `.agents/skills/<kebab-case-name>/SKILL.md`.

   Do not write in `$AGENT_HOME/agent/skills/` directly. The config home is seeded from the image at every start, so a file written there is lost on the next start, and no gate reads it while it lives.
3. **Draft the Frontmatter:** Read [`patterns/signposting.md`](patterns/signposting.md) first: the name and the description are the signpost that decides whether the body is ever loaded, so the word that leads is chosen before the template is filled. Construct the mandatory YAML frontmatter using the exact template schema below.
4. **Draft the Content:** Generate descriptive, step-by-step instructions, examples, and constraints. Where the skill holds checks, place each one where its input exists, per the `principle-check-placement` skill. When the content carries more than one kind, or a code-bearing form, split it per [`patterns/nested-patterns.md`](patterns/nested-patterns.md).
5. **Write File:** Use file system tools to create the folder and write the final `SKILL.md` file automatically.
6. **Offer the Review:** the review in [`runbook/review.md`](runbook/review.md) checks the skill against the rule-loss and length bars. Ask the operator whether to run it; dispatch it only on their word, and fix what it names before reporting the skill as done. The same runbook reviews an existing skill or a prompt that is about to change.

## Standard SKILL.md Output Template

The frontmatter below is a convenience copy of what the frontmatter gate requires; the gate is authoritative.

```markdown
---
name: <kebab-case-name>
description: <Clear explanation of when the agent should automatically trigger this skill>
---
```

## The body's sections

The body carries the sections its work needs; no fixed order is mandated. A short skill or prompt may carry none of them beyond the frontmatter above.

## Nested files

A skill may carry siblings beside `SKILL.md`. The `SKILL.md` index names each one and the situation that opens it; a sibling it does not name is never loaded.

| File | Open when |
|---|---|
| [`patterns/nested-patterns.md`](patterns/nested-patterns.md) | the content grows past one body and you must decide what stays inline and what becomes a sibling |
| [`patterns/prose-entrypoint.md`](patterns/prose-entrypoint.md) | the new skill wraps a script or a command with a fixed call shape |
| [`patterns/signposting.md`](patterns/signposting.md) | the new skill's name or description is being chosen, or an existing signpost is reviewed |
| [`runbook/review.md`](runbook/review.md) | a skill has just been written, or a skill or prompt is about to change, and it needs the rule-loss and length review |

## How to Use the Generated Skill

1. Open chat.
2. Type `/` and select the new skill, or describe the task if the skill auto-triggers.
3. Prompt it with the intended task.
4. The agent runs the workflow, writes the file, and sets up the automation.
