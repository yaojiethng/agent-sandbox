---
name: pi-reviewer-dispatch
description: Dispatch the pinned reviewer pair over one brief, read-only, with the preconditions enforced. Use when a review needs more than one model's judgement on a document, a diff or a change set, and the run must be reproducible.
---

# pi-reviewer-dispatch

Dispatch two reviewers over one brief file. A reviewer takes a brief, holds judgement against it, and returns a report.

## What a reviewer is

The contract is what makes this a reviewer rather than any subagent.

- **Read-only.** No edits, no commits, no test suite. The caller applies what the report names.
- **One brief, passed verbatim.** The brief is the only variable input. A reviewer that is told something the brief does not say is a second brief.
- **A pinned model and thinking level.** The caller chooses both. The pair agrees or disagrees, and agreement is the signal.
- **A report in the brief's shape**, returned to the caller.
- **Its own session file and log.** The log is the only evidence the run leaves.
- **The effective model read back from the session file**, never assumed.

## The pi form

A caller on pi runs the pair through the script beside this skill:

```bash
bash "$AGENT_HOME/agent/skills/pi-reviewer-dispatch/dispatch.sh" <brief-file> <scratch-dir>
```

The script holds the pair, which is `openrouter` with `z-ai/glm-5.3-flash` and `opencode-go` with `step-5-preview-free`, both at thinking level `high`. It runs them in the foreground of one call, so neither is orphaned, and gives each its own timeout and log.

Two rules the script enforces and a caller must not work around. Pass the model id in full, provider prefix included, because `--model` matches a substring over the provider's list and takes the last match, so a short id can run a different model silently. And read the effective model from the session file, because only a total mismatch produces a warning.

A caller on another harness follows the contract above and supplies its own invocation.

## The scratch directory

The provider `AGENTS.md` defines the container's scratch directory. This skill follows that definition and carries no value of its own, so the path has one home.

Pass that directory as the second argument. The script creates the run directory beneath it with `mktemp -d`, and keeps it, printing the path, because the logs are the reviewer's only evidence.

## Steps

1. **Name the brief and the scratch directory.** Both are absolute paths. Done when the brief file is non-empty and the scratch directory exists and is writable; the script refuses either case.
2. **Commit or stash the working tree.** The script refuses a dirty tree, because a reviewer reading content the caller is still editing produces findings that cannot be attributed to a revision. Done when `git status --porcelain` prints nothing.
3. **Run the script.** Done when two log files exist under the printed run directory and neither is empty. An empty log with a zero exit code means the reviewer did no work, and the script reports that as a failure.
4. **Read both reports and verify their claims.** A report is evidence, not a conclusion. Check each finding against the tree before acting, and say which claims you refuted. Agreement between the pair is high-signal; disagreement is where to look hardest. Done when every finding accepted is checked, and every one refuted is named as refuted.

## Non-goals

- Does not write a report. Each reviewer writes its own, and the caller acts on it.
- Does not own the brief. The brief's content is the calling unit's, and this skill passes it unchanged.
- Does not cover a worker fan-out. A dispatch that writes, holds a worktree and returns work is the harness's `taskq_*` shape, not this one.
- Does not triage findings. Whether a finding is fixed or filed is the caller's decision.

## Failure modes

| Failure | Response |
|---|---|
| The working tree is dirty | the script refuses; commit or stash first |
| A reviewer logs nothing | the script exits non-zero and names the reviewer; re-run that reviewer |
| A reviewer bound a model other than the one requested | the script exits non-zero and prints both ids; the run's result does not stand |
| The scratch directory is absent or unwritable | the script refuses; the provider `AGENTS.md` defines the path |
| One reviewer is unavailable | the pair is the mechanism, so report the missing half rather than treating one report as the whole |
