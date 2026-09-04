# Test Quality Campaign - Run (Main-Agent Template)

## Purpose

Spawn a fresh subagent to run the campaign and produce a proposal, then work that proposal through a normal iteration.

## Step 1 - Spawn the reviewer

Ensure your working tree is clean, then spawn a fresh subagent with the campaign prompt:

```bash
pi -p "$(cat workflow/coding-agent/test-quality-campaign.md)"
```

The subagent runs the whole campaign on its own: it audits, fixes tests, leaves the changes uncommitted, and writes its report to the output mount. It does not commit. It shares this workspace, so its uncommitted changes and output-mount writes are visible to you.

## Step 2 - Collect the proposal

From the subagent's returned summary block, record:

- `SESSION_DIR` - the report location in the output mount.
- `changes` - the files it changed (uncommitted).
- `suite` - the final pass/fail/skip counts.

Then read `$SESSION_DIR/FINAL_REVIEW.md`.

## Step 3 - Work the proposal through the iteration

The subagent's uncommitted changes and its report are a proposal. Operate the normal iteration workflow with the operator: review the proposal, and accept, amend, cherry-pick, or reject as the iteration requires. Commit at iteration close per `docs/operations/git_policy.md`.

The report's sections feed the iteration:

- `Remaining Gaps & Recommended Next Steps` become roadmap tasks.
- `Bash Conventions & Testing Policy Gaps` become policy proposals, one section at a time, per `docs/operations/documentation_policy.md`.
- `Architectural & Functional Seams` become ADR or discussion candidates.
- `Agent Feedback & Gotchas` become entries in `devlog/AGENT_FEEDBACK.md`.

## Invariants

- The subagent never commits. The main agent commits at iteration close, as the normal workflow requires.
- The report stays in the output mount and is not committed.
- No fixed accept/reject procedure is imposed beyond the regular iteration workflow.
