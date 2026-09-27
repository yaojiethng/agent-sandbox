# Agent Handover

**Date:** 2026-09-27
**Milestone:** M3.1 - Backpressure
**Type:** Documentation
**Status:** Closed

## Objective

Land roadmap row 85: compact the four read-through documents into one settled report paired with the jsonl register as the evidence store, and retire the markdown findings table.

## Scope

Roadmap row 85 ("Compact the read-through record and fold its evidence into the register"). Design settled by the grill-me session preceding this iteration (served as Gate 1 and Gate 2):

- One new report `devlog/discussions/20260927-report-settled-test_suite_readthrough.md` (new `report` discussion type).
- Register pair renamed: `20260927-report-settled-test_suite_readthrough.jsonl`, gaining an optional `evidence` string field on measured rows.
- The three original markdown files (`20260923-study-active-test_suite_complexity_audit.md`, `20260924-design-active-test_suite_readthrough.md`, `20260925-design-draft-readthrough_process_review.md`) deleted after the report is complete.
- Governance: `discussion_policy.md` gains the `report` type row, the status-ladder note, and the Reports subsection with its six required sections.
- Format doc `20260925-design-draft-findings_register_format.md` updated: name-pair rule, `evidence` schema row, propagation list.
- Live consumers updated: roadmap rows 81/82/83/143, `churn-analysis-run.md` line 7, six design notes, format doc. Handover references stay as history.
- Roadmap row 85 write-back.

## Carried forward

None.

## Acceptance criteria

1. Report exists at `devlog/discussions/20260927-report-settled-test_suite_readthrough.md` with the six required sections and `Status: settled`. Verifiable: `ls` + `grep -n "^##"`.
2. Register pair renamed; the old register name and the three original markdown files no longer exist (paired negative check). Verifiable: `ls` + `git status`.
3. jsonl integrity: 319 rows, ids 1-319 unique and ascending, every row parses; `evidence` present only on measured rows. Verifiable: perl queries.
4. Format doc updated: name-pair rule names the new register; schema table gains the `evidence` row; propagation list updated. Verifiable: `grep`.
5. `discussion_policy.md` amendments land: `report` type row, status-ladder note, Reports subsection. Verifiable: `grep`.
6. Zero live-consumer references to the four old filenames remain (roadmap, workflow prompts, design notes, format doc; handovers excluded). Verifiable: `grep`.
7. Report numbers reproduce from the jsonl code blocks: perl one-liners give the same counts the report states. Verifiable: run the code blocks.
8. Process content preserved: the durable process-review sections each appear in the report. Verifiable: `grep` section headings.
9. Roadmap row 85 write-back: `[x]`, report named. Verifiable: `grep`.

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/discussions/20260927-report-settled-test_suite_readthrough.md`](../discussions/20260927-report-settled-test_suite_readthrough.md) | new: the settled report |
| [`devlog/discussions/20260927-report-settled-test_suite_readthrough.jsonl`](../discussions/20260927-report-settled-test_suite_readthrough.jsonl) | renamed register + evidence field |
| [`docs/operations/discussion_policy.md`](../operations/discussion_policy.md) | report type amendment |
| [`devlog/discussions/20260925-design-draft-findings_register_format.md`](../discussions/20260925-design-draft-findings_register_format.md) | name-pair rule, evidence row, propagation list |
| `devlog/roadmap.md` | rows 81/82/83/143 links, row 85 write-back |
| `workflow/coding-agent/prompts/churn-analysis-run.md` | register link rename |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| New `report` discussion type, draft-to-settled lifecycle | post-action record; existing types are pre-action | grill-me session, this iteration; to be written into `discussion_policy.md` |
| Register pair renamed to follow the report | format doc name-pair rule: data file is found from its report | format doc |
| Single optional `evidence` string field | schema discipline; prose-sized content fits a string | format doc schema table |
| Three original markdown files deleted | compaction is the task; git history retains them | this handover |
| Yield data stays a static ledger in the report, register numbers computed from jsonl | per-step metrics do not fit one-object-per-finding schema | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Closed handover `20260926-10` lacks the `Carried forward` and `Deferred items` sections (policy requires canonical markers) | contradiction | next iteration -- flag at pre-close; correction requires operator direction. Triaged to: What's Next watch-out -- the M3.1 pre-close gate surfaces it for an operator-directed correction |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20260927-report-settled-test_suite_readthrough.md` | new: the settled report, ten sections, computed counts |
| `devlog/discussions/20260927-report-settled-test_suite_readthrough.jsonl` | renamed from the active readthrough pair; 262 rows gain the optional `evidence` field (319 rows total) |
| `devlog/discussions/20260923-study-active-test_suite_complexity_audit.md` | deleted; content folded into the report Phase 0 |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.md` | deleted; findings evidence moved to the jsonl, process content to the report |
| `devlog/discussions/20260925-design-draft-readthrough_process_review.md` | deleted; content folded into the report Post-review learnings |
| `docs/operations/discussion_policy.md` | `report` type row, status-ladder note, Reports subsection with ten required sections |
| `devlog/discussions/20260925-design-draft-findings_register_format.md` | name-pair rule points at the new pair; `evidence` schema row; query examples, propagation list updated |
| `devlog/roadmap.md` | rows 81/82/83/143 links to the report; row 85 write-back |
| `workflow/coding-agent/prompts/churn-analysis-run.md` | register link to the report |
| `devlog/discussions/20260924-design-draft-diff_pipeline_unification.md` | register link to the report |
| `devlog/discussions/20260924-design-draft-resolver_contract.md` | register link to the report |
| `devlog/discussions/20260925-design-draft-diff_workflow_invariants.md` | register link to the report |
| `devlog/discussions/20260925-design-draft-interactive_command_contract.md` | register link to the report |
| `devlog/discussions/20260925-design-draft-operator_surface.md` | register link to the report |
| `devlog/handovers/20260927-01-docs-compact_readthrough_record.md` | this handover |

## Deferred items

None.

## What's Next

M3.1 - Backpressure. Roadmap maintenance: row 85 landed and links repointed; the M3.1 pre-close review gate (`docs/operations/iteration_policy.md`) now opens -- it owns the sub-milestone compaction, changelog drafting, and the review gate. Watch-outs:

- Closed handover `20260926-10` lacks `Carried forward` / `Deferred items` canonical markers; correction needs operator direction.
- The M3.1 pre-close surface reconciles the open M3.1-scoped AGENT_FEEDBACK entries (`[A]` 2026-09-25 guard-not-pinnable, `[A]` 2026-09-22 vacuous-assertion) and the probation entries.

**Conclusions from this iteration:** the four read-through documents compact into one report + jsonl pair; the evidence-move and the compaction are one restructure.
