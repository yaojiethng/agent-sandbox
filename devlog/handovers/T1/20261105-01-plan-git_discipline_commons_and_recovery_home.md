---
date: 2026-11-05
milestone: T1 - Workflow + Policy Organization
type: Plan
status: Closed
---

# Handover - the git-discipline rewrite and the recovery row share a home

## Objective

File two units under one home: the rewrite of `git-discipline` from the intent that history is a commons, and the question of where the recovery reference belongs, which the rewrite's scope is the first to be able to answer.

## Scope

Two open rows under T1, at the same nesting level. The first is the convention rewrite; the second is the `Recovery is not git work` row, moved out of M3.3.3, where it sat in the active sub-milestone although its subject is which convention owns the reference.

The plan session is scoped to those rows alone, on the operator's C1 release: the framing, the rule set it produces and the disposition of each feedback entry belong to the rewrite's own iteration, not to this one.

Ruled out of scope, one sentence each with the reason: the framing decision and its ADR, because C1 leaves them to the rewrite; the feedback dispositions, for the same reason, so the row names the set without prescribing an answer for any member; and the carriers that will follow the rewrite (`AGENTS.md` `**Git hygiene.**`, `iteration_protocol.md`, `task_type_taxonomy.md`, `closed_record_corrections.md`, `coding_agent_project_bindings.md`), because none of them changes until the convention they cite does.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The recovery row sits under T1 at the same nesting level as the rewrite row, and no longer under M3.3.3 | `rg -n "Recovery is not git work" devlog/roadmap.md` prints one line, inside the T1 section; `rg -n "Recovery is not git work" devlog/roadmap_future.md` prints nothing | Agent [x] |
| The rewrite row states the intent, the feedback set it disposes of, and its mechanism class | read the row in `devlog/roadmap.md` | Agent [x] |
| The handover names the session's milestone under the task-list convention's identifier form | the record's frontmatter `milestone` field reads `T1 - Workflow + Policy Organization` | Agent [x] |
| `bash scripts/lint.sh` is clean | twenty gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The plan session writes the two roadmap rows and no design record | The operator released C1: the framing and the rule set are the rewrite's to settle, and a design record written before that iteration would fix an answer it has not been asked to reach | this record |
| Both rows live under T1 | `git-discipline` is a convention-skill, and T1 owns the workflow prompts, the conventions and the decisions behind them; T7's git rows own the harness's own git operations (the index lock, the dirty read, the diff pipeline, a worker's write capability), which this rewrite does not touch | `devlog/roadmap.md` |
| The two rows are siblings, the rewrite first | The operator directed that the recovery row be filed alongside the rewrite at the same nesting level; the rewrite is placed first because it is what makes the recovery row's question answerable | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The recovery row sat in the active sub-milestone although its own text said it needed a home, and its subject is a convention-ownership question rather than pipeline work | defect (record) | a reader scoping M3.3.3 carried a unit the milestone does not own | corrected in this iteration; `devlog/roadmap.md` |
| The rewrite's feedback set spans three owners: three entries are the convention's own subject, one is already carried by `code-review`, and three sit with `dispatch`, `testing` and T7 | scope note | the rewrite would otherwise claim work another milestone owns, or drop work it owns | stated in the row as a set to dispose of, each member by its date; the rewrite decides which is which |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | Files the rewrite row and the recovery row under T1 as siblings, and removes the recovery row from M3.3.3 |
| `devlog/handovers/20261105-01-plan-git_discipline_commons_and_recovery_home.md` | This record |
