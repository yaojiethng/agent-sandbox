---
description: Draft - run two or more work tracks concurrently, each in its own git worktree on its own branch, with a fresh subagent per track, the primary holding verification, records and the merge; a curated parallel dispatch shape.
argument-hint: "[track list - a roadmap task set, a row list, or a named track plan - optional]"
---

> $@

# Parallel Work - Concurrent Work Tracks (Main-Agent Template)

**Scope:** how the primary runs several work tracks at once: the track plan, the worktree and branch lifecycle, the concurrent dispatch, the per-track verification, the repair path, the merge order, and the record rule that makes the merge possible.

## Purpose

`sequential-work.md` runs one unit at a time, because a subagent that has worked one unit carries its assumptions into the next. That rule is about context, not about wall clock: two units that share no files and no assumptions lose nothing by running side by side, and the trial this template records ran two tracks concurrently with no interference and no lost defect. The saving is real only when the tracks are genuinely independent, so this template spends most of its length deciding that, because the failure mode is not a merge conflict - it is two tracks that quietly depend on each other and produce a plausible wrong answer.

The primary holds the plan, the worktrees, the briefs, the dispatch, the verification of every return, the records, and the merge. A track subagent holds one track's work inside its own worktree. Nothing crosses between a track subagent and the primary's tree except a return, a brief, and a merge.

The measured results behind this template - wall clocks, defect counts, the reproduced record conflict, the two-track load ceiling - are in [`20260927-design-draft-parallel_auto_experiment.md`](../../../devlog/discussions/20260927-design-draft-parallel_auto_experiment.md).

## When to run this way

Run this way when the plan names two or more tracks that are independent, each is well specified, and the operator wants the wall clock back. Independent means: no track reads or writes a file another track owns, and no track's acceptance depends on another track's result. Two units that must change one file are one unit, and one track is not a parallel run.

Not this template:

- one track, or units with a real dependency between them - use [`sequential-work.md`](sequential-work.md), which is sequential by design and needs no worktrees.
- a read-mostly pass over many files, where each subagent reads a slice and returns verdicts with no commits - use [`fanout-run.md`](fanout-run.md). Its frozen snapshot is cheaper, because a subagent's edits stay in its own extraction and the primary merges nothing.
- a whole campaign handed to a single subagent - use [`test-quality-campaign-run.md`](test-quality-campaign-run.md).
- tracks where the operator must decide at boundaries the worker itself detects - use [`task-queue.md`](task-queue.md). It runs a fan-out as a fork and a join, hands each break point to the operator, and brings the accepted tracks back.

## Preconditions

**Concurrency is bounded by the host, and the bound is measured, not assumed.** The runner dispatches 8 test files in parallel under a 5 second per-file deadline, and a heavy file under load is documented to expire that deadline and take its whole file's unit count with it. A trial on sixteen cores ran two concurrent full suites in 15 and 12 seconds with no deadline pressure; the same trial did not test three tracks, and a smaller host has not been tested at all. Before dispatching, confirm the core count, and start with two tracks. Add a third only after a run at two has been clean. Never raise `TEST_PARALLEL` to fit more tracks into a loaded host: lower it per track instead, so the sum stays at or below the core count.

**One baseline commit.** Every track branches from the same commit. Branches cut from different baselines merge against a moving target and the conflict set becomes unreproducible.

**The model is chosen from the provider's own model list.** The overlay provider registers its own list, separate from the base provider's, and a model identifier from the wrong list fails the whole dispatch in seconds. Read the list for the provider in the command, not from memory or from another provider's output. Take the provider, model and thinking level for a worker track from the `_IMPLEMENTER` role recommendation in the project-level `AGENTS.md`.

## Step 1 - Build the track plan

Apply the well-specifiedness test from [`sequential-work.md`](sequential-work.md) Step 1 to each track: a scope confirmation must raise no open question about the design, the acceptance criteria, or the checks. A track that would raise a question is design work, not run work, and it does not go in the plan.

**The independence test.** Write each track's owned-file set, then compare every pair of sets. Any file in two sets is a shared file, and the two tracks are one track. This is the same disjoint-files rule `sequential-work.md` applies across units, lifted from within a run to across concurrent runs.

**Close each owned-file set under the test surface.** For every shell file a track changes, the track also owns every test file that exercises it, and the set is computed by searching the test tree for the file's basename rather than by naming convention. The convention `scripts/X.sh` to `tests/test_X.sh` covers most cases and misses the rest - `src/libs/cli.sh` is covered by `tests/test_cli_lib.sh` - and a track that changes a script without owning its test ships a red suite that no subagent will notice, because the subagent verifies the files its brief named. Compute the closure before the brief is written, and put the result in the brief.

**Ownership is per track, not per unit.** The brief states the track's whole owned-file set; each unit names the subset it touches, and any file in the track's set is in bounds. A per-unit file list invents a boundary that does not exist: a track subagent that finds a defect in a file the track already owns will decline to fix it, and report it instead, which is safe but wastes the discovery.

**Name the excluded files.** If operator direction excluded a file from an earlier campaign, and a track must change it anyway, the brief says so and gives the reason. A parallel run widens the blast radius of a brief, so an unexplained excursion into an excluded file is invisible until review.

## Step 2 - Cut the worktrees and the branches

One worktree and one branch per track, both named for the track, both cut from the baseline commit:

```bash
git worktree add -b "exp/<track>" "/tmp/wt-<track>" <baseline>
```

A linked worktree, not a copy. A copy has its own object store, so the tracks have no common ancestor and the consolidation becomes patch application instead of a merge. A branch, not a detached HEAD: a detached worktree can be read but not merged by name.

Keep the primary's tree clean for the whole run. The primary does not edit files while tracks are live, because a dirty primary tree moves the merge base under the tracks.

**A track's commits are reachable only from this repository, and the container does not outlive the session.** Nothing pushes, and a branch cut in the container is not on the host. So a track has exactly two safe fates: its commits land in the session's own history, or they are exported as a bundle. A third fate - a branch left standing at the end of the session - loses the work, and a worktree left registered is not the worktree's own backup.

The merge is the ordinary route: cut the tracks into the session branch and the session's own export carries them. When the operator defers the merge past the session, export each track before the session ends.

`package_branch` requires a real `.git` directory and refuses a linked worktree, whose `.git` is a file. Package a clone of the track's repository instead, one bundle directory per track, because the tool overwrites its output directory on every run:

```bash
git clone -q --no-hardlinks "$REPO_ROOT" "/tmp/port-<track>"
git -C "/tmp/port-<track>" checkout -q "<track-branch>"
source /opt/sandbox/lib/package_branch.sh
package_branch "/tmp/port-<track>" "$HOME/workspace/output/bundles/<bundle>" false "<baseline>"
```

The baseline is the run's baseline commit, so the exported patches apply on top of whatever the session itself lands. Check the bundle's `.export-status` reads `SUCCESS` and that its patch count matches the track's commit count, then say in the run presentation that the tracks are exported and where.

## Step 3 - Dispatch the tracks concurrently

One fresh subagent per track, all dispatched before any of them returns. The tracks are the unit of context here: a subagent that has worked one track's files carries its assumptions into the next, so one subagent per track, never one subagent for several tracks.

**Wrap every dispatch so its failure and its duration are visible.** Redirect to a log file, never a pipe, and echo the exit code and the elapsed seconds. Pre-flight each brief before dispatch:

```bash
brief="/tmp/<track>.brief"                    # the track's instructions; must exist and be non-empty
[ -s "$brief" ] || { echo "brief missing or empty: $brief" >&2; exit 1; }
cd "/tmp/wt-<track>" && nohup bash -c 'S=$(date +%s); pi --provider <p> --model <m> --thinking <t> -p "$(cat /tmp/<track>.brief)"; echo "RC=$?"; echo "SECONDS=$(( $(date +%s) - S ))"' > "/tmp/<track>.log" 2>&1 &
```

Read `RC` and `SECONDS` from each log after the run, and map what you see to what happened:

- `RC=0`, empty log, clean worktree: the brief was empty or missing and pi did no work - a no-op, not a pass. The guard should have caught it before dispatch.
- `RC=0`, non-empty log, changed worktree: the track ran; the suite decides the rest.
- `RC!=0`: the run failed; read the log.
- Empty log while `SECONDS` grows: the track is still thinking, not dead.

**Poll the worktrees, not the logs, for liveness.** Two `git` calls per track per poll answer the question the log cannot: is it working, has it finished a unit, has it stalled.

```bash
git -C "/tmp/wt-<track>" status --porcelain | wc -l   # files in flight
git -C "/tmp/wt-<track>" log --oneline <baseline>..HEAD | wc -l   # units landed
```

## Step 4 - Verify each return against its own worktree

The report is a claim about the tree. Check the tree, in that track's worktree, with the primary's own commands:

- `git status --porcelain` lists exactly the files the track owns, with no scratch file and no backup;
- read the diff, do not count it;
- run the suite yourself and read the counts, comparing them against the arithmetic the track's units imply;
- compare the returned unit count with the baseline count, and account for every unit of growth. A count that grew by more than the units added has a duplicate in it.

Run the **whole** suite for the track's return, not the files the brief named. A subagent that verified only its named files cannot see a defect in a file the brief omitted, and the primary's full run is the check that closes the brief's gaps. On a loaded host, run the two tracks' verifications in sequence rather than concurrently: the primary's verification is the scarce resource, and a false red from a deadline expiry costs more than the seconds saved.

## Step 5 - Repair a rejected return

A return that fails the primary's verification becomes a repair brief to the same track: the defect, the evidence, the file the track now owns, and the count it must land on. Dispatch it into the same worktree, on the same branch, so the track's history stays self-contained and the consolidation stays a merge.

Give the repair brief a numeric acceptance criterion where one applies - the unit count the suite must report - and say so explicitly. The count is evidence, and a numeric target stops a repair from quietly adding a registration to make a number work.

`sequential-work.md`'s stop table has no row for this case, and this step is the row: a `done` return that the primary's verification rejects routes to a repair brief, not to a correction in the primary's own tree.

## Step 6 - Merge, in order

The operator may hold the branches for a later consolidation, in which case this step is a no-op and the branch names are the deliverable. When the merge is in scope:

1. Merge the tracks into the integration branch one at a time, in a fixed order, so a conflict has one known locus. A fixed order also makes the merge reproducible: the same two branches conflict the same way twice.
2. Expect conflicts only in shared files. Disjoint-file track commits merge clean, and that is the check that the independence test did its job.
3. Resolve any conflict in the primary, and re-run the full suite and lint after the merge, not per track. The merge is a new tree state, and neither track's verification covers it.
4. Retire the worktrees and branches last, after the merge is verified: `git worktree remove` and `git branch -d`. A registered worktree left behind is a scratch artifact the next run trips over.

## Step 7 - The records

No track writes a record. Not `devlog/roadmap.md`, not `devlog/AGENT_FEEDBACK.md`, not `devlog/changelog.md`, not a handover. The primary writes them, after the merge, from what it verified.

This is not tidiness. Concurrent record writes do not merge: two branches each flipping one checkbox on adjacent roadmap rows produce a content conflict, and the record files are precisely the files every unit would want to touch. The general rule is that in a parallel run, the files every unit needs are the files no unit may write. A unit that genuinely must change a shared record carries the change as a proposal, and the primary applies it.

The one documented exception to `sequential-work.md`'s "a subagent never commits": in this template a track subagent commits to its own branch, because the operator may want the track's work to outlive the run as a mergeable branch. The exception is scoped to the track's own branch. A track subagent still never commits to the integration branch, never stages anything outside its worktree, and never writes a record.

## Step 8 - Review the run

The run's own review is the bounded loop in [`review-loop-run.md`](review-loop-run.md), over the merged range. Per track, record what the trial measured and what it cost: units, subagent runs, wall clock per unit, defects found by the primary's verification, and defects the tracks reported themselves. Those numbers are the only evidence for the next concurrency decision, and they are the input the T2 telemetry rows will make automatic.

## Failure modes observed

(a) **A model identifier from the wrong provider's list.** The overlay provider registers its own list. A foreign identifier fails every track in seconds with an upstream error, identically, and the only evidence is the log tail. Read the list for the provider in the dispatch command.

(b) **A brief that names a script and not its test.** The unit changes the script, verifies the files the brief named, reports green, and the suite is red. The primary's full-suite run catches it; the closure computed in Step 1 prevents it.

(c) **A duplicate test definition and registration.** Bash lets the last definition win, so the duplicate is invisible in the output, the registration liveness gate does not notice it, and the suite's unit count inflates. A count that includes a duplicate cannot be compared with a baseline count. Verify the arithmetic in Step 4.

(d) **Two tracks writing the same record file.** A content conflict on adjacent rows. See Step 7.

(e) **A per-unit file list mistaken for a track boundary.** A track subagent finds a defect in a file the track owns, declines to fix it because the unit's list omitted it, and reports it. The discovery survives; the fix waits for another dispatch. State the track's whole set.

(f) **A detached worktree.** Readable, not mergeable by name. Cut a branch.

(g) **Concurrent verification on a loaded host.** Two full suites plus two live tracks on a small host produces deadline expiries that read as red suites. Verify in sequence; keep the sum of the runner's job counts at or below the core count.

(h) **A worktree or probe branch left registered after the run.** Prune at the boundary and check `git worktree list` and `git branch --list` before the run is called clean.

(i) **A track left standing when the session ends.** The branch was never merged and never exported, and the container is gone, so the work is unrecoverable. Export the tracks in Step 2, before the run reaches its end; a registered worktree is not a backup.

## Invariants

- One track per worktree, one branch per track, one baseline commit for all tracks, and a branch rather than a detached HEAD.
- One fresh subagent per track; no subagent continues from another track's session.
- No two tracks own one file, and every track's owned-file set is closed under the test surface.
- No track writes a record, and no track subagent commits outside its own branch.
- The primary verifies every return in that track's worktree, with its own suite run and its own diff read, and accounts for every unit of count growth.
- A rejected return goes back to its track as a repair brief, never into the primary's tree as a quiet correction.
- Merges happen in a fixed order, after the tracks are verified, and the merged tree is verified again.
- Every track's commits are either in the session's history or in an exported bundle before the session ends.
- Records are written after the merge, by the primary, from verified evidence.
