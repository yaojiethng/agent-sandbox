---
description: Open a new iteration. Finds the latest handover, runs the roadmap maintenance check, creates the new handover, then gates on scope and acceptance criteria before any work begins. Use at the start of every iteration. Accepts an optional argument describing the type and focus  --  this takes priority over the prior handover's orientation.
argument-hint: "[workflow|impl|design|spec|plan|story|study|chore] <focus description>"
---

> $@

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `task-list`, `work-log`, `decision-records`, `docs`, `git-discipline`, `testing`

## Orient

Read the most recent handover and the roadmap:

```text
ls devlog/handovers/ | sort | tail -1 | xargs -I{} read devlog/handovers/{}
read devlog/roadmap.md
```

No other files are needed at this stage.

## Roadmap maintenance check

Run before creating the handover.

Verify the roadmap reflects the state the prior handover claims. If the roadmap still shows a completed sub-milestone as active, run the [`roadmap-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/roadmap-maintenance/SKILL.md) skill over `devlog/roadmap.md` and apply its report after creating this handover but before presenting the scope proposal at the scope gate. The skill writes nothing, so the row edits are this prompt's. Record the maintenance execution in this handover's Completed table. Present the maintained roadmap state as part of the scope proposal.

## Directive

Read the prior handover's Objective and Findings for context before evaluating the directive. The prior handover carries no continuation scope: the roadmap is the sole task list, and a missing directive is an unmet scope-gate precondition, not something the agent derives.

The types are the type vocabulary in the project's `work-log` convention, `.agents/skills/work-log/SKILL.md`; this table is the directive word a caller may write.

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

- Stop and ask the operator for the directive. A scope gate confirms a scope the operator named; an empty directive is that precondition unmet, and the agent does not derive one. Exception: a reply to a wrapup report that names a next task -- "ok", or the operator picking up the report's suggestion -- is the directive, not an empty scope.

If the directive slot is non-empty:

- Identify the type from the directive using the table above. If the type cannot be determined, stop to ask the operator before continuing.

## Create the handover

Before creating the handover, read the iteration invariants in `iteration_policy.md`: `## Iteration Invariants`, and the record-state and close invariants under it. Create the handover per those rules. Set Status to `Active`.

Write the record from the project's template, `.agents/skills/work-log/assets/handover.md`, and set `status` to `Active`. The filename, the vocabulary and the format window are the project's `work-log` convention, in `.agents/skills/work-log/SKILL.md`. Do not write the fields as bold header lines.

## Step 2  --  Define the task scope

Derive scope from the argument, the prior handover, and the roadmap. Read any additional files needed to make the scope concrete  --  what files will change, what will not change, and why.

The scope proposal carries a file table, `File | Why in scope`, one markdown link per file. It is the table's only owner: the record carries no file list. When design names a file the table does not carry, add it before presenting the gate.

If scope cannot be confidently derived, ask the operator one question at a time to define the task scope. Do not guess. Only when scope is clear do you continue to the design step below.

**A row that is not ready is a route, not a question.** When scope cannot be derived because the row is not ready to be built, name which of the two reasons holds and hand off rather than working around it. An unresolved design decision is [`plan.md`](plan.md)'s, which owns design and alignment. A row that is not yet cut into work units is [`scope.md`](scope.md)'s, which owns the work-unit table and emits it in the brief.

**One iteration, one unit.** The unit rule is the policy's: one roadmap task, one vertical slice, one commit, one handover. Apply it here; do not restate it.

**Purpose reconciliation.** Before presenting the scope, check the iteration's expressed purpose against the current tree. A purpose already silently resolved by landed work becomes recording or retiring that resolution, not re-implementing it.

This step defines scope but does not stop for a release. The scope gate below confirms it together with the acceptance criteria.

## Step 3  --  Design

Skip design only if the roadmap entry already carries resolved decisions with recorded rationale (a task list alone does not satisfy the skip). Otherwise open a design document in `devlog/discussions/` per the project's `work-log` convention (`.agents/skills/work-log/SKILL.md`). Gather requirements and resolve any deferred story that depends on this iteration. Record decisions in the roadmap and handover per the project's `task-list` convention. If the design ends in an implementation decision, create an ADR before releasing, per the project's `decision-records` convention. Design runs before the scope gate and does not itself stop for a release; the operator confirms design as part of the scope gate.

**Design precedence.** This step designs what one iteration builds. A design that outgrows a single iteration is [`plan.md`](plan.md)'s, which runs at milestone or task grain.

Exit condition: all design questions resolved and recorded, and the ADR created if applicable. Confirmation happens at the scope gate, not here.

## Step 4  --  Information gathering pass

After design is confirmed, read in order: the roadmap task, the design decisions, the conceptual documents, and the architecture documents. Accumulate lapses across all four; group related lapses by document boundary; surface them together at the scope gate, per the `doc-maintenance` review pass, `workflow/coding-agent/skills/doc-maintenance/SKILL.md`. (Assessed step: run unless not applicable to the iteration type.)

## Scope gate

This is the collapsed gate the operator-involved workflows share. It confirms scope **and** acceptance criteria together, and clears on a single operator approval. Step 2 defined the scope; this gate presents it and the AC table as one release.

Before presenting the scope, run the promotion check: read the Milestone Summary table, identify the milestone this iteration targets (from roadmap frontmatter or iteration context), and if the target's status implies less progress than this iteration intends (e.g. `Not started` when starting an iteration), update it to `In progress` and record the change in the handover's Completed table. The promotion rule lives in the `roadmap-maintenance` skill's promotion invariant.

Present the handover's `Decisions pending` table with the scope. Design runs before this gate, so a design question the agent could not settle is already recorded; presenting it here is what lets the operator answer it in the same reply that releases the scope. A `Decisions pending` table holding only the canonical marker needs no presentation -- say so in one line rather than showing an empty table.

### Step 5 -- Acceptance criteria (at the scope gate)

Define the acceptance criteria in the table the project's `work-log` convention states, one row per criterion:

| Criterion | Verification | Result |
|---|---|---|

The authoring standards are [`iteration_policy.md`](/opt/sandbox/docs/policies/iteration_policy.md) `### Acceptance-criteria invariants`: what qualifies as a criterion, the delta and traceability rules, the three-way `Operator` / `Agent [x]` / `Agent [ ]` marking, and the `Not yet defined.` gate. Apply them here; this step adds only what the scope-gate presentation needs beyond them. Every iteration that touches architecture includes *"Architecture documents in scope describe the system as built."*, and a criterion may be one line when it is specific.

When the handover's `## Decisions` table is not empty, or the iteration created an ADR entry, the acceptance-criteria table carries this criterion: *every decision this iteration recorded is realized in the files.* `wrapup` B1 verifies it with the others at the close.

**Pre-verify every criterion the agent can verify now.** For each criterion whose `Verification` is a runnable command, run the command and show the output. For "read first N lines" criteria, show `head -N`.

**When writing ACs that require test verification**, use `make test` (which runs `scripts/run_tests.sh`, globbing `tests/test_*.sh`) as the standard command. Do not run `tests/knowledge/` tests for implementation ACs  --  they document external tool behaviour or diagnostic scripts, not system behaviour, and are excluded from `make test` by design (see the `testing` skill's test homes).

Present together:

- **Restate the intent first.** State the operator's goal and the problem the work solves, so the gate confirms understood intent rather than echoing the request back. Present the scope against that intent.
- The iteration type with a one-line justification (the operator confirms the type alongside scope)
- What is in scope this iteration and why
- The scope proposal's file table, `File | Why in scope`, one markdown link per file
- The full acceptance criteria table with pre-verification results
- What is explicitly deferred and why
- Any questions that must be resolved before work can begin

Re-read each criterion and verify it is satisfiable given the confirmed scope. A criterion that would fail on a correct implementation is a specification bug  --  resolve it now, not at pre-close.

Everything you present is a proposal: the operator reviews, approves, and commits (the project `AGENTS.md` Output Format owns this rule). Do not produce any file, code, or structural output until the operator releases this gate.

Stop here and wait for an explicit release before continuing. On release, update the handover  --  replace `Not yet defined.` with the confirmed acceptance criteria. The handover is the canonical location for AC.

## Step 6  --  Implementation and the write-back discipline

Produce changes against the confirmed scope. Write tests alongside per the `testing` skill. On design divergence, correct the architecture document before continuing. Record adjacent issues in the handover's Findings; defer them by default.

The record-state invariants live in [`iteration_policy.md`](/opt/sandbox/docs/policies/iteration_policy.md); this step applies them to the handover. The policy owns the rules; this step is their operational face. Satisfy each record-state invariant as you produce deliverables: record decisions where they are made, write findings as they arise, and verify every record write landed in the same turn (grep the row key or content you claim to have written -- the write is not done until the grep finds it).

The handover write-back fires at three moments in the runbook's operation:

- **On task completion:** mark the completed task in the handover's Scope and Completed; check whether findings from it belong in Findings before starting the next task.
- **On discovery:** a bug, contradiction, design gap, obstacle, or new file in scope goes to Findings immediately; if it changes the approach, surface it in chat before proceeding.
- **On steering received:** operator instruction that changes the scope of a current or future iteration goes to Findings before resuming; if it creates a future task, it is written back to the roadmap as an open row.

**Prompt-scope discipline.** A campaign or review prompt must not contradict its own success criteria. Name the in-scope targets explicitly. If a criterion can only be met by a change that looks out of scope, make the criterion flag-only or name the target. When the agent detects such a contradiction at runtime, stop and ask the operator for a ruling; do not resolve it silently.

## Step 7  --  Pre-close verification

Step 7 is the pre-close verification before the release gate. Present a pre-close summary and wait for the operator to release it; the release feeds the release gate, so this is not a separate named gate. The summary has six sections:

1. **Acceptance criteria** -- the table the project's `work-log` convention states, with `Result` carrying the marking; each criterion marked accepted or pushed. Run verifiable checks and show output.
2. **Roadmap write-back** -- per task touched, the exact row change and the completed rows it supersedes or invalidates, per the project's `task-list` convention. When a task's sub-rows are all resolved, present the compacted outcome summary here, not only the marker flip, in the form the `/milestone-close` compaction procedure states. When no task was touched, state `none worked this iteration`.
3. **Propagation replay** -- required when the iteration applied a naming rule, structural rule, or interface change across more than two files, or produced an explicit file table, or used "all", "every", "throughout", or "wherever X appears". A row-by-row comparison of every file planned to receive the change:

| File | Change planned | Status |
|---|---|---|

Every row must carry a status. A deferred or not-started row must be written back to the roadmap as an open row before the gate closes.

4. **Commit message** -- present the delivery commit's message with the summary: subject, body, footer. The operator reads the body against the body budget in the `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`.
5. **Decisions pending** -- replay the handover's `Decisions pending` table. Every entry must be resolved, cited, or pushed to the roadmap as an open row.

6. **Findings and record checks.** Run the `roadmap-maintenance` skill over `devlog/roadmap.md` and the `handover-maintenance` skill over this handover. List every finding with its `Triaged to:` destination, and both reports with what the iteration changed after reading them. A missing destination blocks the release, and so does a record check whose finding the iteration did not answer.

The operator's explicit forward signal on this pre-close summary is the release gate's release. A message that reviews output without a clear forward signal does not satisfy the exit condition.

## Release gate

This is the common acceptance gate the operator-involved workflows share. Present the acceptance criteria status table, the findings queue, and the commit message. Every criterion carries a status, every finding carries a destination, and the commit body stays within the git policy's body budget. Do not close until the operator releases. After this gate's release, the close hands off to `/wrapup`. Exit condition: explicit release received.

## Steps 8-9  --  Close and seed (via /wrapup)

After the release gate, run the consolidated close from [`/wrapup`](wrapup.md) Part B. `/wrapup` owns the shared close steps -- AC verification, propagation replay, scope reconciliation, roadmap write-back, carry-forward resolution, findings review/publish, closing ADRs and discussion docs whose work landed, closing the handover, and seeding what's next -- so this prompt does not restate them. `/wrapup` B4 and B9 keep the close as **one commit**: the work, the handover marked `Closed`, the roadmap write-back, and the `Status: Closed` edit all fold into it, and the commit message matches the iteration type per the `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`.

Steps that stay specific to `/iter` because they gate the release, not the mechanical close:

1. **Step 7 pre-close summary** (above) presents the AC table, roadmap write-back, propagation replay, and commit message to the operator before the release gate -- the operator, not the close, judges the work.
2. **Findings publication.** The gate decides each destination. The close publishes each destination, and the operator confirms the attribution.

## The acceptance gate

`/iter` stops at the acceptance gate. It presents the acceptance criteria table, the roadmap write-back, the propagation replay, and the commit message. It also presents the findings queue and the record-check reports. The operator releases, and [`/wrapup`](wrapup.md) takes the iteration from there. Compaction, changelog drafting, escalation clearance, and the pre-close review gate are milestone-grain work, owned by [`/milestone-close`](milestone-close.md). This prompt does not run them.

**Defects found by a reviewer are fixed, not filed.** A finding naming a defect in what this iteration produced is fixed here, even when it surfaced at the pre-close gate. The rule is [`iteration_policy.md`](/opt/sandbox/docs/policies/iteration_policy.md) `### Close invariants` `Defect resolution`; this step applies it before the release gate.

## File Tracking

There is no document registry; the docs tree is the authoritative file list. The iteration's file list is the scope proposal's, presented at the scope gate.

## Policy

The invariants these steps must not break are in [`iteration_policy.md`](/opt/sandbox/docs/policies/iteration_policy.md) and the separation is recorded in the ADR `coding_agent_loop_workflow.md`.
