---
name: initialize
description: Install or update a project's convention-skills. Use when a project has no .agents/skills entries for the workflow, when a convention-skill is the seeded stub, or when the operator asks to set the workflow up on a project.
---

# initialize

## Purpose

The workflow reads and writes project content through **conventions**. A convention is a structure over a subset of content - the task list, the work log, the decision records, the docs, the git discipline, the testing convention, the evals. Each convention is served by a **convention-skill** the project owns, under `.agents/skills/`.

This skill installs and updates that set. The workflow ships a **default convention-skill corpus** in `assets/conventions/`, one directory per convention. Each shipped skill is a **stub**: its content states that a skill is expected, that what was found is a stub, and a few open questions offered without direction. The stub is a specific failure mode for the agent to reason over, not a default convention.

## When to run

- The project has no `.agents/skills/<convention>/` for a convention the workflow needs.
- A convention-skill is still the seeded stub, and the operator wants to fill it in.
- The operator asks to set the workflow up on a project, or to revisit a convention.

## Procedure

1. List the corpus at `assets/conventions/`, beside this skill. That list is the workflow's declaration of the conventions it expects.
2. For each convention, test whether `.agents/skills/<name>/` exists in the project.
3. **Absent** - install it: copy the corpus directory to `.agents/skills/<name>/`. Report it as seeded, and say that its content is a stub until the project states the convention.
4. **Present, still the stub** - report it as unstated. Offer the stub's questions; do not answer them for the operator.
5. **Present and written** - report it as stated. Change it only when the operator asks.
6. Report the set: stated, stubbed, and absent. A project with a stated skill for every required convention is equipped; one with gaps is not, and the gaps are what the agent reasons over.

## Boundaries

- **The workflow imposes nothing.** This skill installs the project's own skills. It does not enforce a convention, and it does not run as a gate; the agent reasons over a gap with the steering it has loaded.
- **The stubs are failure directions, not defaults.** They tell the agent what is missing. They do not state a convention the project did not choose.
- **Generating the project's actual conventions is out of scope.** The operator and the agent establish them. The stub's questions are offered, not answered.

## A convention may cover more than one structure

A convention can hold more than one structure. `work-log` carries two, `assets/handover.md` and `assets/discussion.md` beside its `SKILL.md`, because the work-unit record and the exploration record are two structures over one subset. A corpus directory may hold any number of files.
