# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Workflow
**Status:** Closed
**Re-opened:** 2026-09-26 - the close was premature. The protocol was re-scoped from a dispatcher for the read-through register to a dispatcher for any well-specified roadmap task; the record moved out of the prompt into a design note; and the review step became a bounded loop. The delivery is the commit after the first one, and the text below is the re-opened record.

## Objective

Run any well-specified roadmap task as a released plan of units: one fresh subagent per unit, the return verified against the tree before it lands, one commit per unit, and a bounded review of the run.

## Scope

Two workflow prompts, one design note, four roadmap rows for the workflow organisation work, the entry-point inventory, and this record. No production file, no test, and no policy document changes.

## Carried forward

| Item | From handover |
|---|---|
| The dispatch method as practised across the nine coverage-campaign units and the fix lane | [20260925-13](20260925-13-test-pin_hint_selection_and_health_gate.md) through [20260925-23](20260925-23-fix_readthrough_code_rows_and_state_allowlist.md) |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | The template runs any well-specified roadmap task, not one campaign's register | `auto.md` names no register, no row id and no `action_kind`; the work list comes from the roadmap or the operator | Agent [x] |
| 2 | The well-specifiedness test is stated, with the parked path | `auto.md` Step 1: no open question on the answer sheet, parked rows carry their questions | Agent [x] |
| 3 | The unit rule is stated | `auto.md` Step 1: one commit, one context, one verification, disjoint files, vertical slice | Agent [x] |
| 4 | Dispatch is blocking and the subagent is the only writer | `auto.md` Step 3 and the invariants; no background dispatch, no frozen snapshot | Agent [x] |
| 5 | A failure is evaluated, resumed at most once, and filed before any reset | `auto.md` Step 4 routing table and the `partial_<unit>_<slug>` packager call | Agent [x] |
| 6 | The main session reads the record, approves it, then lands it | `auto.md` Steps 4 and 5: verify the tree, then write records and commit | Agent [x] |
| 7 | The prompt carries procedure only | no `devlog` path and no status line in either prompt; the draft marker rides the frontmatter description | Agent [x] |
| 8 | The review step is a bounded loop with a verdict contract | `review-loop-run.md`: `VERDICT ACCEPT\|BLOCK`, one fix round per block, cap three | Agent [x] |
| 9 | Lint clean, suite unchanged | `bash scripts/lint.sh` clean; `bash scripts/run_tests.sh` at 980 units, 0 failed | Agent [x] |

## Propagation checklist

| File | Change | Status |
|---|---|---|
| [`workflow/coding-agent/prompts/auto.md`](../../workflow/coding-agent/prompts/auto.md) | rewritten for any well-specified roadmap task; procedure only | done |
| [`workflow/coding-agent/prompts/review-loop-run.md`](../../workflow/coding-agent/prompts/review-loop-run.md) | new draft: the bounded review loop | done |
| [`devlog/discussions/archive/20260926-design-draft-auto_run_protocol.md`](../../devlog/discussions/archive/20260926-design-draft-auto_run_protocol.md) | new: status, options, decision, deviations, what would settle it | done |
| [`workflow/coding-agent/audits/surface-area-report.md`](../../workflow/coding-agent/audits/surface-area-report.md) | the `/auto` row updated; a `/review-loop-run` row added | done |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | four T1 rows; row 101's amendment; row 103's loop note | done |
| this handover | re-opened and rewritten | done |

Not propagated, with reason: `docs/development/testing_policy.md` has no See Also row because neither prompt is a testing pass; `review-pass-run.md` is untouched because roadmap row 103 owns it; the provider-layer `AGENTS.md` is untouched because the protocol adds no operator command.

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/auto.md`](../../workflow/coding-agent/prompts/auto.md) | the run protocol; deployed by the folder COPY into `/opt/workflow/agent/prompts/` |
| [`workflow/coding-agent/prompts/review-loop-run.md`](../../workflow/coding-agent/prompts/review-loop-run.md) | the review step, reusable by any verdict review |
| [`devlog/discussions/archive/20260926-design-draft-auto_run_protocol.md`](../../devlog/discussions/archive/20260926-design-draft-auto_run_protocol.md) | the record the deployed prompt cannot carry |
| [`workflow/coding-agent/audits/surface-area-report.md`](../../workflow/coding-agent/audits/surface-area-report.md) | the entry-point inventory |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the formalisation rows |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One release of the pilot plan; scope and criteria confirmed together | The two confirmations are amendments together or clear together, and an underspecified criterion is an open question at the scope step - the collapse is a deliberate run-ahead of `iteration_policy.md`, which the T1 row formalises | the design note; `auto.md` Step 1 |
| A unit is one commit and one handover, split vertically by feature | A horizontal slice cannot verify itself; a vertical slice is a working increment that one context holds | `auto.md` Step 1 |
| The subagent never stages and never commits | A commit is the iteration's close artifact, and the primary's verification must precede it; the primary also stages only the owned files | `auto.md` Purpose and Step 5 |
| The status, the deviations and the rationale live in the design note, not the prompt | A deployed prompt is executed by an agent that needs the procedure; rationale there is context cost with no execution value | the design note, Consequences |
| The draft marker rides the frontmatter `description` | It is the only in-deployment signal that the protocol is a draft, and it costs one word in metadata the operator already reads | this record |
| A park exports through the branch packager before the reset | The bundle carries the landed patches beside the partial attempt, so the run's earlier history travels with it and a later attempt can apply it | `auto.md` Step 4 |
| The review step is its own prompt, capped at three rounds | The existing review pass is capped near six and took eight rounds historically, because enumerable classes were not swept before each round | `review-loop-run.md`; the T1 consistency-pass row |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The first version of the template embedded the read-through register - its row ids, its `action_kind` filter and its row language - so it could dispatch one campaign and no other task. | contradiction | the re-scope that re-opened this record |
| The campaign's own dispatch practice piped the subagent run through `tail`, which returns the pipe's status rather than the subagent's and drops unflushed output on an interrupt, against the provider-layer instruction to capture a run to a log file. | contradiction | the log-file form in Step 3 and failure mode (b) |
| A background dispatch was killed at tool-call end and left a record repaired in part. | contradiction | failure mode (a); the blocking-dispatch invariant |
| A killed run cannot report at all, so a timeout cannot be self-classified by the subagent. | contradiction | the routing table splits the vocabulary by who observes the stop: the subagent returns `done`/`partial`/`stuck`/`needs-decision`, and the primary infers the timeout from the dispatch status |
| `review-pass-run.md` converges slowly by design: it caps near six rounds, the pass it generalised from took eight, and its own calibration blames doc-contract drift and count reconciliation. | steering | the bounded three-round loop, and the new T1 row for one exhaustive consistency pass |
| The prompt cannot link its own record: a repo-side path is dead inside the container, where the prompt lives at `/opt/workflow/agent/prompts/`. | constraint | the procedure-only prompt and the separate design note |
| `surface-area-report.md` still names `_agent_sig_sources` in `src/libs/container_sig.sh`, which no longer exists. | scope change | flagged only, routed to a documentation pass |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/auto.md` | the run protocol: the well-specifiedness test, the unit rule, the released plan, the brief, the blocking dispatch, the stop routing, the records, the run review, seven failure modes |
| `workflow/coding-agent/prompts/review-loop-run.md` | the bounded loop: the invitation, the verdict contract, the bar, the cheap-class sweep, the cap |
| `devlog/discussions/archive/20260926-design-draft-auto_run_protocol.md` | the record: six options considered, the decision, the three deviations, what would settle it |
| `workflow/coding-agent/audits/surface-area-report.md` | a `/review-loop-run` entry-point row, and `/auto` re-described |
| `devlog/roadmap.md` | T1: the loop-to-workflow move with two subtasks, the workflow/policy ADR, the Gate 1+2 collapse, the exhaustive consistency pass; row 101's amendment; row 103's loop note |
| this handover | re-opened, rewritten, with the verification evidence |

## Deferred items

The formalisation of the workflow and policy separation (T1: the four loop workflows, the ADR, the gate collapse, the consistency pass). `review-pass-run.md`'s convergence and its mutation-step edit (roadmap row 103).

## What's Next

The register's remaining open rows (3 test-class, 31 code, 46 note), roadmap row 84 (one verdict vocabulary), row 86 (the mutation suite), and the T1 workflow organisation rows.

Read at iteration start: this handover, `workflow/coding-agent/prompts/auto.md`, the design note, and the provider-layer `AGENTS.md` sections on fresh subagent invocation and review subagents.

**Conclusions from this iteration:** the dispatch method generalises once the work list stops coming from one record's schema; the two things that make an unattended run safe are a blocking dispatch that leaves the subagent as the only writer, and a primary that verifies the tree rather than reading the report; and the record a deployed prompt cannot carry is exactly the record that keeps a draft honest.
