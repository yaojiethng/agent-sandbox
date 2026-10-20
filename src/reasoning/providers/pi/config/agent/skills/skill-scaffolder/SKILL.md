---
name: skill-scaffolder
description: Automates the creation of a new agent Skill by generating directories and SKILL.md templates. Use when the user asks to create, scaffold, or clone a skill.
---

# Skill Scaffolder Workflow

You are an expert at creating reusable agent Skills. When the user asks to create or execute a "create skill" workflow, execute these exact steps.

## Workflow Steps

1. **Clarify Intent:** Ask the user what specific workflow, constraints, or task they want the new skill to specialize in.
2. **Determine Target Path:** Ask if this skill should be local to the current project or global.
   - Project Path: `skills/<kebab-case-name>/SKILL.md`
   - Global Path: `~/.pi/agent/skills/<kebab-case-name>/SKILL.md`
3. **Draft the Frontmatter:** Construct the mandatory YAML frontmatter using the exact template schema below.
4. **Draft the Content:** Generate descriptive, step-by-step instructions, examples, and constraints. Where the skill holds checks, place each one where its input exists, per [`principle-check-placement`](../principle-check-placement/SKILL.md).
5. **Write File:** Use file system tools to create the folder and write the final `SKILL.md` file automatically.

## Standard SKILL.md Output Template

The frontmatter below is a convenience copy of what the frontmatter gate requires; the gate is authoritative. The body's section shape is stated in `docs/development/prompt-authoring-conventions.md` `## The prompt and skill structure`, and this skill reads it there rather than restating it.

```markdown
---
name: <kebab-case-name>
description: <Clear explanation of when the agent should automatically trigger this skill>
---
```

## The body's sections

Take the section shape from `docs/development/prompt-authoring-conventions.md`. When that document is not reachable from the tree the skill is scaffolding, ask the operator for it rather than writing a shape from memory: a restated shape is the copy that drifts.

## How to Use the Generated Skill

1. Open chat.
2. Type `/` and select the new skill, or describe the task if the skill auto-triggers.
3. Prompt it with the intended task.
4. The agent runs the workflow, writes the file, and sets up the automation.
