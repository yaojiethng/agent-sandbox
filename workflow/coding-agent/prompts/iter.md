---
description: Open a new iteration. Finds the latest handover, runs the roadmap maintenance check, creates the new handover, then gates on scope and acceptance criteria before any work begins. Use at the start of every iteration. Accepts an optional argument describing the type and focus  --  this takes priority over the What's Next section of the prior handover.
argument-hint: "[workflow|impl|design|spec|plan|story|study|chore] <focus description>"
---

> $@

## Orient

Read the most recent handover and the roadmap:

```text
ls devlog/handovers/ | sort | tail -1 | xargs -I{} read devlog/handovers/{}
read devlog/roadmap.md
```

No other files are needed at this stage.

---

## Roadmap maintenance check

Run before creating the handover.

Verify the roadmap reflects the state the prior handover claims. If the roadmap still shows a completed sub-milestone as active, run roadmap maintenance after creating this handover but before presenting the scope proposal (Step 2). Record the maintenance execution in this handover's Completed table. Present the maintained roadmap state as part of the scope proposal.

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

```text
Range-read: docs/operations/iteration_policy.md [Step 1  --  Open handover and Step 1 Details](iteration_policy.md#step-1-open-handover).
```

Create the handover per those rules. Set Status to `Active`.

---

## Gate 1  --  Confirm scope (Step 2)

Derive scope from the argument, the prior handover, and the roadmap. Read any additional files needed to make the scope concrete  --  what files will change, what will not change, and why.

**One iteration, one unit.** One iteration is one roadmap task, scoped as one vertical slice, landed as one commit with one handover. Propose no split by default; a slice that cannot deliver the outcome in one unit names the handling method (split or consolidate).

**Purpose reconciliation.** Before presenting the scope, check the iteration's expressed purpose against the current tree. A purpose already silently resolved by landed work becomes recording or retiring that resolution, not re-implementing it.

Present:

- The iteration type with a one-line justification (the operator confirms the type alongside scope)
- What is in scope this iteration and why
- What is explicitly deferred and why
- Any questions that must be resolved before work can begin

Everything you present is a proposal: the operator reviews, approves, and commits (the project [`AGENTS.md`](../../AGENTS.md) Output Format owns this rule).

If scope cannot be confidently derived, ask the operator one question at a time. Do not guess. Do not produce any file, code, or structural output until the operator confirms scope and sends an explicit release.

Stop here and wait for an explicit release before continuing.

---

## Step 3  --  Design

After Gate 1 is released, skip design only if the roadmap entry already carries resolved decisions with recorded rationale (a task list alone does not satisfy the skip). Otherwise open a design document in `devlog/discussions/` per [`discussion_policy.md`](docs/operations/discussion_policy.md). Gather requirements and resolve any deferred story that depends on this iteration. Record decisions in the roadmap and handover per [`roadmap_policy.md`](docs/operations/roadmap_policy.md). If the design ends in an implementation decision, create an ADR before releasing (see [`adr_policy.md`](docs/operations/adr_policy.md)).

Exit condition: all design questions resolved and recorded, ADR created if applicable, and the operator confirmed.

---

## Step 4  --  Information gathering pass

After design is confirmed, read in order: the roadmap task, the design decisions, the conceptual documents, and the architecture documents. Accumulate lapses across all four; group related lapses by document boundary; surface them together before Gate 2 per [`documentation_policy.md`](docs/operations/documentation_policy.md). (Assessed step: run unless not applicable to the iteration type.)

## Step 5  --  Acceptance criteria

Once Gate 1 is released, define the acceptance criteria in a four-column table:

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|

Universal preconditions (`make test passes clean`, `bash -n passes`) are preconditions, not acceptance criteria. Omit them from the AC table; verify them as prerequisites before pre-close. Each criterion must describe an observable delta  --  the operator verifies by running a command, not by reading source alone. A criterion may be one line if it is specific. Every iteration that touches architecture must include: *"Architecture documents in scope describe the system as built."*

**Pre-verify every criterion the agent can verify now.** For each criterion whose "Verifiable by" is a runnable command, run the command and show the output. For "read first N lines" criteria, show `head -N`. Mark the Verified by column: `Agent [x]` (pass), `Agent [ ]` (fail, expected in pre-state). Criteria the agent cannot verify are marked `Operator`.

**When writing ACs that require test verification**, use `make test` (which runs `scripts/run_tests.sh`, globbing `tests/test_*.sh`) as the standard command. Do not run `tests/knowledge/` tests for implementation ACs  --  they document external tool behaviour or diagnostic scripts, not system behaviour, and are excluded from `make test` by design (see `testing_policy.md`).

Present the full table with pre-verification results. Wait for the operator to confirm the acceptance criteria. Once confirmed, update the handover  --  replace `Not yet defined.` with the confirmed criteria. The handover is the canonical location for AC.

---

## Gate 2  --  Stop before implementation

Before releasing, present the acceptance criteria table to the operator. Every criterion must be visible, not implied. Re-read each criterion and verify it is satisfiable given the confirmed scope. A criterion that would fail on a correct implementation is a specification bug  --  resolve it now, not at pre-close. Do not begin implementation until the operator releases this gate.

Exit condition: Operator confirmed the criteria are satisfiable. Explicit release received.

---

## Step 6  --  Implementation and the write-back discipline

The communication rules below operationalise the canonical rules in [`iteration_policy.md`](docs/operations/iteration_policy.md) During the iteration: this prompt is the runbook that walks through them; the policy is their owner.

Produce changes against the confirmed scope. Write tests alongside per [`testing_policy.md`](docs/development/testing_policy.md). On design divergence, correct the architecture document before continuing. Record adjacent issues in the handover's Findings; defer them by default.

The handover write-back fires at three moments:

- **On task completion:** mark the completed task in the handover's Scope and Completed; check whether findings from it belong in Findings before starting the next task. Do not accumulate updates  --  write immediately.
- **On discovery:** a bug, contradiction, design gap, blocker, or new file in scope goes to Findings immediately. If it changes the approach, surface it in chat before proceeding.
- **On steering received:** operator instruction that changes the scope of a current or future iteration goes to Findings before resuming. If it affects a future iteration, also write it to Deferred items or What's Next.

Record decisions in the Decisions table as they are made, with the document where each was recorded. If a decision is only in chat, it does not exist for the next iteration. Record new acceptance criteria as they are defined. Update Deferred items immediately when an item leaves scope.

**Record write-back gate.** When announcing a record write (a finding row, a decision, a task, a roadmap row), verify it landed in the same turn. Grep the row key or content you claim to have written. The write is not done until the grep finds it.

**Prompt-scope discipline.** A campaign or review prompt must not contradict its own success criteria. Name the in-scope targets explicitly. If a criterion can only be met by a change that looks out of scope, make the criterion flag-only or name the target. When the agent detects such a contradiction at runtime, stop and ask the operator for a ruling; do not resolve it silently.

---

## Step 7  --  Pre-close verification

Step 7 is a mandatory gate before iteration end. Present a pre-close summary and wait for an explicit operator release before advancing to Steps 8-9. The summary has four sections:

1. **Acceptance criteria** -- table `| # | Criterion | Verifiable by | Status |`; each criterion marked accepted or pushed. Run verifiable checks and show output. Do not reuse the Step 5 format; this table answers "did it pass?", not "who can verify?".
2. **Roadmap write-back** -- per task touched this iteration, the exact row change, and completed rows the change supersedes or invalidates. Per [`roadmap_policy.md`](docs/operations/roadmap_policy.md). When no task was touched, state `none worked this iteration`.
3. **Propagation replay** -- required when the iteration applied a naming rule, structural rule, or interface change across more than two files, or produced an explicit file table, or used "all", "every", "throughout", or "wherever X appears". A row-by-row comparison of every file planned to receive the change:

| File | Change planned | Status |
|---|---|---|

Every row must carry a status. A deferred or not-started row must appear in the handover's Deferred items before the gate closes.

4. **Commit message** -- present the delivery commit's message with the summary: subject, body, footer. The operator reads the body against the body budget in [`git_policy.md`](docs/operations/git_policy.md).

The operator releases this gate with an explicit forward signal. A message that reviews output without a clear forward signal does not satisfy the exit condition.

---

## Gate 3  --  Stop before close

The acceptance criteria status table and the commit message must be visible. Every criterion shown, every status populated, the commit body within the git policy's body budget. Do not close until the operator releases. Exit condition: explicit release received.

---

## Steps 8-9  --  Close and seed

After Gate 3 is released, these steps are mechanical. Close produces **one commit**: the work, the handover marked `Closed`, the roadmap write-back, and the `Status: Closed` edit all fold into it. The commit message matches the iteration type per [`git_policy.md`](docs/operations/git_policy.md).

Order:

1. Apply the approved roadmap write-back per [`roadmap_policy.md`](docs/operations/roadmap_policy.md). Run roadmap maintenance. Keep the Completed table accurate, one row per file. Mark each acceptance criterion accepted or pushed.
2. **Scope reconciliation** -- before writing anything else, compare the confirmed Step 2 scope against the Completed table. Every item in scope but not in Completed must be in Deferred items. No unaccounted items.
3. **Carry-forward resolution gate** -- compare every Carried forward item against the Completed table and Deferred items. Each must be completed, re-deferred, or escalated to a named roadmap entry. A carried-forward item in none of the three is dropped -- find it and triage it.
4. **Findings review/publish** -- route each Findings entry to a destination: Decisions table, Deferred items, What's Next via Carried forward, a named roadmap entry, or the feedback record [`devlog/AGENT_FEEDBACK.md`](../../../devlog/AGENT_FEEDBACK.md) tagged `[A]` (agent-raised) or `[O]` (operator-raised). Attribution is operator-owned; the agent proposes a class. The Findings section must be empty or contain only entries with a triage destination before close.
5. **Seed What's Next** -- identify the next iteration's scope from the roadmap task list and Deferred items (deferred items take priority). Note whether roadmap maintenance is run or pending. List blocking design questions. Populate Conclusions and What's Next for the next agent; a superseded implementation handover gets a Context line.

---

## Sub-milestone close

A sub-milestone follows the sequence `active -> pre-close -> close`. In pre-close, run the sub-milestone cleanup: compaction, changelog drafting, escalation clearance, and the review gate. At close, no new decisions are made.

**Pre-close review gate.** Surface to the operator: open `devlog/AGENT_FEEDBACK.md` entries (including operator-raised `[O]`) and any pending sweeps; and entries under probation for a `dismiss` / `maintain` / `escalate` decision. For probation entries, the operator decides: **dismiss** (the fix held, delete it), **maintain** (fix not stress-tested, extend), **escalate** (problem resurfaced, re-scope). Escalation of far-reaching correctness work defers the close; low-urgency escalation files as a task at the top of the next sub-milestone.

---

## File Tracking

There is no document registry; the docs tree is the authoritative file list. The iteration-scoped list is the active handover's Hot files section, governed by [`handover_policy.md`](docs/operations/handover_policy.md).

---

## Policy

The invariants these steps must not break are in [`iteration_policy.md`](docs/operations/iteration_policy.md) and the separation is recorded in the ADR [`coding_agent_loop_workflow.md`](docs/adr/coding_agent_loop_workflow.md).
