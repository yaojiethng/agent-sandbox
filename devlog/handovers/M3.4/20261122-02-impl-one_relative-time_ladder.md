---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - one relative-time ladder

## Objective

Elapsed time is rendered by one ladder and one plural rule: the two densities differ in their labels, not in the buckets they choose.

## Scope

The M3.4.2 row **One relative-time ladder**, second of the three iterations this session runs. The row's epoch round-trip half landed with `20261122-01` (`ts_epoch` and `ts_from_epoch` in `src/libs/time_format.sh`), so this iteration records that resolution and owns the ladder and the plural rule. The file list is the scope proposal's and is presented at the scope gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One ladder: both densities resolve a given elapsed time to the same bucket | `bash tests/test_session_log.sh` - the bucket table asserts verbose and compact name the same bucket across every threshold | Agent [x] |
| One plural rule: no count phrase carries its own singular/plural branch | `grep -rn "echo '' \|\| echo 's'" src/ scripts/` prints nothing | Agent [x] |
| No second ladder exists | `grep -rnE 'diff < 60\|diff < 3600\|2592000' src/ scripts/` prints only `src/libs/session_inventory.sh` | Agent [x] |
| Both densities carry the month bucket | `test_relative_time_units` and `test_relative_time_compact_units` assert 31 days as "1 month ago" and "1M ago" | Agent [x] |
| The commit-distance phrase shares the plural rule | `test_project_commits_since_phrases_and_edges` passes on 0, 1 and 2 commits | Agent [x] |
| The roadmap row compacts to its landing note and handover link | `grep -n 'One relative-time ladder' devlog/roadmap.md` | Agent [x] |
| Every decision this iteration recorded is realized in the files | the `## Decisions` table read against the delivery diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One internal renderer holds the ladder; `relative_time` and `relative_time_compact` are the two public densities and each is a three-line wrapper. | The two functions differed in their thresholds, not only their labels, so the ladder was two ladders that happened to agree on the common cases. One renderer is the one place a threshold can change. | This table; `src/libs/session_inventory.sh` |
| One plural helper, `_plural_count N NOUN`, is shared by the verbose density and by `project_commits_since`. | The singular/plural branch was copied four times: three in the verbose ladder, one in the commit phrase. `project_commits_since` keeps its own noun ("commit"), which is why the helper takes the noun rather than fixing "minute". | This table; `src/libs/session_inventory.sh` |
| The month bucket applies to both densities, at 30 days. | The compact density already had it and the verbose one did not, so an age of 40 days rendered as "40 days ago" beside "1M ago" in the same table. Observable change, named: verbose ages of 30 days or more now read "N months ago". | This table; `src/libs/session_inventory.sh` |
| A gate scans the tree for a second ladder, and a table unit binds the two densities to one bucket set. | The row's defect is two ladders; a scan is what notices a third, and the table is what proves the two that exist agree. | This table; `tests/test_session_log.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's "two epoch round-trips" half was resolved by `20261122-01` before this iteration opened. | record | The row asks for work the tree already has, so a reader would re-derive it. | This iteration's write-back, which records the resolution in the landing note. |

## Completed

| File | Change |
|---|---|
| [`src/libs/session_inventory.sh`](../../../src/libs/session_inventory.sh) | `_plural_count` and `_relative_render` replace the two ladders and the four plural branches. |
| [`tests/test_session_log.sh`](../../../tests/test_session_log.sh) | The bucket table, the month bucket, the singular case and the no-second-ladder scan. |
| [`devlog/roadmap.md`](../../roadmap.md) | The **One relative-time ladder** row compacts to its landing note and handover link. |
