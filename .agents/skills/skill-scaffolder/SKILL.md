---
name: skill-scaffolder
description: Automates the creation of a new agent Skill by generating directories and SKILL.md templates. Use when the user asks to create, scaffold, or clone a skill.
---

# Skill Scaffolder Workflow

You are an expert at creating reusable agent Skills. When the user asks to create or execute a "create skill" workflow, execute these exact steps.

## Workflow Steps

1. **Clarify Intent:** Ask the user what specific workflow, constraints, or task they want the new skill to specialize in.
2. **Determine Target Path:** Ask where the skill is delivered from.
   - Every session, from the config home: `src/reasoning/providers/pi/config/agent/skills/<kebab-case-name>/SKILL.md`. The image seeds it to `$AGENT_HOME/agent/skills/` at every start.
   - Every session, from a module's payload: `workflow/<module>/skills/<kebab-case-name>/SKILL.md`.
   - This project only: `.agents/skills/<kebab-case-name>/SKILL.md`.

   Do not write in `$AGENT_HOME/agent/skills/` directly. The config home is seeded from the image at every start, so a file written there is lost on the next start, and no gate reads it while it lives.
3. **Draft the Frontmatter:** Construct the mandatory YAML frontmatter using the exact template schema below.
4. **Draft the Content:** Generate descriptive, step-by-step instructions, examples, and constraints. Where the skill holds checks, place each one where its input exists, per the `principle-check-placement` skill.
5. **Write File:** Use file system tools to create the folder and write the final `SKILL.md` file automatically.

## Standard SKILL.md Output Template

The frontmatter below is a convenience copy of what the frontmatter gate requires; the gate is authoritative.

```markdown
---
name: <kebab-case-name>
description: <Clear explanation of when the agent should automatically trigger this skill>
---
```

## The body's sections

The body's order is in `docs/development/prompt-authoring-conventions.md` `## Structure of a workflow document`, which lists the parts a skill carries and the parts that only a prompt carries. This skill lives in the project tree, so that document resolves wherever the skill runs.

## How to Use the Generated Skill

1. Open chat.
2. Type `/` and select the new skill, or describe the task if the skill auto-triggers.
3. Prompt it with the intended task.
4. The agent runs the workflow, writes the file, and sets up the automation.
