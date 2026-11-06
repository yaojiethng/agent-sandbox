---
date: 2026-11-05
milestone: M3.5.1 - The work-log record layer
type: Implementation
status: Closed
---

# Handover - The work-log record seam

## Objective

Build the work-log record seam: one layout declaration, one accessor, one tool for the derived reads, and a handover gate that walks track folders.

## Scope

The first unit of M3.5.1. It declares the work-log layout once, reads it through one accessor, answers the derived reads from one tool, and makes the handover format gate walk nested track folders while skipping `archive/`. It keeps the current flat tree valid: the 240 existing records still pass, the tool derives a flat record's track from its `milestone` field, and new tracks use folders from this unit. The migration of the 240 records is U3's; the prompt and reference carriers are U2's.

The `active-milestone` scalar is set to M3.5.1 for the iteration and returns to M3.3 at close.

Out of scope, with reasons: the prompt and reference carriers (U2); the 240-file migration and the cutoff tag (U3); the discussion and feedback commands, which stay shape-only per the design record.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The layout is declared once | `src/build/record-layout.json` names the handover root and the archive rule, and `recordTrees` reads from it; a grep of `src/build/` and `scripts/lint/` shows only the declaration and the accessor | Agent [x] |
| One accessor | `src/build/record-layout.mjs` is the only reader of the declaration, and `scripts/worklog.sh` uses it | Agent [x] |
| The tool answers the reads | `scripts/worklog.sh latest`, `active`, `track`, `reserve-id` and `list` each return the expected value on a fixture | Agent [x] |
| Two tracks on one day do not collide | a fixture with two track folders writing the same date and index resolves both | Agent [x] |
| The gate walks track folders and skips the archive | nested record and nested `archive/` fixtures | Agent [x] |
| The flat tree stays green | the 240 existing records pass `check_handover_format`, and `worklog latest` returns one | Agent [x] |
| The suite is green | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` clean | Agent [x] |

## Decisions

None.

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Where is a track's id block recorded? | `reserve-id` and the convention | the track folder's `README.md` (recommended); the roadmap row; a `devlog/tracks/` ledger |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `scripts/lint/handover-format.mjs` scans flat, so a nested folder would pass unchecked | defect | the gate would report clean over an unscanned tree | this unit |
| `runbooks/chain.md` validates `Active` only on the most recent handover | defect | the chain audit misreports every track but the last | U2 |
| The tool's first walk treated a track's `README.md` as a handover, so `latest` returned the ledger | defect | fixed here by a `filename` pattern in the declaration; the walk now selects records only | this unit |
| The `--track` filter read only the folder, so a flat record's track was invisible to `latest` and `active` | defect | fixed here: a flat record's track is its `milestone` field until the migration moves it | this unit |

## Completed

| File | Change |
|---|---|
| `src/build/record-layout.json` | the one declaration: record trees, the handover and discussion roots, the archive, the filename pattern and the id block |
| `src/build/record-layout.mjs` | the accessor and the CLI: `latest`, `active`, `track`, `reserve-id`, `list`, `path`, `trees`; a flat record's track is its `milestone` field |
| `scripts/worklog.sh` | the seam the procedures call |
| `.markdownlint-cli2.mjs` | `recordTrees` is read from the declaration instead of held here |
| `scripts/lint/linking.mjs`, `scripts/lint/doc-wrap.mjs` | the comments point at the declaration; both keep reading the config key |
| `scripts/lint/handover-format.mjs` | the default scan walks track folders through the accessor and skips the archive |
| `scripts/check_handover_format.sh` | the root is read from the declaration; the staged pathspec follows it |
| `.agents/skills/work-log/SKILL.md` | folder-is-track, id-is-identity, order-is-git, and the tool's commands |
| `tests/test_worklog_tool.sh` | six behavioural tests over a synthetic root |
| `tests/test_handover_format_gate.sh` | a nested folder and a nested archive case |
| `tests/test_numbering.sh` | a duplicate id across two folders fails |
| `devlog/handovers/20261105-15-impl-worklog_seam.md` | this record |
| `devlog/roadmap.md` | write-back: None; the M3.5.1 row stays open for U2 and U3 |
