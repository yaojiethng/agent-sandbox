# Agent Handover

**Date:** 2026-09-27
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Workflow
**Status:** Closed

## Objective

Run two concurrent work tracks in separate git worktrees under a new `parallel-auto` workflow draft, and record the measured results in a design document.

## Scope

Two deliverables, both new files:

| Deliverable | Path | Status |
|---|---|---|
| Design document carrying the measured results of this run | `devlog/discussions/archive/20260927-design-draft-parallel_auto_experiment.md` | to create |
| Workflow draft combining fan-out and auto | `workflow/coding-agent/prompts/parallel-auto.md` | to create |

The payload is two concurrent tracks, each a worktree and a branch:

| Track | Worktree | Branch | Units |
|---|---|---|---|
| A | `/tmp/wt-a` | `exp/track-a` | `_CLI_TOLERANT` cleanup; host-requirements matrix and probe alignment |
| B | `/tmp/wt-b` | `exp/track-b` | git-policy body and reference rules; design-doc policy amendment |

The track commits stay on their branches. Operator direction: a future iteration consolidates and merges them into the main branch, and that merge is the test case for `/merge` feedback.

Feedback on `fanout` and `auto` is a third output, recorded in `devlog/AGENT_FEEDBACK.md` by reconciling against the existing entries rather than opening siblings.

Blockers: none. All four units pass the well-specifiedness test in [`auto.md`](../../workflow/coding-agent/prompts/auto.md) Step 1.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `workflow/coding-agent/prompts/parallel-auto.md` exists with frontmatter and a section list covering the worktree lifecycle, dispatch, verification, merge order and the record rule | `head -6` plus the section list | Agent [x] accepted |
| AC2 | The design document exists and its results section carries measured numbers from this run: per-track wall clock, unit counts, conflicts hit, merge outcome | read the results section against the run logs | Agent [x] accepted |
| AC3 | Both tracks ran concurrently, each in its own worktree on its own branch, and each unit landed as one commit on that branch | `git branch --list 'exp/*'` and `git log exp/track-a --oneline` | Agent [x] accepted: 4 commits on `exp/track-a`, 2 on `exp/track-b` |
| AC4 | The primary verified each track's return against its worktree before accepting it: own suite run, own diff read, not the subagent's report | the verification record in the design document | Agent [x] accepted: 5 primary verifications, 3 found defects |
| AC5 | Negative check: no track commit touches a record file. `git log exp/track-a exp/track-b --name-only` names no path under `devlog/` | the same command, grep for `devlog/` | Agent [x] accepted: no match |
| AC6 | Feedback on `fanout` and `auto` is recorded, reconciled against the existing `AGENT_FEEDBACK.md` entries (no sibling entry on the same topic) | read the entries and the reconciliation note | Agent [x] accepted: 2 recurrences, 1 new entry |
| AC7 | Lint gate clean, 0 findings | `bash scripts/lint.sh` | Agent [x] accepted: 697 files, 0 findings |
| AC8 | Handover committed with the single delivery commit, Status Closed | `git log` | Agent [x] accepted |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/prompts/parallel-auto.md` | the workflow draft (to create) |
| `devlog/discussions/archive/20260927-design-draft-parallel_auto_experiment.md` | the design document (to create) |
| `devlog/AGENT_FEEDBACK.md` | feedback on `fanout` and `auto` |
| [`workflow/coding-agent/prompts/auto.md`](../../workflow/coding-agent/prompts/auto.md) | the template this one combines with (reference) |
| [`workflow/coding-agent/prompts/fanout-run.md`](../../workflow/coding-agent/prompts/fanout-run.md) | the fan-out half (reference) |
| `devlog/handovers/archive/20260927-04-workflow-parallel_auto_experiment.md` | this handover |

Out of scope this iteration: the track branches are not merged, and `devlog/roadmap.md` gains no write-back for work that has not landed on the main branch.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Linked git worktrees, not a copied tree | a copy has its own object store, so the merge degrades to patch application and loses the common ancestor; a linked worktree shares objects and keeps a real three-way merge | this handover, evidence in the design document |
| One model for both tracks (`gpt-5.1-codex`, high thinking) | the experiment measures the workflow, not the model; varying the model is a separate run | this handover |
| Two tracks, not three | 16 cores with `TEST_PARALLEL=8` default; the measured concurrent run leaves no headroom for a third | this handover |
| Track subagents commit to their own branch | the operator requires the track work to survive for a later merge, which needs commits; this deviates from the `auto.md` rule that a subagent never commits | this handover, findings |
| Track subagents write no record | the reproduced adjacent-row conflict on `devlog/roadmap.md` makes concurrent record writes unmergeable; the primary owns the records | this handover, findings |
| `parallel-auto.md`, no `-run` suffix | the operator named the draft; the short-name group (`auto.md`, `merge.md`, `rebase.md`) carries the same shape | this handover |
| The design document is the record of the run, and the workflow draft carries the rules | the operator asked for one design document with the real testing results and one workflow draft; splitting them keeps a result from being read as a rule and a rule from being read as a result | this handover |
| The as-built section structure is the skeleton proposed mid-run | the record-layer skeleton gate needs operator confirmation, and the run was already in flight with results to record; the structure is flagged for correction rather than held back | this handover, findings |
| A rejected return goes back to its track as a repair brief, not into the primary's tree | the track's history stays self-contained, so the later consolidation is a merge rather than a reconstruction | this handover, design document F2 |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| The first brief named a script and not its test file, so a track unit shipped a red suite and reported green | workflow | the primary's full-suite verification caught it; the durable fix is the test-surface closure in brief construction | recorded in `AGENT_FEEDBACK.md` (new entry) and in the draft's Step 1 |
| `auto.md`'s stop table has no row for a return the primary's verification rejects | workflow | a `done` return needing a whole repair unit has no defined route; two such returns occurred | draft Step 5 supplies the row; the `auto.md` amendment is a follow-up |
| A duplicate test definition and registration passes the registration liveness gate and inflates the unit count | test | the count is the evidence a reviewer compares against a baseline, so an inflated count is unverifiable | recorded as a recurrence in `AGENT_FEEDBACK.md`; a duplicate check in `scripts/check_test_liveness.sh` is a follow-up |
| The model identifier came from the wrong provider's model list; both tracks failed identically in 19s | workflow | the failure was visible only because each dispatch was wrapped in a timer and an exit-code echo | draft Preconditions and failure mode (a); the T2 telemetry rows own the durable fix |
| Track A changed `scripts/macos_bootstrap.sh`, which the M3.1 read-through excluded from its scope by operator direction | scope | the change is required by the matrix row it satisfies, and the exclusion was a campaign scope rather than a standing rule | flagged for the operator at the consolidation iteration |
| The `[A] 2026-09-20` feedback entry scoped itself to a `roadmap_future.md` section that does not exist | record | a dead pointer; the T2 rows in the active milestone own that work | corrected in place while amending that entry |
| Two tracks on sixteen cores showed no deadline pressure, but three or more tracks were not tested | investigation | the concurrency ceiling is host-specific and must be measured, not assumed from this run | stated as a limit in the design document; a per-host measurement is a follow-up |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/archive/20260927-design-draft-parallel_auto_experiment.md` | the design record: direction, the design, the measured run, 9 findings, the fan-out and auto feedback, rejected designs, follow-ups |
| `workflow/coding-agent/prompts/parallel-auto.md` | the workflow draft: preconditions, 8 steps, 8 observed failure modes, 8 invariants |
| `devlog/AGENT_FEEDBACK.md` | one new entry (brief construction); two recurrences (the duplicate-count class, the unmeasured-run entry); one dead scope pointer corrected |
| `devlog/handovers/archive/20260927-04-workflow-parallel_auto_experiment.md` | this handover |

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| Consolidate and merge `exp/track-a` and `exp/track-b` into the main branch | the operator scoped this iteration to the experiment; the merge is also the `/merge` feedback case | a future iteration; the cross-track merge is verified clean |
| Vary the model across tracks to compare yield per unit | one model this run, so the workflow result is not confounded | a future iteration of the draft |
| A duplicate definition and registration check in `scripts/check_test_liveness.sh` | the durable fix for the count-inflation defect; it is test infrastructure, not this iteration's workflow deliverable | a future iteration; the defect is recorded in `AGENT_FEEDBACK.md` and the design document |
| A `verified-defective` row in the `auto.md` stop table | the draft supplies the route; amending the parent template is a separate change | a future iteration |
| A brief-construction helper that computes a unit's test-surface closure | the rule is in the draft; the helper is tooling | a future iteration |

## What's Next

M3. The draft and the design record are this iteration's output. The two track branches hold four units of pinned work that no track has merged and no primary has landed: `_CLI_TOLERANT` removed and prune made strict, and the host requirement matrix, install probe and macOS bootstrap brought into agreement on `readlink -f`, `find -printf` and `rsync`. The consolidation iteration starts from a verified-clean cross-track merge, and its first question is the operator's: `scripts/macos_bootstrap.sh` was outside the M3.1 read-through's scope, and track A changed it.
