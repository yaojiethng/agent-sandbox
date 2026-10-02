---
date: 2026-10-02
milestone: T1 - Workflow + Policy Organization
type: Impl
status: Closed
---

# Handover - The roadmap record link and wrap gates

## Objective

Make the roadmap records' links and prose checkable by the lint gate rather than by a reader, and end the wrap-debt exemptions when the file they cover is next edited.

## Scope

The link gate resolves relative targets and heading fragments across `devlog/roadmap.md`, `devlog/roadmap_future.md` and `devlog/changelog.md`, and then across the whole tree with the closed record trees exempted. The wrap gate ends a `doc-wrap` file exemption on the commit that next touches the file. Out of scope: re-pathing the dead links inside the exempted trees, which is a roadmap row; the prompt and document changes the gates reported, which are their own unit.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | A link that no longer resolves fails `make lint` on the commit that breaks it | `bash scripts/lint.sh` over a fixture with a dead target | pass |
| 2 | The records' link targets and fragments resolve | `bash scripts/lint.sh`, gate output `Record links gate: clean across 3 records` | pass |
| 3 | A listed legacy file's exemption ends when the file is edited | `bash scripts/check_doc_wrap_legacy.sh <legacy file>` exits 1 with its finding; the same run on a file with no entry exits 0 | pass |
| 4 | The grandfathered trees are never enforced | `bash scripts/check_doc_wrap_legacy.sh devlog/changelog.md` exits 0 | pass |
| 5 | Suite and lint green | `bash scripts/run_tests.sh`: 1028 of 1028 across 70 files; lint clean across 5 gates | pass |

## Hot files

| File | Change |
|---|---|
| `scripts/lint/record-links.mjs` | new markdownlint rule: relative targets exist, fragments name a heading |
| `scripts/lint/doc-wrap.mjs` | reads the shared `recordTrees` list and the `DOC_WRAP_ENFORCE` seam |
| `scripts/check_doc_wrap_legacy.sh` | derives the changed set, enforces it, reports stale entries |
| `scripts/check_markdown.sh` | counts custom-rule findings, prints the exempt coverage line |
| `scripts/lint.sh` | registers the legacy wrap gate as a fifth gate |
| `.markdownlint-cli2.mjs` | one `recordTrees` list, referenced by both rules; the 42-entry `legacyFiles` list |
| `tests/test_record_links_rule.sh` | 11 fixture tests for the rule |
| `tests/test_doc_wrap_legacy_gate.sh` | 5 tests for the gate and the seam |

## Decisions

1. **The gate is a markdownlint custom rule, not a bash script.** The first implementation was a bash gate wrapping `markdownlint-cli2`. It was replaced because markdownlint-cli2 discovers `.markdownlint-cli2.mjs` by walking up from the working directory and merges it with `--config`, so a temporary config cannot override the repository's own, and a single-file invocation still lints the config's globs. A rule inside the config's own `customRules` list has none of those problems. Handover `20261002-20` was the superseded version.
2. **The exclusions are configuration, and one setting has one key.** `recordTrees` is declared once in `.markdownlint-cli2.mjs` and read by `record-links` and `doc-wrap` under the same key. Two keys for one setting (`ignoredRoots`, `grandfatherTrees`) shipped briefly and had already drifted.
3. **The exempt set prints its size on every clean run.** `record-links coverage: 3 exempt tree(s), 651 Markdown file(s) exempt`, read from the same declaration, so the number and the list cannot disagree.
4. **`doc-wrap` is registered, and its exemptions expire on the next edit.** `grandfatherTrees` covers the closed record trees, which are appended to and never reflowed. `legacyFiles` covers 42 live files with wrap debt; they are exempt from the tree-wide run and enforced through `DOC_WRAP_ENFORCE`, which the rule reads to stop exempting a file the commit touches. The gate is blocking (operator ruling, 2026-10-02).
5. **`devlog/AGENT_FEEDBACK.md` is a legacy file, not a record tree.** Under the broad `devlog/` exemption it was covered by accident; unifying the lists surfaced its 40 findings, and it joined `legacyFiles`, where its exemption ends on its next edit.

## Decisions pending

- The grandfathered trees have no owner and no end. `legacyFiles` ends on the next edit; `recordTrees` ends when someone migrates a tree, and no row schedules that migration. The roadmap row carries the count and the choice; the gate does not enforce it.
- The coverage line measures the exempt set's size, not its debt: the three trees hold 1,195 dead links that the line reads as health. A baseline or a debt figure beside the count is an operator call.

## Findings

- **An enabled rule missing from `customRules` is a silent no-op.** `doc-wrap` ran unregistered for the life of the config, and the first several measurements of its behaviour in this session were taken against a config that no longer ran it. `check_markdown.sh` still has no assertion that every enabled rule name resolves to a `customRules` entry; the finding is recorded, the check is not written.
- **`check_markdown.sh` counted only `error MD<digits>`.** Custom-rule findings printed as `markdownlint: 0 finding(s)` beneath 1,902 errors. Fixed: the count matches any rule name.
- **`--staged` enforces the index, not the working tree.** A legacy file edited but not staged passes the gate silently. The precondition is stated in the script header rather than enforced.
- **`MD051` (link-fragments) checks same-file fragments only**, and no built-in rule tests that a relative target exists, so a custom rule is genuinely required.

## Completed

The rule, the gate, the config, the wiring, five tests over them, and 29 dead links in prompts, skills and documents that the rule reported.
