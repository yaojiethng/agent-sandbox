---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Active
---

# Handover - Retire documentation_policy

## Objective

Empty `docs/policies/documentation_policy.md`: its convention moves into the `docs` skill, its mechanism into the two procedures that run it, its remainder into the principle corpus and the provider `AGENTS.md`, and the file is deleted.

## Scope

`M3.3.2 - Retire the policy form`, slice `Retire documentation_policy`. It continues the settled chain in [`20261014-design-settled-retire_the_policy_form.md`](../discussions/20261014-design-settled-retire_the_policy_form.md), after `Retire git_policy` (handovers `20261022-09`, `20261022-10`), and runs last but one: `Retire iteration_policy` follows.

The design's map at section grain, resolved here:

| Sections | Fate |
|---|---|
| `## Folder Structure`, `## Format` (7 subsections), `## Drafting` (3), `## Document Types` (2), `### Reserved terminology` | convention, into the `docs` skill |
| `## Tooling checks` (2) | mechanism, into `doc-maintenance` |
| `### Post-close document corrections` | mechanism, into `record-correction`, its only caller |
| `### Missing documents` | already stated in the project `AGENTS.md`, so deleted and not moved |
| `### Rule placement`, `## Prohibited content` | remainder, into the principle corpus and `agent_workflow.md` |
| `### Simplified Technical English` | the seven-skill index is deleted; its two tests split, below |
| `## Rule authority` | the norm kinds stay in `agent_workflow.md` `## Norm kinds`; the ledger mechanics stay in the script |

The slice is three units, each landing a usable state.

| Unit | Lands | Ends when |
|---|---|---|
| 1 | the convention into the `docs` skill: `SKILL.md` from the seeded stub, `assets/` for the header block and the section-order skeleton, a reference for the format rules that need lookup | the tree rule, header, character set, wrapping, references, numbering, grep structure and drafting rules read from the skill, and the five gate headers cite it |
| 2 | the mechanism into `doc-maintenance` and `record-correction` | the lint rule set is a check in the pass, and the correction form lives with the runbook that applies it |
| 3 | the remainder, the ledger, the deletion: rule placement, prohibited content, the ledger `SOURCES`, the citation sweep, the file | `git grep documentation_policy` returns only `devlog/` and `docs/adr/archive/`, the ledger is regenerated and green, and `docs/policies/` holds `iteration_policy.md` alone |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The `docs` skill holds the convention | `grep` each of: folder tree, header block, character set, line wrapping, numbering, grep-navigation, skeleton-first | Agent [x] |
| The five gate headers cite the skill, not the policy | `grep -l documentation_policy` over `scripts/check_document_shape.sh scripts/check_markdown.sh scripts/lint/doc-ascii.mjs scripts/lint/document-shape.mjs .markdownlint-cli2.mjs` prints nothing | Agent [x] |
| `doc-maintenance` carries the lint rule set obligation as a check | `grep` the registered-but-unenabled rule | Agent [ ] |
| `record-correction` carries the post-close correction form, including the per-type table | `grep` the five forms | Agent [ ] |
| The literal-reader test is stated in the provider `AGENTS.md`, both copies | `grep -c` the phrase in the repo source and in `~/.pi/agent/AGENTS.md` | Agent [ ] |
| The ledger's `SOURCES` names the new homes and the ledger is regenerated | `grep` the `SOURCES` array; `scripts/check_norm_ownership.sh --check` is clean | Agent [ ] |
| The policy file is deleted | `test ! -e docs/policies/documentation_policy.md` | Agent [ ] |
| No live surface names it | `grep -rln documentation_policy docs scripts src workflow .agents AGENTS.md tests readme.md` prints nothing | Agent [ ] |
| The roadmap row closes and the parent names the last slice | `grep` the row and the parent line | Agent [ ] |
| Lint, ledger, suite and handover gate clean | the four scripts | Agent [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The literal-reader test goes to the provider `AGENTS.md`, beside the corpus it belongs to | It ranges over all seven judgements and prescribes none of its own, so no single skill owns it. AGENTS.md already states two writing rules in place and is what remains of the communication standard after M3.3.4's amendment, so a rule that governs every text lands there | this record |
| The seven-skill index is deleted rather than relocated | The provider `AGENTS.md` lists the same corpus with a gloss per judgement, and a third copy is what the slice is retiring | this record |
| `doc-maintenance` receives the checks, not the rules it applies | Its Non-goals refuse to hold a rule: a finding whose correct form no sentence determines is a gap to report. So the lint rule set obligation becomes a gate-table row and every rule goes to `docs` | this record |
| The post-close correction form lands in `record-correction`, not in `doc-maintenance` | That runbook is the section's only caller, and the form is what it applies | this record |
| `### Missing documents` is deleted without a move | The project `AGENTS.md` already states it, in the same words, as a rule the agent obeys | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `### Simplified Technical English` named two tests and M3.3.4 filed the corpus without either: `cut-what-carries-nothing` states the delete test as its own, and the literal-reader test has no home in any skill | gap | a check that catches an instruction permitting unintended work would have died with the file | the test moves to the provider `AGENTS.md` in unit 3 |
| `doc-maintenance` names `documentation_policy.md` as the rule home it deliberately does not restate, in three places | defect | after the deletion the pass points at a missing file, and its Non-goals would have no target to defer to | retargeted in unit 2 |
| The ledger's `SOURCES` array names the policy file as one of its two sources, and 60 ledger rows are sourced from it | defect | deleting the file empties half the ledger's source set silently, and `--check` would fail on rows whose source is gone | `SOURCES` repoints and the ledger regenerates in unit 3 |
| Five gate headers and one advisor dispatch cite the policy as their rule's source of truth | defect | a script comment pointing at a deleted file is a reader's dead end, and the advisor would judge a slice against a bar that no longer exists | retargeted in units 1 and 3 |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/docs/SKILL.md`](../../.agents/skills/docs/SKILL.md) | rewritten from the seeded stub: the tree, the header, the content rules, grep structure, drafting and the per-type obligations |
| `scripts/check_document_shape.sh` | the header-format citation retargets, both places |
| `scripts/check_markdown.sh` | the rule-subset citation retargets |
| `scripts/lint/doc-ascii.mjs` | the character-set citation and the box-drawing exception retarget |
| `scripts/lint/document-shape.mjs` | the header-format citation retargets |
| `.markdownlint-cli2.mjs` | the two citations retarget |
| `tests/test_doc_wrap_rule.sh` | the wrapping citation retargets |
