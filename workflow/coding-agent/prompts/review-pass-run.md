# Autonomous Review Pass - Run (Main-Agent Template)

## Purpose

Spawn fresh subagent reviewers against the iteration's changes, work their findings through WIP commits, and converge on an approved state before closing the iteration. Generalized from the first full pass (iteration `20260912-05`: thermo-nuclear code review + test-quality campaign; 8 review rounds to APPROVE, campaign proposal accepted and folded).

The main agent orchestrates; subagents review. Subagents are fresh contexts (`pi -p`) -- they see only what the prompt states and what the committed diff contains. They never commit; the main agent commits.

## Preconditions

1. **Working tree committed as WIP.** Subagents review an exact diff range (`git diff <base>..<head>`), not a moving tree. Commit the session's work first with a free-form WIP message; the delivery commit at close replaces it (git_policy: squash).
2. **Review concerns chosen.** Typically two: a structural code-quality review (e.g. the thermo-nuclear skill) and an audit campaign (e.g. the test-quality campaign). The operator may substitute or add concerns; each concern is one subagent.
3. **Operator release of scope** per iteration_policy (this template runs mid-iteration, after implementation, before close).

## Spawning a review subagent

```bash
pi -p "$(cat <review-prompt-or-skill-file>)"
```

**Timeout and resume.** Run each review with a generous timeout; the default is 20 minutes (`timeout 1200 pi -p ...`). A longer review or campaign may need more; do not start with less than the default. If a run times out, do not repeat the work: pi auto-saves the interrupted session. Resume it with `pi --session <saved-session-path-or-id>` (browse with `pi -r`) and collect its verdict. A fresh run is only needed when the resumed session cannot continue.

Every review prompt carries, explicitly:

- **Scope**: the exact diff range and the list of touched files. State that uncommitted working-tree files (e.g. a campaign proposal sitting in the tree) are out of scope and must not be modified.
- **Read-only constraint**: report inline; no edits, no writes, no commits.
- **Context block**: the design decisions the diff implements, so the reviewer does not re-litigate settled operator decisions. Link the handover.
- **Prior-round blockers** (rounds 2+): the list of previous blockers with a claim of where each was fixed, so the reviewer verifies rather than re-discovers.
- **Verdict contract**: end with `VERDICT: APPROVE` or `VERDICT: BLOCK` plus the blocker list. The verdict is the loop's control signal -- do not accept prose-only conclusions.

If the subagent's skill file does not already contain the review standards, inline them (the thermo-nuclear skill's full text is inlined via `$(cat ...)` in 20260912-05; audit skills live in `workflow/coding-agent/audits/`).

## Standing review instruction (seed every round)

Two finding classes proved high-yield and are not reliably produced by reviewer skills unprompted. Seed them in every review prompt:

1. **Doc-contract drift**: sweep for documents (e2e checklists, architecture docs, usage blocks, handover text) that pin the output strings, commands, exit semantics, or count/shape contracts the diff changed. An internally consistent diff can still break an external document that asserts the old behavior; nothing mechanical catches this.
2. **Contract-without-mechanism**: for each invariant the diff claims (teardown symmetry, skip semantics, fail-closed paths), ask which failure paths actually reach the mechanism -- traps, error returns, swallowed exit codes in pipelines (`cmd | grep || true` eats rc). This class appeared twice in one iteration.

## The review loop

1. Run the review round (fresh subagent each round -- never reuse a context; the reviewer must see the code, not the previous review's reasoning).
2. Triage the verdict:
   - **APPROVE**: stop the loop. Record non-blocking observations in the handover findings for the operator to triage.
   - **BLOCK**: for each blocker, diagnose, fix, and commit as a WIP commit (one commit per fix round). Then go to 1 with the updated blocker history.
3. **Round cap**: if not converged after ~6 rounds, stop and report to the operator with the open blockers -- either the change has a structural problem the fixes keep masking, or the review scope needs narrowing. Do not grind silently.

Calibration from 20260912-05: blockers converged quickly (rounds 1-3 were mechanism bugs; rounds 4-7 were almost entirely doc-contract drift and vocabulary/count reconciliation). Late-round blockers are still worth fixing -- they are one-line, zero-risk, and the consistency bar is the point of the review -- but the main agent should self-check the cheap classes (docs pinning changed strings, counts in the handover, header/usage text lagging behavior) BEFORE spawning each round; self-checking removes most of the late-round churn.

## Campaign / proposal subagents

An audit campaign (e.g. `test-quality-campaign.md`) differs from a review: it FIXES and leaves its changes **uncommitted** as a proposal, with a report (location, changed files, suite counts) in its summary block.

- Verify the proposal: suite green with it applied, the changes attributable, no product-source edits left behind (campaigns may mutate and restore source during mutation testing -- confirm restoration with `git diff`).
- The operator decides: **accept** (fold into this iteration), **defer** (own iteration), or **reject**. Accepting means the proposal's changes ride the delivery commit and its report's recommendations become handover findings / deferred items.
- Campaign rule proposals that touch policy documents are NEVER folded silently -- they are listed as deferred policy proposals for a future iteration (documentation_policy: one section at a time).

## Close

Per iteration_policy Step 7 and git_policy:

1. Apply the roadmap write-back (including rows for accepted proposals).
2. Mark the handover Closed with AC statuses, findings (including the review round history and outcome), and deferred items.
3. `git add -A && git commit` -- the single typed delivery commit. WIP commits squash into it; the campaign proposal (if accepted) is part of it.
4. Report the commit hash; surface any operator-owned follow-ups (e.g. feedback entries the campaign closed, version pins pending image rebuild).

## Invariants

- Subagents never commit. The main agent commits, always.
- A fresh subagent per round; no session reuse.
- No blocker is closed by argument -- only by a fix in a commit the next round can verify.
- The verdict contract is mandatory; a round without an explicit verdict did not happen.
- Records state, not session history: the handover names the mechanism and outcome, not the round numbers' drama.
