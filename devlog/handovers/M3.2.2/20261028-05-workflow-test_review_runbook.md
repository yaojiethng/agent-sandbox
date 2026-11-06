---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The test-review runbook

## Objective

Give a test change a reviewer: a runbook that judges a test's evidence value, replacing the retired test-quality campaign and its `-run` wrapper.

## Scope

Opens the M3.2.2 row **The test-quality campaign is subsumed into a `test-review` runbook**, which discharges the campaign's `pending` fate in the carrier-fates record.

In scope: the new `test-review` runbook, its row in the shell's table, the `code-review-bash` pointer, the `testing` skill's pointer, the deletion of the campaign and its wrapper, and the records that carried their fate. Out of scope: the behaviour under test (a defect a test exposes is reported, not repaired), and the per-file High Value/High Noise rating, which had no consumer after the campaign ran.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `test-review` states what it accepts and returns | read `runbooks/test-review/SKILL.md` | Agent [x] |
| The criteria list defines the bad-test forms, one line each | read `## The criteria` | Agent [x] |
| A finding must demonstrate that the test cannot turn red | read `## Proof` | Agent [x] |
| The shell lists the runbook in its table | read `code-review/SKILL.md` `## Runbooks` | Agent [x] |
| `code-review-bash` names `test-review` where it disclaims test judgement | read its `Does not judge` | Agent [x] |
| The campaign and its `-run` wrapper are gone | `test ! -e .agents/audits/test-quality-campaign.md -a ! -e .agents/drafts/test-quality-campaign-run.md` | Agent [x] |
| The carrier-fates record no longer says `pending` for either retired carrier | grep the table | Agent [x] |
| No live text routes to the deleted wrapper | `grep -rn test-quality-campaign --include='*.md' workflow .agents devlog/roadmap.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The gate is a runbook, not a section of `testing` | the author and the judge are different contexts; a loose how-to plus one strict review is the separation the operator asked for | this handover |
| The criteria live in the runbook, and `testing` points at it | two copies of a criterion drift; the skill stays the loose collection of what to do | this handover |
| `## Proof` is the spine | a finding that does not show the test cannot fail is an opinion; the assertion, the revert and the green result are the evidence | this handover |
| A finding ends in delete, rewrite, or keep with the reason, and deletion is the default | a test that proves nothing is worse than no test: it is green evidence that is not evidence | this handover |
| Both campaign files are deleted, not trimmed | the campaign ran once as `c772e25c` and its output was accepted in full; the census already recommended about twenty line removals from the rest | this handover |
| The per-file rating is not migrated | its only consumer was the campaign, and the suite it triaged no longer exists | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A test change had no reviewer: `code-review-bash` disclaimed test judgement and the `testing` skill's completion list was the author grading their own work | defect | `test-review` lands as the gate, and both the shell and the bash runbook point at it | fixed in this iteration |
| The campaign's Authority said the convention wins, then the body restated the convention and one clause contradicted it ("Outside the campaign, tests are opt-in and product-first" against "Tests arrive with the code") | defect | the campaign is deleted; the `testing` skill is the single owner of the how-to | fixed in this iteration |
| The campaign's `-run` wrapper invoked raw `pi -p`, naming no role, setting no timeout and writing no log, which `dispatch` now owns | defect | the wrapper is deleted; a campaign-shaped run is dispatched through the shell like any other runbook | fixed in this iteration |
| Handover `20261028-02` claimed the consolidation row recorded the assertion-sweep deletion, and the roadmap row does not; the carrier-fates row still said `pending` | defect | the carrier-fates row now records the retirement; the roadmap row is left to the consolidation row rather than edited here | corrected in the carrier-fates table |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/code-review/runbooks/test-review/SKILL.md` | new: the criteria, the proof spine and the voice |
| `workflow/coding-agent/skills/code-review/SKILL.md` | the shell's table gains the `test-review` row |
| `workflow/coding-agent/skills/code-review/runbooks/code-review-bash/SKILL.md` | its `Does not judge` line points at `test-review` |
| `.agents/skills/testing/SKILL.md` | one pointer in `## Before you close the change` |
| `.agents/audits/test-quality-campaign.md` | deleted; the campaign ran as `c772e25c` |
| `.agents/drafts/test-quality-campaign-run.md` | deleted; `dispatch` owns the invocation |
| `.agents/audits/surface-area-report.md` | both campaign rows retired |
| `devlog/discussions/20261026-report-settled-carrier_fates.md` | both `pending` rows retired |
| `devlog/roadmap.md` | the draft count drops to three, and the unit row is closed |
| `.agents/drafts/parallel-work.md`, `.agents/drafts/sequential-work.md` | the campaign-run routing is removed |
| `devlog/handovers/20261028-05-workflow-test_review_runbook.md` | this handover |
