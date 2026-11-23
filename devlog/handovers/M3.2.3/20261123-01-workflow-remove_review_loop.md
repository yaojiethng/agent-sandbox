---
date: 2026-11-23
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - The review loop is removed

## Objective

Remove the loop scaffolding from the `code-review` shell, so a review is one pass and repetition belongs to the invoking task. Trim the shell under `writing-for-agents` while it is open.

## Scope

The iteration records the reversal of the loop the closed M3.3.3 row landed. It runs under M3.2.3, which owns the workflow command surface, and opens that sub-milestone as `In progress`. That closed row is already compacted into the changelog, so there is no closed roadmap row to edit; the correction lives in the ADR, the feedback record and this handover. It files no new loop task: the requirements are not settled, and a row would be a forecast.

In scope: the review shell, the two dispatch drafts that cite the shell's loop, the ADR correction, the feedback recurrence, and this record. The shell is also trimmed under `writing-for-agents`: its duplicated purpose, reading-path table and dispatch paragraph are removed. The operator owns `/thermonuclear-review`; its loop residue stays, and that file is out of scope. Out of scope: the vendored thermo-nuclear runbook, which carries no loop scaffolding and has no store edge to diff against; the other runbooks; the autonomous agent loop in `autonomous_agent_loop.md`; and any loop mechanism or interface row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The review shell carries no loop state, rounds, cap or convergence rule. | `grep -rniE '## The loop\|review loop\|prior round\|one pass only\|round: 1\|verdict: BLOCK' workflow/coding-agent/skills/code-review/SKILL.md .agents/drafts/sequential-work.md .agents/drafts/parallel-work.md` prints no hit. | Agent [x] |
| The shell states one pass and names the invoking task as the owner of repetition. | read `## When this runs` in `workflow/coding-agent/skills/code-review/SKILL.md`. | Agent [x] |
| The operator-owned `/thermonuclear-review` is unchanged. | `git diff --exit-code -- src/reasoning/agent-runtime/pi/config/agent/prompts/thermonuclear-review.md`. | Agent [x] |
| The closed roadmap row carries no loop claim, and no new loop task is filed. | read the M3.3.3 changelog entry and `grep -n 'loop primitive' devlog/roadmap.md`; the changelog carries no loop clause and the roadmap gains no row. | Agent [x] |
| The ADR and feedback records carry the correction and the recurrence. | `grep -n '2026-11-23' docs/adr/coding_agent_loop_workflow.md devlog/AGENT_FEEDBACK.md`. | Agent [x] |
| The shell is trimmed to its four jobs: parameters, one-pass boundary, environment translation and runbook list. | read `workflow/coding-agent/skills/code-review/SKILL.md`; it has no separate `## Purpose`, no reading-path table and no dispatch paragraph. | Agent [x] |
| The handover is filed under M3.2.3 and that milestone is `In progress`. | the `milestone` field; `grep -n 'M3.2.3 - Dispatch Workflows' devlog/roadmap.md` shows the summary row. | Agent [x] |
| The gates pass. | `bash scripts/lint.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| File no new loop task; record the reversal in the ADR and this handover. | The requirements are not settled, so a row would be a forecast. The closed M3.3.3 row is already compacted into the changelog, which carries no loop clause to correct. | This record; the ADR correction |
| Remove the loop rather than make it optional. | The failure is the loop itself: fresh seats re-derive contradictory remedies, and a verdict per round makes a nit a blocker. The 2026-10-31 feedback entry records 15 rounds on one artifact. | This record; the ADR correction |
| Keep the vendored thermo-nuclear runbook unchanged. | It carries no loop scaffolding, and it has no store edge to diff an edit against. | This record |
| State the boundary in one sentence, not a new section. | There is no loop mechanism to document; the shell names one pass and the task owns repetition. | The shell's `## When this runs` |
| No M3.2.3 `Not in scope` line. | The operator asked for the removal only; a boundary line would be another forecast. | This record |
| Trim the shell to its four jobs: parameters, one-pass boundary, environment translation and runbook list. | The loop removal left the purpose restated three times, the reading path as a table the body already carried, and the dispatch mechanism described in two places. | This record; the shell |
| Leave the operator-owned `/thermonuclear-review` unchanged. | The operator reverted the edit and owns the macro; its loop residue is theirs, not this iteration's. | This record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The 2026-09-21 feedback entry's mitigation points at `references/loop.md`, deleted on 2026-11-03. | record | a stale pointer beside the rule that removes the loop | this iteration: the entry is reopened as a recurrence |
| The two dispatch drafts cite the shell's `## The loop`. | record | a live carrier of the removed section | this iteration: re-pointed at one pass |
| The closed M3.3.3 row is already compacted into the changelog, so no roadmap row exists to correct. | record | the planned closed-row correction has no carrier; the correction moves to the ADR and this record | this record; the ADR correction |
| The shell restated its purpose in the intro, `## Purpose` and the reading path, and described the dispatch mechanism twice. | record | duplication the loop removal exposed | this iteration: trimmed under `writing-for-agents` |
| The operator-owned `/thermonuclear-review` carries loop residue. | record | the operator reverted the edit; the file stays unchanged and out of scope. | This record |
| The first filing named M3.3.6, which does not own the review loop. | record | the review loop is a workflow surface and M3.2.3 owns it; the record moved and M3.2.3 opened before the commit. | this iteration: M3.2.3 opened |
| No new roadmap row for a loop mechanism. | record | the operator declined a requirement that is not settled | this record |

## Completed

| File | One-line change summary |
|---|---|
| `workflow/coding-agent/skills/code-review/SKILL.md` | removed `## The loop`; one pass, task-owned repetition; trimmed from 77 to 58 lines |
| `.agents/drafts/sequential-work.md` | re-pointed the run review at one pass |
| `.agents/drafts/parallel-work.md` | re-pointed the run review at one pass |
| `docs/adr/coding_agent_loop_workflow.md` | dated correction: the review loop reference is removed |
| `devlog/AGENT_FEEDBACK.md` | the framing entry is reopened as a recurrence; the convergence entry is mitigated |
| `devlog/roadmap.md` | M3.2.3 opened as `In progress` to carry this iteration |
| `devlog/handovers/M3.2.3/20261123-01-workflow-remove_review_loop.md` | this record |

`/thermonuclear-review` was edited and then reverted by the operator; it is unchanged in this commit.
