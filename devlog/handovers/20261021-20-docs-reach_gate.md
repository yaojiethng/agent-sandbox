---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Documentation
status: Closed
---

# Handover - The reach axis is held to the manifest by a gate

## Objective

Stop the reach axis from being two hand-stated lists that drift apart, by holding the taxonomy's route table and the manifest's mount rows to each other.

## Scope

The roadmap row **The reach axis is stated by hand where the manifest could render it**.

The row named one solution: a `scope` value on the manifest's `image` and `cells` rows, a renderer for `## Reach`, and a gate over the pair. Two rounds of scoping replaced it with the gate alone, because a renderer and a gate give the same guarantee at different costs. A renderer rewrites the section, so a hand edit disappears without a report. A gate refuses the edit and names the side that moved, which is what `scripts/check_norm_ownership.sh --check` already does for the ledger. The `scope` key existed to feed the renderer, so it went with it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The gate reads both ends and copies neither | `node scripts/lint/reach.mjs` prints five mount points and four folders, all derived | Agent [x] |
| A root on one side and not the other fails the umbrella | `bash tests/test_check_reach.sh` prints `6 passed, 0 failed`, one case per assertion | Agent [x] |
| The gate runs as part of `bash scripts/lint.sh` | the umbrella prints `Lint: clean in 8s across 12 gates` | Agent [x] |
| The live tree is clean | `bash scripts/check_reach.sh` prints `reach: clean across 5 mount point(s) and 4 folder(s)` | Agent [x] |
| The suite and the ledger still hold | `bash scripts/run_tests.sh` prints `1284 passed, 0 failed`; `bash scripts/check_norm_ownership.sh --check` prints `clean across 140 row(s)` | Agent [x] |

## Decisions

The gate derives each folder's class from the table's own `Delivered by` column. A row that reads `nothing` states folders the manifest must not reach; any other row states roots the manifest must deliver. The first attempt classified a folder by whether an image source covered it, and that is circular: a folder the taxonomy states repository-only, shipped by the manifest, would have been read as delivered and passed. The test that caught it is the one that ships `devlog/`.

The mount route names four mount points instead of one. The gate's first run against the live tree reported the four `/opt/workflow/agent/` roots the manifest mounts and the table did not route. That was the drift the row existed to catch, found by the instrument built to catch it, and it is the argument for a gate over a renderer: a renderer built from the manifest would have emitted the new rows silently and nobody would have learned that the table had been incomplete.

A renderer stays unbuilt. Its remaining benefit is one fewer hand edit when a mount moves, which is rare, and its cost is the silent overwrite of anything a writer adds to the section.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The route table named one mount point where the image uses five, so four roots reached every session with no stated reach | defect | found by the gate's first run and fixed in the same unit. The table now names `/opt/sandbox/`, `/opt/workflow/agent/skills/`, `/opt/workflow/agent/prompts/` and `/opt/workflow/agent/modules/` | fixed in this unit |
| A folder's class cannot be derived from the manifest without circularity | defect | the first classifier would have passed the exact drift the gate exists to catch. The table's `Delivered by` column is the side that states it | fixed in this unit |
| The row named a `scope` key, a renderer and a gate, and none of the three was needed together | process | the row's stated nature of change was a guess about a solution, written before the guarantee was separated from the machinery. The gate keeps the guarantee | recorded here; the row's ending is rewritten to the guarantee rather than the machinery |

## Completed

| File | Change |
|---|---|
| [`scripts/lint/reach.mjs`](../../scripts/lint/reach.mjs) | the scanner: parses the `## Reach` table and the manifest's mount rows, and reports the side that moved |
| [`scripts/check_reach.sh`](../../scripts/check_reach.sh) | the gate wrapper, with the fixture seam and the failure message that names both files |
| [`tests/test_check_reach.sh`](../../tests/test_check_reach.sh) | six cases: clean, an unrouted mount, an empty route, a repository-only folder the manifest ships, a delivered folder the tree lacks, and the section boundary |
| [`docs/reference/documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md) | the route names all five mount points, and `## Reach` states the gate that holds it |
| [`docs/development/instruction-surface-conventions.md`](../../docs/development/instruction-surface-conventions.md) | `## The gates` lists the reach gate with the others |
| [`scripts/lint.sh`](../../scripts/lint.sh) | the gate joins the umbrella |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed as the guarantee, not the machinery |
