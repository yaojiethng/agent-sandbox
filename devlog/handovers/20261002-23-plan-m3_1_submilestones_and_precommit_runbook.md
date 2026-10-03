---
date: 2026-10-02
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Plan
status: Closed
---

# Handover - Plan: the M3.1 backpressure sub-milestones and the pre-commit gates

## Objective

Plan the restructure of M3.1 into two sub-milestones -- M3.1.1 holding the completed backpressure work and M3.1.2 holding the pre-commit gates -- with M3.1.2's task list, a draft runbook for the hooks, and every related open roadmap row filed under it.

## Problem

The backpressure work landed and closed under M3.1, and the gates have grown since: five lint gates, a staged-set pre-commit hook, and one rule registered this session by hand that sat enabled but unregistered for weeks without anything noticing. Two things are unowned. The cost of the hook and of the gate set on a real staged change has not been measured since the parallel-shellcheck change landed in 2026-09, and no procedure says how a gate is added, amended, or retired -- the roadmap carries that gap as a single unscoped row, and the registration failure is its first real cost.

## Scope

Under discussion with the operator. Provisional deliverables:

1. The M3.1 restructure in `devlog/roadmap.md`: M3.1 as a parent, M3.1.1 holding the completed content, M3.1.2 holding two tasks -- shorten the hook and lint wall-clock, and formalize the procedure for adding, amending and removing a pre-commit gate -- with the existing related rows filed under M3.1.2.
2. A labelled draft in `workflow/coding-agent/drafts/` carrying the braindump of that procedure, noting that refinement happens in M3.1.2.
3. This handover and a single `plan:` commit at the close.

Out of scope: implementing either M3.1.2 task, and any change to the gates themselves.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | M3.1 is a parent with an objective, M3.1.1 holds the completed content, M3.1.2 holds the two tasks | `devlog/roadmap.md` sections `#### M3.1`, `#### M3.1.1`, `#### M3.1.2` | pass |
| 2 | The M3.1.1 summary row resolves to a heading | the Markdown gate's record-links rule over the summary table | pass |
| 3 | Every related open row files under M3.1.2 | the two rows moved out of T1; the T2 telemetry rows stay and are named as the measurement source | pass |
| 4 | The braindump is a labelled draft | `workflow/coding-agent/drafts/precommit-gate-runbook.md` carries `**Status:** draft` and the refinement note | pass |
| 5 | Suite and lint green | `bash scripts/run_tests.sh`: 1028 of 1028; lint clean across 5 gates | pass |

---
[CORRECTION -- 2026-10-02: the Acceptance criteria row 4 verification closed its inline code span one character early, leaving a stray `**` inside the code. The cell now reads `**Status:** draft`, which is the marker the named draft file carries. No assertion in the record changes.]

---

## Hot files

`devlog/roadmap.md`, `devlog/changelog.md`, `workflow/coding-agent/drafts/`, `docs/adr/git_hooks.md`, `src/capability/git-hooks/pre-commit.sh`, `docs/development/bash-coding-conventions.md`.

## Decisions

1. **The closed changelog entry is renumbered, at operator direction.** `## M3.1 - Backpressure` becomes `## M3.1.1 - Backpressure`, so the summary row for M3.1.1 resolves to a heading. This is a text change to a closed record, which `roadmap_policy.md` `## Corrections to Closed Roadmap and Changelog Entries` and [`closed_record_corrections.md`](../../docs/adr/closed_record_corrections.md) reserve for the successor-entry mechanic, and the ADR states that corrections apply at the operator's direction. The deviation is recorded here rather than narrowed: the entry gains a correction block naming the change and its reason, and the section below carries the successor that the mechanic would have required anyway.
2. **M3.1 becomes a parent with an objective, and its hook sentences move to M3.1.2.** The two paragraphs that sit on M3.1 today describe the hook, the mount-delivery exception, and the gates the completed child built. The hook sentences belong to the child that now owns hook work, and the parent keeps what a parent carries: an objective and children.
3. **Two rows move under M3.1.2, and the T2 telemetry rows stay.** The lint-rules skill row is task 2, and the exempted trees' 1,195 dead links are a gate-coverage debt with no owner. The T2 rows measure subagent cost, not gate cost; M3.1.2's first task names T2 as its measurement source rather than moving rows about subagents into a gate milestone. Nothing else moves.
4. **M3.1.2 carries its task list with a `Not started` status, and the policy line that forbade it is replaced.** `roadmap_policy.md` `### Record shape` gave a task checklist to the active sub-milestone alone, which the roadmap had not followed for months and which would make work filed under a future milestone unreachable. The line now admits rows written in advance and states the invariant the practice relies on: a milestone holding an open row is never `Complete`. The finding that prompted the change is recorded in [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md) as an `[O]` entry, because the line protected something real -- a reader scanning for unchecked work should find the active milestone -- and the replacement had to say what took over that job.
5. **The braindump is a dump, and it is built from the reflection reviewers' proposals.** `workflow/coding-agent/drafts/precommit-gate-runbook.md` carries `**Status:** draft` and says refinement happens in M3.1.2. Its content is the four proposals the 2026-10-02 reviewers made about gates -- a rule inside the tool that owns the config; legacy state as declared data with an expiry; one setting, one key; a bulk restore voiding prior conclusions -- the tooling reviewer's measured markdownlint-cli2 mechanics, the procedure those imply, what the absence of the runbook cost this session, and the four questions left open for M3.1.2. A prior subagent had proposed the runbook; the dump is that proposal, not a fresh one.

---
[CORRECTION -- 2026-10-02: Decision 1 linked `closed_record_corrections.md` through `../../../`, which resolves above the repository root and names no file. The path now climbs two levels, which resolves to `docs/adr/closed_record_corrections.md`. The link target is unchanged. No finding surfaced by the correction; the record-links gate does not reach this file, because `devlog/handovers/` is a declared record tree.]

---

## Decisions pending

None. The changelog's correction block uses the file's own form, and check 3.15 now names both forms so the two records can differ without either being a defect.

## Findings

- The registration gap is now detectable: the Markdown gate warns when an enabled rule resolves to no `customRules` entry (`scripts/check_markdown.sh`, handover `20261002-22`). That warning is the input to the add/amend/remove procedure this milestone would formalize.
- `scripts/lint.sh` currently costs about 5 seconds in this container; the 2026-09 study measured the pre-parallel gate at about 30 seconds, dominated by one `shellcheck` pass over every tracked file.
- The pre-commit hook checks only the staged set, so its cost scales with the change, not the repository; with nothing staged it exits immediately.

## Completed

M3.1 split into M3.1.1 and M3.1.2; the closed changelog entry renumbered under a correction block; two rows filed under the new child; the braindump draft; the policy line that forbade task lists in non-active milestones replaced, with the finding that prompted it logged; check 3.15 amended to accept both correction-block forms.

M3.1.2 inherits four open rows: the two tasks you named, the gate-coverage debt, and the budget question nested under the first.
