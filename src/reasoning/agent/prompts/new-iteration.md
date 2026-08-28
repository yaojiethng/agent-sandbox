---
description: Open a new iteration. Finds the latest handover, runs recovery checks, creates the new handover, then gates on scope and acceptance criteria before any work begins. Use at the start of every iteration. Accepts an optional argument describing the type and focus  --  this takes priority over the What's Next section of the prior handover.
argument-hint: "[workflow|impl|design|spec|plan|story|study|chore] <focus description>"
---

> $@

## Orient

Read the most recent handover and the roadmap:

```
ls devlog/handovers/ | sort | tail -1 | xargs -I{} read devlog/handovers/{}
read devlog/roadmap.md
```

No other files are needed at this stage.

---

## Recovery checks

Run before creating the handover.

**Post-close bookkeeping check:** Verify the roadmap reflects the state the prior handover claims. If the roadmap still shows a completed sub-milestone as active without post-close bookkeeping having been applied, the prior iteration's close sequence did not complete. Run post-close bookkeeping after creating this handover but before presenting the scope proposal (Step 2). Record the bookkeeping execution in this handover's Completed table. Present the post-bookkeeping roadmap state as part of the scope proposal.

---

## Directive

Read the prior handover's What's Next section before evaluating the directive.

| Type | Shortform |
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
- Follow handover policy. Derive type and objective from What's Next.

If the directive slot is non-empty:
- Identify the type from the directive using the table above. If the type cannot be determined, stop to ask the operator before continuing.
- **Step 1  --  Compare types.** Extract the type implied by What's Next. If the directive's type and What's Next's type do not match, this iteration diverges  --  go to Diverges below.
- **Step 2  --  Compare topics.** If types match, check whether the directive subject overlaps with What's Next (shared keywords, named files, task references). If no recognisable overlap, ask the operator whether this iteration supersedes or adjusts prior work.
  - **Continues or adjusts prior work:** The directive takes priority over What's Next's framing but does not change the type or supersede the work in progress.
  - **Diverges from prior work:** This iteration supersedes the prior implementation thread. Record a Context handover line in What's Next so the implementation thread can be resumed. See `docs/operations/handover_policy.md` Types section.

---

## Create the handover

Before creating the handover:

```
Range-read: docs/operations/iteration_policy.md [Step 1  --  Open handover and Step 1 Details](iteration_policy.md#step-1-open-handover).
```

Create the handover per those rules. Set Status to `Active`.

---

## Gate 1  --  Confirm scope (Step 2)

Derive scope from the argument, the prior handover, and the roadmap. Read any additional files needed to make the scope concrete  --  what files will change, what will not change, and why. Present:
- What is in scope this iteration and why
- What is explicitly deferred and why
- Any questions that must be resolved before work can begin

If scope cannot be confidently derived, ask the operator one question at a time. Do not guess. Do not produce any file, code, or structural output until the operator confirms scope and sends an explicit release.

Stop here and wait for an explicit release before continuing.

## Gate 2  --  Acceptance criteria (Step 5)

Once Gate 1 is released, define the acceptance criteria in a four-column table:

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|

Each criterion must describe an observable delta  --  the operator verifies by running a command, not by reading source alone. A criterion may be one line if it is specific. Every iteration that touches architecture must include: *"Architecture documents in scope describe the system as built."*

**Pre-verify every criterion the agent can verify now.** For each criterion whose "Verifiable by" is a runnable command, run the command and show the output. For "read first N lines" criteria, show `head -N`. Mark the Verified by column: `Agent [x]` (pass), `Agent [ ]` (fail, expected in pre-state). Criteria the agent cannot verify are marked `Operator`.

**When writing ACs that require test verification**, use `make test` (which runs `scripts/run_tests.sh`, globbing `tests/test_*.sh`) as the standard command. Do not run `tests/knowledge/` tests for implementation ACs  --  they document external tool behaviour or diagnostic scripts, not system behaviour, and are excluded from `make test` by design (see `testing_policy.md`).

Present the full table with pre-verification results. Wait for the operator to confirm the acceptance criteria. Once confirmed, update the handover  --  replace `Not yet defined.` with the confirmed criteria. The handover is the canonical location for AC.
