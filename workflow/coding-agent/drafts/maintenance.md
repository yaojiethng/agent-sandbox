---
description: "Dispatch prompt for record maintenance. Picks the maintenance payload for the job, runs it, and reports it. Also carries the single-worker worktree dispatch loop, so an isolated maintenance run has one documented procedure. Use when the operator asks to maintain the roadmap, check the roadmap against roadmap_policy.md, verify compaction readiness, check handover content quality, audit the handover chain, trace a deferred item across iterations, or run any of those inside its own worktree. Supersedes the roadmap and handover survey in gm.md."
argument-hint: "[target - roadmap, handovers, both, or a worktree dispatch - optional]"
---

> $@

# Maintenance - The Dispatch Runbook

**Scope:** one dispatcher for record maintenance over `devlog/roadmap.md` and `devlog/handovers/`. It owns the choice of payload, the run against that payload, and the report. It corrects records through the payloads it dispatches to. It does not open or close an iteration, does not sequence roadmap work, and does not survey project state outside those two records.

## Purpose

The maintenance skills carry the checks. Nothing invoked them. This prompt is the entry point the operator reaches for, and it holds the routing that picks between the two payloads and the loop that runs a payload inside its own worktree.

This prompt owns three things. It decides which payload a job belongs to. It runs that payload as written and reports in the payload's own output shape. When the operator wants the run isolated, it dispatches one worker into its own git worktree and reviews the return.

The authoritative rules stay in the policy documents. The payloads are convenience copies of those rules, and this prompt is a convenience copy of nothing. Where a payload and a policy document disagree, the policy document wins.

## When to run

- The operator asks to check the roadmap against `roadmap_policy.md`, or to fix a roadmap defect. That is [`roadmap-maintenance.md`](../skills/roadmap-maintenance.md).
- The operator asks whether a compaction pass is safe, or wants the roadmap prepared for one. That is [`roadmap-maintenance.md`](../skills/roadmap-maintenance.md), Step 4.
- The operator asks about the content quality of the handover the current iteration is writing. That is [`handover-maintenance.md`](../skills/handover-maintenance.md), Track A.
- The operator asks to audit the closed handover chain, or to trace one deferred item across iterations. That is [`handover-maintenance.md`](../skills/handover-maintenance.md), Track B.
- The operator asks for any of the above to run in its own worktree, isolated from this session's tree. That is Step 5 of the procedure below, which carries the whole dispatch loop.

## When not to run, and what replaces it

- A survey of project state (git history, stashes, branches, open feedback entries, unsettled discussions, and a list of candidate next tasks) is [`gm.md`](../prompts/gm.md). This prompt supersedes the roadmap and handover parts of that survey, because the two payloads carry both and this prompt dispatches them. Migrating `gm.md` onto this prompt is a separate step and has not happened. Until that step lands, `gm.md` keeps its inline survey, and running both in one session duplicates the work.
- Choosing which roadmap rows can run unattended is [`backlog-triage.md`](../prompts/backlog-triage.md). A parked row is a planning question, not a maintenance defect.
- Planning or opening a unit is [`plan.md`](../prompts/plan.md) and [`iter.md`](../prompts/iter.md). Maintenance corrects records inside an open unit; it does not decide what the next unit is.
- Ending a session is [`wrapup.md`](../prompts/wrapup.md). The close owns its own maintenance step and does not hand that step to this prompt.
- A finding that no policy text covers is a gap to report, not a rule to add here.

## The procedure

### Step 1 - Name the job and the payload

Take the argument when the operator gave one and the request when they did not. Classify the job against the payloads, then state the choice before acting.

| The job | Payload |
|---|---|
| Roadmap markers, nesting, compaction, structure, or pre-compaction readiness | [`roadmap-maintenance.md`](../skills/roadmap-maintenance.md) |
| Handover content quality on the active handover | [`handover-maintenance.md`](../skills/handover-maintenance.md), Track A |
| Handover chain structure, deferred chain, status, or dangling references | [`handover-maintenance.md`](../skills/handover-maintenance.md), Track B |

A job that names both subjects runs both payloads, roadmap first, and reports each separately. Never merge their findings into one table; the two have different severities and different policy owners.

**Done when:** the job is named, the payload is named, and a job touching both records has both payloads named.

### Step 2 - Read the payload and the policy it cites

Read the chosen payload in full, then read the policy document it names as authoritative. Follow the read discipline in `AGENTS.md`: grep to locate the section, then read it.

**Done when:** the policy rules that govern the change are read from the policy document, not from the payload alone.

### Step 3 - Run the payload as written

Run every step of the payload in order. Apply its severity routing: a Medium or Low correction is applied, and a High correction is reported and held for the operator's release. Stop the run and name the failing condition rather than pressing past it.

**Done when:** every step of the payload has run, each completion criterion holds, and every High finding is named and held rather than applied.

### Step 4 - Report and gate

Present the report in the payload's own output shape, including its counts and its gate state. Then run the repository gate when a record file changed:

```bash
bash scripts/lint.sh
```

**Done when:** the report is delivered and `bash scripts/lint.sh` is clean, or the failing gate and its findings are named in the report.

### Step 5 - Decide whether to delegate

Delegate into a worktree when the operator asks for isolation, when the job holds more files than one agent context should carry, or when a cheap model can run the checks and this session reviews the result. Otherwise run the payload here and stop after Step 4.

**Done when:** the run is either in this session and finished, or delegated, with the reason for delegating stated.

### Step 6 - Cut the worktree and the branch

Choose the branch name and the path yourself; neither is a fixed value. Cut the branch from the current `HEAD`:

```bash
git worktree add -b <branch> <path> HEAD
```

Use a linked worktree, not a copy. Keep this session's tree clean for the whole worker run, because an edit made here moves the merge base under the worker.

**Done when:** the worktree exists at `<path>`, the branch `<branch>` is checked out inside it, and this session's tree has no uncommitted change.

### Step 7 - Write the brief inside the worktree

Write the worker's brief to a file inside the worktree, not to a path outside it and not to a command line alone. The brief names the task, its whole owned-file set, the checks to run, and the report shape. A brief is reproducible only when the file survives the run.

The worker does not review, does not merge, and does not write a record. Say so in the brief.

**Done when:** a non-empty brief file exists inside the worktree, and it states the owned files, the checks, the report shape, and the worker's limits.

### Step 8 - Run the worker in the foreground

Pre-flight the brief, then run the worker in the foreground of the tool call that needs its result. Capture the run to a log file, never through a pipe.

```bash
brief=<path to brief>                    # the worker's instructions; must be non-empty
[ -s "$brief" ] || { echo "brief missing or empty: $brief" >&2; exit 1; }
run_timeout=<seconds>                    # the run's timeout; set it yourself
start=$(date +%s)
timeout "$run_timeout" pi --provider <p> --model <m> --thinking <level> -p "$(cat "$brief")" > log 2>&1
rc=$?
echo "rc=$rc secs=$(( $(date +%s) - start ))"
```

Never append `&`. A worker backgrounded with `&` is killed when the tool call returns, and its work is lost with no error and a short log. To run two workers, put both inside one call and wait for both. Take the provider, model, and thinking level from the `_IMPLEMENTER` role recommendation in the project-level `AGENTS.md`.

**Done when:** the run has exited, its exit code and elapsed seconds are recorded, and the log is at a path the review can read.

### Step 9 - Review the return

The report is a claim about the tree. Check the tree.

- Read the diff in the worktree. Do not count it.
- Run the checks the brief named, with this session's own commands, and read the counts.
- `rc=0` with an empty log means the worker did no work. Treat it as a failure, not a pass.
- `rc!=0` means the run failed. Read the log and report what it says.

**Done when:** the diff has been read, the checks have been run here, and the verdict is stated with what was verified rather than what the worker claimed.

### Step 10 - Merge and clean up

The primary owns the review and the merge. Merge the worker branch into the current branch, then remove the worktree and the branch:

```bash
git merge <branch>
git worktree remove <path>
git branch -D <branch>
```

A branch left standing after the session is lost work, and a worktree left registered is not the worktree's own backup.

**Done when:** the branch is merged into the current branch, and both the worktree and the branch are gone.

## Output shape

The report opens with one dispatch line naming the target, the payload, and the scope examined. Then the payload's own report, in the shape that payload defines.

A delegated run adds three blocks after the payload's report:

| Block | Content |
|---|---|
| Run | The worktree path, the branch, the brief path, the log path, the exit code, and the elapsed seconds. |
| Verification | The diff summary, the checks run here with their counts, and the verdict that follows from them. |
| Merge | The merge commit, then confirmation that the worktree and the branch were removed. |

A run that changed no record says so in one line, with the state it found and the gate result. That is a complete report.

## Non-goals

- Editing `gm.md`. This prompt supersedes the survey `gm.md` performs inline over the roadmap and the handover chain, and migrating `gm.md` onto this prompt is a separate step. Until it lands, `gm.md` remains as it is and this prompt is the way to reach either payload.
- Surveying project state outside the two records. Git history, stashes, branches, feedback entries, and candidate next tasks belong to [`gm.md`](../prompts/gm.md).
- Deciding what the next unit of work is. This prompt corrects records; it does not choose work.
- Writing policy. A finding no policy covers is reported, and the rule belongs in `docs/operations/`.
- Running several maintenance tracks at once. This prompt dispatches one worker at a time. A multi-track maintenance campaign is [`parallel-work.md`](parallel-work.md), and the fork, join, and bring-back primitive is the task-queue prompt.

## Failure modes and invariants

- **A backgrounded worker is lost without an error.** A worker started with `&` is killed when the tool call returns. The log stays short, the report never arrives, and the loss reads as a hang. Run the worker in the foreground.
- **A clean exit code is read as a pass.** `rc=0` with an empty log means no work ran. Judge the tree and the checks, never the exit code alone.
- **The payload is read as the policy.** The payload is a convenience copy and can go stale. Where it disagrees with the policy document, the policy document wins.
- **A High finding is applied instead of held.** A correction that changes what a record asserts needs the operator's release first. Apply Medium and Low; report and hold High.
- **Both payloads are merged into one report.** The roadmap payload and the handover payload have different severities and different policy owners. Report them separately.
- **The worker merges its own work.** The primary owns the review and the merge. A worker reports; it does not close the branch or clean up the worktree.
- **A live worktree blocks the next run.** A leftover worktree or branch is not a backup and is not the session's history. Remove both at the end of every delegated run.
