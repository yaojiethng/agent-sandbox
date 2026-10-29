---
date: 2026-10-26
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The instruction-cleanup comparison

## Objective

Measure whether the landed 168-line cleanup pass raises faults over one file that the 18-line goal-only draft does not, and leave the result in a form the next session can act on without this conversation.

## Scope

In scope: one calibration file, two arms, one model, faults only, and the record that holds both lists.

- The calibration file is `.agents/audits/kelsey-code-reviewer.skill.md`, 158 lines: in the census, unseen by either arm, and carrying all four fault classes.
- Both arms ran role `_REVIEWER` at thinking `high` on `deepseek/deepseek-flash`, one assignment pinned for both.
- Out of scope: screening the faults, which needs the operator and became its own roadmap row; any fold; and any score of validity, which this handover does not supply.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The calibration file is one the census will screen, and no arm had seen it | the file is named in `code-review`'s not-yet-accepted table and in this record | Agent [x] |
| Both arms ran the same assignment and level | `seat 1 turn 1` lines in both run records name `deepseek/deepseek-flash at high` | Agent [x] |
| Both fault lists are landed verbatim, with their sites | the discussion record's two arm tables, twenty rows each | Agent [x] |
| The site overlap is computed, not asserted | the record's count section and matrix name the nine shared and eleven unique sites per arm | Agent [x] |
| Neither arm screened, folded or edited anything | both stopped after the judgement; `git status` was clean of audit-file changes after the runs | Agent [x] |
| The record states what it awaits | the record's closing section names the ruling and where it lands | Agent [x] |
| The follow-up work is owned outside this handover | two roadmap rows under the payload consolidation carry it | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The comparison pins the assignment rather than resolving the role | arm B's first run resolved to `opencode/deepseek-v4.1-flash-free` because that model's cooldown expired between the two dispatches. Two runs of one role may land on different assignments, so an unpinned pair measures the resolution order rather than the prompt | this handover |
| The unpinned run is discarded rather than scored | it is a different model over the same prompt, so including it would compare prompts across models | this handover |
| The arms stop before the screen | the screen needs the operator's ruling, and a run that guessed it would produce a fault list already filtered by an unstated judgement | this handover |
| Format is not compared | the two arms returned the same four fields without being constrained to, and a format difference would confound the fault count | this handover |
| The outcome is recorded as counts and sites, not as a verdict | validity is the operator's call, and equal counts do not by themselves settle whether the pass's length earns its place | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| On one file the 168-line pass and the 18-line draft raised the same number of faults, and each caught eleven sites the other missed | comparison | length bought no coverage on this file, so the pass's remaining bulk is a consolidation candidate rather than a settled artifact | roadmap row **A shorter cleanup pass that keeps what the long one misses** |
| The two arms disagree in kind, not only in count: the pass found the mechanical rules, the draft found the persona layer and the unevidenced-finding rule | comparison | a cleanup pass that raises structural faults is the one whose output a removal can act on, and the ruling must prefer removal over rewording | roadmap row **Screen the calibration file**, which carries the precedence rule |
| Both arms flagged the frontmatter environment block (`tools:`, `model: opus`) as harmful, in a file the new `code-review` shell already supplies those fields for | corpus | that half of the file is answered by the shells unit; the screen should not re-open it | roadmap row **Screen the calibration file**, noted there |
| A role resolves per attempt, so two runs of one role can use different models | dispatch | any future comparison of prompts must pin, or it measures the resolution order | this handover; a line for `dispatch.md` rides when that file is next touched |

## Completed

| File | Change |
|---|---|
| [`20261026-report-settled-instruction_cleanup_comparison.md`](../discussions/20261026-report-settled-instruction_cleanup_comparison.md) | the run shape, both fault lists verbatim, the count, the site matrix, and what the record awaits |
| [`devlog/roadmap.md`](../roadmap.md) | two open rows under the payload consolidation: the per-site screen with the precedence rule, and the shorter pass that keeps what the long one misses |
