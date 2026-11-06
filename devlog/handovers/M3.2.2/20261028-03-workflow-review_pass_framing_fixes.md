---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The review loop reference and the turn-end status

## Objective

Extract the review loop into a `code-review` reference document, replace its round cap with an operator-cadence check-in, and give the pi provider layer a one-line turn-end status.

## Scope

Continues **The review-pass family** (M3.2.2). The seat surface and the mutation step are settled; this is the family's framing slice, plus the provider-layer status line the operator directed in the same unit.

In scope: the loop pattern as `code-review/references/loop.md`, linked from the shell by one line; the range, copy-pair and check-in rules inside it; the retirement of the `review-loop-run.md` draft and its carriers; and the one-line `## Reporting` section in the pi provider `AGENTS.md` with its subject-table row. Out of scope: the mutation step (filed under M3.1.2), the churn and fan-out passes, the exhaustive consistency pass, and the runbooks' judging criteria.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The reference states the range, copy-pair and check-in rules, and the verdict rule | read `references/loop.md` | Agent [x] |
| The shell links it in one line and carries no loop body | read the shell | Agent [x] |
| The draft is gone, and no live carrier invokes `/review-loop-run` | `grep -rn review-loop-run` over the live tree | Agent [x] |
| The provider layer carries `## Reporting`, and the subject table its row | grep both files | Agent [x] |
| Every decision recorded is realized in the files | each Decisions row checked against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The round cap is dropped and replaced by an operator-cadence check-in | the two templates carried different magic numbers (3 and 6), so the count was arbitrary; the operator chooses the cadence and decides at each check-in | this handover |
| The loop is a reference document under the `code-review` skill, linked by one line | progressive disclosure: the shell stays an index, and the loop is read only when a run to convergence is asked for | this handover |
| The two draft templates cite the reference rather than restating it | one source of truth; the drafts keep their own shapes | this handover |
| The status line is filed in the pi provider `AGENTS.md` | it is true of every provider but has no provider-neutral always-loaded carrier yet, so the pi layer stands in, as that document's `## The layers` states | this handover |
| Nothing is removed for the status line | no existing line carries the turn-end status, so the `## Instruction Surface` add-by-replacing rule's alternative applies | this handover |

## Decisions pending

None.

## Findings

| # | Finding | Type | Impact | Triaged to |
|---|---|---|---|---|
| 1 | None of the three framing rules is stated in a shipped artifact; rule 2 is partly present in the two drafts, which do not ship, and rule 3 is absent everywhere | defect | a review brief can still key its range to a handover date, and can name one of a seeded/runtime pair without saying which copy is authoritative | this iteration |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/code-review/references/loop.md` | new: the review loop and its three rules |
| `workflow/coding-agent/skills/code-review/SKILL.md` | the one-line pointer to the reference |
| `.agents/drafts/review-loop-run.md` | deleted; its content is the reference |
| `.agents/drafts/review-pass-run.md`, `sequential-work.md`, `parallel-work.md` | lose the cap and retarget to the reference |
| `.agents/audits/surface-area-report.md` | the `/review-loop-run` entry point is removed |
| `docs/adr/coding_agent_loop_workflow.md` | the `-run` family no longer lists `review-loop-run` |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the `## Reporting` line |
| `docs/development/instruction-surface-conventions.md` | the `Reporting` subject-table row |
| `devlog/AGENT_FEEDBACK.md` | the 2026-09-21 entry is mitigated |
| `devlog/roadmap.md` | the framing-fixes row is marked and closed |
| `devlog/handovers/20261028-03-workflow-review_pass_framing_fixes.md` | this handover |
