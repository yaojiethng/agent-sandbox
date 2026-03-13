# Skill — Project Onboarding

## Role

You are onboarding a project into agent-sandbox. Your job is to produce the files that allow the sandbox to run against this project correctly.

All outputs are proposals. The operator reviews, adjusts, and copies them into the repository manually. You do not verify or run anything.

---

## Step 1 — Identify project shape

Read the **Project to Onboard** section below before proceeding.

| Project shape | Action |
|---|---|
| Obsidian vault | Read `workflow/knowledge-vault/onboarding.md` and follow it instead of this procedure |
| General project | Continue with Step 2 |

If a new project shape is encountered that warrants specific handling, flag it to the operator before proceeding. Do not invent a dispatch path that does not exist.

---

## Step 2 — System reference

agent-sandbox is a containerized sandbox and orchestration harness. The CLI command `agent-sandbox` is installed on the host via `make install` in the agent-sandbox repo.

Every onboarded project needs two files committed to its repo:

1. A `Makefile` that calls the `agent-sandbox` CLI with project-specific vars
2. An `agent_context_brief.md` that the agent reads at the start of each session

Key constraints:
- All paths must be WSL/Linux format (`/mnt/c/...` or `/home/...`). Never write Windows paths. Convert with: `wslpath 'C:\your\path'`
- The project must be a git repository with at least one commit
- `.workspace/` is created at project root by agent-sandbox at runtime
- Machine-specific vars (`SERVE_PORT`, `OPENCODE_SERVER_PASSWORD`) live in `.env` at the project root — never committed

---

## Step 3 — Produce files

### 1. `Makefile`

Follow `docs/_template/Makefile.template` exactly. Change only the three variables at the top. Place at project root.

### 2. `agent_context_brief.md`

Place at project root. Must be complete enough for a fresh agent to orient itself and begin work without further instruction.

```
# Agent Context Brief — <project-name>

## Project
<one paragraph: what the project is, what it does, its current state>

## Constraints
<project-specific constraints: coding standards, conventions, files not to touch>

## Output
<what good output looks like: expected file changes, patterns to follow>
```

---

## Project to Onboard

<!-- Fill in before handing to agent -->

**Project name:** <!-- e.g. my-project -->
**Project description:** <!-- what the project is and what it does -->
**Project location (WSL path):** <!-- e.g. /mnt/c/Users/you/Projects/my-project -->
**Project structure:** <!-- paste output of: tree <project-root> -L 2 -->
**Is the project already a git repo with at least one commit?** <!-- yes / no -->

---

## Output format

Produce each file as a separate fenced code block labelled with its filename. Do not combine files. Do not produce files not listed above.

---

## Verification checklist

- [ ] `PROJECT_NAME` in the Makefile matches the project name
- [ ] `AGENT_BRIEF` points to `agent_context_brief.md` (relative to project root)
- [ ] `agent_context_brief.md` contains enough context for a fresh agent to begin work
- [ ] `.workspace/` is in the project's `.gitignore` (note this, do not add it yourself)
- [ ] `.env` is in the project's `.gitignore` (note this, do not add it yourself)
