---
date: 2026-10-27
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - Ruling the two AGENTS.md layers against one ownership criterion

## Objective

Give both `AGENTS.md` layers a stated ownership criterion and a subject table, rule every section of both against it, and land a check that fails a section placed in the wrong layer, so that the always-loaded surface stops being governed by a paragraph inside a path table.

## Scope

Continues the instruction-surface work this session opened, measured at [`20261027-report-draft-surface_census.md`](../discussions/20261027-report-draft-surface_census.md).

The set is every `##` section of both layers: 14 in the project layer, 6 in the provider layer, 20 in all. Each ends in one ruling: keep, move, split, merge or shrink. The criterion, the ruling classes and the subject table live in [`instruction-surface-conventions.md`](../docs/development/instruction-surface-conventions.md) `## The layers`, which already owns the layer split; each layer states its subject in one sentence and points there.

The wording pass joined the scope during the iteration on operator direction: every line of both files was reread asking whether a session that had read only that file could act on it. `## Two surfaces` in `instruction-surface-conventions.md` states the rule the pass applied and the one it left for the maintainer.

Out of scope: the four instruction-defect classes and their detectors, which are filed as their own roadmap row; the index-budget gate over layer lines and description characters, which is the census row promoted rather than built here; and any rewrite of a sentence a ruling moves, since a placement change that also rewrites is not reviewable.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The project layer's `## Scope` tells a session editing either file where to read first, by a chapter link, and states no ownership test of its own; the provider layer's names only its paths | the pointer line with its anchor, and no ownership sentence in either | Agent [x] |
| The criterion, the five ruling classes, the subject table and the reader test are in `instruction-surface-conventions.md` `## The layers` | the section read against the table | Agent [x] |
| Every level-two heading in both layers has a table row naming its own layer, 18 of 18 | `bash scripts/check_instruction_surfaces.sh` reports clean | Agent [x] |
| The check refuses both ways: a heading with no row, and a row naming the other layer | `bash tests/test_instruction_surfaces.sh` asserts both refusals | Agent [x] |
| Every section carries exactly one ruling, recorded | the `## Rulings` table holds 18 rows | Agent [x] |
| No rule is lost by a move: each moved block is found at exactly one path | per-block grep, output shown at pre-close | Agent [x] |
| The two provider copies stay identical | the same check compares them | Agent [x] |
| No line in either working-surface file names an architecture the session has not chosen, and each reads cold | `grep -c 'layer\|surface'` returns only the pointer filename, the product name and the verb | Agent [x] |
| Every decision this iteration records is realized in the files | each Decisions row maps to a line on disk | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The criterion, the ruling classes and the subject table live in `instruction-surface-conventions.md` `## The layers`; each layer points there and states no test of its own | a criterion judges how the surface is filed, which is no part of the work a session does, so in a layer it is a rule the working agent can act on nowhere; `principle-own-the-scope-you-declare` prescribes linking to the owning document ahead of moving content, and the two reach points are a pointer in `## Scope` and the check's failure message | this handover; that section |
| A layer states its subject in one sentence; a rule about where sections belong is maintenance material | the dividing test is whether the working agent can act on the sentence during the work, which the subject sentence passes and a filing rule fails | this handover; that section |
| The ownership check extends `scripts/check_instruction_surfaces.sh` rather than adding a script | it already reads both layer tables and the `session` rows, so a second script over the same two files is a copy of one check | this handover |
| The check keys on `##` headings against a subject table | headings are mechanical to extract and the table is the only judgement it needs | this handover |
| A split section's sentences move without being rewritten | a placement change that also rewrites cannot be reviewed | this handover |
| A tool-specific caveat leaves the layer; the general rule stays where it is owned | the tool surface changes faster than the layer: the `edit`-versus-`sed` paragraph was written for one harness and the codemode path made its preference untrue, while record writes are already held by `iter.md` line 156 and a tree edit is checked by the diff the close reads | this handover; `file-content.md` `p-58` |
| A working-surface line is read cold, so a term the session cannot use is a defect in it | the two files are the first thing a session reads and the only thing it reads before working; a word like 'layer' asks it to resolve a distinction it has no way to resolve, and the cost is paid on every session | this handover; `instruction-surface-conventions.md` `## Two surfaces` |
| The two provider copies are compared by the same check | the layer says they must not diverge and nothing measures it | this handover |
| The rows and this handover stay under M3.2.2 | its charter is the audit and review of this surface, and the filing rule puts an iteration's decisions under the active sub-milestone; the rows refile at M3.2.2's close if they outlive it | this handover; the roadmap front matter unchanged |
| The design record is absorbed and deleted | the criterion-in-each-layer decision it was built on is overturned, the rule now governing design records makes one operator-directed, its surviving decisions are the rows above, and no other file cites it | this handover, after the deletion |

## Decisions pending

None.

## Rulings

Every level-two section of both layers, one ruling each. The classes and the criterion are in [`instruction-surface-conventions.md`](../docs/development/instruction-surface-conventions.md) `## The layers`.

| Section | Layer | Ruling | Why |
|---|---|---|---|
| `Scope` | provider | keep | opens by naming what the session is running inside and lists the resources that harness exposes; a project on this image cannot edit the file, so it needs no ownership pointer |
| `The Container` | provider | keep | the two containers and the tool set, and it took the three rules that only the project layer carried; renamed from `Agent Harness`, which named an architecture the session never chose |
| `Write Discipline` | provider | split | the wrap rule and the `.scratchpad/` rule name project conventions, and a tool list is not write discipline |
| `Communication Standards` | provider | keep | eleven one-line claims over the principles they link; the index is the cheap form |
| `Read Discipline` | provider | move, then shrink to two sentences | it came from the project layer, where nothing in it named this tree; the command recipes are procedure the agent derives, and the exceptions are kept |
| `Fresh Subagent Invocation` + `Running Review Subagents` | provider | merge into `Subagents` | one subject in two sections: the bare `pi -p` form, and the review as a dispatch with seats. The form, the steps and the failure rules belong to the `dispatch` skill, so the merged section states only what shapes a job: a role and never a model, seats make a review, a reviewer is read-only, attribution rides in the brief |
| `Scope` | project | keep | opens by naming the project the session is working on and lists its working directories, then points at the editing conventions |
| `System` | project | keep | describes the product this repository builds |
| `Role` | project | shrink to one clause | nothing cited it, and each paragraph is owned where the agent goes: design by `plan.md` and this step, development by `/iter` Step 6 and `git-discipline`, the audit shape by `## Output Format`. The live sentence, that a design settles an incomplete milestone first, moved to `## Iteration Lifecycle`; the rest was a taxonomy of stances an invoked agent never selects from |
| `Instruction Surface` | project | keep | five steering rules no other file states; the mechanism they name is a filed row. Moved below `Collaboration Protocol`, so a reader meets what it must not do and how work is done before how the instruction text is kept in budget |
| `Constraints` | project | split | three container rules left for the provider layer; git hygiene and the review-ready definition stay |
| `Collaboration Protocol` | project | keep | every rule cites a roadmap, ADR or work-log convention of this tree |
| `Propagation Discipline` | project | keep | points at a project skill |
| `Feedback and Gotchas Record` | project | keep | a project record |
| `Model Recommendations` | project | shrink | it keeps the table, the tags and the operator's ownership of the values; the resolve, pass and confirm procedure moved to the `dispatch` skill, which is what invokes it |
| `Output Format` | project | keep | one clause of `docs` duplication, already a pointer |
| `Missing Documents` | project | keep | cites the docs convention |
| `Iteration Lifecycle` | project | keep | this repository's protocol, and it absorbed the provider layer's duplicate of the one-commit rule |
| `Iteration Start` | project | keep | the reading list |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The layer heuristic flagged five sections and three were wrong (`System` and `Scope` are correctly the project's; project `Model Recommendations` is deliberately split with the provider layer's dispatch rules) | finding | a detector tuned on this heuristic would file wrong rulings | this iteration; the gate replaces the heuristic |
| The wrap rule is stated in the provider layer and again in the `docs` convention, which the provider line then cites: one real cross-layer paraphrase duplicate the lexical test could not see | defect | the one duplication class that costs behaviour, and nothing detects it | this iteration's `shrink` ruling on `Write Discipline` |
| The operator interrupted this iteration with a sidequest: the design-document demand in `/iter` Step 3 is unreachable by construction and contradicts the `work-log` convention that owns the design record | steering | scope of the interrupted iteration unchanged; the sidequest owns the fix | [`20261027-02-workflow-design_document_restriction.md`](20261027-02-workflow-design_document_restriction.md) |
| The mandatory design document in `/iter` Step 3 has no recorded decision behind it: `12dba54e` (handover `20260928-07`) mirrored it from the retired `iteration_policy.md` minor-loop table, `3a2890c7` reformatted it, and no ADR entry establishes it. Its skip clause requires the roadmap row to already carry resolved decisions, which a fresh row never does, so the default is inverted and `/plan` own grain is duplicated | defect | every iteration pays a design record: 19 exist since 2026-10-14 and 13 carry no status line at all | roadmap row filed under M3.2.2 |
| Shrinking `Running Review Subagents` removed the only place the provider layer named `model-recommendations.md`, and `Fresh Subagent Invocation` still pointed at a `**Which model.**` section the same edit deleted | defect | a shrink can take a rule the section was not about, and a dangling pointer survives a gate that only counts headings | the suite caught it; the role table is named in `Fresh Subagent Invocation`, which now also delegates the dispatch form to the skill |
| The `edit`-versus-`sed` paragraph in the provider layer has no recorded decision behind it: it entered with `3c06c7dc`, which bundled three unrelated rules into one commit, and no ADR states it; its preference is already untrue for a codemode call | defect | a tool-specific rule in the always-loaded layer rots when the tool surface moves, and nothing detects the rot | deleted from the layer; the durable part is the bash pattern `p-58` |
| The first design stated the criterion in both layers and carried the subject table in the layer it governs, which is a rule about the corpus loaded into every session | defect | confounds the set a working agent reads with material for the reader who files the next rule, and pays 20 table rows of always-loaded budget for it | overturned at the scope gate; the placement decision above carries the principle and the reader test |
| 134 of 550 sessions open two instruction files on the same subject, and 154 operator turns are corrections | measurement | the cost is choice and correction, not document count, which is why this iteration rules ownership rather than trimming text | [`20261027-report-draft-surface_census.md`](../discussions/20261027-report-draft-surface_census.md) |

## Completed

| File | Change |
|---|---|
| [`AGENTS.md`](../AGENTS.md) | twelve sections ruled; the three container rules left for the provider file; the scratch rule and the editing pointer in; `Role` deleted and its live clause moved; `Instruction Surface` moved below `Collaboration Protocol`; every line reread cold |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../src/reasoning/providers/pi/config/agent/AGENTS.md) | six sections ruled; three container rules, the tool set and the reading rule in; `Write Discipline` split; the two dispatch sections merged into `Subagents`; `Agent Harness` renamed `The Container`; `Scope` reframed as the resources the harness exposes |
| `$AGENT_HOME/agent/AGENTS.md` and `$AGENT_HOME/agent/skills/dispatch/SKILL.md` | synced from the repository source; the check proves they match |
| [`docs/development/instruction-surface-conventions.md`](../docs/development/instruction-surface-conventions.md) | `## Two surfaces`, the criterion and its test, the ruling classes, the editing conventions, the stand-in assumption, the 18-row subject table, the gate's claim |
| [`docs/SKILL.md`](../.agents/skills/docs/SKILL.md) | `## Drafting` gained the voice rule |
| [`SKILL.md` for `dispatch`](../src/reasoning/providers/pi/config/agent/skills/dispatch/SKILL.md) | the resolve, pass-verbatim and confirm sequence the skill is the home for |
| [`file-content.md`](../workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/file-content.md) | `p-58`, an edit by shell command checks that its anchor matched |
| [`check_instruction_surfaces.sh`](../scripts/check_instruction_surfaces.sh) | reads the subject table; refuses a heading with no row, a row naming the wrong layer, and a row whose section no layer carries |
| [`test_instruction_surfaces.sh`](../tests/test_instruction_surfaces.sh) | three new refusals asserted, 11 tests |
| [`devlog/roadmap.md`](../roadmap.md) | this unit's row closed under M3.2.2; two rows raised for the judgements left open; the provider-neutral fragment moved to M3.6.5 with its build dependency |
