---
date: 2026-10-03
milestone: M3.2.1 - Loops as Workflows
type: Housekeeping
status: Closed
---

# Handover - Completion context on the two roadmap parents that carry a landed gate

## Objective

State, on the two roadmap parent rows whose text reads as landed while an open sub-item remains, what landed and what is left.

## Scope

The `gm` survey of 2026-10-03 ran `roadmap-maintenance.md` over `devlog/roadmap.md` and reported three partially complete parents carrying no completion context under check 1.3. Two of them are gate rows whose text already says the gate landed, and their open sub-item is a separate piece of work, so the row reads to a picking agent as untouched.

| In | Out |
|---|---|
| Completion context on the `The prompt draft gate` parent | The marker change, which check 1.4 forbids while a child is open |
| Completion context on the `Prompt frontmatter parse gate` parent | The third parent, `Docs and ADR consolidation`, which carries twelve completed rows to summarise |
| | The write-back pairing rows and the handover cutover, which are units 2 and 3 of the same session |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The `The prompt draft gate` parent states what landed and names the open sub-item | `grep -n 'The prompt draft gate' devlog/roadmap.md`; the row names both halves | Agent [x] |
| The `Prompt frontmatter parse gate` parent states what landed and names the open sub-item | `grep -n 'Prompt frontmatter parse gate' devlog/roadmap.md`; the row names both halves | Agent [x] |
| Neither parent carries a closed marker over an open child | `grep -nE '^\s*- \[x\]' devlog/roadmap.md` against its indented children; no parent of either row is `- [x]` | Agent [x] |
| The records pass the gates | `bash scripts/lint.sh` reports clean across 6 gates | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the two parent rows carry the completion context |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Add the completion sentence rather than flip the marker | check 1.4 reads a closed parent holding an open child as done, so the marker stays open | this handover |
| Leave the third parent, `Docs and ADR consolidation` | summarising twelve completed rows is authored prose, not a mechanical edit; it waits | the survey finding |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| A parent row whose text reads as landed, with an open sub-item beneath it, is indistinguishable from an untouched task to the agent that picks it up. Both rows landed their gate in an earlier iteration. | gap | fixed here for two rows; the third parent is named in Scope |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | completion context added to the `The prompt draft gate` and `Prompt frontmatter parse gate` parents |
