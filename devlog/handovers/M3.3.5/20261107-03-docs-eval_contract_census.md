---
date: 2026-11-07
milestone: M3.3.5 - The eval pipeline
type: Documentation
status: Closed
---

# Handover - the eval contract is recorded, the records are censused, and the roadmap is written back

## Objective

Make the eval contract the decision record the harness answers to, delete the exploration records a live carrier now holds, and write the milestone's state back to the roadmap.

## Scope

The documentation and record half of the eval pipeline. The harness and its tests are `20261107-01`; the case-set gates are `20261107-02`. It also carries the task-list rule that a future row names a requirement rather than an unshipped artifact, the source-catalog entry for the Anthropic skills library, and the roadmap write-back for the whole branch.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The eval harness contract is an ADR with seven requirements and one decision | `docs/adr/eval_harness_contract.md` holds R1-R7 and the 2026-11-07 entry | Agent [x] |
| The concluded records a live carrier now holds are deleted | the 14 deleted files are named in this record's Completed table | Agent [x] |
| The surviving claims are in the ADR set | `docs/adr/principle_skill_shape.md` and `docs/adr/single_source_model_recommendations.md` carry them | Agent [x] |
| The Anthropic skills library is a named source, not a fork | `.agents/registry/sources/anthropic-skills.json` carries its row | Agent [x] |
| The roadmap closes the harness row, opens the remaining rows and names this branch's records | `devlog/roadmap.md` M3.3.5 | Agent [x] |
| The record and lint gates are green | `bash scripts/check_handover_format.sh`; `bash scripts/check_record_names.sh`; `bash scripts/check_record_lifecycle.sh`; `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A concluded record whose subject a live carrier holds is deleted | The record is a second source once the ADR states the same subject, and an orphaned concluded record has no task left to serve | `work-log`; `docs/adr/principle_skill_shape.md` |
| The source library is a catalog row with a reason, not a vendored copy | The harness cross-references its grading model and keeps its own implementation | `.agents/registry/sources/anthropic-skills.json` |
| The roadmap is written back from the final tree, not from the intermediate commits | The branch is one delivery of the eval pipeline, and the roadmap states the tree a reviewer opens | `devlog/roadmap.md` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Which defect does the default review miss? | A doc-maintenance case that separates the skill from its absence | a cross-document inconsistency; a claim whose deciding source is an obscure manifest; or a weaker model as the instrument |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The first doc-maintenance restart did not separate its configurations | measurement gap | The roadmap row stays open and names the next attempt's requirement; the run detail is no longer carried as evidence | `devlog/roadmap.md` *The doc-maintenance eval restart* |
| A future-milestone row named an unshipped artifact path | record defect | The task-list convention now requires the requirement, not the artifact path | `.agents/skills/task-list/SKILL.md` |

## Completed

| File | One-line change summary |
|---|---|
| `docs/adr/eval_harness_contract.md` | Records R1-R7 and the declaration decision |
| `docs/adr/principle_skill_shape.md` | Carries the communication corpus and its three judgements |
| `docs/adr/single_source_model_recommendations.md` | Carries the model-catalog rejection |
| `.agents/registry/sources/anthropic-skills.json` | Adds the read-not-forked source row |
| `.agents/skills/task-list/SKILL.md` | Requires a future row to name its requirement |
| `devlog/roadmap.md` | Activates M3.3.5, closes the harness row, opens the remaining rows and records this branch's handovers |
| `devlog/roadmap_future.md` | Names requirements instead of unshipped artifacts |
| `devlog/discussions/20261002-study-active-review_lens_learnings.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261004-study-settled-deepseek_effort_levels.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261016-design-settled-dispatch_ownership.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261016-design-settled-reasoning_layer_install.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261018-study-settled-numbering_scheme_census.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261019-report-settled-retirement_carry_over.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261020-report-settled-duplication_map.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261022-design-settled-testing_policy_into_the_skill.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261023-design-rejected-cited_command_gate.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261023-design-settled-prompt_command_surface.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261023-report-retirement_rule_loss_audit.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261026-report-draft-eval_inputs_required.md` | Deleted; the ADR now holds its six requirements |
| `devlog/discussions/20261101-study-draft-task_row_form.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261104-report-settled-enabled_models_scope_head.md` | Deleted; the live carrier holds its subject |
| `devlog/discussions/20261020-design-settled-communication_domain_replan.md` | Deleted; the ADR now holds its subject |
| `devlog/discussions/20261021-design-settled-initialize_corpus_boundary.md` | Deleted; the ADR now holds its subject |
| `devlog/discussions/20261021-design-settled-inverse_defect.md` | Deleted; the ADR now holds its subject |
| `devlog/discussions/20261021-design-settled-principle_corpus_shape.md` | Deleted; the ADR now holds its subject |
| `devlog/discussions/20261024-design-rejected-model_catalog.md` | Deleted; the ADR now holds its subject |
