---
date: 2026-10-06
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - A Shipped Document's Links Resolve in the Image

## Objective

Close the measured dead-link class: a document that ships into the container links a document that does not, so its reader follows a pointer to a path that is not there. 105 links sat in that class across 21 shipped documents.

## Scope

The link check resolved an instruction root's links in the image's path space and a bundled document's links in the repository's. That split made a prompt's links correct and left every shipped `reference/` and `policies/` document unguarded, because both checks agreed that a relative link to `docs/adr/` resolves. It resolves in the repository. The container holds no repository tree, so the link is dead for the reader the document declares.

In scope: the check, the 105 links, the four stale paths and terms the sweep surfaced alongside them, the test cases, and the rule's documentation. Out of scope: the doc-maintenance skill that owns the review half, and the `default:` half of the reader pass.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A link from a shipped file that resolves only in the repository fails the gate | a probe document under `docs/reference/` linking `../adr/sandbox_delivery_model.md` reports `link target does not exist in the image` | Agent [x] |
| A link between two shipped documents still resolves | `tests/test_record_links_rule.sh` `test_link_between_two_bundled_documents_is_clean` | Agent [x] |
| No shipped document links a document that does not ship | the sweep reports zero, and lint is clean across the tree | Agent [x] |
| The rule is stated where its authors read it | `prompt-authoring-conventions.md` `## A reference resolves where the prompt runs` | Agent [x] |
| The suite is green | `bash scripts/run_tests.sh` | Agent [x] -- 1118 tests across 76 files, 0 failed |
| Lint is clean | `bash scripts/lint.sh` | Agent [x] -- 8 gates clean |
| The handover closes | this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/lint/record-links.mjs` | the image-space check now covers every shipped file |
| `tests/test_record_links_rule.sh` | one case inverted, one added |
| 21 documents under `docs/reference/` and `docs/policies/` | 105 link sites |
| `docs/development/prompt-authoring-conventions.md` | the rule stated for bundled documents |
| `docs/development/bash-coding-conventions.md`, `docs/adr/coding_agent_loop_workflow.md`, `docs/policies/documentation_policy.md` | stale folder paths from the rename |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The check keys on `image_path_of(name)`, not on the instruction-root list | the shipped set is the manifest's `image` rows, and a bundled document ships as surely as a prompt does; the instruction-root filter was the defect | `record-links.mjs` header |
| A non-shipping target is named by its repository path in a code span | the settled form for a prompt, and the display text of most of the 105 sites already was that path | `prompt-authoring-conventions.md` |
| The rule is stated in the authoring conventions, and proposed as a policy clause | a new policy clause is a governance change and is proposed in chat before it is written | this handover, `## Findings` |
| The `cells` guard in the rule is removed with the filter it protected | no reader remains, and `imageMap`'s own guard still fails loudly on a broken declaration | `record-links.mjs` |

## Decisions pending

| Decision | Needs |
|---|---|
| The `### Reference handling` clause in `documentation_policy.md` | operator release; the proposed text is quoted in the review reply |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `documentation_policy.md` `### Reference handling` says documentation and policy link to the ADR that records a decision. From a shipped document that link is now a gate failure, so the clause needs the shipped-document exception. Text proposed in the reply. | design gap | blocks the policy's own consistency until released |
| The folder list in `documentation_policy.md` `## Folder Structure` still read `reference/`, `reference/`, `operations/`. Two of the three names were retired by the rename, and a duplicated `reference/` had hidden the loss. | agent mistake | fixed in this unit |
| `docs/adr/coding_agent_loop_workflow.md:18` named `docs/operations/` in a live ADR. Fixed as a stale path, which leaves the rule open: whether a path inside a dated ADR entry follows a rename. Proposed for `adr_policy.md`, still awaiting release. | design gap | one live ADR corrected, the rule undecided |
| `docs/development/bash-coding-conventions.md` carried `docs/architecture` and `docs/concepts` in an example array. The example is the only reader either name had left. | agent mistake | fixed in this unit |

## Completed

| File | Change |
|---|---|
| `scripts/lint/record-links.mjs` | the image-space check applies to every shipped file; the instruction-root filter and its guard are gone |
| `tests/test_record_links_rule.sh` | the bundled-document case inverted, the bundled-pair case added; 18 passed |
| 21 shipped documents | 105 links to ADRs, records and development documents became names |
| `docs/development/prompt-authoring-conventions.md` | a paragraph stating the rule for a bundled document |
| `docs/development/bash-coding-conventions.md` | two example paths |
| `docs/adr/coding_agent_loop_workflow.md` | a live ADR's stale policy path |
| `docs/policies/documentation_policy.md` | the folder list |
| `devlog/handovers/20261006-08-workflow-a_shipped_documents_links_resolve_in_the_image.md` | this handover |
