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
| **Minor** | 1. Open handover ... 9. Seed, with Gates 1-3 | [`/iter`](../../workflow/coding-agent/prompts/iter.md) runs the steps; [Minor Loop -- Step Details](#minor-loop----step-details) holds the rules |

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

**Record decisions where the work lives.** Decisions belong in the documents where they were made (roadmap, architecture docs). The handover points to those documents -- it does not reproduce their content.

**Confirm the scope before writing code.** The implementation details -- files, interfaces, naming -- are confirmed by the operator before any code is produced. They are the agreement, not a starting point.

**Documentation is part of the task, not a cleanup step.** Architecture and concepts documents are updated before implementation begins -- they describe the agreed design the code is written against. If implementation reveals a divergence from the agreed design, correct the document before the iteration ends; do not defer it. A sub-milestone cannot close if any in-scope architecture or concepts document contradicts the system as built.

**Acceptance criteria describe a delta.** Every AC describes something observable that was false or absent before the iteration and true or present after it. The operator verifies by running the system -- never by reading source alone. "Not file state" prohibits criteria verifiable only by reading source; it does not prohibit operator-runnable file-existence checks (`ls path` after a rename), which are observable behaviour.

Principles owned by other layers and echoed here:

- **All outputs are proposals** (the operator reviews, approves, and commits) -- owned by the project [`AGENTS.md`](../../AGENTS.md) Output Format.
- **Resolve open questions before advancing** (surface explicitly; the iteration does not advance past an unanswered scope or design question) -- owned by [`/iter`](../../workflow/coding-agent/prompts/iter.md) as the iteration variant.
- **Scope is fixed at confirmation** (adjacent issues go to Findings, deferred) -- owned by [`/iter`](../../workflow/coding-agent/prompts/iter.md).
- **Roadmap reflects reality** (completed items marked promptly) -- owned by [`roadmap_policy.md`](roadmap_policy.md).
- **Tests for non-trivial logic** -- owned by [`testing_policy.md`](../development/testing_policy.md).

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

The minor loop runs from [`/iter`](../../workflow/coding-agent/prompts/iter.md). The prompt owns the step sequence, the entry and exit conditions of each step, and the templates. This policy holds the rules the steps must not break. Rules that bind every step regardless of prompt:

- **Gates stop for explicit operator release.** Gate 1, Gate 2, and Gate 3 each stop the loop until the operator sends a forward signal. A message that reviews output without a clear forward signal does not release a gate. Packaging changes (`/package-branch`) do not release Gate 3 -- iteration-end actions do not begin until the operator explicitly confirms after testing.
- **One iteration, one unit.** One iteration is one roadmap task, scoped as one vertical slice and landed as one commit with one handover; a slice crosses file kinds and directories, so a policy file, a template and a record that serve one outcome form one unit. Propose no split by default. **Split:** each part delivers an outcome of its own, closes on its own handover, and leaves the repository working after it lands; the scope proposal carries a work-unit table -- the unit, its commit type, the owned files, the handover -- released at Gate 1. **Consolidate:** no part delivers an outcome of its own; such a part is work inside one unit (a per-section, per-file, or per-layer change, or a phase of an iteration). The work-unit table an autonomous run's proposal carries is defined in [`auto.md`](../../workflow/coding-agent/prompts/auto.md). The review cadence does not change the unit count: a policy change released one section at a time is one iteration.
- **Activity tags.** `(always)` runs without exception; `(confirmed)` requires explicit operator release; `(assessed)` check runs, skip allowed when not applicable to iteration type.
- **Acceptance criteria describe a delta.** An AC must be an observable change -- verified by running the system, never by reading source alone. See Principles.
- **Open exchanges are recorded before the next commit.** An exchange is a conversation with the operator whose result is not yet resolved. Write its results to a record before committing: the iteration's handover when the exchange resolves inside the iteration, a `devlog/discussions/` record when it opens its own question. Until the iteration closes, the record is provisional; commit it as `wip:` per [`git_policy.md`](git_policy.md#transient-commits-fold-into-the-delivery-commit).

---

## Minor Loop -- Step Details

`/iter` carries the procedure of each step and gate. This section holds the rules that survive: who owns a decision, what state a handover must reach, and what a gate's exit condition requires.

### Step 1 -- Open handover

The roadmap maintenance check and the handover creation procedure run from [`/iter`](../../workflow/coding-agent/prompts/iter.md); the handover content rules are in [`handover_policy.md`](handover_policy.md). Rules the prompt must not break:

- **Roadmap maintenance ordering.** If the prior handover's What's Next notes roadmap maintenance is pending, or the roadmap still shows a completed sub-milestone as active, run roadmap maintenance after creating the handover but before presenting the scope proposal. Record the maintenance execution in this handover's Completed table. Read the roadmap as-is at iteration open -- no compaction checks are needed at iteration open.

### Step 2 -- Confirm scope

The scope proposal procedure runs from [`/iter`](../../workflow/coding-agent/prompts/iter.md). Rules the prompt must not break:

- **No output before scope is confirmed.** The scope gate applies to every iteration type without exception. For housekeeping iterations, a target file list and the nature of the change is a sufficient scope proposal -- the gate still applies.
- **Context sufficiency.** If context is insufficient for a scope proposal (key files missing, roadmap task list unclear, prior handover not available), the agent does not guess at scope; it asks the operator one question at a time until a proposal can be made, then waits for confirmation.
- **Purpose reconciliation.** Before presenting the scope proposal -- and again when presenting acceptance criteria (Step 5) -- check the expressed purpose of the iteration against the current tree: a purpose may already be silently resolved by landed work (fixes, tests, skills, docs) that no record claims. If so, surface it in the proposal; the scope becomes recording or retiring the existing resolution, not re-implementing it, and the acceptance criteria are phrased against the tree as it is.
- **Multi-iteration sessions.** When a session contains multiple iterations, write the detailed per-step implementation plan only for the active iteration. The handover may list all iterations for orientation. Do not write iteration N+1's plan or its dependencies until iteration N's output is confirmed.
- **Handover Scope section.** The Scope section of the handover reflects the confirmed scope before the iteration proceeds.

### Gate 1

No output until operator releases. The agent presents the iteration type with brief justification as part of the scope proposal -- the operator confirms the type alongside scope.

### Step 5 -- Acceptance criteria

Per [`handover_policy.md`](handover_policy.md#acceptance-criteria) for AC format and null marker rules; the defining and pre-verification procedure runs from [`/iter`](../../workflow/coding-agent/prompts/iter.md). Rules the prompt must not break:

- Universal preconditions (`make test passes clean`, `bash -n passes`) are preconditions, not acceptance criteria. They gate every iteration equally and add no iteration-specific information. Omit them from the AC table; verify them as prerequisites before pre-close instead.
- The `Not yet defined.` marker must be replaced before Step 6.
- Criteria the agent cannot verify -- manual review, head -N, operator-only access -- are marked `Operator`; criteria with a runnable command are marked `Agent [x]` (pass) or `Agent [ ]` (fail, expected in pre-state).

### Gate 2

Before releasing: the acceptance criteria table is presented to the operator -- every criterion visible, not implied. Each criterion is re-read and verified for satisfiability given the confirmed scope; a criterion that would fail on a correct implementation is a specification bug -- resolve it now, not at pre-close. No implementation until operator releases.

Exit condition: Operator confirmed criteria are satisfiable. Explicit release received.

### During the iteration

The communication rules the iteration must satisfy are stated here, canonically. [`/iter`](../../workflow/coding-agent/prompts/iter.md) runs them as a procedural runbook -- the three write-back moments and where each writes. A rule here is the invariant; the prompt's restatement of it is the runbook around the rule, not a second owner.

- **Record decisions live.** A decision is recorded in the handover's Decisions table as it is made, with the document where it was recorded. If a decision is only in chat, it does not exist for the next iteration.
- **Write Findings immediately.** A bug, contradiction, design gap, blocker, or new file entering scope goes to Findings at once -- not accumulated. On task completion, check whether its findings belong in Findings before starting the next task. On steering received, write it to Findings (and to Deferred items or What's Next when it affects a future iteration) before resuming.
- **Surface approach changes in chat.** If a discovery changes the current approach, surface it in chat before proceeding.
- **Verify record writes landed.** When announcing a record write (a finding row, a decision, a task, a roadmap row), grep the row key or content claimed. A claimed record that is not verified to exist is a record defect: the write is not done until the grep finds it. This gate fires at the moment of writing; it is distinct from the roadmap write-back at Step 7/8-9, which fires at pre-close.
- **Findings is the shared agent-managed recording surface** for the agent-feedback and gotchas records. Entries are classified at the review/publish step at iteration end, not at the moment of writing. Attribution is operator-owned; the agent proposes a class and the operator confirms it.
- **Prompt-scope discipline.** A campaign or review prompt must not contradict its own success criteria. Name the in-scope targets explicitly (for example the test runner, not just "tests"); if a criterion can only be met by a change that looks out of scope, make the criterion flag-only or name the target. When the agent detects such a contradiction at runtime, stop and ask the operator for a ruling; do not resolve it silently by extending or narrowing scope. The stop-and-ask behavior applies to the subagent and to the main agent authoring the prompt.

### Step 7 -- Pre-close verification

Step 7 is a mandatory gate before iteration end. The pre-close summary's four-section format and the presentation procedure run from [`/iter`](../../workflow/coding-agent/prompts/iter.md). Rules the prompt must not break:

- The summary shows the AC status table -- every criterion marked accepted or pushed, verifiable checks run with output shown -- and the delivery commit message (subject, body, footer), which the operator reads against the body budget in [`git_policy.md`](git_policy.md).
- The roadmap write-back section states, per task touched, the exact row change and the completed rows the change supersedes or invalidates, per [`roadmap_policy.md`](roadmap_policy.md#when-the-roadmap-is-touched). When no task was touched, it states `none worked this iteration` -- never leave the row implicit.
- **Propagation replay.** A row-by-row replay is required when any of the following apply: the iteration applied a naming rule, structural rule, or interface change across more than two files; the scope produced an explicit file table at Step 4 (information gathering pass); or the task description used language like "all", "every", "throughout", or "wherever X appears". Every row carries a status (`completed` / `deferred` / `not started`); a row with status `deferred` or `not started` must appear in the Deferred items section before the gate closes, and the operator cannot release Step 7 while any row is unresolved. When a replay is not required, the summary still covers what was built, tests produced, AC status per criterion, and recommended manual checks.

The gate releases on an explicit operator forward signal; the release rule is above under Minor Loop -- Iteration Workflow.

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

After Gate 3 is released, the close is mechanical -- the operator has already reviewed and approved the compaction text and AC status. The unified close for the active-operator prompts (`/iter`, `/plan`, `/document`) runs from [`/wrapup`](../../workflow/coding-agent/prompts/wrapup.md) Part B; the milestone-record close runs from [`/milestone-close`](../../workflow/coding-agent/prompts/milestone-close.md). Both stop for operator release at the close gate. The rules below bind the close; `/wrapup` runs them.

**Close produces one commit.** At iteration end the iteration is a single commit carrying the work, the handover marked `Closed`, and the roadmap write-back. Every transient commit (`wip:` checkpoints, corrections) and the `Status: Closed` edit fold into it. The commit message matches the iteration type per [`docs/operations/git_policy.md`](git_policy.md). Milestone-close bookkeeping -- compaction, changelog, and promotion -- types `plan`.

**Scope reconciliation -- run before writing anything else.** Compare the confirmed scope from Step 2 against the Completed table. Every item that was in scope but is not in Completed must appear in Deferred items. There must be no unaccounted items -- if something was attempted but not finished, it is deferred; if it was never started, it is deferred; if it was descoped mid-iteration, it is deferred with the reason. The Deferred items section is not complete until this check passes.

**Carry-forward resolution gate -- run after scope reconciliation, before seeding What's Next.** Compare every item in the Carried forward section against the Completed table and the Deferred items section. Every carried-forward item must have a resolution: it was completed (in Completed table), it is re-deferred (in Deferred items table with reason), or it is escalated to the roadmap (a named entry in `roadmap.md`). Any carried-forward item that is absent from all three is a dropped item -- find it, triage it, and write it to one of the three destinations. The Deferred items section is not complete until this gate passes.

**Findings review/publish -- run after the carry-forward resolution gate.** Route each Findings entry to its destination: the Decisions table, Deferred items, What's Next (via Carried forward), `roadmap.md` (via a named task entry), or the feedback record [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md). Class A (agent experience, friction, poor stack design, poor operator prompting) is tagged `[A]`. Class B (recurring agent mistakes and code smells) is tagged `[O]`. Class C (steering, scope, blockers, technical findings) goes to the existing destinations. The `[A]`/`[O]` tag names who raised the entry: the agent (`[A]`) or the operator (`[O]`). **Attribution is operator-owned.** The agent proposes a class; the operator confirms it. The agent does not classify its own mistakes as another party's. The Findings section must be empty or contain only entries with a `Triaged to:` annotation before the handover can be closed. **Entry condition for seeding What's Next:** this gate must pass before What's Next is written.

**Scope amendment:** if any implementation gap discovered this iteration affects the scope -- missing flag, unspecified behaviour, ambiguous fixture approach -- amend the scope before closing. Do not leave scope gaps for the next iteration to re-derive.

#### Seed next iteration

- Identify the next iteration's scope from two sources: the roadmap task list, and the Deferred items just written. Deferred items take priority -- they represent work already started or committed to that must not be silently dropped.
- If this was the final iteration of a sub-milestone, note in What's Next whether roadmap maintenance has been run or is pending. This is the signal the next iteration uses in its Step 1 roadmap maintenance check.
- List any blocking design questions explicitly -- these are not general notes, they are concrete blockers the next agent must resolve before advancing.
- Populate the **Conclusions from this iteration** field: decisions made, approaches confirmed, dead ends ruled out this iteration. Only what the next agent would otherwise re-derive from scratch -- not a full log.
- Populate What's Next with enough orientation that the next agent does not need to read this iteration's history: it is written for the next agent, not the current one. It is source material for that agent's Step 1, not a continuation directive; the next agent creates its own handover before acting on anything written here.
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
