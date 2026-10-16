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
- **A clean tree before dispatch.** The worker's change set is then the diff against that tree, and the caller can attribute every line.
- **Its own log and event stream.** The log is the only evidence the run leaves.
- **A report in the brief's shape**, returned to the caller.

## The form

A caller runs the script beside this skill:

```bash
bash "$AGENT_HOME/agent/skills/opencode-dispatch/dispatch.sh" <brief-file> <scratch-dir> [role]
```

The role defaults to `_IMPLEMENTER`. The script builds the command through the runner seam (`/opt/sandbox/lib/dispatch.sh`), so the flag mapping lives in one place, and runs it in the foreground of one call so the worker is never orphaned. It writes the log and the change set beneath the scratch directory and prints their paths. It refuses a missing or empty brief, an absent or unwritable scratch directory, and a dirty tree.

Env overrides: `OPENCODE_DISPATCH_MODEL`, `OPENCODE_DISPATCH_THINKING`, `OPENCODE_DISPATCH_TIMEOUT`.

The provider `AGENTS.md` defines the container's scratch directory. Pass that directory as the second argument, because the script keeps its run directory and its logs are the evidence.

## Steps

1. **Name the brief and the scratch directory.** Both are absolute paths. Done when the brief file is non-empty and the scratch directory exists and is writable; the script refuses either case.
2. **Commit or stash the working tree.** The script refuses a dirty tree, because a change set read against a tree the caller is still editing cannot be attributed to a revision. Done when `git status --porcelain` prints nothing.
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
| The working tree is dirty | the script refuses; commit or stash first |
| The worker logs nothing | the script exits non-zero and names the log path |
| The worker exits non-zero | the script exits non-zero and names the log path; read the log before re-running |
| The scratch directory is absent or unwritable | the script refuses; the provider `AGENTS.md` defines the path |
| The role table is missing or the role is absent | the seam refuses; the change is `$AGENT_HOME/model-recommendations.md` |
| The free tier refuses the request | the request did not come through the CLI; check `DISPATCH_OPENCODE_BIN` resolves to the real `opencode` |
