---
date: 2026-11-16
milestone: M3.7 - Git boundary and repository state
type: Workflow
status: Closed
---

# Handover - The change-pipeline bundle, iteration 1: git-discipline and the history-cleanup runbook

## Objective

Ship `git-discipline` as a workflow mechanism in the `coding-agent` module, carrying `history-cleanup` as a runbook behind a thin prompt, and declare the `work-log` and `task-list` conventions each document actually uses.

## Scope

Continues the M3.7 change-pipeline work; iteration 1 of three. The decision that git discipline is a workflow mechanism is recorded in the ADR entry this iteration adds.

This iteration moves `git-discipline` from `.agents/skills/` to `workflow/coding-agent/skills/`, moves `history-cleanup` under it as `runbooks/history-cleanup/`, adds the thin `/history-cleanup` prompt, removes git-discipline from the convention corpus, and corrects the convention declarations. `record-correction` stays a prompt; `recovery` is not moved in this iteration, but its git-discipline read is repointed because the layer move would otherwise break it.

Out of scope: iteration 3 (making `work-log` and `task-list` optional) and iteration 2 (the `change_pipeline` main document, renamed from `change_model`), both accepted and ordered 3 before 2 after this iteration. Moving `recovery` into the bundle is deferred; only its convention read changes here. The roadmap rows for the three iterations are filed at this iteration's scope gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `git-discipline` resolves from `workflow/coding-agent/skills/git-discipline/`; no `.agents/skills/git-discipline/` remains; the skill map reports no collision. | `test ! -e .agents/skills/git-discipline`; `node scripts/skill_map.mjs` | Pass |
| `history-cleanup` is a runbook under `git-discipline/runbooks/history-cleanup/`; the top-level skill directory is gone; `/history-cleanup` runs the runbook. | `test ! -e workflow/coding-agent/skills/history-cleanup`; `read workflow/coding-agent/prompts/history-cleanup.md` | Pass |
| `history-cleanup` declares `work-log` and `task-list`; `record-correction` declares `task-list`; each declaration matches a use in the body. | `grep -n "Project conventions" -A6` on both | Pass |
| No live carrier names `.agents/skills/git-discipline`; the carriers name the module path or the module skill. | `grep -rn "\.agents/skills/git-discipline" --include='*.md' --include='*.sh' --include='*.mjs' . \| grep -v '^./devlog/'` prints nothing | Pass |
| The `initialize` corpus no longer carries `git-discipline`; the convention list no longer includes it, and the ADR current entry records the move. | `test ! -e workflow/coding-agent/skills/initialize/assets/conventions/git-discipline`; `grep -rn "git-discipline" workflow/coding-agent/skills/initialize` | Pass |
| The ADR entry records that git discipline is workflow mechanism and supersedes the 2026-10-14 clauses. | read `docs/adr/coding_agent_project_bindings.md` | Pass |
| The gates pass. | `node scripts/skill_map.mjs`; `bash scripts/check_instruction_surfaces.sh`; `bash scripts/check_references.sh`; `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Pass: 1624/1624 tests, 28 lint gates |
| The three roadmap rows are filed; this iteration's sub-row is marked at its close. | `grep -n "change-pipeline bundle" devlog/roadmap.md` | Pass: filed; the sub-row marks at the close |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `git-discipline` is workflow mechanism, not a project convention; it ships in the `coding-agent` module. | The operator's decision: the commit vocabulary and branch scheme are the workflow's, not a project's. This supersedes the 2026-10-14 `coding_agent_project_bindings.md` clause that put git-discipline in the convention corpus; git remains an available tool, and the coding-agent module is the workflow, not a git module. | ADR entry; this record |
| The bundle is the existing `coding-agent` module, not a new module. | It already carries `history-cleanup` and `record-correction`; adding `git-discipline` needs no settings entry, no manifest cell and no cross-module links. | This record |
| `history-cleanup` becomes a runbook under `git-discipline` with a thin prompt wrapper; the wrapper shape is `/recovery`'s, not `record-correction`'s. | The series is git-discipline's subject; `/recovery` is the thin wrapper precedent, while `record-correction` is a full procedure. | This record; the prompt and runbook |
| `record-correction` stays a prompt; `recovery` is not moved this iteration. | `record-correction`'s subject is the record; `recovery`'s move is a later row, and its body is not needed to deliver this iteration. | This record |
| The declaration audit adds `task-list` where the body uses it: `history-cleanup` and `record-correction` now; `recovery` when it moves. | The history-cleanup audit hardcodes the roadmaps and changelog, and `record-correction`'s forms name them; the declaration was incomplete. | The convention blocks |
| Iteration 3 (optional conventions) runs before iteration 2 (the main document). | The main document would otherwise state the conventions as required and be edited again when they become optional. | This record; the roadmap rows |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|
| `history-cleanup`, `record-correction` and `recovery` read the task list but do not declare `task-list`. | record | The declaration understates the convention set; a project with no `task-list` would not be asked about it. | `history-cleanup` and `record-correction` here; `recovery` at its move |
| `record-correction` is 165 lines and owns a procedure, so it is not the thin-wrapper precedent. | design | Using it as the model for `/history-cleanup` would copy a full procedure instead of wrapping a runbook. | `/recovery`, the model used here |
| `docs/reference/change_model.md` is the model, not a dispatcher; the dispatch is split between it and `git-discipline`'s Runbooks table. | design | Iteration 2 is a consolidation, not a no-op; `change_pipeline` must take the dispatch or it is a third list. | iteration 2 |
| `git-discipline`'s `iteration_protocol.md` and `change_model.md` references leave the workflow layer root once it ships. | code | A shipped relative link outside its layer is a hard finding; the citations must be dropped or made absolute. | this iteration; dropped or absolute |
| `scripts/measure_sessions.mjs` lists `git-discipline` among the convention skills. | code | After the move it counts a path that no longer exists, so the measurement silently misses the skill. | this iteration; entry removed |

## Completed

| File | One-line change summary |
|---|---|
| `workflow/coding-agent/skills/git-discipline/SKILL.md` | moved from `.agents/skills/`; links re-pointed and the out-of-layer fold citations dropped |
| `workflow/coding-agent/skills/git-discipline/references/branching.md` | moved; the change-model link made absolute and "convention" became "skill" |
| `workflow/coding-agent/skills/git-discipline/references/commit-types.md` | moved unchanged |
| `workflow/coding-agent/skills/git-discipline/references/correction.md` | moved; the prompt and runbook links re-pointed |
| `workflow/coding-agent/skills/git-discipline/references/prepare.md` | moved; "convention" became "skill" |
| `workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/SKILL.md` | moved under the skill; declares `work-log` and `task-list`; parent and branching links added |
| `workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/scripts/audit.sh` | moved with the runbook |
| `workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/scripts/inversions.mjs` | moved with the runbook |
| `workflow/coding-agent/prompts/history-cleanup.md` | new thin wrapper in the `/recovery` shape |
| `workflow/coding-agent/prompts/commit.md` | dropped the empty convention read and linked the skill |
| `workflow/coding-agent/prompts/iter.md` | dropped the convention read and re-pointed three skill mentions |
| `workflow/coding-agent/prompts/wrapup.md` | dropped the convention read |
| `workflow/coding-agent/prompts/plan.md` | re-pointed the skill path |
| `workflow/coding-agent/prompts/milestone-close.md` | re-pointed the skill path |
| `workflow/coding-agent/prompts/backlog-triage.md` | re-pointed the skill and commit-types paths |
| `workflow/coding-agent/prompts/record-correction.md` | dropped the git-discipline convention read, added `task-list`, linked the skill |
| `workflow/coding-agent/prompts/recovery.md` | dropped the git-discipline convention read, added `task-list` |
| `workflow/coding-agent/skills/recovery/SKILL.md` | dropped the convention read, added `task-list`, and re-pointed the history-cleanup and git-discipline links |
| `workflow/coding-agent/skills/initialize/SKILL.md` | removed git discipline from the convention list |
| `workflow/coding-agent/skills/initialize/assets/conventions/git-discipline/SKILL.md` | deleted: git-discipline is no longer a convention |
| `docs/adr/coding_agent_project_bindings.md` | new current entry: git discipline is workflow mechanism |
| `docs/adr/git_commit_history_commons.md` | "convention" became "skill" where it named git-discipline |
| `docs/adr/closed_record_corrections.md` | same wording correction |
| `docs/adr/task_type_taxonomy.md` | commit-types path and "convention" corrected |
| `docs/adr/work_log_record_seam.md` | branching path corrected |
| `docs/adr/change_model.md` | "convention" became "skill" |
| `docs/reference/iteration_protocol.md` | commit rule path and wording corrected |
| `AGENTS.md` | Git hygiene, Output Format and Iteration Lifecycle name the module path |
| `scripts/check_commit_message.sh` | reads the commit-types file from the module |
| `scripts/check_agent_primitives.sh` | reads the prepare runbook from the module |
| `scripts/measure_sessions.mjs` | git-discipline leaves the convention list |
| `tests/test_agent_primitives.sh` | fixture path updated |
| `tests/test_commit_hook.sh` | fixture path updated |
| `tests/test_commit_message_check.sh` | fixture path updated |
| `tests/test_git_hook.sh` | fixture path updated |
| `tests/test_eval_harness.sh` | sample project file moved to `work-log` |
| `tests/test_eval_specification.sh` | sample project file moved to `work-log` |
| `tests/test_history_cleanup_audit.sh` | runbook script path updated |
| `tests/test_history_cleanup_detector.sh` | runbook script path updated |
| `devlog/roadmap.md` | the parent row and the three iteration sub-rows filed; iteration 1 marked `[x]` at the close |
