---
description: Draft: run an operator-released unit plan by delegating one unit at a time to a fresh subagent, verifying every return against the tree before the next dispatch, and landing one commit per unit.
argument-hint: "[plan reference - a roadmap task, a row list, or the unit table - optional]"
---

> $@

# Autonomous Run - Unit Dispatch (Main-Agent Template)

**Scope:** how the primary agent runs a released multi-unit plan: the well-specifiedness test, the unit split, the subagent brief, the blocking dispatch, the evaluation of each stop, the records, and the run review.

## Purpose

One plan, one unit at a time. The primary dispatches a unit to a fresh subagent, verifies the return against the tree, writes the records, and commits. A subagent is a context device: the primary holds the plan, the records and the accumulated evidence at once, while the subagent holds one unit's source and its checks.

Dispatch a fresh subagent per unit. A subagent that has already worked one unit carries its assumptions into the next, so never continue a unit's session into another one; the resume path in Step 4 is the single exception, and it resumes the same unit.

The primary owns the run plan, the well-specifiedness test, the unit split, the owned-file sets, the briefs, the dispatch, the verification, the records and every commit. A subagent owns its unit's work and its report. A subagent never commits, never stages, and never edits a record.

## When to run this way

Run this way when the plan names its units and the units are independent. Independent means one unit's work does not depend on another unit's result; two units that must change one file are one unit.

Not this template: one large pass fanned out to concurrent subagents on a frozen snapshot (see [`fanout-run.md`](fanout-run.md)), or a whole campaign handed to a single subagent (see [`test-quality-campaign-run.md`](test-quality-campaign-run.md)).

## Step 1 - Build the run plan

Build the plan from the roadmap task list, or from the list the operator names. It names every unit and the order they run in.

**The well-specifiedness test.** A row enters the plan only when a scope confirmation would raise no open question: the design or spec is clear, the acceptance criteria are clear, and nothing is left to decide. Write the answer sheet for each candidate row - the type, what is in scope, what is deferred, the acceptance criteria with their checks, and the unit split - then read it back. Any line that would be a question parks the row. The parked rows and their questions are presented with the plan. A row that needs a decision is design work, not run work.

**The unit rule.** A unit is one roadmap task, scoped as a vertical slice, and it lands as one commit and one handover. The binding rule is in [`docs/operations/iteration_policy.md`](../../../docs/operations/iteration_policy.md). It fails the rule if any of these fail:

- **One commit.** The slice lands as one commit with one handover. If the commit subject cannot be written from the slice's diff, the boundary is wrong in one of two directions: re-scope the slice, or merge two units. A per-section or per-file commit inside one task is not a split -- it is one unit broken across commits.
- **One context.** The source, the tests and the evidence fit one subagent context with room to spare. A unit that needs two contexts splits. A unit that needs no fresh context is not worth dispatching.
- **One verification.** Its acceptance criteria are checkable without another unit landing first.
- **Disjoint files.** No two units own one file, checked across the whole run.

Split vertically, never by layer: a unit is one feature end to end, across the files it touches, and a feature too large for one context splits into sub-features that are each a working increment. Work phrased horizontally ("harden every gate") is a sequence of vertical slices or a design task, not a unit. A slice crosses file kinds and directories -- a policy file, a template and a record that serve one outcome are one slice, and the disjoint-files test binds two units, not one unit's sites.

**Present the plan and wait for the release.** The plan carries, per unit: the subject, the commit type, the owned files, the handover, and the acceptance criteria. Present it with the parked rows, and dispatch nothing before the operator releases it. After the release the run is unattended: the split changes only by stopping and reporting, because a different split is a different plan.

## Step 2 - Write the brief

One brief per unit, written to a file outside the tree. The brief carries:

- the unit's subject, and the commit type the diff will get;
- the owned files, and the prohibition on every other tree edit;
- the acceptance criteria, each with the command that checks it;
- the evidence the unit owes: for every criterion that pins production behaviour, a mutation check that names the test file it must fail and restores the file byte-identical;
- the report format, with its machine-readable tail;
- the prohibitions: do not commit, do not stage, do not edit a record, leave no mutated file unrestored.

Fix the report vocabulary in the brief:

```text
FILE <path> <one-line change>
AC <n> <pass|fail>
BITE <n> <file> <restored byte-identical: yes|no>
SUITE <passed>/<total> <files>
STOP <unit> <done|partial|stuck|needs-decision> <one line>
```

The tail is what the primary collects; the prose above it is a claim to check. The `STOP` line is mandatory. A subagent that cannot finish inside its budget returns a coherent partial rather than being killed, because a killed run cannot report at all.

The brief also states its budget, its model and its thinking level: the subagent cannot see its own invocation flags, and the report needs the attribution.

## Step 3 - Dispatch, blocking

```bash
timeout 1800 pi --provider opencode-go --model deepseek-v4-flash --thinking xhigh \
  -p "$(cat /tmp/auto/<unit>.brief)" > /tmp/auto/<unit>.log 2>&1
echo "pi rc=$?"
```

The dispatch blocks, and while it runs the primary does not touch the tree: that is what makes the subagent the only writer. Dispatch in the foreground, never in the background - a background subagent is killed when the tool call that started it returns, and it leaves the tree half-changed.

Log to a file, never through a pipe: a pipe drops the unflushed output when the run is interrupted, and it returns the status of the last pipe stage instead of the status of the subagent. Read the report's tail with `tail -26 <log>`.

No frozen snapshot is needed, because there is no sibling writer. The live tree is the input and the output, and the parked primary is the isolation.

## Step 4 - Evaluate the stop, then verify

The report is a claim about the tree. Check the tree:

- `git status --porcelain` lists exactly the owned files, with no scratch file and no registered worktree;
- read the diff, do not count it;
- run the suite yourself and read its counts (`bash scripts/run_tests.sh`);
- re-run each claimed mutation check, or confirm the failing file it names;
- compare each mutated file with its backup (`cmp`);
- collect the report's tail with a script.

A green suite that the subagent reports is not evidence; the primary's own run is, and the suite is cheap. Correct in the primary's own turn only a defect the primary can fix as a line - a stale call-site arity, a unit the destination suite already covers - and record the correction. A defect beyond a line does not come back to the primary's tree: it goes back to the unit's own tree as a repair brief, so the unit's history stays whole and the repairs fold into it rather than landing beside it.

Then route by the observed stop, with at most one additional attempt in every branch:

| Observed | Move |
|---|---|
| `rc=0`, `done` | verify, then approve and land; a rejected verification is not a stop-state change and routes on the row below |
| verification rejected a `done` return | one repair brief to that unit, carrying the defect, the evidence and the file the unit now owns; the repair runs in the unit's tree on the unit's branch, and gets one attempt before the file-and-park route |
| `rc=0`, `partial` | resume once: re-brief as a continuation and keep the tree |
| `rc=124` (timeout) with progress | resume once: `pi --session <path> "Continue and give your final report."` |
| `rc=124` with no progress, or a tree that cannot be verified | file the work, reset the owned paths, dispatch a fresh attempt |
| `rc=0`, `needs-decision` | surface the question in chat; answered, resume once; unanswered, park with no further attempt |
| `rc=0` with no `STOP` line | treat as `stuck` |

File the work before any reset:

```bash
bash /opt/sandbox/lib/package_branch.sh --to="$HOME/workspace/output" \
  --bundle-summary=partial_<unit>_<slug>
git checkout -- <owned files>
git clean -fd <owned paths>
```

The export runs while the tree still holds the work, so the bundle carries the landed units' patches beside the partial attempt as `uncommitted.diff`; the run's earlier history travels with the partial, and the partial can be applied later. Reset only the owned paths, never the whole tree.

A parked unit does not stop the run unless a later unit depends on it. A `needs-decision` stop is evidence that the well-specifiedness test failed, and a timeout usually means the unit was too big; both go into the parked list with the fix they need.

## Step 5 - Land the unit

Write the records after the verification, never before:

- add or update the roadmap row, and flip a task's checkbox only when its last unit has landed;
- write the unit's handover, carrying the verification evidence and the corrections;
- commit once, with the commit type taken from the diff.

Then confirm the boundary: suite green, lint clean, tree clean. An interrupted run stops cleanly at the last boundary, and the landed units stand.

## Step 6 - Review the run

The run's work is committed, so the review range is a fixed `git diff <run-base>..HEAD` and the tree is clean.

1. Sweep the cheap classes over the run's changes: documents that pin strings, commands, exit semantics or counts the run changed, and any term or count that drifted across records.
2. Run the bounded review loop in [`review-loop-run.md`](review-loop-run.md), with a reviewer of the operator's choice.
3. Present the run: the units and their commits, the review verdict, the parked units with their files, the bundle directories filed, and the rows that stay open.

## Failure modes observed

Carry each rule into the brief.

(a) **A background dispatch.** The subagent was killed with the tool call, halfway through a record repair. Dispatch blocking.
(b) **A pipe instead of a log file.** The output and the exit status were lost. Redirect to a file and read `pi`'s own status.
(c) **A duplicate unit.** The destination suite already pinned the case, and the new unit failed the same mutation. Read the destination suite first, and delete the duplicate rather than keep both.
(d) **A stale call site.** The unit called a helper with the arity it had before a rename. Run the suite, and read the diff for the call sites the unit touched.
(e) **A work list taken from a shared data file.** The unit named rows that belonged to another kind of work. Take the list from the unit's own deliverable.
(f) **A tree that never returned to clean.** A worktree stayed registered and a scratch file stayed in the tree. Prune, and check `git status --porcelain` at every boundary.
(g) **A tool that is not in the image.** `pgrep`, `jq`, `python3`, `make` and `docker` are absent, so a brief that calls one fails at its first command. Use the repository's own scripts, and check that a tool exists before a brief depends on it.

## Invariants

- One unit per dispatch, and one fresh subagent per unit, except a resume of the same unit.
- No subagent commits, stages, or edits a record.
- One suite runs at a time; with a blocking dispatch that is automatic.
- The tree is clean at every unit boundary, and no partial attempt is ever committed.
- A mutation check that counts as evidence names a failing file and a byte-identical restore.
- Records are written after verification, and one unit is one commit.
- A return the primary's verification rejects goes back to its own unit as a repair brief, never into the primary's tree as a quiet correction.
- The roadmap is the task list; the chat presentation is a digest.
