---
date: 2026-11-02
milestone: M3.3.3 - The skill maintenance pipeline
status: Closed
type: Implementation
---

# Handover - the scaffolder retires

## Objective

Leave one skill that authors prompts and skills. `skill-scaffolder` states what `instruction-authoring` now carries, so its last uncarried pattern moves beside the two that moved in row 1, the one routing rule its body holds is carried, and the directory dies with its carriers repointed.

## Scope

The roadmap row **`skill-scaffolder` retires into `instruction-authoring`**, in the task group **M3.3.3 - The skill maintenance pipeline**, section **The authoring surface it owns**.

The unit is one directory and the six live places that name it. `git mv` carries `patterns/prose-entrypoint.md` into the skill, which then names it in the index and in the step that decides what the artifact is. The routing rule that survives is a skill installed from upstream belongs to `skill-fork`, because a fork inherits its content rather than inventing it. Deleting the directory and repointing the carriers is the same unit: a tree with the skill gone and a live pointer into it is worse than either state.

**Out of scope, one sentence each.** Row 3 retires `docs/development/prompt-authoring-conventions.md`, whose two links are repointed here and whose rules are not. The move of `principle-prose-entrypoint-over-mechanism` out of the principle corpus is its own row, which keeps its decision and takes the new path. Seeding this skill into the provisioned corpus is its own open row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The pattern arrives by rename, its text untouched | `git show --stat HEAD` reports it as a rename, and `git log --follow` reaches the scaffolder's copy | Agent [x]: `git status` stages it as `R`, and it is the tree's only copy |
| The skill names the pattern it gained | `grep -c 'prose-entrypoint.md'` = 2 in `SKILL.md`, one in the index and one in the step | Agent [x]: 2, one in step 2 and one in the index |
| The installed-skill routing rule survives | `grep -c 'skill-fork'` in `SKILL.md` = 1, in the step that settles what the artifact is | Agent [x]: 1, in step 2 |
| The directory is gone | `test -d .agents/skills/skill-scaffolder` fails, and `git status` shows its four files deleted | Agent [x]: four deletions staged, no directory |
| No live file names it | `grep -rn 'skill-scaffolder' .agents docs workflow src scripts tests` prints nothing; closed roadmap rows and the handover chain keep their history | Agent [x]: 0 matches across the five roots; three closed rows and this chain keep theirs |
| The tree is green | `bash scripts/lint.sh` clean, and `bash scripts/run_tests.sh` shows no new failure | Agent [x]: lint clean across 19 gates; 1440 tests, 1440 passed, 0 failed |

## Decisions

| Decision | Why | Rejected |
|---|---|---|
| The pattern moves by `git mv` and its text is not touched | It is the unit's only arrival, and rewriting text while moving it makes the move unreviewable | a rewrite in the same commit, which would hide the move |
| The scaffolder's `SKILL.md` dies whole, by citation | Its path table, its `$AGENT_HOME` warning, its signpost rule, its body's freedom, its nested-file index and its review offer are in `references/skill-conventions.md` already. What is left teaches the operator pi's chat UI | carrying it into the sheet section by section, which restates the sheet inside the sheet |
| The installed-skill rule lands in the step that settles the artifact | It decides who writes the file, which is the same question as what the file is | the skill sheet, which is read for a skill's own rules rather than for which skill to use |
| The carriers repoint in the deleting commit | A live link into a deleted directory is a broken tree | a two-commit split with a broken tree between them |

## Decisions pending

None.

## Findings

| Finding | Evidence | Triaged to |
|---|---|---|
| The row's premise that two gate comments name the skill is stale | `grep -rn 'skill-scaffolder' scripts/` prints nothing, so the repoint list is carriers only | the row's closed form |
| Two future-roadmap sentences name the skill as a duplicate-declaration location and as the home of the `leitwort` field | `roadmap_future.md` lines 39 and 44 | this unit, text only |
| Two open rows name it as the future home of a principle and as a corpus member | `roadmap.md` lines 299 and 300 | this unit, text only |
| `project-documentation` defers the name rather than the fact | `references/organization.md:37` says the surface is "managed by the `skill-scaffolder` skill, a name this reference corrects at the rename and not before" | this unit; this is that rename |

## Completed

| Artifact | What it now holds |
|---|---|
| [`.agents/skills/instruction-authoring/SKILL.md`](../../.agents/skills/instruction-authoring/SKILL.md) | 45 lines. Step 2 gains the two routes the scaffolder's body held and the sheets did not: an installed skill is `skill-fork`'s, and one that wraps a mechanism stops at the command line. The index gains that pattern as its fifth file. |
| [`.agents/skills/instruction-authoring/patterns/prose-entrypoint.md`](../../.agents/skills/instruction-authoring/patterns/prose-entrypoint.md) | arrives by rename, its 43 lines untouched |
| [`.agents/skills/skill-scaffolder/`](../../.agents/skills/) | deleted: its `SKILL.md` and the three siblings it duplicated |
| six carriers | `project-documentation`'s organization reference no longer defers the rename; `skill-fork` hands on to the successor; `prompt-authoring-conventions.md` points both signposting links at the new path; two `roadmap_future.md` sentences name the successor; two open roadmap rows take the new path and one drops the word "scaffolder" from its title |
| this record | six criteria accepted, four decisions, four findings |

The scaffolder's description claimed "the steps, the signpost, the body and the file". What it carried that the skill did not was two routing sentences, and both are now the skill's.
