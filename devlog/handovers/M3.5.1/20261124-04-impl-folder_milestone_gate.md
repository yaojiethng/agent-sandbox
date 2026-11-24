---
date: 2026-11-24
milestone: M3.5.1 - The work-log record layer
type: Implementation
status: Closed
---

# Handover - the folder and the milestone field agree

## Objective

Make the handover's track folder and its `milestone` field one fact, and have the format gate fail when a record is filed under one track while its field names another.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A record under one track whose `milestone` names another fails, and the finding names the folder and the field. | `bash tests/test_handover_format_gate.sh`, mismatch case | Accepted |
| The live corpus passes. | `bash scripts/check_handover_format.sh` | Accepted -- clean across 414 |
| A record under `archive/` is exempt. | the gate's archive case | Accepted |
| The gate's header names the added check. | `grep -n 'track' scripts/check_handover_format.sh` | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The check extends the handover format gate. | The gate already parses the frontmatter and walks the live tree, so the declaration and the reader stay in one artifact. | This record |
| The pass rule is the `task-list` convention's form: the field equals the track id or starts with `<track> - <name>`. | A second, looser definition of the field would be a collision. | `task-list` `## The milestone identifier` |
| A record filed directly under `devlog/handovers/` is outside this check. | The row's subject is agreement between two homes, not the presence of a track folder; the fixture records that file at the root stay legal. | This record |
| `archive/` is exempt. | The archive is frozen, and the live walk already skips it. | `src/build/record-layout.json` |

## Findings

None.
