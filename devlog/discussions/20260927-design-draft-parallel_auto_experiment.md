# Design: Running Fan-Out and Auto Together - A Measured Trial

**Status:** draft
**Date:** 2026-09-27
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow

## Summary

Two work tracks ran concurrently, each in its own git worktree on its own branch, each driven by a fresh subagent, while the primary agent held the plan, the records and the merge. The mechanism works: the isolation held, the two tracks never collided, and the primary's own verification caught every defect the subagents missed. Three design rules fell out of the run, and one of them -- that a track's owned-file set must be closed under the test surface -- is a defect in how the `/auto` brief is built today. The payload of the run is four units of pinned work that still needs a consolidation iteration; what this document settles is the workflow.

## Direction

[`auto.md`](../../workflow/coding-agent/prompts/auto.md) dispatches one unit at a time to a fresh subagent, sequentially, in one working tree. [`fanout-run.md`](../../workflow/coding-agent/prompts/fanout-run.md) fans a read-only pass out across concurrent subagents on a frozen snapshot, and keeps the register in the primary. Each solves a real constraint: `auto.md` because a subagent that has worked one unit carries its assumptions into the next, and `fanout-run.md` because one context cannot hold a large pass. Neither uses the other's answer. `auto.md` has no concurrency, and `fanout-run.md` has no commits.

The claim under test is narrow: the two combine if each track gets its own linked worktree, and if the records stay with the primary. Everything below either supports that claim or bounds it.

## Required reading

- [`auto.md`](../../workflow/coding-agent/prompts/auto.md) - the unit dispatch template this extends, its well-specifiedness test, its unit rule, and its stop table.
- [`fanout-run.md`](../../workflow/coding-agent/prompts/fanout-run.md) - the fan-out half: the frozen snapshot, file ownership, and the primary's share of the work.
- [`review-loop-run.md`](../../workflow/coding-agent/prompts/review-loop-run.md) - the bounded review loop the returned units feed.
- [`devlog/handovers/20260927-04-workflow-parallel_auto_experiment.md`](../handovers/20260927-04-workflow-parallel_auto_experiment.md) - the iteration record: scope, acceptance criteria, decisions.
- [`20260926-design-draft-auto_run_protocol.md`](20260926-design-draft-auto_run_protocol.md) - the design record behind `auto.md`.

## The design

### One worktree and one branch per track

A track is a named body of work with its own branch, cut from one baseline commit, living in one linked worktree outside the primary's tree. The track's subagent works only in that worktree and commits only to that branch. The primary never edits a file inside a track worktree; a change the primary needs goes into a brief and back through a subagent, or waits for the merge.

The worktree is a linked worktree, not a copy, and the reason is the merge. A copied tree carries its own object store, so the two histories have no common ancestor and the consolidation degrades to patch application. A linked worktree shares the object store with the primary's repository, so a track's commits are immediately visible to the primary, and the consolidation is an ordinary three-way merge.

The branch is not optional. A worktree left on a detached HEAD can be read but not merged by name, which forces the consolidation to discover commits by hash.

### What the primary owns

The primary owns the plan, the worktree and branch lifecycle, the briefs, the dispatch, the verification of every return, the records, and every commit on the main branch. A subagent owns its track's work inside its worktree. This split is `auto.md`'s existing split, unchanged: `auto.md` already says a subagent never edits a record, and this design makes that rule load-bearing instead of advisory.

### The record rule

No track writes `devlog/roadmap.md`, `devlog/AGENT_FEEDBACK.md`, `devlog/changelog.md`, or any handover. The primary writes them, after the merge, from what it verified.

The rule exists because concurrent record writes do not merge. The pre-flight probe for this trial reproduced it exactly: two branches each flipping one checkbox on adjacent roadmap rows produced a content conflict in `devlog/roadmap.md` on merge, with the conflict hunk covering both rows. The same probe merged disjoint-file commits cleanly, so the collision is specific to the record files, and the record files are exactly the files every unit would want to touch.

### Verification

The primary runs the suite itself, in the track's worktree, and reads the diff itself. `auto.md` already requires this and gives the reason: a green suite a subagent reports is a claim, not evidence. This trial is the argument for that rule in a stronger form than `auto.md` states. Two of the four units were reported `done` with green verification and were still wrong, and both defects were invisible to the subagent because both sat outside the file list its brief gave it.

### Repair

A return that fails the primary's verification becomes a repair brief to the same track, carrying the defect, the evidence, and the file the track now owns. The repair runs in the track's worktree, on the track's branch, so the track's history stays self-contained and the consolidation stays a merge rather than a reconstruction.

## The run

### Environment

Sixteen cores, git 2.39.5, a Linux container. Baseline `bash scripts/run_tests.sh` in the primary tree: 998 units across 66 files, 0 failed, 12 to 15 seconds wall clock. The runner dispatches 8 files in parallel by default under a 5 second per-file deadline, with heavier files declaring their own budget.

### Pre-flight probes, before any dispatch

| Probe | Result |
|---|---|
| `git worktree add` a second tree, run the suite in it | 34 units across 2 files in 0.5s; lint clean in 4s |
| Two concurrent runs of the three deadline-sensitive test files | both green, 7s each, against 8s for the same three serially |
| Two concurrent full suites, one per worktree | 15s and 12s, both green |
| Fixed-path writes under `/tmp` in the test suite | none; every fixture directory is `mktemp`-scoped |
| Object store shared between the worktrees and the primary | a commit in a worktree resolves in the primary with `git cat-file` |
| Merge of disjoint-file commits from two branches | clean |
| Merge of two adjacent roadmap-row flips | **content conflict in `devlog/roadmap.md`** |

The last two rows are the design in one line each: the tracks merge, the records do not.

### Dispatch

Both tracks were dispatched within seconds of each other, each a fresh subagent, each with its brief on disk, each writing to its own log.

The first dispatch failed on both tracks, identically, in 19 seconds: the model identifier had been taken from a different provider's model list than the one the run used, and the provider answered `Model is unavailable` (HTTP 400). Both tracks died the same way, and the only evidence was the two log tails, because nothing in the dispatch command reported a duration or a status. Re-dispatched on the overlay provider's own list, the run proceeded. One model was used for every track, so the result measures the workflow and not the model.

### Results per track

| Track | Branch | Units | Subagent runs | Subagent time | Commits | Final suite | Lint |
|---|---|---|---|---|---|---|---|
| A - pinned code fixes | `exp/track-a` | 2 | 3 | 802s | 4 | 1001 units, 0 failed | clean |
| B - policy text | `exp/track-b` | 2 | 1 | 135s | 2 | 998 units, 0 failed | clean |

The two tracks ran concurrently. Track A's wall clock is the sum of its three sequential subagent runs, and those overlapped track B's single run in full.

Track A's suite count ends at 1001 rather than 998 because the units added real coverage: a strict-parse assertion that names the rejected flag, a prune unknown-flag rejection, and probe coverage for the two newly declared host requirements.

### Cost per unit

| Unit kind | Wall clock | Note |
|---|---|---|
| Policy prose, one file, one rule set (track B) | 67s per unit | no test surface, no code |
| Shell change with tests (track A, first pass) | 221s per unit | two units in 443s |
| Repair unit, one fixture (track A) | 145s | one unit |
| Repair unit, three defects (track A) | 214s | one unit |

The order of magnitude between prose and shell work is the useful number for planning a free-model run: a prose track fills a model's time at roughly a third of the rate of a code track, and both are far cheaper than the primary's verification, which ran five times in this trial.

### Defects found by primary verification, not by the subagents

| # | Defect | How it surfaced | Repair |
|---|---|---|---|
| 1 | A unit changed `scripts/macos_bootstrap.sh` without owning `tests/test_macos_bootstrap.sh`, so the fixture still built the old binary set and two units failed | the primary's full suite in the worktree: 1001 units, 2 failed, against a subagent report of green | repair brief; fixture rebuilt, one new case added for the `realpath`-without-`readlink` host |
| 2 | `tests/test_cli_lib.sh` defined and registered one test name twice, so bash overwrote the first body and the suite counted one assertion twice | the primary's unit count against the branch's own arithmetic | repair brief; duplicate removed, count returned to the predicted 1001 |
| 3 | The GNU findutils prefix never reached `PATH`, so the requirement the bootstrap had just installed and verified was still unmet on a real macOS host | found by a repair subagent, unprompted, and reported rather than fixed | repair brief; prefix added to `gnubin_paths()`, the doc's manual `PATH` line, and a new assertion pinning it |

Track B needed no repair. Its two units landed as reported, and the primary's diff read found one adjacent improvement the subagent made on its own initiative: it corrected a sentence in `git_policy.md` that said "in the body" where the rule was about the description.

### What the run did not establish

Two tracks on sixteen cores showed no deadline pressure, but the evidence is two tracks. The runner's per-file deadline is documented to flake under load, so the ceiling for concurrent tracks on a smaller host is untested and must be measured per host, not assumed from this run.

The model was held constant deliberately, so nothing here compares models or prices them against yield.

The consolidation merge was not performed: the branches are the deliverable of this trial, and merging them is a separate iteration whose result is the test case for the `/merge` workflow.

## Findings

**F1 - Concurrent record writes are unmergeable, and the record files are the ones every unit wants.** Two branches flipping adjacent roadmap rows conflicted. The design answer is the record rule, and the general form is: in a parallel run, the files every unit needs are the files no unit may write. Where a unit genuinely must change a shared record, the change is carried out by the primary after the merge.

**F2 - `auto.md`'s stop table has no row for a return the primary's verification rejects.** The table routes `rc=0, done` to verify and approve, and its repair guidance permits the primary to correct in its own turn only a defect the primary can fix as a line. This trial produced two returns that were `done` by the table's own rules and needed a whole repair unit. The table needs a `verified-defective` row that routes to a repair brief, and it needs to say that the repair goes back to the track rather than into the primary's tree.

**F3 - A brief's owned-file list must be closed under the test surface, and the closure is computable.** The defect that started this cascade came from a brief that named a script and not its test. The mapping is mostly a naming convention, `scripts/X.sh` to `tests/test_X.sh`, but not entirely: `src/libs/cli.sh` is covered by `tests/test_cli_lib.sh`. A convention check would have missed it, so the closure has to be computed by searching the test tree for the file's basename. This is the highest-value rule the trial produced, because it is the one that prevents a red suite from ever reaching the primary's verification.

**F4 - Ownership belongs to the track, not to the unit.** A repair subagent declined to fix a defect it had found, because the fix crossed its own brief's per-unit file list, even though the file belonged to the same track it was already working in and no other track could touch it. Its caution was half right: the fix needed a code file and a doc file to change together, and a one-sided fix would have left them disagreeing. The rule is that a brief states the track's whole owned-file set, each unit names the subset it touches, and any file in the track's set is fair game.

**F5 - A duplicate test definition and registration passes the registration liveness gate and inflates the suite's unit count.** `scripts/check_test_liveness.sh` verifies that every registration resolves to a definition and every definition has a registration, in both directions. It does not notice a name used twice, and bash's last-definition-wins makes the duplicate invisible in the output. The unit count is evidence - it is what a reviewer compares against a baseline - so a count that includes a duplicate cannot be compared. The durable fix is a duplicate check in that gate. This is a recurrence of the duplicate-row class already recorded in [`AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md), where a duplicate row in a numbered findings log was likewise invisible to the contiguity check that was supposed to catch it.

**F6 - A subagent that finds a defect outside its brief reports it instead of fixing it or hiding it.** This happened twice: once for record references the track could not touch, once for a code defect in a file the track did own. Both were reported in a `done` report, with the reasoning, and neither was a wasted discovery. The ownership discipline produced findings rather than silence, which is the behaviour the ownership rules want.

**F7 - A dispatch needs a wrapper to make failure and duration visible.** The failed dispatch was two tracks dying identically in 19 seconds, visible only by reading the log tails. Wrapping each dispatch in a shell timer and an exit-code echo cost two lines and produced every duration in this document. The T2 telemetry rows own the durable instrument; until they land, the wrapper is the mitigation.

**F8 - A subagent's log stays empty until the run flushes, so the worktree is the only liveness signal.** During the whole run, the primary could see progress only by asking the worktree: the count of dirty files and the count of commits told it that a track was working, had finished a unit, or had stalled. That is enough for a liveness check and it costs two `git` calls per track per poll. It is a partial answer to the T2 subagent-liveness row, available today with no instrumentation.

**F9 - A track can walk into a file the operator had excluded from a campaign.** The M3.1 read-through excluded `scripts/macos_bootstrap.sh` from its scope by operator direction. The host-requirements unit changed it, correctly, because the matrix row that declares the requirement cannot be satisfied without it. The exclusion was a campaign scope, not a standing rule, and the change is right - but a parallel run widens the blast radius of a brief, so the brief should name the files that prior operator direction excluded and say why the unit is touching them anyway.

## Feedback on fan-out and auto

**On `auto.md`.** Three of its rules held under parallelism without amendment: the well-specifiedness test, the disjoint-files rule across a run, and the primary-verifies-the-return rule. Two need work. The stop table needs the `verified-defective` row from F2. The brief construction needs the test-surface closure from F3 and the track-level ownership from F4. The template's statement that a subagent never commits is the one rule this design deliberately breaks, because the operator required the track work to survive for a later merge; the draft states the exception and its reason rather than leaving the templates in contradiction.

**On `fanout-run.md`.** Nothing in this run contradicted it, and the two templates answer different questions. The fan-out model optimises a single agent's context across many read-only units on a frozen snapshot; this design optimises wall clock across a few write-capable tracks on live branches. The frozen snapshot is the cheaper mechanism when the pass is read-mostly, because each subagent's edits stay in its own extraction and the primary merges nothing but verdicts. Where a track must produce commits that outlive the run, a frozen snapshot is the wrong instrument, because an extraction has no branch to commit to. The two are complementary: a large documentation sweep is still a fan-out, and it does not need this design.

**On the cost model.** The trial's numbers say the free model's budget should go to code and prose tracks in roughly equal part by unit count, not by wall clock, and that the primary's verification is the scarce resource, not the model. Five primary verifications backed four units here, and three of the five found something.

## Designs considered and rejected

**A copied tree per track.** Rejected. A copy has its own object store, so the consolidation has no common ancestor and becomes patch application, with conflict resolution by hand and no way to ask git what diverged.

**Three or more concurrent tracks.** Not rejected, untested. The load evidence covers two tracks on sixteen cores. The per-file deadline is documented to flake under load, so the number has to be measured per host before a template hard-codes it.

**Fan-out inside a single worktree for write-capable units.** Rejected for this purpose. Concurrent subagents editing one tree interleave their edits with no ownership boundary that git can enforce; the fan-out template avoids this by giving every subagent its own extraction, which is correct for read-mostly passes and wrong for a track that must commit.

**No subagents: the primary runs both tracks itself, serially.** Rejected. It forfeits the only thing the design adds, and it concentrates the verification and the implementation in one context, which is the failure mode the fan-out template was written to avoid.

## Follow-ups

| Follow-up | What it needs |
|---|---|
| A duplicate definition and registration check in `scripts/check_test_liveness.sh` | **Filed** as a roadmap row in T1, the duplicate test name check in the registration gate (2026-09-27); a rule in the gate plus a negative test |
| A `verified-defective` row in the `auto.md` stop table | **Landed** in `auto.md` (2026-09-27): the table routes a rejected verification back to its own unit as a repair brief, and the invariants carry the rule |
| A brief-construction helper that computes a unit's test-surface closure | **Filed** as a roadmap row in T1, brief construction: derive a unit's owned-file set from the tree (2026-09-27); F3 makes this the difference between a green and a red suite |
| Consolidation of `exp/track-a` and `exp/track-b` into the main branch | a later iteration; the cross-track merge is already verified clean, and the merge itself is the `/merge` feedback case. Both branches are exported as bundles, because a branch that is neither merged nor exported dies with the container |
| A model comparison across tracks | hold the workflow constant and vary the model, which this trial deliberately did not do |
| A per-host concurrency measurement | run three or four tracks on a smaller host and record where the per-file deadline starts to bite |
| Whether a subagent can propose a work-unit split | no subagent was asked to propose one in this trial, so the trial is silent on it; recorded as open on the roadmap's scope-to-unit row |
