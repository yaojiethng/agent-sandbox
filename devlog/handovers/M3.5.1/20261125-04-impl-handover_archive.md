---
date: 2026-11-25
milestone: M3.5.1 - The work-log record layer
type: Implementation
status: Closed
---

# Handover - the handover archive is retired

## Objective

Delete the handover archive, which no live document cites and no gate reads, and drop its declaration so the record layer holds one live region and one archive.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The handover archive is gone and its records are in the parent commit. | `test ! -d devlog/handovers/archive`; `git ls-tree -r cd1f60d2 devlog/handovers/archive` | Accepted: absent; the commit lists 716 records. |
| The layout declares no handover archive. | `node -e` reads `kinds.handover.archive` and `kinds.discussion.archive` | Accepted: undefined; the discussion archive is set. |
| A handover under `archive/` is a finding, not an exemption. | `bash tests/test_handover_format_gate.sh` | Accepted: 22 passed, 0 failed, including the archive mismatch case. |
| The gates and the suite are clean. | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Accepted: lint clean across 31 gates; 1753 passed, 0 failed. |
| Every decision this record carries is realized in the files. | Step 7 read of the Decisions table | Accepted: the deletion, the layout key, and the named citations are in the files. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete `devlog/handovers/archive/`; keep the discussion and ADR archives. | 126 files cite the discussion archive and 12 cite the ADR archive, including 21 roadmap links and the live ADRs' evidence tables; two live files cite the handover archive. | This record |
| Drop the handover `archive` key from `record-layout.json` and leave `kind_archive` for the other kinds. | The declaration is the single switch: with no key, the gate treats a record under `archive/` as a track mismatch rather than an exempt region. | This record |
| Name the two cited handover-archive records by id instead of path. | A handover is named, never linked, and the removal commit holds the record. | This record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's premise, that all three archive trees hold only closed-milestone records, holds for the handover archive alone. | evidence | The scope narrows to one tree; the other two stay as cited evidence stores. | This record |
| 12 archived discussion records link into the handover archive; those links dangle after the delete. | evidence | Accepted: a frozen record is a snapshot of the tree at write time, and the linking gate exempts a non-active record. | This record |
| The discussion and ADR archives stay, on operator direction, because live documents cite them as evidence. | scope | Ruled out of this iteration; no row is needed while their citations resolve. | This record |
