---
description: Open a new session. Finds the latest handover, runs recovery checks, creates the new handover, then gates on scope and acceptance criteria before any work begins. Use at the start of every session. Accepts an optional argument describing the session type and focus — this takes priority over the Next session section of the prior handover.
argument-hint: "[workflow|impl|design|spec|plan|story|study|chore] <focus description>"
---

> $@

## Orient

Read the most recent handover and the roadmap:

```
ls docs/devlog/handovers/ | sort | tail -1 | xargs -I{} read docs/devlog/handovers/{}
read docs/devlog/roadmap.md
```

No other files are needed at this stage.

---

## Recovery checks

Run before creating the handover.

**Trigger B check:** Verify the roadmap reflects the state the prior handover claims. If the prior handover's Next session notes Trigger B is pending (or the roadmap still shows a completed sub-milestone as active), the prior session's close sequence did not complete. Run Trigger B after creating this handover but before presenting the scope proposal (Step 2). Record the Trigger B execution in this handover's Completed table. Present the post-Trigger-B roadmap state as part of the scope proposal.

**Compaction note:** Compaction is no longer a Step 1 action. It happens at Steps 8–9 after Gate 3 release per `roadmap_policy.md`. No compaction checks are needed at session open — read the roadmap as-is.

Report the outcome of both checks before proceeding.

---

## Session directive

Read the prior handover's Next session section before evaluating the directive.

| Session type | Shortform |
|---|---|
| Design | `design` |
| Spec | `spec` |
| Implementation | `impl` |
| Story | `story` |
| Investigation | `study` |
| Planning | `plan` |
| Workflow | `workflow` |
| Housekeeping | `chore` |

If the directive slot is empty:
- Follow handover policy. Derive session type and objective from Next session.

If the directive slot is non-empty:
- Identify the session type from the directive using the table above. If the type cannot be determined, stop to ask the operator before continuing.
- **Step 1 — Compare session types.** Extract the session type implied by Next session. If the directive's type and Next session's type do not match, this session diverges — go to Diverges below.
- **Step 2 — Compare topics.** If types match, check whether the directive subject overlaps with Next session (shared keywords, named files, task references). If no recognisable overlap, ask the operator whether this session supersedes or adjusts prior work.
  - **Continues or adjusts prior work:** The directive takes priority over Next session's framing but does not change the session type or supersede the work in progress.
  - **Diverges from prior work:** This session supersedes the prior implementation thread. Record a Context handover line in Next session so the implementation thread can be resumed. See `docs/operations/handover_policy.md` Session Types section.

---

## Create the handover

Before creating the handover:

```
Range-read: docs/operations/iteration_policy.md §Step 1 — Open handover and §Step 1 Details.
```

Create the handover per those rules. Set Status to `Active`.

---

## Gate 1 — What is being asked? (Step 2)

Both gates must be confirmed before any work begins. They apply to every session regardless of type or size.

Derive scope from the argument, the prior handover, and the roadmap. Read any additional files needed to make the scope concrete — what files will change, what will not change, and why. Present:
- What is in scope this session and why
- What is explicitly deferred and why
- Any questions that must be resolved before work can begin

If scope cannot be confidently derived, ask the operator one question at a time. Do not proceed with a best guess. Do not produce any file, code, or structural output until the operator confirms scope and sends an explicit release.

Stop here and wait for the release before continuing.

## Gate 2 — What does done look like? (Step 5)

Once Gate 1 is released, state what a successful output looks like. Define criteria in a four-column table:

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|

Each criterion must describe an observable delta — the operator verifies by running a command, not by reading source alone. A criterion may be one line if it is specific. Every session that touches architecture must include: *"Architecture documents in scope describe the system as built."*

**Pre-verify every criterion the agent can verify now.** For each criterion whose "Verifiable by" is a runnable command, run the command and show the output. For "read first N lines" criteria, show `head -N`. Mark the Verified by column: `Agent ✅` (pass), `Agent ❌` (fail, expected in pre-state). Criteria the agent cannot verify are marked `Operator`.

**When writing ACs that require test verification**, use `make test` (which runs `scripts/run_tests.sh`, globbing `tests/test_*.sh`) as the standard command. Do not run `tests/knowledge/` tests for implementation ACs — they document external tool behaviour or diagnostic scripts, not system behaviour, and are excluded from `make test` by design (see `testing_policy.md`).

Present the full table with pre-verification results. Wait for the operator to confirm. Once confirmed, update the handover — replace `Not yet defined.` with the confirmed criteria. The handover is the canonical location for AC.

Implementation does not begin until both gates are confirmed.
