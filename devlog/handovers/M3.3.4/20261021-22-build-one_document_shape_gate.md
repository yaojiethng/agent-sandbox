---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Implementation
status: Closed
---

# Handover - One gate holds the instruction documents' frontmatter and their shape

## Objective

Reduce the number of gates and scanners the milestone left behind, without losing a rule any of them enforced.

## Scope

The roadmap row **One gate holds the instruction documents' frontmatter and their shape**, plus the loader deletion that was proposed with it.

Two scanners read the same files the same way. Both derived their roots from the manifest's cells, both carried their own recursive collect, both loaded pi's frontmatter parser, and both reported findings in one shape and exited on a count. The claims differed: one held that a block parses and a shipping document declares its reader, the other that a `principle-` skill carries the corpus shape and a claim.

`yaml-loader.mjs` went with them. Pi's frontmatter parser is `yaml`'s `parse` behind the product's own block extractor, so the handover scanner, the one gate that reads a file pi never loads, takes the same loader every other scanner takes.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One gate replaces the two | `grep -c check_document_shape scripts/lint.sh` is 1, and `Lint: clean` prints across 11 gates | Agent [x] |
| No rule was dropped | `node scripts/lint/document-shape.mjs` prints 116 instruction files, 20 shipping documents and 25 principle skills, the three counts the two gates printed separately | Agent [x] |
| The merged gate is tested on both claims | `bash tests/test_document_shape.sh` prints `14 passed, 0 failed`, three cases of which cover the parse claim | Agent [x] |
| The umbrella's frontmatter cases still hold | `bash tests/test_lint_umbrella.sh` prints `35 passed, 0 failed` | Agent [x] |
| One loader serves every scanner that parses | `grep -rn "loadPiFrontmatter" scripts/lint/` names three scanners and one module | Agent [x] |
| The ledger follows the gate | `bash scripts/check_norm_ownership.sh --check` prints `clean across 140 row(s), 23 gated` | Agent [x] |
| The suite is green | `bash scripts/run_tests.sh` prints `1287 passed, 0 failed` | Agent [x] |

## Decisions

The merged gate carries three claims, and a gate may: `check_container_layout.sh` already holds a dozen. What a gate owns is one subject, and the subject here is the instruction document: its block, its declared reader, and, where it is a principle, its shape.

The fail-closed rule moved from the corpus to the module tree. The old shape gate failed when a scan root held no `principle-` directory, which is right for the tree the gate ships to and wrong for a fixture pointed at one claim. A fixture that exercises the parse claim has no principle corpus and should not fail for it. The rule now reads `REPO_ROOT === MODULE_ROOT`, so the real tree keeps the guarantee and a fixture is a tree with what it was given.

The corpus finding stayed a finding rather than an early exit. The old gate printed an error and exited before its report, so a tree with a malformed block and no principle lost the parse finding behind the corpus message. Both now print in one report.

`--map` stayed. It is a derived view of the corpus by claim, it has one consumer, and moving it elsewhere would give it a second home.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Two scanners held one file set, one walk and one parser, and only their claims differed | result | the merge removed a manifest read, a walk, a report and a wrapper. `scripts/lint/` holds nine scanners where it held eleven | fixed in this unit |
| `yaml-loader.mjs` reached a parser pi already exports, and the handover scanner reimplemented the extractor that parser begins with | result | one loader now serves every scanner that parses frontmatter, and one rule holds: a gate parses by the rules the product parses by | fixed in this unit |
| The module-tree fail-closed branch has no unit test, because a fixture is never the module tree | gap | the guarantee rides a three-line condition. A fixture that copied the module root without its principles would test it and would also need the claim table, so it is recorded rather than built | recorded here; no row filed |
| The frontmatter claim had no test file of its own before this unit | result | the merged harness holds both claims, and its three parse cases are new coverage rather than moved coverage | fixed in this unit |

## Completed

| File | Change |
|---|---|
| [`scripts/check_document_shape.sh`](../../scripts/check_document_shape.sh) | the gate, replacing `check_frontmatter.sh` and `check_skill_shape.sh` |
| [`scripts/lint/document-shape.mjs`](../../scripts/lint/document-shape.mjs) | three claims, one walk and one report, replacing `frontmatter.mjs` and `skill-shape.mjs` |
| `scripts/lint/yaml-loader.mjs` | deleted; `handover-format.mjs` takes the surviving loader |
| [`tests/test_document_shape.sh`](../../tests/test_document_shape.sh) | the merged harness, 14 cases, three of them new parse coverage |
| [`tests/test_lint_umbrella.sh`](../../tests/test_lint_umbrella.sh) | the frontmatter cases point at the merged gate and its seams |
| [`scripts/lint.sh`](../../scripts/lint.sh) | 11 gates |
| [`scripts/lint/norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv) | eight rows move to the merged gate's observer, and three reclassified lines take it |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md), [`docs/adr/principle_skill_shape.md`](../../docs/adr/principle_skill_shape.md) | the gate named in each |
| [`devlog/roadmap.md`](../roadmap.md) | the row filed and closed |
