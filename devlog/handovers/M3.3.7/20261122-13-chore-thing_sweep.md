---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Housekeeping
status: Closed
---

# Handover - the banned word is swept and held

## Objective

`docs/reference/terminology.md` bans `thing` as a noun and nothing enforces it. Sweep the live carriers, and give the ban the check its entry implies.

## Scope

The shipping instruction surfaces the vocabulary gate already derives from the manifest, the gate's new claim, its fixture tests, and the terminology entry naming the check. Not in scope: records (ADRs, handovers, discussions, the changelog), which the ban's own scope excludes.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The gate holds the ban | `bash tests/test_vocabulary.sh`: a surface carrying the word fails, the registry entry passes, a longer word passes | Agent [x] |
| The declared surfaces carry none | `bash scripts/check_vocabulary.sh` reads clean across 6 sources | Agent [x] |
| The entry names its check | `docs/reference/terminology.md` `## thing` cites `scripts/check_vocabulary.sh` | Agent [x] |
| Every decision is realized in the files | the gate's pattern and exemption, the three fixture cases, the entry's line | Agent [x] |
| Gates hold | `lint.sh` clean across 30 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The sweep's scope is the gate's subject set, not the whole tree. | The gate derives its surfaces from `src/build/container-interface.json`, so the set is declared rather than hand-listed, and a surface added to the manifest is covered without editing the sweep. | This record |
| The gate gains the claim rather than a second script. | `check_vocabulary.sh` already holds a reserved-term ban over exactly these surfaces, with a `VOCABULARY_SCAN_ROOT` fixture seam. | `scripts/check_vocabulary.sh` |
| Records keep the word. | The ban's scope excludes a historical record, and `devlog/` carries what was true then. | `docs/reference/terminology.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The census reads 51 sites across the six declared surfaces. | Sweep | Each needs the artifact the sentence means, so this is a reading pass, not a substitution. | This iteration |
| The word appeared inside a code sample on one surface. | Content | The sample is renamed rather than excepted, so the gate needs no fence parser. | Fixed this iteration |

## Completed

| File | One-line change summary |
|---|---|
| [`scripts/check_vocabulary.sh`](../../scripts/check_vocabulary.sh) | Second pattern, the entry-heading exemption, updated header and message. |
| [`tests/test_vocabulary.sh`](../../tests/test_vocabulary.sh) | Three cases: a hit, the entry, a longer word. |
| [`docs/reference/terminology.md`](../../reference/terminology.md) | The entry names its check. |
| 38 carrier files | 51 sites rewritten to the artifact the sentence means. |
| [`devlog/roadmap.md`](../../roadmap.md) | The row closes. |
| [`20261122-13-chore-thing_sweep.md`](20261122-13-chore-thing_sweep.md) | This record. |
