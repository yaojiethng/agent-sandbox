---
date: 2026-10-24
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - The scoping prompt states the questions and the principles

## Objective

Make `/scope` the prompt that writes one brief, by running the four questions in their native form and naming the principles that deepen them instead of restating those judgements.

## Scope

The `/scope` prompt, the one `docs/reference/workflow_statechart.md` command row it contradicts, and the staged copy the running container reads.

Two items ruled out, each with its reason. The `/scope` prompt's own description of the artifact was reviewed against `docs/development/prompt-authoring-conventions.md`, not rewritten to a second vocabulary: the tree says "brief" in `iter.md`, `plan.md`, `wrapup.md` and the drafts, so the word stays. The corpus gap below is filed, not fixed here, because it is M3.3.3's end state.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The four questions stand in their native form, each naming the skills that deepen it | `sed -n '/^## The four questions/,/^## Rewrite/p' workflow/coding-agent/prompts/scope.md` | Agent [x] |
| No judgement is restated beside a name; the prompt names 21 principle skills | `grep -o 'principle-[a-z-]*' workflow/coding-agent/prompts/scope.md \| sort -u \| wc -l` prints 21 | Agent [x] |
| The prompt writes the brief and invokes no close | `grep -n '/wrapup\|/commit' workflow/coding-agent/prompts/scope.md` prints nothing | Agent [x] |
| The brief's parts are the run's, including the measured facts and the model assignment | `sed -n '/^## The brief.s parts/,/^## The work units/p' workflow/coding-agent/prompts/scope.md` | Agent [x] |
| The work-unit table names the document that defines it | `grep -c 'iteration_protocol.md#unit-and-scope-invariants' workflow/coding-agent/prompts/scope.md` prints 1 | Agent [x] |
| The statechart row and its exit edge agree with the new close | `bash scripts/check_statechart.sh`, and the row reads `plan_scoping` | Agent [x] |
| The staged copy is the tree's file | `diff -q workflow/coding-agent/prompts/scope.md /opt/workflow/agent/modules/coding-agent/prompts/scope.md` prints nothing | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates, `bash scripts/run_tests.sh` at 1309 tests over 94 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The four questions stay in their native, compact form; their elaboration is cut | the operator's direction: the questions are strong as prompts, and the appended guidance restated what the question already asks | the prompt, `## The four questions` |
| The principles are named, not linked and not restated | a skill name resolves at `$AGENT_HOME/agent/skills/<name>/SKILL.md`, and the review found "linked" overstated an inline code span | the prompt, `## The four questions` and `## Refine the plan and the prose` |
| `/scope` opens no session, writes no record and commits nothing; the end prints a suggestion | the prompt's own scope line already said it opens no session, and its close ran `/wrapup` and `/commit`, which `/wrapup`'s `## Called from` does not list. The operator chose the suggestion over the session | the prompt, `## Hand off` and `## Non-goals` |
| The statechart moves `/scope` to `plan_scoping` and gains one exit edge to `it_open` | the brief cuts the ask into units, so the state is right; the state had no exit that represented a released brief, only `/plan`'s design probe | [`workflow_statechart.md`](../../docs/reference/workflow_statechart.md) `## Commands` and its diagram |
| The work-unit table points at `iteration_protocol.md`, not `task-list` | the review measured that `task-list` owns where a row lands and its nature of change, while the table's columns are the iteration protocol's | the prompt, `## The work units` |
| The artifact keeps the tree's word "brief" | four carriers use it, and a rename would ride this unit as a separate sweep with its own carrier list | the prompt, and this record's Scope |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Eight of the principle skills the prompt names are absent from the repository's delivered skill tree, so the image does not source them: `principle-attack-the-premise`, `principle-build-the-lever`, `principle-exhaust-the-design-space`, `principle-prove-it-works`, `principle-model-the-domain`, `principle-subtract-before-you-add`, `principle-never-block-on-the-human`, `principle-sequence-verifiable-units` | record | a container seeded from the image with no host mount carries the pointer and not the skill | the M3.3.3 row **Ingest `pstack` upstream**, whose end state is that every `principle-*` skill in the config home resolves to a source in the tree |
| The `_REVIEWER` role line's second candidate, `opencode-go/minimax-m3.1-flash-free`, is deprecated upstream: the review's seat 2 answered `ModelDeprecated` and the run stopped with one report instead of two | mechanism | a two-seat review silently degrades to one report until the table is edited | the operator, because `.agents/model-recommendations.md` is operator-owned; not edited here |
| The first `/scope` rewrite cut seven of the brief's ten parts and the work-unit cut rule, and the review caught all eight | record | a brief could have been written without its model assignment or its measured facts | fixed here: the parts are restored, and the cut rule with its source of truth |

## Completed

| File | Change |
|---|---|
| [`workflow/coding-agent/prompts/scope.md`](../../workflow/coding-agent/prompts/scope.md) | rewritten around the four native questions, the named principles, the brief's ten parts, the work-unit table's owner, and a suggestion in place of a close |
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | the `/scope` command row leaves `plan_scoping` with no dispatch, and the diagram gains `plan_scoping --> it_open : the operator releases the brief to a run` |
| `~/.pi/agent` equivalent, `/opt/workflow/agent/modules/coding-agent/prompts/scope.md` | the staged copy, identical to the tree's file |
| [`devlog/roadmap.md`](../roadmap.md) | a T1 row for this unit, closed here |
