# Agent Handover

**Date:** 2026-08-19
**Milestone:** M2.6.6 — terminology (session→iteration)
**Type:** Implementation (2B field-schema migration)
**Status:** Closed

## Objective

Execute **iteration 2B — handover field-schema migration**: rename the handover field headings/schema to schema-neutral names (strip "session"/"iteration" from all field headings), coordinate every consumer that reads those field names, and establish a formal historical transition so closed handovers with old headings (Bucket C3) keep parsing.

## Scope

The field-schema migration only. Renames the handover field headings to schema-neutral names and updates all consumers that reference them by name. The session→iteration *prose* sweep (2A), `RUN_ID`→`SESSION_ID` (iteration 3), the bundles refactor (iteration 4), and the `new-session`→`new-iteration` file rename (2A) are all out of scope.

## Carried forward

| Item | From handover |
|---|---|
| Reordered plan: 2B (schema migration) runs before 2A (prose sweep) | `20260819-10` |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | No `## …session…` or `**…Session…**` schema field remains in the handover template | `grep -rn "^## Next session\|^## Mid-session findings\|^## Completed this session\|^## Decisions made this session\|^## Session directive\|\*\*Session date:\|\*\*Session type:" docs/ src/` → zero non-handover hits | Agent ✅ |
| 2 | All consumers reference the neutral headings (wrapup, whats-next, audit.skill, recovery.skill, new-session.md, project_index, iteration_policy) | grep per consumer file; all use `What's Next`/`## Findings`/`## Completed`/`## Decisions`/`## Directive`/`**Date:**`/`**Type:**` | Agent ✅ |
| 3 | Historical handovers not retro-renamed; history-scanning consumers dual-grep old+new | `recovery.skill.md` and `whats-next.md` grep `-E "…\|…"` both forms | Agent ✅ |
| 4 | Full suite green | `bash scripts/run_tests.sh` | Agent ✅ (476/0/0) |
| 5 | Migration logged as a GOTCHAS entry with a removal point | `devlog/GOTCHAS.md` `[G] 2026-08-19` entry present | Agent ✅ |

## Findings

| Finding | Type | Impact |
|---|---|---|
| 1 | The "session" remaining in `iteration_policy.md`, `git_policy.md`, `audit.skill.md` line 33, `whats-next.md` after the grep, and `AGENTS.md` are **workflow-step names / prose** (`Mid-session findings triage`, `mid-session findings review/publish step`, "at session close", "session branch"), NOT field headings. They are correctly deferred to 2A (the step names become "findings review/publish step" there). | next unit (2A) |
| 2 | `tests/eval/eval_templates.sh` (T6 `**Session type:**`) and `eval_commit3.sh` (C15 "Mid-session findings triage gate") are **archival** point-in-time audits (Bucket C3), not run by `make test`. Left untouched per the prior finding. | next unit (none — archival) |
| 3 | `whats-next.md` dual-grep `-E "Mid-session findings|Findings"` — the bare `Findings` alternative is broad, but acceptable as a transition bridge; the GOTCHAS entry documents the cleanup point. | current unit (documented) |

## Completed

| File | Change |
|---|---|
| `docs/operations/handover_policy.md` | Template: `**Session date:**`→`**Date:**`, `**Session type:**`→`**Type:**`; `## Decisions made this session`→`## Decisions`, `## Mid-session findings`→`## Findings`, `## Completed this session`→`## Completed`, `## Next session`→`## What's Next`; File Naming table (`Session date`→`Date`, `Session type`→`Type`); Session Types table → `Type`; Canonical Null Markers table → neutral; prose field refs ("Next session is context-only"→"What's Next is context-only", "add it to Mid-session findings"→"add it to Findings") |
| `docs/operations/iteration_policy.md` | Step 1 "populate Hot files and Session type"→"and Type"; Gate 1 "session type"→"type" (×2); Step 1 Details `**Session type:**`→`**Type:**`; on-task/on-discovery/on-steering "Mid-session findings"→"Findings", "Next session"→"What's Next"; propagation replay / scope reconciliation / carry-forward gate / review-publish step — "Completed this session"→"Completed", "Next session"→"What's Next", "Mid-session findings"→"Findings"; Step 8–9 "Seed next session"→"Seed What's Next", "Next session actionable"→"What's Next actionable"; recovery check "Next session"→"What's Next" |
| `src/reasoning/agent/prompts/new-session.md` | `## Session directive`→`## Directive`; "Next session section"→"What's Next section"; `| Session type |`→`| Type |`; "session type"→"type" (field refs); frontmatter description "session type"→"type", "Next session section"→"What's Next section" |
| `src/reasoning/agent/prompts/wrapup.md` | "Completed this session table"→"Completed table" (×3); "Seed next session"→"Seed what's next"; "Next session section"→"What's Next section" |
| `src/reasoning/agent/prompts/whats-next.md` | read "Next session sections"→"What's Next sections"; Step 4 grep `"Mid-session findings"`→`-E "Mid-session findings|Findings"` (dual-grep) |
| `src/reasoning/agent/drafts/audit.skill.md` | required-sections list → neutral (Decisions, Findings, Completed, What's Next); `## Next session`→`## What's Next`; `## Completed this session`→`## Completed` |
| `src/reasoning/agent/drafts/recovery.skill.md` | `grep "**Session date:"`→`grep -E "**Session date:|**Date:"` (dual-grep); "Verify session date consistency"→"Verify date consistency" |
| `docs/development/project_index.md` | "Completed this session table"→"Completed table" |
| `devlog/GOTCHAS.md` | Added `[G] 2026-08-19` dual-grep bridge entry with removal point (~30 handovers / ~1 week) |
| `devlog/handovers/20260819-11-impl-2b_field_schema_migration.md` | This handover — written under the NEW schema (first adoption) |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| A | **Bold preamble fields stay bold** — `**Session date:**`→`**Date:**`, `**Session type:**`→`**Type:**`, not promoted to `##` headings | operator (Q1): bold-field format retained for preamble `type`/`date` |
| B | **Dual-grep transition** — history-scanning consumers match both old+new heading forms; active-handover readers use new only | operator (Q3): dual grep is fine |
| C | **Migration logged as a GOTCHAS entry** with explicit removal point (~30 handovers / ~1 week) | operator (asked to record in gotchas; fits the sweep workflow) |
| D | `## Session directive`→`## Directive` in the new-session.md prompt | operator (Q2 confirmed) |
| E | `git_policy.md`, remaining `iteration_policy.md` step names, `AGENTS.md` prose, `tests/eval/*` left untouched | 2A / bucket-C3 territory — out of 2B scope |

## What's Next

2A — session→iteration prose/entity sweep: rename `new-session` skill → `new-iteration` + invocation surface; sweep independent ops-workcycle prose "session"→"iteration" across `git_policy.md`, `iteration_policy.md` step names, `AGENTS.md`, skills/drafts/concepts/dev docs; B4 new devlog prose. Now unblocked by the neutral schema (no field heading carries "session" anymore). Re-read the dual-grep GOTCHAS entry.
