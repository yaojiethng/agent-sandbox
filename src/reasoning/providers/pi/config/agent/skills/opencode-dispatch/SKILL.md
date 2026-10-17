---
name: opencode-dispatch
description: Dispatch one general OpenCode worker over a brief, read-write, on the free OpenCode tier that pi cannot reach. Use when a subagent should do real work (edit files, run tests) and the work should run on the free model.
---

# opencode-dispatch

Dispatch one worker over one brief. A worker edits, runs tests, and returns work.

## What a worker is

The contract is what makes this a general subagent rather than a reviewer.

- **Read-write.** It edits the tree, runs tests, and returns the change set. The caller verifies the tree and lands the commit.
- **One brief, passed verbatim.** The brief is the only variable input.
- **A pinned model and thinking level.** The default is the free model `opencode/deepseek-v4.1-flash-free` at `high`. pi cannot reach that tier, which answers `403 FreeTierError`, so the run goes through the real OpenCode CLI and never spoofs a client.
- **A named base revision.** The report is attributable to the revision the caller names, so the caller can attribute every line. This is what lets a later pass over the same unit run in place.
- **Its own log and event stream.** The log is the only evidence the run leaves.
- **A report in the brief's shape**, returned to the caller.

## The form

A caller runs the script beside this skill:

```bash
bash "$AGENT_HOME/agent/skills/opencode-dispatch/dispatch.sh" <brief-file> <scratch-dir> [role]
```

The role defaults to `_IMPLEMENTER`. The script builds the command through the runner seam (`/opt/sandbox/lib/dispatch.sh`), so the flag mapping lives in one place, and runs it in the foreground of one call so the worker is never orphaned. It writes the log and the change set beneath the scratch directory and prints the run directory, the log path and the changed-file count. It refuses a missing or empty brief, an absent or unwritable scratch directory, and an unresolvable base revision.

Env overrides: `OPENCODE_DISPATCH_MODEL`, `OPENCODE_DISPATCH_THINKING`, `OPENCODE_DISPATCH_TIMEOUT`, `OPENCODE_DISPATCH_BASE`.

## The fallback

A role's line may list several models, separated by `;`. The script tries them in file order and starts the next one only when the attempt failed without adding a change of its own, so a second model never inherits a first model's edits. The caller's own uncommitted work is measured out of that comparison, so a dirty tree does not block the advance. Every failed candidate is reported at the end with its class, whether or not a later one succeeded. `OPENCODE_DISPATCH_MODEL` pins one model and disables the fallback.

The attempt is stopped as soon as its log carries a refusal, and the flags that put the CLI's errors on stderr are part of the command the seam builds. Measured on the pinned CLI: a refusal arrives in under a second, and the process then stays alive on an event subscription it never closes, so a caller that waits for exit waits forever. The CLI also discards the response's `retry-after`; the free tier is a per-IP daily quota that resets at UTC midnight, so the class is reported and the next candidate is tried rather than the request retried. `OPENCODE_DISPATCH_STALL` sets the silence backstop, in seconds, for an attempt that prints nothing at all.

The provider `AGENTS.md` defines the container's scratch directory. Pass that directory as the second argument, because the script keeps its run directory and its logs are the evidence.

## Steps

1. **Name the brief and the scratch directory.** Both are absolute paths. Done when the brief file is non-empty and the scratch directory exists and is writable; the script refuses either case.
2. **Name the base revision.** The default is `HEAD`. A later pass names the revision the unit started from, so the report covers the whole unit. A dirty tree is allowed, because that is what a later pass needs. Done when the base resolves to a commit.
3. **Run the script.** Done when the log exists and is non-empty. An empty log with a zero exit code means the worker did no work, and the script reports that as a failure.
4. **Verify the change set against the tree.** The report is a claim about the tree. Read the diff, run the check the brief named, and confirm the report landed. Done when every changed file is one the brief allowed and the check passes.
5. **Commit one unit.** The worker returns work; the caller lands it, one commit for one unit.

## Non-goals

- Does not write the report. The worker reports; the caller acts.
- Does not own the brief. The brief's content is the calling unit's, and this skill passes it unchanged.
- Does not verify the work. The caller checks the tree, per the `prove-it-works` principle skill.
- Does not fan out. One brief, one worker; a parallel fan-out that holds a worktree per worker is the harness's `taskq_*` shape, not this one.
- Does not isolate the tree. The worker runs in the working tree and the caller commits. A worktree per worker is the `taskq_*` shape.
- Does not triage or fix the worker's output. Whether a gap is fixed or filed is the caller's decision.

## Failure modes

| Failure | Response |
|---|---|
| The base revision does not resolve | the script refuses and names the value; correct `OPENCODE_DISPATCH_BASE` |
| The pre-state cannot be captured | the script refuses and names the failure, because a dirty tree must have a recovery point before the worker runs |
| The worker destroys uncommitted work | a worker runs with `--auto` and can reset the tree; the `pre-state` stash commit recovers tracked changes only, and neither an untracked file nor a submodule's modified content is captured |
| The worker commits the caller's uncommitted work | a worker running `git add -A && git commit` folds the caller's edits into a worker commit; the `pre-state` still holds the work and the base-relative set still names the files, but the caller unwinds the worker commit before landing the unit |
| The worker logs nothing | the script exits non-zero and names the log path |
| The worker exits non-zero | the script exits non-zero and names the log path; read the log before re-running |
| The scratch directory is absent or unwritable | the script refuses; the provider `AGENTS.md` defines the path |
| The role table is missing or the role is absent | the seam refuses; the change is `$AGENT_HOME/model-recommendations.md` |
| The free tier refuses the request | the attempt stops on the refusal and the role's next model runs; if every model refuses, the run names each one |
