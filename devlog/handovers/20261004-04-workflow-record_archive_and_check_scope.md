---
date: 2026-10-04
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Workflow
status: Closed
---

# Handover - Workflow: the archive boundary, and what the checks scan

## Objective

Cut each record tree at its own date, move every older record into that tree's `archive/`, scope the checks to the live folder, and bring the few live records at the boundary onto their tree's rule.

## Scope

A new intermission unit under T1 and T5. Unit A of the `model-refresh improvements` parent (handover [`20261004-03-impl-model_refresh_machine_enumeration.md`](20261004-03-impl-model_refresh_machine_enumeration.md)) stays Active and resumes when the intermission closes.

The handover cutoff is 2026-10-03 and the discussion cutoff is 2026-10-02, so no closed record is edited. Targets `devlog/handovers/` and `devlog/discussions/` (the move and the references into both), `scripts/lint/handover-format.mjs` and its test, `workflow/coding-agent/prompts/iter.md`, and the exempt-tree lists in the lint config.

Out of scope: the full rotation the T5 row names (a git tag or branch, and removal from `HEAD`); this is the folder stopgap. Unit A's state-machine work is untouched.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | Every handover dated before 2026-10-03 sits under `devlog/handovers/archive/` (568), and the live folder holds only records dated 2026-10-03 or later (20) | `ls` counts on both folders | Agent [x] |
| 2 | Every discussion dated before 2026-10-02 sits under `devlog/discussions/archive/` (82 `.md` and the one `.jsonl` export), and the live folder holds the three dated 2026-10-02 or later | the same count on the discussions folders | Agent [x] |
| 3 | The live handover folder holds only conforming records, so no closed handover is edited | `bash scripts/check_handover_format.sh` reports the live folder clean | Agent [x] |
| 4 | The three live discussions fit the discussion rule: the analysis record is `20261002-study-active-review_lens_learnings.md` with a `**Status:** active` line, and the report gains `**Status:** draft` | the naming scan and a status-line scan over the live discussion folder | Agent [x] |
| 5 | A live handover with no frontmatter block is a gate finding, and a record under `archive/` is not scanned | `bash scripts/check_handover_format.sh`; the two cases in `tests/test_handover_format_gate.sh` | Agent [x] |
| 6 | Every reference to a moved record resolves to its `archive/` path | a grep for a stale path returns nothing; the link check over the referencing files | Agent [x] |
| 7 | `/iter`'s `## Create the handover` step names the four keys and points at `handover_policy.md ## Format` | read the prompt | Agent [x] |
| 8 | The gates stay green | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| `devlog/handovers/*.md` | 568 records move to `archive/`; the live 20 stay |
| `devlog/discussions/*` | 83 records move to `archive/`; two live records are edited |
| [`scripts/lint/handover-format.mjs`](../../scripts/lint/handover-format.mjs) | the live scan and the block-absent path |
| [`tests/test_handover_format_gate.sh`](../../tests/test_handover_format_gate.sh) | the gate's cases |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | `## Create the handover` delegates the format without naming it |
| [`.markdownlint-cli2.mjs`](../../.markdownlint-cli2.mjs) | `recordTrees`, the exempt-tree list |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | references into both trees, and the T1 and T5 write-back |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Two cutoffs, one per tree: handovers before 2026-10-03 move, discussions before 2026-10-02 move | each tree's records became conforming on their own date. The handover boundary at 2026-10-03 leaves the 20 live records that already carry the frontmatter block, so no closed record is edited; the discussion boundary at 2026-10-02 keeps the report and the study live for their two edits | this record |
| The records that stay live are edited, not archived | the archive holds history, and a current record's defect is fixed where the reader meets it | this record |
| The archive is omitted from the checks, so the live folder is enforced in full | with history out of the folder, a live record that omits the format is a defect by construction, so the block-absent path is a finding rather than a skip | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `scripts/lint/handover-format.mjs` skipped a record with no frontmatter block in the default scan (`if (block === null) { if (force) {...} continue; }`), so the record that omits the block was never dated and never enforced | defect | fixed, criterion 5 |
| The 18 live handovers dated `20261002-01` through `20261002-18` carried no frontmatter block, and 51 sections were missing between them, `Hot files` among them; 6 also carried a forbidden `Deferred items` or `What's Next` section. The handover cutoff at 2026-10-03 moves all 18 into the archive untouched, where a correction would have had to fabricate sections for records written under an older template | obstacle | resolved by the two-cutoff choice |
| References into the two trees are far wider than the trees: 135 distinct moved handovers are cited from 16 files, and 102 distinct moved discussions from 170 files. A prefixed-path rewrite covered them all; no bare sibling link crossed the boundary | scope | done, criterion 6 |
| The live handover scan is `devlog/handovers/*.md`, non-recursive, so an `archive/` subfolder is excluded with no config change; `recordTrees` in `.markdownlint-cli2.mjs` is a path-prefix list, so the archive folders inherit the exemption | capability | done |
| Two references to deleted discussions stay dead (`devlog/AGENT_FEEDBACK.md` and `src/libs/package_branch.sh`), and a live handover's shorthand for four amended records needed its prefix updated by hand. A path re-point follows the move; it is not a correction to the record's content | note | done |

## Completed

- 568 handovers moved to `devlog/handovers/archive/`, 83 discussions to `devlog/discussions/archive/`.
- 624 prefixed references across 220 files re-pathed to the archive paths.
- `20261002-analysis-review_lens_learnings.md` renamed to `20261002-study-active-review_lens_learnings.md`, its frontmatter replaced by a `**Status:** active` line; `20261002-report-draft-default_model_resolution_bug.md` gained `**Status:** draft`.
- `scripts/lint/handover-format.mjs` flags a block-absent record in the default scan; `scripts/check_handover_format.sh` and the scanner header comments state the archive boundary; `tests/test_handover_format_gate.sh` replaces the grandfather case with the live-finding and archive-excluded cases.
- `workflow/coding-agent/prompts/iter.md` names the four keys in `## Create the handover`.
- `devlog/roadmap.md` gains the T1 archive-boundary row and the T5 stopgap note.
- Gates: `bash scripts/lint.sh` clean across 6 gates; `bash scripts/run_tests.sh` 1049/1049 passed.
