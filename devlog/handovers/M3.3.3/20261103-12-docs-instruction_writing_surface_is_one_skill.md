---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Documentation
status: Closed
---

# Handover - the instruction-writing surface is already one skill, split by format

## Objective

Confirm whether the merged instruction-writing surface the row describes still needs to be built, and close the row when the tree already carries it.

## Scope

In scope: the row's four claims, each read against the file that states it.

Out of scope: any rewrite of the four files, which are current; and the upstream statement of the general rule, which is vendored and is cited rather than edited.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One surface holds how an instruction is written | `instruction-authoring/SKILL.md` step 3 names the two format sheets and the shared body | Agent [x] |
| A format-specific rule lives under that format's sheet | `references/prompt-conventions.md` and `references/skill-conventions.md`, each named by the situation that opens it in the skill's index | Agent [x] |
| The Agent Skills format is covered | `skill-conventions.md` states the roots table and the frontmatter; `writing-for-agents` carries the format's information hierarchy, cited from it | Agent [x] |
| pi's loader and prompt commands are covered | `skill-conventions.md` states `disable-model-invocation`; `nested-patterns.md` states that the loader opens a sibling only on a matching task; `prompt-conventions.md` states prompt path resolution, frontmatter and arguments | Agent [x] |
| The OpenCode divergence is stated where a file satisfies both | `prompt-conventions.md` names `$ARGUMENTS`, and records that pi substitutes both spellings while OpenCode substitutes only that one, citing `instruction_surface_declaration.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| No merged document is written | The row was filed before `prompt-authoring-conventions.md` was folded into `instruction-authoring`; that fold is the merge it asks for, and a fifth document stating the same rules would be the copy the milestone removes | this record |
| Format-specific rules stay split by format | A writer arrives with one artifact, a prompt or a skill, and the sheet for that artifact is the file they open; a merged sheet makes them read the other format's rules to find theirs | `instruction-authoring/SKILL.md` step 3 |

## Decisions pending

None.

## Findings

- The row's end state named "the documents it replaces". Those are gone: `docs/development/prompt-authoring-conventions.md` is deleted and its rule lives in the skill's step 6; the `conventions.md` row that listed it is dropped.
- One carrier of the general rule survives outside this skill: `writing-for-agents` states "Every step ends on a completion criterion". It is vendored, so the local test that decides a criterion is stated in `forms.md` item 4, and the prompt sheet points there rather than repeating the absolute.

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | the row is closed; no artifact changed |
