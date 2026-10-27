# The instruction surface, measured

**Status:** draft
**Date:** 2026-10-27
**Instruments:** `.scratchpad/surface/{bill,reads,corpus,exercise,union,dup,near}.mjs`, throwaway, reproducible from the session store and the tree.

## Why this exists

The claim that started this was that the instruction surface has grown unmaintainable and is degrading agent performance. That claim had no number behind it, and every plan to trim was therefore an argument. This report measures it from two sources that predate the plan: the assembled system prompt and the tool calls in 550 project sessions, and the corpus itself as files, statements and history.

Subject: 178 live instruction files under `.agents/skills`, `workflow/coding-agent/{skills,prompts}`, `src/reasoning/agent/skills` and `docs/{reference,development,adr}`, plus the project `AGENTS.md`. Records under `devlog/` are excluded; they are history, not instruction.

## The bill

Parsed from the `system` message's `sections` in each session file.

| Section | Median chars, September | Median chars, October |
|---|---|---|
| `project_context` (both `AGENTS.md` layers) | 21,795 | 28,978 |
| `skills` (the skill index) | 2,515 | 13,697 |
| `tools`, `rules`, `docs`, `preamble` | ~3,300 | ~3,300 |
| **assembled total** | **26,892** | **46,173** |

The assembled context before any work starts grew 72% in a month. The skill index grew 5.4x. The project `AGENTS.md` layer went from 67 lines at creation to 203, and it is half the `project_context` bill; the provider layer is the other half and is unchanged.

## The behaviour

From the same 550 sessions.

| Measure | Value |
|---|---|
| Tool calls, total | 93,372 |
| `grep`/`rg`/`find` calls | 34,318 |
| `read` calls | 12,084 |
| Sessions that re-read at least one file | 273 of 550 |
| Repeat reads, total | 5,464 |
| Sessions with no instruction-file read at all | 203 of 550 |
| Median tool calls per session | 59 |
| Median reads per session | 8 |

The agent searches 2.8 times for every file it opens, and re-opens the same file 5,464 times. That is the retrieval cost, and it is larger than the reading cost.

## The corpus

| Measure | Value |
|---|---|
| Files | 178 |
| Lines | 14,195 |
| Statements (sentences over ten content words) | 3,722 |
| Exact-duplicate statements | 34, 0.5% of text |
| Near-duplicate statements (Jaccard >= 0.55) | 224 in 103 groups, 3.0% of text |
| Exercised by any mechanism in 550 sessions | 135 files, 10,866 lines |
| Never exercised | 43 files, 3,329 lines |
| Never exercised *and* unchanged since 2026-09-01 | 1 file, 38 lines |
| Never exercised and referenced by nothing | 4 files, 163 lines, three of them created this fortnight |

Exercise is the union of three mechanisms: a `read` call, a skill or prompt body injected into a session's user turns, and the always-loaded layers. Twenty of the 178 files are unexercised only because their text changed inside the observation window, which makes the signature match fail; that is a limit of the instrument, not evidence of disuse.

## What this overturns

The plan this measurement was commissioned to support assumed the documents were the problem and that trimming meant deleting unused ones. The data says otherwise on both points.

1. **There is no dead-file tier.** One file is unexercised and stable, at 38 lines. Deleting unused documents is not available as a strategy at this surface's current shape.
2. **There is almost no duplication.** Three per cent of the text restates another statement in other words. The corpus is long because it holds many distinct rules, not because it repeats a few.
3. **The cost is the index and the routing, not the documents.** The always-loaded index grew 5.4x in a month while the documents it indexes were used 1,763 times across 550 sessions. The agent spends 2.8 searches per read.

So the trimmable surface is the always-loaded layer and the number of searches needed to find a rule, in that order. Deleting prose from documents that are read is the lowest-yield lever of the three.

## What it does not show

- Whether a smaller index or a shorter `AGENTS.md` improves agent behaviour. The ablation -- the same held-out questions asked against the full surface and a trimmed one, scored blind -- has not been run. This report measures the surface and infers the cost; it does not test the intervention.
- Whether an index would cut the searches. A deterministic benchmark over sixteen questions, ranking files by keyword count against the bodies and against an index of headings and descriptions, put first-hit accuracy at 2 of 16 and 4 of 16 and the files scanned at 176 against 239. Both arms are too weak to separate: keyword counting over 178 files is not what an agent does, and a benchmark that scores 12 per cent cannot support a claim either way. It is recorded as a null result, not as evidence for the index.
- Whether the 43 unexercised files are unused or merely unexercised. The instrument cannot tell a file nobody needs from a file nobody found, and the second is a routing defect with the same reading.
- The token bill as pi accounts it. The figures are characters from the assembled sections, not billed tokens.

## Artifacts

- The instruments, in `.scratchpad/surface/`, throwaway and reproducible.
- The raw per-session and per-file rows: `.scratchpad/surface/{bill,corpus,exercise}.json`.
