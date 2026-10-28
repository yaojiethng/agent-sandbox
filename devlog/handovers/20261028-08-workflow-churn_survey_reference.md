---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - the churn survey lands as a reference

## Objective

Adopt the churn survey as a standing pass, and file the fan-out protocol under M3.2.3, so the review-pass family's remaining rows are split by subject and the `-run` suffix retirement has one owner.

## Scope

In scope: `.agents/drafts/churn-analysis-run.md` re-derived through a read-back into `code-review/references/churn.md`; the fan-out row filed under M3.2.3; the carriers that named the old draft or the old family. Out of scope: the exhaustive consistency pass, which is the family's other open row, and the "Prompt the What, not the How" principle, which is a row under M3.3.6.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The churn survey is a reference under the shell, not a prompt | the file exists at `code-review/references/churn.md` and no draft named `churn-analysis-run` remains | Agent [x] |
| Its body states the outcome, the trust conditions, the trigger and the conventions | read the reference | Agent [x] |
| No derived state is committed | the reference states the counts are derived on read; no table or report is added to the tree | Agent [x] |
| The fan-out is filed under M3.2.3 with the `-run` suffix retirement | the M3.2.3 row names `fanout-run.md` and the suffix | Agent [x] |
| Every carrier of the old draft is updated | the ADR's `-run` line and the M3.2.3 frontmatter row | Agent [x] |
| The gates pass | `check_markdown.sh`, `check_handover_format.sh`, `lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The draft is re-derived through an operator-directed read-back, not edited line by line | the intent read produced a 45-line goal statement, and the line-by-line disposition would have carried the bloat forward row by row | the reference, and this record |
| The output is a table, not a JSONL register | nothing parses it and the register it joins is prose; a schema would add a validator and a staleness surface with no consumer | the reference |
| The four trust conditions are the data-collection bar | they are testable by re-running the recorded command; a second invariants list is the duplication the diet removed | the reference |
| No code snippet | the requirement is re-derivability, not this command; the rename-surviving count forces the `--follow` class of method without naming it | the reference |
| The counts are derived on read and are not committed | `principle-guard-derived-state`: a cheap derivation that is stored is a stale copy with no warning, so the row records the command, window and revision instead | the reference |
| The join against the findings register is conditional | the register is produced by `read-through-run.md`, which is unadopted, so a missing register leaves the ranking standing alone rather than blocking the pass | the reference |
| The fan-out is filed under M3.2.3 | it is a dispatch shape, and the `-run` suffix retires with the `-work` suffix there | the roadmap |

## Decisions pending

None.

## Findings

- **The read-back is the cheaper diet.** The 117-line draft became 45 lines with no requirement lost: the worked example and the invariants were evidence and restatement, and the command, the classification cases and the section order were mechanism. The operator's method is worth a principle of its own; it is filed for M3.3.6.
- **The first dispatch candidate refused.** `opencode/deepseek-v4.1-flash-free` answered `FreeTierError` and the entrypoint advanced to `opencode-go/deepseek-v4.1-flash`, which ran the brief. The refusal was reported as `client-refused capability provider`, and the worker's report named the pre-existing roadmap modification and left it alone.

## Completed

| Artifact | What changed |
|---|---|
| `workflow/coding-agent/skills/code-review/references/churn.md` | new: the outcome, the four trust conditions, the trigger, the conventions |
| `.agents/drafts/churn-analysis-run.md` | deleted; its requirements live in the reference |
| `.agents/drafts/churn-analysis-goal.md` | deleted; the goal skeleton was the reference's draft |
| `devlog/roadmap.md` | the churn row closed; the fan-out row added under M3.2.3; the frontmatter row shrunk to two drafts |
| `docs/adr/coding_agent_loop_workflow.md` | the `-run` family names the remaining drafts and the churn reference |
