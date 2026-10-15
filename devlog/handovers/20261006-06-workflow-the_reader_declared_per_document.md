---
date: 2026-10-06
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Reader Declared Per Document

## Objective

Declare, on the document itself, the reader it serves, so the ship set is a checkable decision rather than a property of the folder a document happens to sit in.

## Scope

The folder rename gave the tree one ship value per folder. That covers a document that sits in the right folder and nothing else. The declaration covers the other two states: a shipping document that serves nobody in the container, and a document whose reader changed while its folder did not.

The field is `reader`, in the YAML frontmatter, holding one or more of `agent`, `operator` and `maintainer`. It is required on every document in a shipping folder, `docs/reference/` and `docs/policies/`. The shipping folders are read from the manifest's `image` rows, so a new `docs/` row adds coverage with no gate edit.

The rule with teeth: a document that declares the maintainer alone does not ship, and the gate fails one that sits in a shipping folder. That rule resolved an open item on the spot. `docs/reference/context_resolution.md` measured 12 of 12 sections on the maintenance side, so it moved to `docs/development/`, where a maintainer-only declaration is legal.

In scope: the field on 23 documents, the gate extension, three test cases, the policy bullet, and the prose that named the retired folders.

Out of scope, each with its reason: the frontmatter field for the `development/` and `adr/` documents, which may declare a reader but are not required to, because no rule turns on it; and the doc-maintenance skill, which is the next unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every shipping document declares its reader | `bash scripts/check_frontmatter.sh` reports 22 shipping documents declaring a reader | Agent [x] |
| A maintainer-only document cannot ship | a fixture shipping document declaring `reader: [maintainer]` fails the gate | Agent [x] -- `test_frontmatter_gate_rejects_a_maintainer_only_shipping_document` |
| A missing declaration fails | a fixture shipping document with no frontmatter fails the gate | Agent [x] -- `test_frontmatter_gate_requires_a_reader_on_a_shipping_document` |
| A declared reader passes | a fixture shipping document declaring `[agent, operator]` passes | Agent [x] -- `test_frontmatter_gate_accepts_a_declared_reader` |
| The shipping folders come from one source | the gate derives them from the manifest's `image` rows, with `FRONTMATTER_SHIPPED_ROOTS` as the test seam | Agent [x] |
| The prose names the new folders | a repo-wide grep for `architecture and concepts documents` and `the architecture doc` returns nothing | Agent [x] |
| The suite is green | `bash scripts/run_tests.sh` | Agent [x] -- 1117 tests across 76 files, 0 failed |
| Lint is clean | `bash scripts/lint.sh` | Agent [x] -- 8 gates clean |
| The handover closes | this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `docs/reference/` (15 documents) | the reader field, and the folder the gate covers |
| `docs/policies/` (7 documents) | the reader field inside the existing frontmatter block |
| `docs/development/context_resolution.md` | moved out of the shipping set by the new rule |
| `scripts/lint/frontmatter.mjs` | the reader check, and the shipping roots from the manifest |
| `tests/test_lint_umbrella.sh` | three cases for the field |
| `docs/policies/documentation_policy.md` | the header-format rule gains the field |
| `docs/policies/iteration_policy.md`, `docs/policies/adr_policy.md` | prose that named the retired folders |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The field lives in YAML frontmatter, not the header block | the frontmatter gate already parses frontmatter, and the header-format rule already gives policy files a frontmatter block, so the field reuses one parser instead of adding a second | `documentation_policy.md` `### Document header format`, this handover |
| Values are `agent`, `operator` and `maintainer`, one or more per document | they are the three readers the classification measured, and a document can serve two | this handover |
| Required in a shipping folder, optional elsewhere | the rule that turns on the declaration is the ship decision, so that is where the check belongs | this handover |
| The shipping folders are read from the manifest | one source for the layout, so a new docs row reaches this check with no edit | this handover |
| `context_resolution.md` moved to `development/` | its measured reader is the maintainer, and the new rule refuses a maintainer-only document in a shipping folder | this handover |
| Sub-kind names persist; folder names do not | `concept document` still draws the model-versus-rationale distinction inside the reference layer, so it stays, while the plural set phrases that named the shipped folders take the new names | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The folder rename updated paths but not prose. `Architecture and concepts documents` and `the architecture doc` survived in four live files after the folders were gone, and only a grep for the terms found them. A rename needs a term list, not only a path list. | evidence, measured | current iteration, fixed; the recurrence belongs in `devlog/AGENT_FEEDBACK.md` at the operator's word |
| The field would be dead configuration without the check, and the check would be arbitrary without the manifest. Both read one source, so the declaration, the folder and the build cannot drift apart. | design note | current iteration |
| A moved document keeps its outbound same-directory links, which now point at documents that stayed behind. The record-links rule caught both in `context_resolution.md`; nothing else would have. | evidence, measured | current iteration, fixed |

## Completed

| File | Change |
|---|---|
| `docs/reference/*.md` (15 documents) | `reader` declared in a new frontmatter block |
| `docs/policies/*_policy.md` (7 documents) | `reader: [agent]` added to the existing frontmatter block |
| `docs/development/context_resolution.md` | moved from `reference/`, `reader: [maintainer]` declared, same-directory links repointed |
| `scripts/lint/frontmatter.mjs` | the shipping roots from the manifest, the reader requirement, and the maintainer-only finding |
| `tests/test_lint_umbrella.sh` | three cases: missing, maintainer-only, declared |
| `docs/policies/documentation_policy.md` | the header-format rules carry the field, and the prose names reference documents |
| `docs/policies/iteration_policy.md` | the documentation rule names reference documents |
| `docs/policies/adr_policy.md` | two sentences name reference documents |
| `.markdownlint-cli2.mjs` | the exemption follows `context_resolution.md` into `development/` |
| `devlog/handovers/20261006-06-workflow-the_reader_declared_per_document.md` | this handover |
