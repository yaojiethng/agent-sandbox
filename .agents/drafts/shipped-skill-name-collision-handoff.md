---
description: "Handoff - report a skill name an added package shares with a skill this repository ships, at session start. Report it; do not filter it, and do not rewrite an installed package to protect a name."
argument-hint: "[scope note, e.g. where the report surfaces - optional]"
---

> $ARGUMENTS

# Handoff - report a shipped skill name an added package also holds

## What the next session is for

When a project adds a skill package that holds a name this repository also ships, the session must say so. Today it does not: pi's loader silently keeps the first skill it reached and records the loser as a diagnostic nobody reads, so a skill can stop being the one we ship without a single line of output.

Delete this file when the task lands.

## Where things stand

Nothing reports this. `scripts/skill_map.mjs` already treats a layer collision as a hard finding at review time, and it does so by loading the layers with pi's own loader -- read it before writing a second resolver, because it is the existing answer for the shipped layers and the missing half is only the added packages.

The loader's behaviour, which the report must follow rather than fight:

| Behaviour | Detail |
|---|---|
| Order | user skills directory, then the project skills directory, then each package path in settings order |
| Rank | the first skill holding a name wins; later ones are dropped |
| Signal | a diagnostic of type `collision`, carrying `winnerPath`, `loserPath` and the name |

Evidence: `node_modules/@earendil-works/pi-coding-agent/dist/core/skills.js`, `loadSkills`.

## Suggested skills

| Skill | Why this session needs it |
|---|---|
| `principle-delegation-over-machinery` | the loader already decided the winner, so the task is to surface a decision, not to reimplement it |
| `testing` | the report is behaviour and needs a fixture with two skills of one name |

## What the report has to do

1. **Name both paths.** The shipped path and the added path, and the skill name. A reader must be able to tell which artifact they would have to change.
2. **Report, never mutate.** Do not delete directories from an installed package, do not reorder the settings, do not rename the shipped skill. Reporting is the durable answer and the bytes are not ours.
3. **Surface it where the session starts**, not only in a log file, and say in the record which surface you chose and why.
4. **Fail nothing that a reader cannot fix.** A collision is a fact about the project's configuration; the operator resolves it by changing their package list.

## Done when

- Two skills of one name, one shipped and one added, produce a report naming both paths, with a test proving it.
- A session with no collision reports nothing, so the report does not become noise.
- `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean.

## Do not resurrect

An install-time filter that removes the shipped names from an installed package. It was designed, built and withdrawn on 2026-10-31: it mutates bytes this repository did not author to defend a rank the loader had already applied, and the collision diagnostic makes it unnecessary.
