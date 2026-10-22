---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Two skills move into the bucket their dependencies live in

## Objective

Put `pi-bump` and `skill-scaffolder` in the scope their dependencies sit in, so each skill reads only what its own reader can open.

## Scope

A row this unit files and closes, **Two provider-root skills reach only this repository**. It is the file half of the reach rule whose statement is `:330` and whose citation consequence is `:343`; neither of those rows closes here.

`pi-bump` names `src/reasoning/providers/pi/base.dockerfile`, `scripts/lint/pi-extension-compat.mjs`, `devlog/changelog.md` and `bash scripts/lint.sh`. Every one is project-scoped, and the skill ships in every provider image. `skill-scaffolder` is the same shape: its own text says the frontmatter gate is authoritative, and that gate exists only in this repository.

Both moved to `.agents/skills/`. A skill's reach is its root's reach, so the move is the whole change to the reach declaration, and the promotion path back is the same move in reverse.

The seeding leaves a trap that no gate sees. `$AGENT_HOME/agent/skills/` is bind-mounted and seeded from the image at every start, so both skills had a copy there. A name two skills hold keeps whichever the loader finds first, so a stale seed would have shadowed the project copy. Both seeds are removed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both skills sit in the project bucket and neither sits in the provider root | `ls .agents/skills/` names `pi-bump` and `skill-scaffolder`; `ls src/reasoning/providers/pi/config/agent/skills/` names neither | Agent [x] |
| Neither seeded copy remains | `ls ~/.pi/agent/skills/` names neither | Agent [x] |
| No shipped document names a project skill at a path the seeded corpus lacks | `bash scripts/lint.sh` prints `Lint: clean`, and the linking gate is the one that reported it before the fix | Agent [x] |
| The scaffolder's body order resolves in the tree the skill now lives in | `grep -c "## Structure of a workflow document" .agents/skills/skill-scaffolder/SKILL.md` returns 1 | Agent [x] |
| The ledger still balances | `bash scripts/check_norm_ownership.sh --check` prints `clean across 139 row(s)` | Agent [x] |
| The umbrella and the suite are clean | `bash scripts/lint.sh` prints `Lint: clean`; `bash scripts/run_tests.sh` prints `1273 passed, 0 failed` | Agent [x] |

## Decisions

`skill-scaffolder`'s body order goes back to a pointer. In the previous pass it carried a labelled convenience copy, because at provider reach it could not read a project document. Moving it into the project tree removes that reason, and a copy where a pointer resolves is the duplication the corpus bans. The pointer was also wrong: it named `## The prompt and skill structure`, which no heading in that document matches.

`doc-advisor-policy.md` names the scaffolder without a path. The linking gate derives the seeded convention set from `workflow/coding-agent/skills/initialize/assets/conventions/`, so a shipped document may name a project skill at a path only when `initialize` seeds it. `skill-scaffolder` is not in that set, so the line states the skill by name and says why. Adding it to the seed corpus is the promotion path and a different row.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The shape gate reads `.agents/skills/` but polices only directories whose name carries `principle-`, so a project convention skill carries no shape contract | gap | two skills just entered that tree and nothing checks their body, while the provider root's non-principle skills are unchecked for the same reason | M3.3.3, whose pipeline owns the skill shape contract |
| The scaffolder wrote a project skill to `skills/<name>/SKILL.md`, a path no root in this tree carries | defect | a scaffolder that writes the wrong root produces a skill nothing loads. Corrected here to `.agents/skills/<name>/SKILL.md`, because it names the same root the move is about | fixed in this unit |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/pi-bump/`](../../.agents/skills/pi-bump/SKILL.md) | moved from the provider skill root with `git mv`; seeded copy removed |
| [`.agents/skills/skill-scaffolder/`](../../.agents/skills/skill-scaffolder/SKILL.md) | moved, body order returned to a pointer at the heading that exists, sibling link became a name, project skill root corrected; seeded copy removed |
| [`doc-advisor-policy.md`](../../src/reasoning/providers/pi/config/agent/prompts/doc-advisor-policy.md) | its scaffolder bar names the skill without a project path, with the reason the gate needs |
| [`devlog/roadmap.md`](../roadmap.md) | the row filed and closed with its carrier list |
