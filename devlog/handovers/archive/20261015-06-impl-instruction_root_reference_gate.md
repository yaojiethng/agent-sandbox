---
date: 2026-10-15
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Implementation
status: Closed
---

# Handover - the instruction-root reference gate

## Objective

Give the instruction-surface declaration a reader, so a link from a cell's file must land inside the reach that cell grants.

## Scope

The M3.3.1 row `The instruction-root reference gate`. Continues handover `20261015-05`. This is the narrow, decidable half of the parked outgoing-link row, and it closes the last open row of M3.3.1.

Out of scope, and left parked under T1: the general half of the outgoing-link row, which covers repository paths named in comments and backticks, bash file paths, and counts. A throwaway scan found about 65 such references across 18 shipping files, most of them `docs/` paths whose retargeting belongs with the policy-form retirement in M3.3.2. Building that scan now would guess at a boundary the retirement is about to move.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A seeded violation fails the gate | `bash tests/test_record_links_rule.sh` case `test_link_outside_the_cell_reach_is_flagged` passes and names the finding | Agent [x] |
| The tree passes the gate | `bash scripts/check_markdown.sh` is clean over 911 files | Agent [x] |
| The reach is read from the declaration, not hardcoded | `instruction_reach` in `src/build/container-interface.mjs` derives the set from the manifest, so a new cell changes the check with no edit to the rule | Agent [x] |
| A `reachable` row is load-bearing | `test_link_through_a_reachable_row_is_clean` and `test_repository_link_under_a_reachable_row_is_clean` pass | Agent [x] |
| The suite and the lint umbrella are clean | `bash scripts/lint.sh` (8 gates) and `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The narrow half is the link reach, not a content scan | a backticked-path scan flags about 65 legitimate repository references whose retargeting belongs with the policy-form retirement; the ADR's silence test keeps the content whitelist-and-blacklist scan unbuilt | this record; `docs/adr/instruction_surface_declaration.md` |
| The reach is every instruction root, the session paths, and the cell's own `reachable` rows | sibling instruction roots already resolve at runtime and the existing test fixes that boundary; the session paths are the environment every surface reads; the cell's `reachable` rows are what the declaration adds and what the check makes load-bearing | `docs/development/instruction-surface-conventions.md` `## The gates` |
| `instruction_reach` lives in `container-interface.mjs` | the module is the manifest's only reader, and `record-links.mjs` already imports it; putting the derivation anywhere else would create a second parse | `src/build/container-interface.mjs` |
| The general half of the outgoing-link row stays parked | its failures are loud where the retirement will change the paths, so the engine waits for the retirement and a violation | this record; T1 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The literal reading of the row, a link confined to the cell's own root, would fail 31 legitimate sibling-root links. The existing `test_sibling_instruction_root_link_is_clean` had already fixed the boundary at the whole instruction layer. Triaged to: this record's Decisions table. | obstacle, measured | this iteration |
| A repository-path scan over shipping cells finds about 65 references across 18 files, mostly `docs/` paths the policy-form retirement will move. Triaged to: T1 row `An outgoing-link and file-path gate over the instruction surfaces`, and M3.3.2's retirement slices. | steering | roadmap |

## Completed

| File | Change |
|---|---|
| [`src/build/container-interface.mjs`](../../../src/build/container-interface.mjs) | `instruction_reach` derives a cell's reach: instruction roots, session paths, and the cell's `reachable` rows |
| [`scripts/lint/record-links.mjs`](../../../scripts/lint/record-links.mjs) | a link in a cell's file must land inside the cell's reach; a repository link under a `reachable` row resolves there |
| [`tests/test_record_links_rule.sh`](../../../tests/test_record_links_rule.sh) | three cases: a target outside the reach, a reachable-row target, and a repository link under a reachable row |
| [`docs/development/instruction-surface-conventions.md`](../../../docs/development/instruction-surface-conventions.md) | `## The gates` names the third reader and the reach it holds a file to |
| [`devlog/roadmap.md`](../../../devlog/roadmap.md) | the row closes `[x]` with its outcome |
| [`devlog/handovers/archive/20261015-06-impl-instruction_root_reference_gate.md`](20261015-06-impl-instruction_root_reference_gate.md) | this record |
