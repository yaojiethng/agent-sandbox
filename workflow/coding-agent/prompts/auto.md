---
description: Run an operator-confirmed unit plan by delegating one unit at a time to a fresh subagent, verifying every return against the tree before the next dispatch, and landing one commit per unit.
argument-hint: "[plan reference - roadmap row, register selection, or the confirmed unit table - optional]"
---

> $@

# Autonomous Run - Unit Dispatch (Main-Agent Template)

**Scope:** how the primary agent runs a confirmed multi-unit plan: the unit split and its row list, the subagent brief, the dispatch line, the verification of the return, the records the primary keeps, and the failure modes the run must avoid.

## Purpose

One plan, one unit at a time. The primary dispatches a unit to a fresh subagent, verifies the return against the tree, writes the records, and commits. The split is by context: the primary holds the plan, the register, and the accumulated evidence at once, while a subagent holds one unit's source and its mutations.

Dispatch a new subagent per unit. A subagent that has already worked one unit carries its assumptions into the next, so a decision taken for unit 3 silently scopes unit 4. Never continue one unit's session into another.

The primary owns the unit split, the row list, the owned-file sets, the brief, the dispatch, the verification, the register rows, the roadmap write-back, the handover, and the commit. A subagent owns its unit's work and its report. A subagent never commits and never edits a record.

## When to run this way

Run this way when the operator has confirmed a plan whose units are named (unit, commit type, file ownership, own handover) and the units are independent. Independent means one unit's work does not depend on another unit's result. Two units that must change one file are one unit.

Do not use this template to fan out one large pass across concurrent subagents on a frozen snapshot; that is [`fanout-run.md`](fanout-run.md). Do not use it to hand a whole campaign to one subagent; that is [`test-quality-campaign-run.md`](test-quality-campaign-run.md). This template covers the middle case: several units, one at a time, each verified before the next.

## Step 1 - Cut the unit and its row list

Filter the row list by the kind of change the unit can make, not by the subject file. A `test:` unit takes the rows whose `action_kind` is `test`; rows filed against the same files as `code` or `none` belong to another unit. Filtering by subject file alone overstated one campaign by half - 7 of the 21 rows in the diff-pipeline group were test rows, while the entry-point group held 13 of 14. Select with the register query, then recompute the unit size from the filtered count:

```bash
rowlist() {  # rowlist <action_kind> <register.jsonl>
  perl -ne 'BEGIN{$k=shift} next unless /"status":"open"/;
    my ($a)=/"action_kind":"([a-z-]*)"/; next unless $a eq $k;
    my ($f)=/"files":\[([^\]]*)\]/; my @f=($f=~/"([^"]*)"/g);
    my ($i)=/"id":(\d+)/; print "$i\t$f[0]\n"' "$1" "$2"
}
```

Give each unit a disjoint owned-file set, and check it for collisions against every other unit before dispatch. Two units must never own one file.

Name the production files the unit must leave byte-identical, and list them in the brief. A `test:` unit edits production code to prove a bite and restores it; a unit boundary whose diff holds a production change is a dispatch error.

## Step 2 - Write the brief

Write one brief per unit to a file outside the tree. The brief carries:

- the unit's subject, and the commit type the diff will get;
- the owned files, and the prohibition on every other tree edit;
- the row list: id, title, and the file each row names;
- the acceptance criteria, stated so each one can be checked;
- the exact commands the primary will run to verify (`bash scripts/run_tests.sh`, `bash scripts/lint.sh`);
- the report format, with its machine-readable tail;
- the prohibitions: no commit, no record edit, no restored-by-hand mutation left behind.

Fix the report vocabulary in the brief, one line per row:

```text
ROW <id> <verdict>    verdict: pinned | partial | survived
BITE <n> <file> <restored byte-identical: yes|no>
SUITE <passed>/<total> <files>
```

The tail is what the primary collects; the prose above it is a claim to check. A report format left open costs the primary the script that would have collected the unit in one pass.

Keep one brief template per campaign and substitute per unit: the template that ran a nine-unit campaign carried three placeholders - the row list, the owned files, and the subject.

## Step 3 - Dispatch in the foreground

```bash
timeout 1800 pi --provider opencode-go --model deepseek-v4-flash --thinking xhigh \
  -p "$(cat /tmp/auto/<unit>.brief)" > /tmp/auto/<unit>.log 2>&1
echo "pi rc=$?"
```

Run the dispatch in the foreground. A background subagent is killed when the tool call that started it returns, and it leaves the tree half-changed: a register repaired in part, a mutation unrestored.

Log to a file, not through a pipe. A pipe drops the unflushed output when the run is interrupted, and it returns the status of the last pipe stage rather than the status of the subagent. Read the report's tail from the log:

```bash
tail -26 /tmp/auto/<unit>.log
```

Give the run a generous timeout and state it in the brief. Name the model and the thinking level in the brief as well, because the subagent cannot see its own invocation flags and a report needs the attribution.

Resume an interrupted run with an explicit continuation prompt: `pi --session <path> "Continue and give your final report."` An opened session does not continue on its own.

## Step 4 - Verify the return

The subagent's summary is a claim about the tree. Check the tree:

- `git status --porcelain` lists exactly the owned files, and no scratch file or registered worktree;
- read the diff, do not count it;
- run the suite yourself: the pass count, the fail count, and the file count;
- re-run each claimed bite, or confirm the failing file it names;
- compare each mutated file with its backup (`cmp`);
- collect the report's row block with a script.

A green suite that the subagent reports is not evidence; the primary's own run is, and it is cheap - the full suite runs in about twelve seconds. A surviving mutation is recorded where it was found. A bite that cannot fail because the target line changes nothing is not a coverage gap: its disposition rule is in the bite requirement of [`read-through-run.md`](read-through-run.md).

Fix what the return got wrong in the primary's own turn, and note the fix in the unit's handover. A unit that repeats an existing unit is removed, not merged: read the destination suite before accepting a new unit, and check that the two units fail the same mutation rather than assume it.

## Step 5 - Land the unit

Write the records after the verification, never before:

- flip each row's `status` in the register with a line-based edit on `"id":<n>,`, and append a new row for a finding the unit produced;
- write the roadmap note for the completed work;
- write the unit's handover, with the verification evidence and the corrections;
- commit once, with the commit type taken from the diff.

Then confirm the boundary: the suite is green, lint is clean, and the tree holds no uncommitted change. An interrupted run stops cleanly at the last boundary, and the landed units stand.

## Failure modes observed

Each mode below occurred in a real run. Treat each as a warning and carry its rule into the brief.

(a) **A background dispatch.** The subagent was killed when the tool call returned, halfway through the register repair. The rule: dispatch in the foreground, in the same tool call that reads the result.

(b) **A pipe instead of a log.** The output was lost when the run was interrupted, and the exit status read as the pipe's, not the subagent's. The rule: redirect to a log file and read `pi`'s own status.

(c) **A duplicate unit.** Two units written into a destination suite that already pinned the case failed the same mutation, and neither bit. The rule: read the destination suite first, and delete the duplicate rather than keep both.

(d) **A wrong call site.** A unit called a helper with the argument count it had before a rename, and only the suite caught it. The rule: run the suite, and read the diff for the call sites the unit touched.

(e) **A row list taken from the subject file.** The unit named 97 rows where 52 were its kind. The rule: filter by `action_kind`, then recompute the size.

(f) **A tree that never returned to clean.** A worktree stayed registered after a bite run, and a scratch file stayed in the tree. The rule: `git worktree prune`, and check `git status --porcelain` at the boundary.

(g) **A tool that is not in the image.** `pgrep`, `jq`, `python3`, `make` and `docker` are absent, so a brief that calls one fails at its first command. The rule: use the repository's own scripts (`bash scripts/run_tests.sh`, `bash scripts/lint.sh`) and verify a tool exists before a brief depends on it.

## Invariants

- One unit per dispatch, and one fresh subagent per unit.
- No subagent commits, and no subagent edits the register, the roadmap, or a handover.
- One suite runs at a time; a verdict measured under another suite's load is not a verdict.
- The tree is clean at every unit boundary, with no production change left behind.
- A proven bite names a failing file and a byte-identical restore.
- The register is the source of truth; the chat presentation is a digest, and records state, not session history.
