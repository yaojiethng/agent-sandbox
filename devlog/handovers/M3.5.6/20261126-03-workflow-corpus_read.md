---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Implementation
status: Closed
---

# Handover - The twelve survivors, read against the tree

## Objective

Read every surviving discussion record against the tree, decide its fate and its owning row's fate, and state the rule that governs a row whose work will never be done.

## Scope

Row 3 of `M3.5.6`. Twelve records read, twelve verdicts, two owning rows annotated, no record deleted, and one clause added to `task-list`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every survivor names an open row whose subject matches the record. | the ownership listing in Findings; every line names a row title that restates the record's subject | Agent [x] |
| Every survivor carries a verdict from a read, not from its citation. | the verdict table in Decisions | Agent [x] |
| No record whose content has moved past the tree survives unremarked. | three records carry a drift note in Findings | Agent [x] |
| `task-list` states that a cancelled row is deleted, never marked. | `grep -n 'cancelled task is deleted' .agents/skills/task-list/SKILL.md` | Agent [x] |
| The two rows whose evidence moved are re-pointed to what remains. | `grep -n 'Re-read 2026-11-26' devlog/roadmap.md` answers two rows | Agent [x] |
| The gates pass. | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| No record is deleted: each of the twelve answers an open row whose subject still matches. | The rule deletes a record whose content has moved past the tree; a row with a live subject is the opposite case. | This record |
| The two T12 reports stay, and their rows are re-pointed instead. | Their subjects are live upkeep; what changed is which half of each finding still reproduces, so the row text is what drifted. | `devlog/roadmap.md`, the two T12 rows |
| A cancelled row is deleted, and `task-list` says so. | The convention stated no form for a row that will never close, so deleting would have been an invented practice. | `.agents/skills/task-list/SKILL.md` |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| All twelve survivors name an open row: `20261002` and `20261014` to T12, `20261003` to M3.5.2, `20261014-design` to the deferred doc-maintenance eval, `20261016` to T10's drain row, `20261025` to M3.2.3, `20261027` to two M3.3.6 rows, `20261101` to M3.3.8, `20261104` to the durable-settings row, `20261105` and `20261112` and `20261119` to M3.3.6 and M3.4.7. | measurement | the corpus is not orphaned; only the five already deleted were | this record |
| The shipped pi 1.3.0 promotes an in-scope saved default in `main.js` before `findInitialModel` runs, so the user-visible half of `20261002` is fixed upstream while the resolver order and the silent `fallbackMessage` remain. | measurement | the T12 row claimed all three findings still reproduce, which the entry path contradicts | the T12 row, annotated |
| `_addPersistedDefaultToNonEmptyScope` now appends a persisted choice to `enabledModels`, so `20261014`'s re-expansion gap is closed on the persist path and open on the refresh path. | measurement | the row now states which half remains | the T12 row, annotated |
| `20261016-report-carrier_census` cites two `docs/concepts/` paths that no longer exist, and `20261104-report-settings_json_fidelity` cites four paths under `src/reasoning/providers/pi/`; `20261112` cites a removed sample-project fixture. | record | three records point at a tree that has moved; each still answers its row, so the drift is recorded rather than the record deleted | this record; the drain row owns the census correction |
