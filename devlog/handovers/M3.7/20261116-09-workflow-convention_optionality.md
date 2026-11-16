---
date: 2026-11-16
milestone: M3.7 - Git boundary and repository state
type: Workflow
status: Closed
---

# Handover - The change-pipeline bundle, iteration 3: record conventions are optional

## Objective

The change-pipeline bundle runs when a project provides no `work-log` or `task-list`, taking a content-only path and naming the skipped record arm in every report.

## Scope

Continues the M3.7 change-pipeline bundle; iteration 3 of three, executed before iteration 2. The parent row is `The change-pipeline bundle is workflow mechanism`.

This iteration makes the record arms of `history-cleanup`, `recovery` and `record-correction` optional: a missing `work-log` skips the handover and record work, a missing `task-list` skips the roadmap and changelog work, and the content path still runs. It makes the history-cleanup audit's record set an option, branches the `## Project conventions` pointer on absence, and records the optionality in the ADR. The pointer sentence is shared by every carrier, so all 20 sections change, not only the bundle's five.

Out of scope: iteration 2 (the `change_pipeline` main document). The main loop (`iter`, `commit`, `wrapup`) still requires `work-log` and `task-list`; this iteration covers the change-pipeline bundle only. The commit fold is not a record arm and runs without either convention.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `history-cleanup` runs with `work-log` absent: property 5 and the record rewrite are skipped, audit check 1 is skipped, and the report names the skipped arm. | read the runbook; `bash scripts/audit.sh <base> --records=` | Pass |
| `history-cleanup` runs with `task-list` absent: audit check 4 excludes no task-list record path, keeps the `work-log` paths, and the report names the skipped arm. | read the runbook; `tests/test_history_cleanup_audit.sh` | Pass |
| `recovery` runs with both absent: the claim comes from the operator's description and the repository, and step 6 reports instead of writing a handover. | read the skill; `grep` the no-record branch | Pass |
| `record-correction` runs with the record conventions absent: the commit fold runs, the record arm is skipped, and the report names it. | read the prompt | Pass |
| Every `## Project conventions` block carries the branch sentence, and the pointer test accepts it. | `bash tests/test_convention_pointer.sh`; `grep -rl "skip the arm that reads it" --include='*.md' .` | Pass |
| The audit exposes the record set as an option and a test proves the no-record path. | `tests/test_history_cleanup_audit.sh` | Pass |
| The ADR records that the change pipeline's record arms are optional. | read `docs/adr/coding_agent_project_bindings.md` | Pass |
| The gates pass. | `node scripts/skill_map.mjs`; `bash scripts/check_instruction_surfaces.sh`; `bash scripts/check_references.sh`; `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Pass |
| The iteration's roadmap sub-row is marked at its close. | `grep -n "Iteration 3" devlog/roadmap.md` | Pass: marked `[x]`; the generic-files question filed under the parent |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The record arms are optional; the content arms are not. | A project may legitimately run the change pipeline without a work log or a task list. The series, the commit and the recovery content still have their evidence. | ADR entry; this record |
| `work-log` owns property 5, the record rewrite, audit check 1, the handover root, the feedback record and the discussions; `task-list` owns the roadmap and changelog record paths in audit check 4. | The two conventions own different files, so one switch would conflate them. | This record; the audit options |
| The audit takes the record set as an option: `--records=` empty skips check 1, and `--record-paths=` empty removes the record exclusion from check 4. | The audit currently hardcodes the task-list paths, which is the evidence of the undeclared dependency. | This record; the audit |
| A skipped arm is named in the report; silence is a finding. | The operator must be able to tell a content-only pass from a complete one. | The five documents |
| The pointer sentence changes for every carrier, not only the bundle. | The sentence is one canonical string and `test_convention_pointer.sh` enforces it; changing the bundle alone would leave two forms. | This record; the pointer test |
| The main loop's requirements are unchanged. | `iter`, `commit` and `wrapup` write the iteration record; the bundle is the part that can run without it. | This record; the ADR entry |
| The commit fold is not a record arm. | The fold rewrites the commit; the record amendments are a separate, optional carrier. | This record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `audit.sh` hardcodes the roadmap, future roadmap, feedback, discussions and changelog paths in `record_paths_regex`. | code | The audit cannot run a no-`task-list` project without treating those paths as records, and the hardcoding is the undeclared dependency. | this iteration; `--record-paths=` |
| `recovery` step 1 reads the handover and roadmap, and step 6 writes the handover; it has no no-record branch. | design | A project without `work-log` cannot complete the recovery procedure as written. | this iteration |
| `record-correction`'s record-arm section assumes `work-log`, `decision-records` and `task-list` are present. | design | The commit fold is usable without them, but the prompt does not say so. | this iteration |
| The `## Project conventions` block treats every missing convention as a stop. | design | That is the opposite of optionality; a missing `task-list` would block the content-only pass. | this iteration |
| `git-discipline`'s fold says the record amendments ride with the fold, without a no-record branch. | record | A reader without `work-log` cannot tell whether the fold still applies. | this iteration; one sentence |
| The `## Project conventions` pointer sentence is shared by 20 carriers and the test enforces one canonical form. | record | Changing the bundle's five alone fails `test_convention_pointer.sh`; the sentence changes globally. | this iteration; all 20 carriers |

## Completed

| File | One-line change summary |
|---|---|
| `workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/SKILL.md` | property 5, the record rewrite and the audit options made conditional; the report names the skipped arm |
| `workflow/coding-agent/skills/git-discipline/runbooks/history-cleanup/scripts/audit.sh` | `--records=` skips check 1; `--record-paths=` controls check 4's record exclusion |
| `workflow/coding-agent/skills/git-discipline/SKILL.md` | one sentence: without `work-log` the fold is the commit alone |
| `workflow/coding-agent/skills/recovery/SKILL.md` | the claim falls back to the operator and the repository; step 6 reports without a handover |
| `workflow/coding-agent/prompts/history-cleanup.md` | the convention pointer branches on absence |
| `workflow/coding-agent/prompts/recovery.md` | the convention pointer branches on absence |
| `workflow/coding-agent/prompts/record-correction.md` | the record arm is optional; the commit fold still runs |
| `docs/adr/coding_agent_project_bindings.md` | new entry: the change pipeline's record arms are optional |
| `tests/test_history_cleanup_audit.sh` | the no-record and no-record-paths cases |
| `tests/test_convention_pointer.sh` | the canonical pointer sentence updated |
| the 15 other `## Project conventions` carriers | the shared pointer sentence updated in `backlog-triage`, `bootstrap`, `gm`, `iter`, `milestone-close`, `milestone-start`, `package-eval-snapshot`, `plan`, `scope`, `sidequest`, `wrapup`, `code-review`, `handover-maintenance`, `prose-review` and `roadmap-maintenance` |
| `devlog/roadmap.md` | iteration 3 marked `[x]`; the generic-files question filed under the parent |
