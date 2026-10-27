---
name: dispatch
description: Dispatch one worker over a brief through the dispatch entrypoint, read-write or print-only. Use when a subagent should do real work and the model has to come from the role table rather than from this skill.
---

# dispatch

Dispatch one worker over one brief. A worker edits, runs tests, and returns work. The role names the model, and this skill names none.

## What a worker is

The contract is what makes this a general subagent rather than a reviewer.

- **Read-write.** It edits the tree, runs tests, and returns the change set. The caller verifies the tree and lands the commit.
- **One brief, passed verbatim.** The brief is the only variable input.
- **A role, not a model.** The call names a role, and the entrypoint resolves it against the role table, so a model move is a data edit and the invocation says which role ran. A model chosen here would be a second copy of the table.
- **A named base revision.** The report is attributable to the revision the caller names, so the caller can attribute every line. This is what lets a later pass over the same unit run in place.
- **Its own log and event stream.** The log is the only evidence the run leaves.
- **A report in the brief's shape**, returned to the caller.

## The form

A caller runs the entrypoint:

```bash
bash scripts/dispatch.sh --role _IMPLEMENTER --brief <brief-file> --worker --run \
  [--base <rev>] [--run-dir <dir>]
```

The entrypoint resolves the role, derives the runtime from the assignment, builds the command and runs it in the foreground of one call, so the worker is never orphaned. It writes the log and the change set beneath the scratch directory and prints the run directory, the log path and the changed-file count. It refuses a missing or empty brief, an absent or unwritable scratch directory, and an unresolvable base revision.

Without `--worker`, the entrypoint prints the command a role resolves to and records nothing. That form takes `--dir` instead of `--run-dir`, and it is how a caller checks what a role resolves to before spending an attempt.

A review takes seats. `--seats <n> --run` runs n read-only attempts over the role's candidates and reports each seat's outcome, and `dispatch.md` holds the seating and the turns. A subagent cannot see its invocation flags, so the brief states the provider, model and thinking level it runs at, and the report carries them; where the caller took the assignment from the role line rather than pinning it, the report says `startup default`. A seat run takes `--dir` and refuses `--worker`, because a worker returns one change set. `--model` pins an assignment and every seat then runs it, recording each attempt like any other: resolution is the default, and a pin is the caller's stated value.

Resolution, the runtime rule, the walk and the failure vocabulary belong to [`dispatch.md`](/opt/sandbox/docs/reference/dispatch.md), and this skill points there rather than restating them. What the caller acts on is in one place, the exit code: zero means the worker ran, one a refusal before any attempt, three blocked with the earliest wait named, and any other code is the worker's own.

Env overrides: `DISPATCH_TIMEOUT` for the attempt's limit, `DISPATCH_STALL` for the silence window and `DISPATCH_POLL` for the poll interval.

## The fallback

A role's line may name several assignments, separated by `;`. The entrypoint tries them in file order and starts the next one only when the attempt failed without adding a change of its own, so a second model never inherits a first model's edits. The caller's own uncommitted work is measured out of that comparison, so a dirty tree does not block the advance. Every failed candidate is reported at the end with the class it ended in, whether or not a later one succeeded.

The attempt is stopped as soon as its log carries a refusal, because a refused process stays alive on an event subscription it never closes. The provider `AGENTS.md` defines the container's scratch directory; pass it as `--run-dir`, because the entrypoint keeps its attempt logs and its change set there.

## Steps

1. **Name the brief and the scratch directory.** Both are absolute paths. Done when the brief file is non-empty and the scratch directory exists and is writable; the entrypoint refuses either case.
2. **Name the role.** A general worker runs as `_IMPLEMENTER`. Done when the role resolves; a role the table does not name is refused by name, and the change is the role table.
3. **Resolve the assignment, then pass it verbatim.** `node src/libs/dispatch/cli.ts table resolve --role <ROLE>` prints `<provider>/<model> <level|-> <runtime>`, or prints nothing and exits 1. Print the result before dispatching, so the assignment is in the transcript, and pass the id in full: `--model` matches as a substring and takes the last id that contains it. Done when the printed assignment is the one the command carries.
4. **Name the base revision.** The default is `HEAD`. A later pass names the revision the unit started from, so the report covers the whole unit. A dirty tree is allowed, because that is what a later pass needs. Done when the base resolves to a commit.
5. **Run the entrypoint.** Done when the log exists and is non-empty. An empty log with a zero exit code means the worker did no work, and the entrypoint reports that as a failure.
6. **Verify the change set against the tree.** The report is a claim about the tree. Read the diff, run the check the brief named, and confirm the report landed. Done when every changed file is one the brief allowed and the check passes.
7. **Commit one unit.** The worker returns work; the caller lands it, one commit for one unit.

## Non-goals

- Does not choose the model. The role table is the operator's, and a model named in a skill or a brief shadows it.
- Does not write the report. The worker reports; the caller acts.
- Does not own the brief. The brief's content is the calling unit's, and this skill passes it unchanged.
- Does not verify the work. The caller checks the tree, per the `prove-it-works` principle skill.
- Does not fan out. One brief, one worker; a parallel fan-out that holds a worktree per worker is the harness's `taskq_*` shape, not this one.
- Does not isolate the tree. The worker runs in the working tree and the caller commits. A worktree per worker is the `taskq_*` shape.
- Does not triage or fix the worker's output. Whether a gap is fixed or filed is the caller's decision.

## Failure modes

| Failure | Response |
|---|---|
| The base revision does not resolve | the entrypoint refuses and names the value; correct `--base` |
| The pre-state cannot be captured | the entrypoint refuses and names the failure, because a dirty tree must have a recovery point before the worker runs |
| The worker destroys uncommitted work | a worker runs with `--auto` and can reset the tree; the `pre-state` stash commit recovers tracked changes only, and neither an untracked file nor a submodule's modified content is captured |
| The worker commits the caller's uncommitted work | a worker running `git add -A && git commit` folds the caller's edits into a worker commit; the `pre-state` still holds the work and the base-relative set still names the files, but the caller unwinds the worker commit before landing the unit |
| The worker logs nothing | the entrypoint exits non-zero and names the log path |
| The worker exits non-zero | the entrypoint exits non-zero and names the log path; read the log before re-running |
| The scratch directory is absent or unwritable | the entrypoint refuses; the provider `AGENTS.md` defines the path |
| The role table is missing or the role is absent | the entrypoint refuses and names the role; the change is `model-recommendations.md` |
| Every assignment for the role refuses | the run names each one with its class; the caller reads the entries beside the one that worked |
