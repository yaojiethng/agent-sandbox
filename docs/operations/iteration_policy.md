# Iteration Policy

The authoritative workflow for all development in agent-sandbox. Defines the two loops that govern work: the major loop for milestone planning, and the minor loop for iteration execution. Principles here are stable; the child documents that govern each subprocess will evolve as the project matures.

Read this document at the start of any iteration. Read the relevant child document before performing that subprocess.

| Loop | Step | Governing document |
|---|---|---|
| **Major** | 1. Close prior milestone | [`roadmap_policy.md`](roadmap_policy.md#top-level-milestone-close) -- Top-level milestone close |
| | **Gate 1** | select next milestone |
| | 2. Orient to next milestone | `roadmap.md` |
| | **Gate 2** | select sub-milestone (also entry point from roadmap maintenance when a sub-milestone closes) |
| | 3. Open or revise stories | [`story_policy.md`](story_policy.md#when-to-open-a-story) |
| | 4. Investigate or design | [`discussion_policy.md`](discussion_policy.md) |
| | 5. Resolve stories | [`discussion_policy.md`](discussion_policy.md) -- Stories |
| | **Gate 3** | release sub-milestone for execution |
| **Minor** | 1. Open handover | [Step 1 Details](#step-1----open-handover) |
| | 2. Confirm scope | [Step 2 Details](#step-2----confirm-scope) |
| | **Gate 1** | wait for operator release before any output |
| | 3. Design | [`roadmap_policy.md`](roadmap_policy.md#structure-and-filing-rules) |
| | 4. Information gathering pass | [`documentation_policy.md`](documentation_policy.md) |
| | 5. Acceptance criteria | [Step 5 Details](#step-5----acceptance-criteria) |
| | **Gate 2** | wait for operator release before implementation |
| | 6. Implementation | -- |
| | 7. Pre-close verification | [Step 7 Details](#step-7----pre-close-verification) |
| | **Gate 3** | wait for operator release before iteration end |
| | 8-9. Close and seed | [Steps 8-9 Details](#steps-8-9----close-and-seed) |

## Loop workflow prompts

The loops run as invocable workflow prompts under `workflow/coding-agent/prompts/`. The procedure lives in the prompts; this policy holds the rules the prompts must not break. See the ADR [`coding_agent_loop_workflow.md`](../adr/coding_agent_loop_workflow.md) for the taxonomy and the state diagram.

- `/iter` -- the base interactive minor loop: [`iter.md`](../../workflow/coding-agent/prompts/iter.md).
- `/auto` and `/parallel-auto` -- declared expansions of `/iter`: [`auto.md`](../../workflow/coding-agent/prompts/auto.md), [`parallel-auto.md`](../../workflow/coding-agent/prompts/parallel-auto.md).
- `/milestone-start` -- opens the major loop: [`milestone-start.md`](../../workflow/coding-agent/prompts/milestone-start.md).
- `/milestone-close` -- closes the major and sub-milestone: [`milestone-close.md`](../../workflow/coding-agent/prompts/milestone-close.md).
- `/plan` -- major-loop planning: [`plan.md`](../../workflow/coding-agent/prompts/plan.md).

---

## Principles

**Plan before executing.** No file, code, or structural change is produced without a confirmed plan. Proposals wait for operator confirmation before becoming outputs.

**Resolve open questions before advancing.** If a design or scope question cannot be answered, the iteration does not advance to the next step. Surface the question explicitly -- do not assume an answer and proceed.

**Record decisions where the work lives.** Decisions belong in the documents where they were made (roadmap, architecture docs). The handover points to those documents -- it does not reproduce their content.

**Confirm the scope before writing code.** The implementation details -- files, interfaces, naming -- are confirmed by the operator before any code is produced. They are the agreement, not a starting point.

**Scope is fixed at confirmation.** Adjacent issues discovered during implementation are recorded in Findings and deferred. They do not enter the current iteration silently.

**Documentation is part of the task, not a cleanup step.** Architecture and concepts documents are updated before implementation begins -- they describe the agreed design the code is written against. If implementation reveals a divergence from the agreed design, correct the document before the iteration ends; do not defer it. A sub-milestone cannot close if any in-scope architecture or concepts document contradicts the system as built.

**All outputs are proposals.** The operator reviews, approves, and commits. The agent does not decide what is final.

**Tests for non-trivial logic.** Any function with meaningful branching, error handling, or external dependencies gets tests. Tests are produced alongside implementation, not deferred.

**Acceptance criteria describe a delta.** Every AC describes something observable that was false or absent before the iteration and true or present after it. The operator verifies by running the system -- never by reading source alone. "Not file state" prohibits criteria verifiable only by reading source; it does not prohibit operator-runnable file-existence checks (`ls path` after a rename), which are observable behaviour.

**Roadmap reflects reality.** Completed items are marked promptly. Cleanup follows `roadmap_policy.md`.

---

## The Two Loops

Development operates at two cadences:

**Major loop** -- triggered when a major milestone closes (e.g. M1 -> M2). Plans the next major milestone: defines sub-milestones, opens stories, commissions investigations, and produces scoped roadmap entries. Operator-heavy. Output is a planned milestone ready for execution.

**Minor loop** -- a single iteration targeting one sub-milestone (e.g. M2.1). Assumes the sub-milestone is scoped. Proceeds through scope, design, implementation, and documentation in sequence. Output is working software and updated documents, closed in a handover.

The loops are sequential at the major level -- a major milestone must be planned before iterating on sub-milestones -- but the minor loop repeats for each sub-milestone within the major milestone.

---

## Major Loop -- Milestone Planning

The major loop opens a milestone and plans it before iteration begins. It is a planning and investigation cadence, not a coding one. The output is a scoped sub-milestone ready for iteration -- its readiness criteria are in [`milestone_policy.md`](milestone_policy.md).

The major loop runs from the workflow prompts:

- [`/milestone-start`](../../workflow/coding-agent/prompts/milestone-start.md) opens the next major milestone.
- [`/plan`](../../workflow/coding-agent/prompts/plan.md) scopes the milestone and refines its designs.

The major loop is sequential at the top: a major milestone must be open before iterating on its sub-milestones. The minor loop then repeats for each sub-milestone within the milestone.

---

## Minor Loop -- Iteration Workflow

An exchange is a conversation with the operator whose result is not yet resolved: an interview, a design discussion or a scope negotiation. Write an open exchange's results to a record before the next commit. Use the iteration's handover when the exchange resolves inside the iteration, and a `devlog/discussions/` record when it opens its own question. Move the decisions to the handover's Decisions, the actions to Roadmap rows, and the deferred items to Deferred items when the iteration closes. Until then, the record is provisional. Use `wip:` for its commits, per [`git_policy.md`](git_policy.md#transient-commits-fold-into-the-delivery-commit).

The information gathering pass (step 4) reads in order: the roadmap task, design decisions, conceptual docs, architecture docs. Lapses are accumulated across all four documents and surfaced together before Gate 2 -- related lapses grouped for easy review. Tags: `(always)` runs without exception; `(confirmed)` requires explicit operator release; `(assessed)` check runs, skip allowed when not applicable to iteration type.

| Step | Tag | Entry condition | Action | Exit condition |
|---|---|---|---|---|
| **1 -- Open handover** | always | Iteration begins | Run the roadmap maintenance check (verify roadmap against prior handover; if roadmap maintenance is pending, run it after creating handover but before scope). Create handover: new file with date and sequential index, read prior handover for Carried forward, reset Completed table, populate Hot files and Type, write canonical markers for nullable sections. Per [Step 1 Details](#step-1----open-handover). | Handover draft complete. |
| **2 -- Confirm scope** | always | Handover draft complete | Present scope proposal including iteration type and justification. Cover: what is in scope and why, what is deferred and why, any unresolved questions. If context insufficient, ask one question at a time. For multi-iteration sessions, write the implementation plan for the active iteration only. Wait for explicit release before any output. Per [Step 2 Details](#step-2----confirm-scope). | Operator confirmed scope and sent explicit release. A confirmation without a clear forward signal does not satisfy this condition. |
| **Gate 1** | always | Scope confirmed | No output until operator releases. Agent must present type with justification in the scope proposal -- operator confirms the type alongside scope. | Explicit release received. Type confirmed. |
| **3 -- Design** | confirmed | Gate 1 released. Skip if roadmap entry already has resolved decisions with recorded rationale -- task list alone does not satisfy skip. | Open a design doc in `devlog/discussions/` per [`discussion_policy.md`](discussion_policy.md#designs). Gather requirements; resolve any deferred story that depends on this sub-milestone; record decisions in roadmap and handover per [`roadmap_policy.md`](roadmap_policy.md#structure-and-filing-rules). If the design ends in an implementation decision, create an ADR before releasing (see [`adr_policy.md`](adr_policy.md)). | All design questions resolved, recorded, ADR created if applicable, and operator confirmed. |
| **4 -- Information gathering pass** | assessed | Design confirmed | Read in order: the roadmap task, design decisions, conceptual docs, architecture docs; accumulate lapses across all four, group by document boundary, surface together before Gate 2. Per [`documentation_policy.md`](documentation_policy.md). | All lapses surfaced and resolved. No open questions. |
| **5 -- Acceptance criteria** | confirmed | Information gathering pass complete | Define criteria in a four-column table: `\| # \| Criterion \| Verifiable by \| Verified by \|`. Pre-verify every verifiable criterion -- for commands the agent can run, show output and mark`Agent [x]` (pass) or `Agent [ ]` (fail, expected in pre-state). Criteria the agent cannot verify are marked `Operator`. Every iteration touching architecture must include: *"Architecture documents in scope describe the system as built."* Replace`Not yet defined.` before exiting. Per [Step 5 Details](#step-5----acceptance-criteria). | Operator confirmed acceptance criteria. |
| **Gate 2** | always | Acceptance criteria confirmed | Before releasing: present the acceptance criteria table to the operator -- every criterion must be visible, not implied. Re-read each criterion and verify it is satisfiable given the confirmed scope. A criterion that would fail on a correct implementation is a specification bug -- resolve it now, not at pre-close. No implementation until operator releases. | Operator confirmed criteria are satisfiable. Explicit release received. |
| **6 -- Implementation** | confirmed | Gate 2 released | Produce code against the confirmed scope; tests alongside per [`testing_policy.md`](../development/testing_policy.md). On design divergence: correct the architecture doc before continuing. Record all other adjacent issues in Findings; defer by default. Per [During the iteration](#during-the-iteration). | All tasks complete. Tests pass. Architecture docs reflect system as built. |
| **7 -- Pre-close verification** | confirmed | Implementation complete | Present pre-close summary in a four-column AC status table. Mark each criterion as accepted or pushed. Run verifiable checks and show output. Propose compaction entries for fully-completed task groups. For multi-file changes under a shared rule, include a propagation replay table. Packaging does not release this gate. Wait for explicit release. Per [Step 7 Details](#step-7----pre-close-verification). | Operator confirmed against AC and compaction text. |
| **Gate 3** | always | Pre-close verified | The AC status table and the commit message must be visible -- every criterion shown, every status populated, the commit body within the body budget. No close until operator releases. | Explicit release received. |
| **8-9 -- Close and seed** | always | Gate 3 released | Apply approved roadmap write-back -- compaction summaries for completed task groups, destinations for generated tasks. Run roadmap maintenance per [`roadmap_policy.md`](roadmap_policy.md#roadmap-maintenance). Run scope reconciliation, carry-forward resolution gate, and the findings review/publish step. Mark each AC accepted or pushed. Update Hot files. Seed What's Next. Per [Steps 8-9 Details](#steps-8-9----close-and-seed). | Roadmap updated. Handover closed. No doc divergences without explicit deferral. No un-triaged findings. What's Next actionable. |

---

## Minor Loop -- Step Details

### Step 1 -- Open handover

Per [`handover_policy.md`](handover_policy.md) for naming, section structure, null markers, and content rules. Create the handover file with today's date and the next sequential index.

- **Roadmap maintenance check:** verify the roadmap reflects the state the prior handover claims. If the prior handover's What's Next notes roadmap maintenance is pending (or the roadmap still shows a completed sub-milestone as active), run roadmap maintenance after creating this handover but before presenting the scope proposal (Step 2). Record the maintenance execution in this handover's Completed table. Present the maintained resource state as part of the scope proposal.
- No compaction checks are needed at iteration open -- read the roadmap as-is.

### Step 2 -- Confirm scope

**One iteration, one unit.** One iteration is one roadmap task, scoped as one vertical slice and landed as one commit with one handover. A slice crosses file kinds and directories, so a policy file, a template and a record that serve one outcome form one unit.

Propose no split by default. When one slice cannot deliver the task's outcome, name the handling method you propose:

- **Split.** Each part delivers an outcome of its own, closes on its own handover, and leaves the repository working after it lands. Carry a work-unit table in the scope proposal: the unit, its commit type, the owned files and the handover. Release the table at Gate 1. Disjoint units in one work-unit table are rare. Such a table appears when several results share one review: a test audit's findings, or a review outcome's fixes.
- **Consolidate.** No part delivers an outcome of its own. Such a part is work inside one unit: a per-section, per-file or per-layer change, or a phase of an iteration.

The review cadence does not change the unit count. A policy change released one section at a time is one iteration. The dispatch-side unit rule, and the work-unit table an autonomous run's proposal carries, are in [`auto.md`](../../workflow/coding-agent/prompts/auto.md).

After the handover draft is complete, present a scope proposal in chat and wait for operator confirmation before producing any file, code, or structural output. This gate applies to every iteration type without exception.

**If sufficient context is available** (handover and roadmap uploaded, task list readable), present the proposal directly using this template:

```text
**Type:** <type> — <one-line justification>

**In scope:**
- <item> — <why now>

**Deferred:**
- <item> — <reason>

**Questions:** <or "None.">
```

For housekeeping iterations, the scope proposal may simply be the target file list and the nature of the change -- that is sufficient. The gate still applies; the operator must confirm before work begins.

**If context is insufficient** (key files missing, roadmap task list unclear, prior handover not uploaded), do not guess at scope. Ask the operator one question at a time until a scope proposal can be made, then present it and wait for confirmation.

**Exit condition:** Operator has confirmed the scope proposal in chat. The Scope section of the handover is updated to reflect the confirmed scope before proceeding.

**Rule:** No output before scope is confirmed.

**Rule:** Purpose reconciliation. Before presenting the scope proposal  --  and again when presenting acceptance criteria (Step 5)  --  check the expressed purpose of the iteration against the current tree: a purpose may already be silently resolved by landed work (fixes, tests, skills, docs) that no record claims. If so, surface it in the proposal; the scope becomes recording or retiring the existing resolution, not re-implementing it, and the acceptance criteria are phrased against the tree as it is.

**Rule:** When a session contains multiple iterations, write the detailed per-step implementation plan only for the active iteration. The handover may list all iterations for orientation. Do not write iteration N+1's plan or its dependencies until iteration N's output is confirmed.

### Gate 1

No output until operator releases. The agent must present the iteration type with brief justification as part of the scope proposal -- the operator confirms the type alongside scope.

### Step 5 -- Acceptance criteria

Per [`handover_policy.md`](handover_policy.md#acceptance-criteria) for AC format and null marker rules. The `Not yet defined.` marker must be replaced before Step 6.

- Universal preconditions (`make test passes clean`, `bash -n passes`) are preconditions, not acceptance criteria. They gate every iteration equally and add no iteration-specific information. Omit them from the AC table; verify them as prerequisites before pre-close instead.
- **Pre-verify every criterion the agent can verify now.** For each criterion whose "Verifiable by" is a runnable command, run the command and show the output. Mark the Verified by column: `Agent [x]` (pass), `Agent [ ]` (fail, expected in pre-state). Criteria the agent cannot verify -- manual review, head -N, operator-only access -- are marked `Operator`.

### Gate 2

Before releasing: present the acceptance criteria table to the operator -- every criterion must be visible, not implied. Re-read each criterion and verify it is satisfiable given the confirmed scope. A criterion that would fail on a correct implementation is a specification bug -- resolve it now, not at pre-close. No implementation until operator releases.

Exit condition: Operator confirmed criteria are satisfiable. Explicit release received.

### During the iteration

Implementation iterations order their tasks in the handover task list. Tasks in an iteration live only in the agent's context. Persist them in the handover task list when they become a finding or require carry-forward. Maintain the task list consistently. The handover write-back fires at three moments:

**On task completion:** When a task in the iteration task list is completed, mark it complete in the Scope section and update Completed. Check whether any findings from that task belong in Findings before picking up the next task. Do not accumulate updates -- write immediately.

**On discovery:** When a bug, contradiction, design gap, blocker, or new file enters scope, write it to Findings immediately. Do not continue to the next task until the finding is recorded. If the finding changes the current approach, surface it in chat before proceeding.

**On steering received:** When the operator provides instruction that modifies the scope of a current or future iteration, write it to Findings before resuming work. If the steering affects a future iteration's scope, write it to Deferred items or What's Next as well. Do not resume until this is done.

Findings is the shared agent-managed recording surface for the agent-feedback and gotchas records. Entries are classified at the review/publish step at iteration end, not at the moment of writing. Attribution is operator-owned; the agent proposes a class and the operator confirms it.

- Record decisions in the Decisions table as they are made, with the document where the decision was recorded. If a decision is only in chat, it does not exist for the next iteration.
- Record new acceptance criteria as they are defined. Pushed (unresolved) criteria from prior iterations are already present in the handover from iteration open -- do not re-copy them.
- Update Deferred items immediately when something is flagged out of scope -- do not accumulate them at iteration end.

**Record write-back gate.** When announcing a record write (a finding row, a decision, a task, a roadmap row), verify it landed in the same turn. Grep the row key or the content you claim to have written. A claimed record that is not verified to exist is a record defect: the write is not done until the grep finds it. This gate is distinct from the roadmap write-back section at Step 7/8-9, which fires at pre-close; this gate fires at the moment of writing.

**Prompt-scope discipline.** A campaign or review prompt must not contradict its own success criteria. Name the in-scope targets explicitly (for example the test runner, not just "tests"); if a criterion can only be met by a change that looks out of scope, make the criterion flag-only or name the target. A prompt whose scope statement conflicts with a success criterion is a defect. When the agent detects such a contradiction at runtime, stop and ask the operator for a ruling; do not resolve it silently by extending or narrowing scope. The stop-and-ask behavior applies to the subagent and to the main agent authoring the prompt.

### Step 7 -- Pre-close verification

Step 7 is a mandatory gate before iteration end. Present a pre-close summary and wait for an explicit operator release before advancing to Steps 8-9. The summary has these sections:

1. **Acceptance criteria** -- table `| # | Criterion | Verifiable by | Status |`; each criterion marked accepted or pushed. Run verifiable checks and show output. Do not reuse the Gate 2 format -- this table answers "did it pass?", not "who can verify?".
2. **Roadmap write-back** -- per task touched this iteration, the exact row change, and completed rows the change supersedes or invalidates. Follow the procedure and requirements in [`roadmap_policy.md`](roadmap_policy.md#when-the-roadmap-is-touched). When no task was touched, state `none worked this iteration` -- never leave the row implicit.
3. **Propagation replay** -- for any iteration that touched multiple files under a shared rule or naming convention, a row-by-row comparison of every file that was planned to receive the change against the Completed table:

| File | Change planned | Status |
|---|---|---|
| `path/to/file.md` | `<what was supposed to change>` | `completed` / `deferred` / `not started` |

Every row must have a status. A row with status `deferred` or `not started` must appear in the Deferred items section before the gate closes. The operator cannot release Step 7 while any row is unresolved.

**A propagation replay is required when any of the following apply:**

- The iteration applied a naming rule, structural rule, or interface change across more than two files
- The scope produced an explicit file table at Step 4 (information gathering pass)
- The task description used language like "all", "every", "throughout", or "wherever X appears"

**When a propagation replay is not required**, the pre-close summary covers: what was built, tests produced, AC status per criterion, and recommended manual checks.

4. **Commit message** -- present the delivery commit's message alongside the summary: subject, body, and footer. The operator reads the body against the body budget in [`git_policy.md`](git_policy.md) before release.

The operator releases this gate with an explicit forward signal (e.g. "proceed", "close the iteration"). A message that reviews output without a clear forward signal does not satisfy the exit condition. Packaging changes (e.g. `/package-branch`) does not release this gate -- iteration-end actions do not begin until the operator explicitly confirms after testing.

### Gate 3

The AC status table and the commit message must be visible -- every criterion shown, every status populated, the commit body within the git policy's body budget. No close until operator releases.

Exit condition: Explicit release received.

### Sub-milestone close

A sub-milestone follows the sequence `active -> pre-close -> close`. The close procedure runs from [`/milestone-close`](../../workflow/coding-agent/prompts/milestone-close.md), which carries the review gate, compaction, changelog, record updates, escalation, and the close commit.

- A sub-milestone is `active` while substantive work is in progress.
- A sub-milestone is `pre-close` when its implementation is complete. In pre-close, the agent completes compaction, changelog drafting, escalation clearance, and the review gate.
- A sub-milestone is `close` when its close checklist completes. At close, no new decisions are made. Substantive work does not occur after close.

**Probation decisions are operator-owned.** For an entry under `probation` in `devlog/AGENT_FEEDBACK.md`, the operator decides dismiss / maintain / escalate. The agent does not decide a probation entry. Escalation of far-reaching correctness work defers the sub-milestone close until the escalated work is complete. Low-urgency escalation is filed as a named task at the top of the next sub-milestone. There is no dedicated `close-blocked` state; a deferred close keeps the sub-milestone `active` until pre-close passes.

---

### Steps 8-9 -- Close and seed

After Gate 3 is released, the close is mechanical -- the operator has already reviewed and approved the compaction text and AC status. The per-iteration close runs from [`/iter`](../../workflow/coding-agent/prompts/iter.md); the milestone-record close runs from [`/milestone-close`](../../workflow/coding-agent/prompts/milestone-close.md). Both stop for operator release at the close gate.

**Close produces one commit.** At iteration end the iteration is a single commit carrying the work, the handover marked `Closed`, and the roadmap write-back. Every transient commit (`wip:` checkpoints, corrections) and the `Status: Closed` edit fold into it. The commit message matches the iteration type per [`docs/operations/git_policy.md`](git_policy.md). Milestone-close bookkeeping -- compaction, changelog, and promotion -- types `plan`; the M2.7 and M3.1 closes both typed `plan`.

**Scope reconciliation -- run before writing anything else.** Compare the confirmed scope from Step 2 against the Completed table. Every item that was in scope but is not in Completed must appear in Deferred items. There must be no unaccounted items -- if something was attempted but not finished, it is deferred; if it was never started, it is deferred; if it was descoped mid-iteration, it is deferred with the reason. The Deferred items section is not complete until this check passes.

**Carry-forward resolution gate -- run after scope reconciliation, before seeding What's Next.** Compare every item in the Carried forward section against the Completed table and the Deferred items section. Every carried-forward item must have a resolution: it was completed (in Completed table), it is re-deferred (in Deferred items table with reason), or it is escalated to the roadmap (a named entry in `roadmap.md`). Any carried-forward item that is absent from all three is a dropped item -- find it, triage it, and write it to one of the three destinations. The Deferred items section is not complete until this gate passes.

**Findings review/publish -- run after the carry-forward resolution gate.** Route each Findings entry to its destination: the Decisions table, Deferred items, What's Next (via Carried forward), `roadmap.md` (via a named task entry), or the feedback record [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md). Class A (agent experience, friction, poor stack design, poor operator prompting) is tagged `[A]`. Class B (recurring agent mistakes and code smells) is tagged `[O]`. Class C (steering, scope, blockers, technical findings) goes to the existing destinations. The `[A]`/`[O]` tag names who raised the entry: the agent (`[A]`) or the operator (`[O]`). **Attribution is operator-owned.** The agent proposes a class; the operator confirms it. The agent does not classify its own mistakes as another party's. The Findings section must be empty or contain only entries with a `Triaged to:` annotation before the handover can be closed. **Entry condition for seeding What's Next:** this gate must pass before What's Next is written.

**Scope amendment:** if any implementation gap discovered this iteration affects the scope -- missing flag, unspecified behaviour, ambiguous fixture approach -- amend the scope before closing. Do not leave scope gaps for the next iteration to re-derive.

#### Seed next iteration

- Identify the next iteration's scope from two sources: the roadmap task list, and the Deferred items just written. Deferred items take priority -- they represent work already started or committed to that must not be silently dropped.
- If this was the final iteration of a sub-milestone, note in What's Next whether roadmap maintenance has been run or is pending. This is the signal the next iteration uses in its Step 1 roadmap maintenance check.
- List any blocking design questions explicitly -- these are not general notes, they are concrete blockers the next agent must resolve before advancing.
- Populate the **Conclusions from this iteration** field: decisions made, approaches confirmed, dead ends ruled out this iteration. Only what the next agent would otherwise re-derive from scratch -- not a full log.
- Populate What's Next with enough orientation that the next agent does not need to read this iteration's history. **This section is written for the next agent, not the current one -- it is source material for that agent's Step 1, not a continuation directive. The next agent will create its own handover before acting on anything written here.**
- If the completed sub-milestone was the last in the major milestone, write "Major loop required before next iteration" in What's Next and leave the sub-milestone ID blank.
- **If this iteration supersedes a prior implementation handover**, include a **Context handover** line in What's Next with a markdown link to the last relevant implementation handover, so the next agent can load full context directly.

---

## File Tracking

There is no document registry. The docs tree itself is the authoritative file list. The iteration-scoped list is the active handover's Hot files section, governed by [`handover_policy.md`](handover_policy.md).

---

## Child Documents

| Document | Governs |
|---|---|
| [`milestone_policy.md`](milestone_policy.md) | Major loop: milestone planning, story and investigation process |
| [`discussion_policy.md`](discussion_policy.md) | Discussion document lifecycle: naming, types, statuses |
| [`story_policy.md`](story_policy.md) | Story lifecycle: format, graduation, closure |
| [`study_policy.md`](study_policy.md) | Study lifecycle: format, recommendation, closure (formerly `investigation_policy.md`) |
| [`adr_policy.md`](adr_policy.md) | ADR lifecycle: creation trigger, content requirements, supersede protocol |
| [`handover_policy.md`](handover_policy.md) | Handover content rules: valid field states, null markers, format conventions, correction procedure |

---

## References

| Document | Purpose |
|---|---|
| [`documentation_policy.md`](documentation_policy.md) | Document structure and folder ownership rules |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update sequence, milestone promotion, changelog format |
| [`audit.skill.md`](../../workflow/coding-agent/audits/audit.skill.md) | Operator-invoked handover audit procedure -- deferred chain integrity, structural completeness, dangling references |
