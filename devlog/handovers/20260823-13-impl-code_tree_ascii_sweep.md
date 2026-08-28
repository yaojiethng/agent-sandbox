# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Extend the `-11` ASCII-punctuation enforcement to the live code tree (`scripts/`, `src/`, `tests/`, `Makefile`), which the `-11` sweep did not cover: ~1258 non-ASCII lines across 131 files, dominated by em-dashes (1067) and arrows (185) in comments/doc-strings.

## Operator decisions (this session)

1. `.skill.md` draft files under `src/reasoning/agent/drafts/` **are in scope** -- sweep them like everything else.
2. **Box-drawing characters are an allowed exception**: leave them in sequence/architecture diagrams. If a box-drawing block sits in documentation AND its content is genuinely tabular, convert it to a markdown table instead. Exception to be recorded in `documentation_policy.md` Character set section.

## Scope

| File set | Change |
|---|---|
| `scripts/**`, `src/**`, `tests/**`, `Makefile` | Mechanical substitutions: em/en-dash -> `--`/`-`, arrow -> `->`, ellipsis, curly quotes, math symbols per context |
| `src/reasoning/agent/drafts/*.skill.md` | Same substitutions (prompt content, operator-approved) |
| Box-drawing sites | Inspect each: diagram -> leave; doc-table -> markdown table |
| [`docs/operations/documentation_policy.md`](../../docs/operations/documentation_policy.md) | Character set section gains the box-drawing-diagram exception |

Out of scope: historical corpus (operator decision, `-11`); devlog/docs prose already conformed.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Zero non-ASCII outside the box-drawing exception in the code tree | final grep: only `domain-model/SKILL.md` tree geometry remains (60 glyphs, all `├── └── │`) | accepted |
| AC2 | Every retained box-drawing site is a diagram (or converted to md table if tabular docs) | 3 sites inspected: SKILL.md trees = diagrams, kept; hermes dockerfile/yaml comment banners = not diagrams, converted to ASCII hyphens | accepted |
| AC3 | Box-drawing exception recorded in documentation_policy.md | Character set section gained exception paragraph + status-marker instruction | accepted |
| AC4 | No behavior change: suite green and deterministic x2 | 634 tests / 39 files / 0 failed x2 | accepted |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Bulk perl substitution with an unanchored alternation mangled two markdown files (`eval_protocol.md`, `propagation-check.md`); caught by immediate re-grep and repaired from git before re-applying with the edit tool | tooling near-miss | For multibyte sweeps: mechanical pass only for unambiguous single-char maps; anything with structure goes through exact-match edits |
| `interactive.sh` checkmarks were runtime UI strings, not comments -- swapped to `[x]` / `[ ]`; no test pinned the old glyph output | scope note | Recorded here |
| Checkmark semantics vary by context: table cells use `[x]`/`[ ]`, bullet lists `- [x]`/`- [ ]` (operator rule); decorative degree prefixes (`✅ Must change`) dropped where wording already carries the degree | operator rule | Applied; status-marker instruction added to policy |

## Completed

| File | Change |
|---|---|
| ~131 files across `scripts/ src/ tests/ Makefile` | em/en-dashes, arrows, ellipsis -> ASCII (mechanical perl pass) |
| [`scripts/workflows/interactive.sh`](../../scripts/workflows/interactive.sh) | Runtime UI strings `✓`/`✗` -> `[x]`/`[ ]` |
| [`tests/knowledge/knowledge_pi_config_cycle.sh`](../../tests/knowledge/knowledge_pi_config_cycle.sh) | Redundant `PRESENT ✓`/`MISSING ✗` marks dropped (words carry meaning) |
| [`src/reasoning/agent/prompts/new-iteration.md`](../../src/reasoning/agent/prompts/new-iteration.md), [`propagation-check.md`](../../src/reasoning/agent/prompts/propagation-check.md), [`tests/eval/eval_protocol.md`](../../tests/eval/eval_protocol.md) | Table-cell markers -> `[x]` / `[ ]`; warning emoji -> word "partial" |
| [`roadmap-audit.skill.md`](../../src/reasoning/agent/drafts/roadmap-audit.skill.md), [`refactor-mv-rename-file.skill.md`](../../src/reasoning/agent/drafts/refactor-mv-rename-file.skill.md) | Emoji references/prefixes removed per operator rules |
| [`hermes/base.dockerfile`](../../src/reasoning/providers/hermes/base.dockerfile), [`config.yaml`](../../src/reasoning/providers/hermes/config/config.yaml) | Comment banner rules `─` -> ASCII `-` |
| [`docs/operations/documentation_policy.md`](../../docs/operations/documentation_policy.md) | Status-marker instruction + box-drawing-diagram exception added to Character set section |

## Deferred items

- Historical corpus remains untouched (operator decision, `-11`).
