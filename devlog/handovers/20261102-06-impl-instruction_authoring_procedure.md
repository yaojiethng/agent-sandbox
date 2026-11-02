---
date: 2026-11-02
milestone: M3.3.3 - The skill maintenance pipeline
status: Closed
type: Implementation
---

# Handover - the authoring skill is a procedure

## Objective

Give the one authoring skill the shape of the work: the steps a writer runs, in the order they run them. The judgement row 1 wrote is kept, the index keeps one row per file, and the vocabulary the repository does not define leaves the text.

## Scope

The roadmap row **`instruction-authoring` is a procedure, not an index**, in the task group **M3.3.3 - The skill maintenance pipeline**, section **The authoring surface it owns**. It lands before the retirement row, so that row retires into a skill worth retiring into.

The unit is one `SKILL.md` and the two sheets' body sections. The five steps take `skill-scaffolder`'s sequence, cut to what is mandatory, and each carries the judgement that decides it: one purpose, the reach rule, the type and the frontmatter keys, the body's rules, the title and description written last from the body, then the review. The two principle citations the scaffolder's body holds move into the sheets, beside the body rules they govern, so nothing is lost when its directory goes.

**Out of scope, one sentence each.** Retiring `skill-scaffolder` is the next row, which moves its remaining pattern and repoints its seven carriers. The two sheets' rules are not rewritten here, only reordered and added to where a step needed a home. `nested-patterns.md`'s missing `runbook/` row and the tree's two spellings of that directory are findings below, not this row's work.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The front door opens with the steps, not with a table | `sed -n '/^## /p'` shows `## Draft in this order` as the first section, and `grep -c '^[0-9]\. \*\*'` gives 5 | Agent [x]: line 10 is `## Draft in this order`, 5 steps |
| Reach is stated once, beside the purpose, and cites the rule it applies | `grep -c 'documentation_taxonomy.md#reach'` = 1, inside step 1 | Agent [x]: 1 occurrence, on line 12, in step 1 |
| The vocabulary the repository does not define is gone | `grep -c 'carrier'` and `grep -ci 'sheet'` are both 0 in `SKILL.md` | Agent [x]: 0 and 0 |
| Every carried file is named once, and named for what it holds | five index rows over the five files `find` prints, no file named twice as a table row | Agent [x]: 5 rows, 5 files |
| The scaffolder's non-mandatory prescriptions are absent | `grep -c 'step-by-step instructions'` and `grep -c 'How to Use'` are both 0 | Agent [x]: 0 and 0 |
| The two citations survive the restructure, stated once | `grep -c 'principle-check-placement'` and `grep -c 'rewrite-syntax-never-semantics'` each = 1 in `SKILL.md` and 0 across the two sheets | Agent [x]: 1, 1, and 0, 0 |
| The tree is green | `bash scripts/lint.sh` clean, and `bash scripts/run_tests.sh` shows no new failure | Agent [x]: lint clean across 19 gates; 1440 tests, 1439 passed, 1 failed - `test_select_session_state_and_age_columns`, which passes alone at 37/37, the parallel-load class AGENT_FEEDBACK records |

## Decisions

| Decision | Why | Rejected |
|---|---|---|
| The steps are the scaffolder's sequence with its prescriptions cut | That sequence is a procedure a reader runs, which the front door was not; its non-mandatory lines were what made it fat | a rewrite from first principles, which would re-solve a shape already in the tree |
| The type follows from what the artifact must do | A model firing it unnamed, and files beside the body, are properties of the work; a format chosen by taste is a coin toss | "prompt or skill?" as a question put to the reader |
| Reach is stated as the rule, in the purpose step | Purpose decides the audience and the audience decides the root, so a separate placement step asked the same question twice | a table of three roots with no rule behind it |
| The title and description are written last | The body is usually a distilled workflow or a persisted prompt, so the signpost is a summary of what the body turned out to do | choosing the name first, from an intent that has not yet been drafted |
| `carrier` and `sheet` leave the text | `carrier` is defined in the glossary as a file that states dispatch behaviour in prose (`terminology.md:251`), so the word I used for prompt-versus-skill collided with a defined one; `sheet` is defined nowhere | keeping either as shorthand, with a definition added, which would spend a glossary entry on a synonym |
| The two principle citations move into the sheets | They govern a body's wording, and the sheets hold a body's rules; a step that recited them was the index-not-procedure defect in miniature | dropping them with the scaffolder |

## Decisions pending

None. The retirement row is scoped already, and the two findings below are filed as rows of their own.

## Findings

| Finding | Evidence | Triaged to |
|---|---|---|
| `nested-patterns.md` types three siblings and the tree carries four | its table has `patterns/`, `assets/` and `references/`; this skill and `project-documentation` also carry a `runbook/`, so the table a writer consults cannot name the directory they need | a roadmap row, unfiled |
| The tree spells that directory two ways | `runbook/` in two skills, `runbooks/` in `project-documentation`, and its links depend on the spelling | the same row, unfiled |
| The retirement row's premise that two gate comments name the skill is stale | `grep -rn 'skill-scaffolder' scripts/` prints nothing | the retirement row's closed form |
| `prompt-authoring-conventions.md` states the frontmatter key set that step 2 now applies | `## Structure of a workflow document` holds the description, argument hint, skill frontmatter and leitwort rules | row 3, which retires it into these files |

## Completed

| Artifact | What it now holds |
|---|---|
| [`.agents/skills/instruction-authoring/SKILL.md`](../../.agents/skills/instruction-authoring/SKILL.md) | 44 lines. Five steps in the order the work happens: purpose with the reach rule beside it, type and frontmatter as decisions, the body with its two citations, then the title and description written from the body, then the review. Below them one index of five files and one vocabulary table whose closing line says why nothing gates the choice. |
| [`devlog/roadmap.md`](roadmap.md) | the row for this unit, above the retirement row, and the closed row's label aligned from "both carriers" to "both artifacts" because the word is retired |
| this record | six criteria accepted with the command and its result, six decisions, five findings each with a destination |

The two sheets are byte-identical to their state at `c30f8569`: the citation line was written into both and withdrawn, because one sentence in two files is the duplicate this skill exists to catch. It is stated once, in step 3.
