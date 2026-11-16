---
date: 2026-11-16
milestone: M3.7 - Git boundary and repository state
type: Workflow
status: Closed
---

# Handover - The change-pipeline bundle, iteration 2: the main document

## Objective

The change pipeline has one main document, titled **Change pipeline domain model**, that names the model and dispatches to `git-discipline`, `history-cleanup`, `record-correction` and `recovery`.

## Scope

Continues the M3.7 change-pipeline bundle; iteration 2 of three, after iterations 1 and 3. The parent row is `The change-pipeline bundle is workflow mechanism`.

This iteration renames `change_model` to `change_pipeline` across the reference, the ADR, the model home, the gate and the live carriers; retitles the reference **Change pipeline domain model**; and adds the reference's `## The operations`, the dispatch to the four change-pipeline skills. The skills keep their own files and procedures; the main document names which one owns each operation.

Out of scope: the generic-files question, filed as a separate subtask under the parent. The internal rules of the four skills. The main loop. Historical `devlog` records keep the old name.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The reference is `docs/reference/change_pipeline.md`, titled **Change pipeline domain model**, and no live `change_model` path remains. | `test -f docs/reference/change_pipeline.md`; `grep -rn "change_model" --include='*.md' --include='*.sh' --include='*.mjs' . \| grep -v '^./devlog/'` prints nothing | Pass |
| The ADR is `docs/adr/change_pipeline.md`; its current entry records the rename and the dispatch. | read the ADR | Pass |
| The reference's `## The operations` names each operation and exactly one owning skill: `git-discipline`, `history-cleanup`, `record-correction`, `recovery`. | read `## The operations` | Pass |
| The model home and gate are renamed: `tests/model/change_pipeline/`, `scripts/check_change_pipeline.sh`, `scripts/lint/change_pipeline.mjs`, and `scripts/lint.sh` invokes the new gate. | `bash scripts/lint.sh`; `bash tests/test_change_pipeline.sh` | Pass |
| The live carriers name `change_pipeline`; the historical `devlog` records are unchanged. | the grep above excludes `devlog` and prints nothing | Pass |
| The gates pass. | `node scripts/skill_map.mjs`; `bash scripts/check_instruction_surfaces.sh`; `bash scripts/check_references.sh`; `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Pass |
| The iteration's roadmap sub-row is marked at its close. | `grep -n "Iteration 2" devlog/roadmap.md` | Pass: iteration 2 and the parent marked `[x]`; the generic-files child remains open |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The main document is the reference, not a new router skill. The dispatch is `## The operations`. | The model already exists at `docs/reference/change_pipeline.md`; a router skill would be a third list beside the model and `git-discipline`'s Runbooks table, and it adds a hop. | ADR entry; the reference |
| The ADR renames with the reference. Its title is **Change pipeline**; the reference's full title is **Change pipeline domain model**. | One subject, one name. The full title belongs to the model reference; the ADR states the decisions behind it. | ADR entry |
| The TLA+ module keeps `ChangeModel`; the snake_case path renames. | The rename is the `change_model` path, not the TLA+ module name; renaming the module adds a TLA+ identity change for no reader gain. | This record; the model home |
| The dispatch names the skill, not a second procedure. | The skills stay as they are; the main document says which one owns each operation. | The reference's `## The operations` |
| Historical `devlog` records keep `change_model` in prose; a link target that would break is re-pointed. | A closed record states what was true when it was written; a link is a live edge and must resolve. | This record |
| The reference owns the dispatch; `git-discipline` keeps its local Runbooks index and cites the reference. | The model is the pipeline's dispatch; the skill's table is a local index. This resolves the pending question. | This record; the reference and the skill |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `change_model` is a larger carrier set than the reference alone: the ADR, the TLA+ model home, the gate, the scanner and four tests. | code | The rename is a cross-tree move, not a document edit; the gate paths and test names must move together. | this iteration |
| The reference already carries `## The primitives` and `## The defect flow`, which partly dispatch. | design | A new dispatch table must not become a third list beside those sections and `git-discipline`'s Runbooks. | this iteration; `## The operations` cites the existing sections |
| The `change_model` name appears in historical `devlog` records. | record | A global replace would rewrite closed records. | this iteration; live carriers only |

## Completed

| File | One-line change summary |
|---|---|
| `docs/reference/change_pipeline.md` | renamed from `change_model.md`; titled **Change pipeline domain model**; body subject updated; `## The operations` added |
| `docs/adr/change_pipeline.md` | renamed; new current entry for the rename and the dispatch; body subject updated |
| `scripts/check_change_pipeline.sh` | renamed; scanner path, default doc and messages updated |
| `scripts/lint/change_pipeline.mjs` | renamed; default doc, model home and output updated |
| `scripts/lint.sh` | invokes the renamed gate |
| `tests/model/change_pipeline/` | moved from `change_model/`; `ChangeModel.tla` and its cfg keep the module name; `model.md` and `transitions.md` updated |
| `tests/test_change_pipeline.sh` | renamed; gate and fixture paths updated |
| `tests/test_change_pipeline_delivery.sh` | renamed; reference path and test name updated |
| `tests/test_model_home.sh` | model-home, gate and reference paths updated |
| `tests/test_parallel_records.sh` | comment updated |
| `docs/reference/workflow_statechart.md` | the change-flow links updated |
| `docs/adr/diff_packaging.md` | the confirm-sequence link updated |
| `docs/adr/recovery_procedure.md` | the model link updated |
| `docs/adr/work_log_record_seam.md` | the model link updated |
| `workflow/coding-agent/skills/git-discipline/references/branching.md` | the lifecycle link updated |
| `workflow/coding-agent/skills/git-discipline/SKILL.md` | the Runbooks section cites the reference's dispatch |
| `devlog/roadmap.md` | iteration 2 and the parent marked `[x]`; the generic-files child remains open; two link targets updated |
| `devlog/roadmap_future.md` | one link target updated |
