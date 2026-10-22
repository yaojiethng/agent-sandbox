---
date: 2026-10-06
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Documentation Tree Carries the Reader's Classes

## Objective

Name each `docs/` folder for the reader it serves, so the ship decision reads off the path, and keep the kind vocabulary people already know.

## Scope

The three shipped trees named kinds. `architecture/` held implementation design, `concepts/` held conceptual models, and `operations/` held the policy corpus plus two guides. The classification of the 23 shipped documents measured readers, and the two axes no longer lined up. `architecture/` held an operator document and `operations/` held six agent rules beside an operator guide.

The iteration replaces the folder set and declares the model behind it. Three levels, one owner each: the folder name carries the kind, the folder set carries the ship decision because every folder has exactly one ship value, and the reader is declared per document.

| Folder | Kind | Ships |
|---|---|---|
| `reference/` | contracts, states and sequences, the interface index, the glossary | yes |
| `policies/` | the rules the loop obeys | yes, until they move into the workflow module |
| `development/` | contributor workflow, conventions, and the procedures for changing the harness | no |
| `adr/` | settled decisions | no |

In scope: the rename and every reference to it, the manifest's `image` and `session` rows, the three provider dockerfiles, the lint exemption list, the four fixtures, the placement rule in `documentation_policy.md`, the folder table and the model in `documentation_taxonomy.md`, and the four procedures the operator directed into `development/` during the review.

Out of scope, each with its reason: `context_resolution.md`, which the classification puts on the maintenance side and which waits for a separate release; the consumer field in document frontmatter, which the operator released as a follow-on and which needs its own schema and gate; and the shrink of the reference layer, which comes after the rename.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The three kind-named trees are gone | `ls docs/` shows `reference`, `policies`, `development`, `adr` and no other document folder | Agent [x] |
| No live file names the retired folders | a repo-wide grep for `docs/architecture/`, `docs/concepts/`, `docs/operations/` and their relative and image forms returns only closed records | Agent [x] |
| The build agrees with the manifest | `bash scripts/check_container_layout.sh` is clean with the two docs rows per provider | Agent [x] |
| The records state the new model | `documentation_policy.md` names the four folders and `documentation_taxonomy.md` carries the folder table and the three levels | Agent [x] |
| Every link resolves | the link check and a resolution pass over each changed file | Agent [x] |
| The suite is green | `bash scripts/run_tests.sh` | Agent [x] -- 1114 tests across 76 files, 0 failed, liveness clean |
| Lint is clean | `bash scripts/lint.sh` | Agent [x] -- 8 gates clean |
| The handover closes | this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `docs/reference/` (16 documents) | holds the reference layer, and the four moved procedures left it |
| `docs/policies/` (7 documents) | the rule corpus, named for what it holds |
| `docs/development/` (15 documents) | receives the procedures for changing the harness |
| `src/build/container-interface.json` | the `image` and `session` rows for the shipped documentation |
| `src/reasoning/providers/*/provider.dockerfile` | three `COPY docs/` lines became two |
| `.markdownlint-cli2.mjs` | 21 exemptions move with the files they exempt |
| `docs/policies/documentation_policy.md` | the placement rule |
| `docs/reference/documentation_taxonomy.md` | the folder table and the three-level model |
| `tests/test_container_layout.sh`, `tests/test_instruction_surfaces.sh`, `tests/test_lint_umbrella.sh`, `tests/test_record_links_rule.sh`, `tests/test_eval_harness.sh` | fixtures that build a policy path |
| `devlog/roadmap.md` | the split rows, the acceptance criterion, and the new row for this restructure |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Three levels, one owner each: kind in the folder name, ship in the folder set, reader on the document | forcing two axes into one name produced names like `operator-surface`, which was unclear because its class dissolves into a reference document and a runbook | `documentation_taxonomy.md`, this handover |
| `reference/` over `system-reference` or `architecture` | it is the one four-quadrant documentation kind that survives the reader test, it says what the folder is for, and it pairs with the minimisation the operator asked for | this handover |
| `policies/` over `rules/` | the files are `*_policy.md` and `documentation_policy.md` already calls the set the policy set | this handover |
| `development/` keeps its name | familiarity, consistent with other projects, though dated | operator direction (2026-10-06) |
| The operator-surface class dissolves | its two members become a runbook and a reference document, so no folder is named for it | this handover |
| Closed records keep their account while live pointers follow the rename | the changelog and the feedback register were reverted, then the changelog's single link was retargeted because a gate checks it; the roadmap's live rows were updated and its closed rows were not | this handover |
| The `image` and `session` rows drop from three docs entries to two | `docs/operations/` split into a shipped policy folder and two documents that do not ship | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The rename activated the legacy wrap debt of every file it touched, 17 findings, because the gate releases a file's debt the first time the file is edited. The fix is mechanical, and it means a rename sweep pays the wrap debt of its whole blast radius. | evidence, measured | current iteration, fixed |
| A blanket replacement of `architecture/` also hit the skill directory `improve-codebase-architecture/`, corrupting one lint exemption and one roadmap line. A path rename must be anchored to a path context, never run as a bare word. | agent mistake | current iteration, fixed; the recurrence belongs in `devlog/AGENT_FEEDBACK.md` at the operator's word |
| Two ADRs name the retired `docs/operations/` folder, one live and one archived. The live one is updated and the archived one keeps its account, but no rule states whether a path inside a dated ADR entry follows a rename. | design gap | `adr_policy.md` at the operator's word |
| `.markdownlint-cli2.mjs` exempts 21 documents by explicit path, so a rename must move every exemption or the exempt file starts failing. The list is unowned and path-coupled. | maintenance hazard | the doc-maintenance skill |
| The four procedures the operator directed into `development/` were moved with their links, and `src/reasoning/providers/AGENTS.template.md` needed the same edit, which the earlier three moves had not touched. | evidence, surveyed | current iteration, fixed |

## Completed

| File | Change |
|---|---|
| `docs/architecture/`, `docs/concepts/`, `docs/operations/` | dissolved into `docs/reference/` and `docs/policies/` |
| `docs/reference/` | 16 documents: the 15 kind-named reference documents plus `project_onboarding_guide.md`, which becomes a runbook |
| `docs/policies/` | the 7 policy documents |
| `docs/development/` | 15 documents, including the four procedures moved during the review |
| `src/build/container-interface.json` | three docs rows per provider became two, and the `session` rows follow |
| `src/reasoning/providers/pi/provider.dockerfile`, `hermes`, `opencode` | three `COPY docs/` lines became two, aligned |
| `.markdownlint-cli2.mjs` | 21 exempt paths, and one restored after the blanket replacement caught a skill name |
| `docs/policies/documentation_policy.md` | the placement rule names the four folders |
| `docs/reference/documentation_taxonomy.md` | the folder table, and the three-level model |
| `docs/development/prompt-authoring-conventions.md` | the reference-form rule names the shipped policy and reference roots |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the provider layer's reachable-paths table names the two shipped roots |
| `scripts/check_frontmatter.sh` | the comment names the policy folder |
| `workflow/coding-agent/prompts/bootstrap.md` | the project layout it teaches follows the policy folder |
| `tests/test_container_layout.sh`, `tests/test_instruction_surfaces.sh`, `tests/test_lint_umbrella.sh`, `tests/test_record_links_rule.sh`, `tests/test_eval_harness.sh` | fixtures build the policy path |
| `docs/reference/context_resolution.md`, `docs/reference/execution_model.md`, `docs/reference/sandbox_host_interface.md`, `docs/reference/sandbox_identity.md`, `docs/reference/sandbox_lifecycle.md`, `docs/reference/terminology.md`, `docs/reference/tool_interface.md` | legacy wrap debt paid, one paragraph per physical line |
| `devlog/roadmap.md` | the acceptance criterion, the split rows' paths, the policy-bundle row, and a closed row for this restructure |
| `devlog/handovers/archive/20261006-05-workflow-the_documentation_tree_carries_the_readers.md` | this handover |
