---
date: 2026-11-16
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - The principle frontmatter is one gate

## Objective

Trim the document-shape gate to the machine contract, and put every principle's frontmatter under one gate, so the body shape stays a convention and the gate checks what a parser reads.

## Scope

This iteration targets the new M3.3.7 row **The principle frontmatter is one gate, and the body shape is a convention**. It also resolves the two adjacent rows the trim carries: **The merged document gate's fail-closed branch has no test** and **`check_document_shape.sh` reports the wrong failure**.

Out of scope: the `metadata.intent` and `metadata.mechanism` values, which the field row owns; the `metadata.leitwort` presence, which waits on the same corpus values; the body-shape wording, which the convention and the exemplar carry; and a rename of `check_document_shape.sh`. The gate name stays because the frontmatter shape is still a shape, and the header says which one.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The principle body check leaves `document-shape.mjs`; the remaining parse, flag and reader checks are clean. | `grep -n "NAMED_PART\|WHY\|inspect(" scripts/lint/document-shape.mjs` returns nothing; `bash scripts/check_document_shape.sh`. | Agent [x] |
| One provider-root frontmatter gate is listed in `lint.sh`, and the neighbour wrapper is gone. | `bash scripts/lint.sh`; `test ! -e scripts/check_principle_neighbours.sh`. | Agent [x] |
| The frontmatter gate requires `name`, `description` and `metadata.neighbours`, and fails a malformed conditional field. | `bash tests/test_principle_frontmatter.sh`. | Agent [x] |
| The convention and the ADR state the split; the convention no longer says the gate holds the body. | Read `skill-conventions.md` `## A principle skill` and the new ADR entry. | Agent [x] |
| The document-shape and umbrella tests cover parse, flag and reader; the principle-shape cases are gone. | `bash tests/test_document_shape.sh`; `bash tests/test_lint_umbrella.sh`. | Agent [x] |
| The failing message prints the finding, not the shell error. | Run the gate against a fixture with a finding and read the message. | Agent [x] |
| The roadmap row, rows 124 and 136, and the stale `Active` handover are resolved. | `grep` each row; `bash scripts/worklog.sh active`. | Agent [x] |
| Every decision this iteration recorded is realized in the files. | `git diff` each decision against the tree. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One provider-root gate owns the principle frontmatter. | The frontmatter is the machine contract: pi parses it, the inventory lever reads it, and the field row depends on it. A second walk of the same corpus is a copy that drifts. | This record; the ADR entry |
| The body shape leaves the gate and stays a convention with the exemplar. | The body's consumer is a reader or an author, not a parser. The 2026-10-21 entry's observer for the body is the review and the exemplar. | This record; the ADR entry; `skill-conventions.md` |
| The document-shape gate keeps the parse, the `disable-model-invocation` boolean and the shipping reader. | Those are the checks with a machine consumer: pi drops an unparseable block, the loader tests the flag with `=== true`, and the shipping set is real. | This record |
| The frontmatter gate requires `name`, `description` and `metadata.neighbours`, and validates `metadata.leitwort`, `intent` and `mechanism` when present. | The corpus does not carry the last three uniformly yet, so a presence requirement would fail today. The field row makes them required. | This record; the ADR entry |
| Rows 124 and 136 are resolved by the trim and the message fix. | The fail-closed branch leaves with the body check, and the failing message is in the file this iteration edits. | This record; the roadmap write-back |
| The document gate keeps its name; the principle gate is `check_principle_frontmatter.sh`. | The document gate still checks a frontmatter shape, and the principle gate's subject is in its name. | This record; the wrapper header. |
| The inventory gains the declaration fields instead of a second walk. | The lever already reads the corpus, and the gate imports it, so one walk serves both. | This record; `principle_inventory.mjs`. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Handover `20261116-13` is still `Active` after its iteration closed, so `scripts/worklog.sh active` names it and a new Active record is ambiguous. | record | Blocks a clean active-record state. | This record; the status is set to `Closed`. |
| The `check_document_shape.sh` failing message holds a backticked path inside double quotes, so the shell executes the path and prints `Permission denied` instead of the finding. | defect | The operator cannot read the failure. | This record; row 136; the wrapper is edited. |
| The merged document gate's fail-closed branch is removed with the body check, so row 124's subject no longer exists. | record | The row would ask for a test of a branch that is gone. | This record; row 124 is marked resolved. |
| The track had no `devlog/handovers/M3.3.7/README.md` block, though the `work-log` convention reserves one. | gap | The next identity is derived from the files, so no collision occurred; the block was undocumented. | This record; the README is created with the `01-38` block. |

## Completed

| File | One-line change summary |
|---|---|
| `scripts/lint/document-shape.mjs` | Drops the principle body check; keeps the parse, flag and reader checks. |
| `scripts/check_document_shape.sh` | States the remaining checks; the failing message is single-quoted. |
| `scripts/lint/principle-frontmatter.mjs` | New. The consolidated frontmatter gate (renamed from `principle-neighbours.mjs`). |
| `scripts/check_principle_frontmatter.sh` | New wrapper (renamed from `check_principle_neighbours.sh`). |
| `scripts/check_principle_neighbours.sh` | Deleted with the rename. |
| `scripts/lint/principle-neighbours.mjs` | Deleted with the rename. |
| `scripts/principle_inventory.mjs` | Exposes the declaration fields for the gate. |
| `scripts/lint.sh` | Lists the frontmatter gate; header names it. |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | The body is a convention; the frontmatter gate is named. |
| `docs/adr/principle_skill_shape.md` | New entry: the split and its rationale. |
| `docs/reference/terminology.md` | The body is a convention; the frontmatter gate is named. |
| `tests/test_document_shape.sh` | Drops the body tests; adds the read-only body case. |
| `tests/test_principle_frontmatter.sh` | Renamed; adds the declaration-field cases. |
| `tests/test_principle_neighbours.sh` | Deleted with the rename. |
| `devlog/roadmap.md` | Adds the row; resolves rows 124 and 136. |
| `devlog/handovers/M3.3.7/README.md` | Reserves the `01-38` block. |
| `devlog/handovers/M3.3.7/20261116-13-impl-principle_intent_mechanism_fields.md` | Status `Active` to `Closed`. |
| `devlog/handovers/M3.3.7/20261116-19-workflow-principle_frontmatter_gate.md` | This record. |
