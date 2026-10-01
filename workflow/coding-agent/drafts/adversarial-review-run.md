---
description: Draft - run an adversarial novel-bug review - the machine gates first, then one focused reviewer for the coupled judgement, then one class-scoped collateral hunter per finding class in parallel, then a confirmation pass.
argument-hint: "[repo path] [scope - what is under review] [baseline]"
---

> $@

# Adversarial Novel-Bug Review - Run (Main-Agent Template)

**Scope:** how the primary agent runs the part of review that no machine gate can do. One focused reviewer carries the coupled judgement and finds the novel bugs. Each finding class it names is then handed to its own hunter, which parallelises because a class decomposes. The two phases are serialised against each other and parallel within themselves.

**Why this shape.** A green suite proves nothing on its own: the task-queue suite stayed green at 202/202 while two invariants were false. The machine gates close the enumerable part of that gap, so the review budget is spent only on what the gates cannot enumerate. Within the review, the primary judgement does not decompose -- it is one reader reasoning across the whole change -- so it stays one reviewer. A defect class does decompose, because each site hosting it is checked independently, so it fans out.

## Preconditions

1. **The machine gates are green and have just run.** Mutation tier and invariant report, both over the same scope. Do not start the review over a scope whose gates have not run: the whole point is that the reviewer's budget buys only what the gates could not.
2. **The change set is committed and the tree is clean.** The reviewer reads `git diff <base>..<head>`. A dirty tree lets a reviewer mistake an unfinished attempt for landed work.
3. **The reviewer role recommendation is read.** Provider, model and thinking level from the `_REVIEWER` row of the project-level `AGENTS.md`, first in listed order. The brief states them so the subagent calibrates depth and the report carries attribution.

## Step 1 - Run the gates

The gates are the precondition, not part of the review. Run them and record the counts; the reviewer brief states them as an assumption it may rely on.

```bash
<gate commands for the primitive under review>
```

Both green. A red gate ends this run: fix it before spending review budget, because a reviewer reasoning about a broken baseline produces findings about the breakage.

## Step 2 - Write the reviewer brief

Write the brief to a file, then dispatch it. The brief is verbatim text passed with `-p`, so it must stand alone: the subagent has no prior conversation and sees only what the brief states and what the committed diff contains.

```bash
brief=/tmp/adversarial/reviewer.brief
mkdir -p /tmp/adversarial
[ -s "$brief" ] || { echo "brief missing or empty: $brief" >&2; exit 1; }
```

## Step 3 - Dispatch one focused reviewer

One reviewer, not a pool. The primary judgement is coupled: a second reviewer reading the same change concurrently produces duplicated findings and averaged depth, and nothing checks the first one's misses.

```bash
timeout 3600 pi --provider <provider> --model <model> --thinking <level> \
  -p "$(cat "$brief")" > /tmp/adversarial/reviewer.log 2>&1
echo "pi rc=$?"
```

Capture to a log file, never through a pipe: a pipe loses the unflushed output on interruption, and the log file and the session transcript survive. Read `rc` and map it:

- `rc=0`, empty log: the brief was empty or pi did no work. A no-op, not a pass.
- `rc=0`, non-empty log: the reviewer ran; its verdict decides the rest.
- `rc!=0`: read the log. On a timeout, resume rather than repeat -- pi auto-saved the session; collect the verdict with `pi --session <path> "Continue and give your verdict."`

## Step 4 - Derive the classes

Read the reviewer log and take its findings. Each finding names a defect class. Write that class as one sentence -- "a multi-step operation whose prune can refuse after the main tree is written" -- before any hunter is dispatched. A class that cannot be written as one sentence is two classes; split it.

**A class earns a hunter only when it decomposes.** Test it: are there at least two sites that could host the class, checked independently of each other? If the class has one candidate site, the primary reviewer already read it and a hunter adds a fresh context to re-read one file. If the class decomposes, each site is an independent check and the fan-out buys real coverage.

Do not fan out over classes the reviewer did not raise. A hunter given a class nobody found is doing the primary reviewer's job in parallel, which is the failure this template exists to avoid.

## Step 5 - Fan out the hunters

One hunter per class, all dispatched before any returns. Hunters are read-only, so they need no worktree and no branch: there is no owned-file set to keep disjoint, and a reviewer that writes nothing cannot collide with another. Dispatch them concurrently from the repository root.

```bash
nohup bash -c 'S=$(date +%s); pi --provider <provider> --model <model> --thinking <level> \
  -p "$(cat /tmp/adversarial/<class>.brief)"; echo "RC=$?"; echo "SECONDS=$(( $(date +%s) - S ))"' \
  > "/tmp/adversarial/<class>.log" 2>&1 &
```

Read `RC` and `SECONDS` from each log when the run returns, and map them as in Step 3. An empty log while `SECONDS` grows is a hunter still thinking, not a dead one.

## Step 6 - Confirm convergence

The hunters widen coverage; they do not decide. Read every hunter log against the primary reviewer's own reading of the named sites, then run one confirmation pass over the combined finding set: one fresh reviewer, the union of findings, no new scope.

The confirmation reviewer reproduces each finding in the code and returns the finding plus `FIXED`, `PARTIAL`, `NOT FIXED`, or `REGRESSED` per prior-round claim. A finding no hunter and no confirmation reviewer can reproduce is dropped, not reported: a wrong finding costs more than a missing one.

Record the outcome in the iteration's records: the gates' counts, the primary verdict, each class and its verdict, the confirmation outcome, and the surviving findings. Records state what the run established, not how many rounds it took.

## The reviewer brief

The primary reviewer. One of these per run, dispatched at Step 3.

````text
# Adversarial novel-bug review: <scope>

You are a fresh adversarial reviewer hunting for NOVEL bugs -- defects no existing test, mutation row, or invariant case anticipates. You are not re-running the gates. The gates are green by assumption; your job is the residue they cannot reach.

Repository: <repo>, branch <branch>. The change set is <diff range>. Inspect it:

```bash
git -C <repo> diff <base>..<head>
```

Read-only: do NOT edit, commit, or push. Report inline.

Model/provider: <provider>/<model> at <level> thinking. This is your attribution line and it goes in your report.

## What is already covered -- do not re-report these

The machine gates ran first over this exact scope and are green:

- Mutation tier: <count> deliberate breaks replayed in a throwaway mirror, each proven to turn the owning suite red. A dropped gate, a reordered effect, a weakened identity, and a removed heartbeat are all caught.
- Invariant report: <count> named cases over <count> invariants, driven over the real tool surface and read from the primitive's own status call.

A finding must survive the question: "why did no mutation row and no named invariant case catch this?" If the honest answer is "they should have", that is a finding against the gates, not against the code -- report it separately, in its own section.

## The contract you hold the code to

<the invariant list, one per line, with the number or label the records use>

Authoritative statements: <the ADR or design record>. Do not re-litigate a settled decision recorded there.

## Where to look hardest

1. **Held by construction, or only by the tests?** For each invariant, name the code path that makes it true. An invariant that holds only because a test sets up the right sequence is a finding: the test is then the mechanism, and any other caller can break it.
2. **Trace an actual run end to end.** Fork, dispatch, join, hold, release, re-request, terminal, verify, proposal, verdict, bring-back, re-queue, close. At each beat ask what state a crash there leaves, and whether the next call can make progress from it. Name the beat and the stuck state.
3. **Prove by negation every path documented as inert.** For each -- a timeout return, a refused call, an idempotent retry -- enumerate the writes it could still reach. A path with one reachable write is a finding.
4. **Partial application.** For every multi-step operation, find the beat between two steps and say what a reader sees there. Then ask whether any recovery path can distinguish "interrupted mid-way" from "never started". If it cannot, the inference is unsound, and that is a finding.
5. **Claims the code does not hold.** Sweep tool descriptions, the prompt, and the design record for statements the code does not implement. A record asserting an atomicity the code lacks is a blocker.
6. **The suite's own blind spots.** Which invariant has no case that would fail if the behaviour regressed? Which case asserts trivia -- a return shape, a log string -- rather than the invariant it names?
7. **Anything the change broke elsewhere.** Grep for consumers of the changed surface and of any name it removed.

## Deliverable

1. A numbered defect list. Each row: file:line -- the defect -- why it violates a named contract item -- the fix -- severity.
2. For each defect, the gate-gap line: why no mutation row and no invariant case caught it. This is the part that generalises to the next primitive.
3. For each contract item, one line: BY CONSTRUCTION (name the path), BY TEST ONLY (name the case), or UNPROVEN.
4. VERDICT: PASS or FAIL.

Severity: blocker = a contract invariant is violated, or a losing bug or deadlock exists; major = a real defect with bounded blast radius; minor = clarity, naming, or a doc mismatch. If you find nothing at a severity, say so explicitly rather than inventing one.

Verify each claim against the code before reporting it. A wrong finding costs more than a missing one. Be terse and concrete; no praise.
````

## The collateral hunter brief

One of these per decomposed class, dispatched at Step 5. `<class>` is the one-sentence class statement from Step 4.

````text
# Class-scoped collateral hunt: <class>

You are a fresh reviewer checking ONE defect class across <scope>. You were dispatched because the primary adversarial review reported a finding in this class and the class decomposes across more than one site.

Repository: <repo>, branch <branch>. The change set is <diff range>. Read-only: do NOT edit, commit, or push. Report inline.

Model/provider: <provider>/<model> at <level> thinking. Attribution line.

## The class

<the primary finding verbatim: file:line, the defect, the contract item it violates>

## Your question

Is the reported instance the only one?

Enumerate every site that could host the class. For this primitive the sites are: every operation's derive, every tool entry point, every path that writes the state journal, every path that writes the main tree, every path that prunes or restores a worktree, every git read that precedes a write, and every recovery or resume path.

For each site, one line:

- NOT APPLICABLE -- name the check that makes the class impossible there.
- SUSPECT -- the concrete sequence that would trigger it, and the file:line.
- CONFIRMED -- file:line, the sequence, the fix.

## The bar

- Prove by negation each NOT APPLICABLE. If you cannot name the check that excludes the class there, it is SUSPECT.
- A site you did not open is not NOT APPLICABLE. Silence is not an answer.
- Severity as in the primary brief: blocker = a contract invariant is violated; major = a real defect with bounded blast radius; minor = clarity or doc mismatch.
- Verify each claim against the code. A wrong finding costs more than a missing one.

## Deliverable

1. The one-sentence class statement.
2. The complete site table above.
3. VERDICT: NO COLLATERAL, or COLLATERAL FOUND with the confirmed rows.

Be terse and concrete; no praise.
````

## The confirmation brief

One of these per run, dispatched at Step 6.

````text
# Confirmation review: <scope>

You are a fresh reviewer on the FINAL pass of an adversarial review run. A primary reviewer and a set of class-scoped hunters have reported findings. Your job is to reproduce each one in the code and return a verdict per finding. You add no new scope.

Repository: <repo>, branch <branch>. Read-only: do NOT edit, commit, or push. Report inline.

Model/provider: <provider>/<model> at <level> thinking. Attribution line.

## What I need from you

1. For each finding below: FIXED, PARTIAL, NOT FIXED, or REGRESSED, with a reason, and the name of the code path or the case that proves it.
2. Does the change still hold each contract item BY CONSTRUCTION, or only where a test happens to drive the sequence? Name the path or admit it is unproven.
3. Run the suite and report the pass count.

<the primary reviewer's findings, then each hunter's confirmed rows, verbatim>

A finding you cannot reproduce is reported as NOT REPRODUCIBLE and dropped. A wrong finding costs more than a missing one. Be terse and concrete; no praise.
````

## Invariants

- The gates run before the review, never after, and a red gate ends the run.
- One primary reviewer per run. Never a pool: the judgement is coupled.
- One hunter per decomposed class, dispatched only for classes the primary reviewer raised.
- Hunters are read-only, so no worktree and no branch. A hunter that writes is out of contract.
- No finding reaches the records until a confirmation pass reproduces it in the code.
- The reviewers never commit. The primary commits, always.
- A verdict is a control signal. A round without an explicit verdict did not happen.
