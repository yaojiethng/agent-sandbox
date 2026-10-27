---
description: "Owns the iteration grain: the two gates, the unit and close invariants the runbooks must not break, and the sidequest rule. The procedures live in the runbooks this document governs."
scope: ["/iter", "/sidequest", "/milestone-start", "/milestone-close", "/plan", "/scope", "/document", "/wrapup", "/commit"]
reader: [agent]
---

# Iteration Protocol

Milestones are nodes in the roadmap's tree, so their structure and states are the project's `task-list` convention's, and the loop model is in `docs/adr/coding_agent_loop_workflow.md`.

Read this document at the start of any iteration.

## Loop workflow prompts

The workflows run as invocable runbooks under `workflow/coding-agent/prompts/`. The procedure lives in the runbooks; this document holds the invariants they must not break. [`autonomous_agent_loop.md`](autonomous_agent_loop.md) holds the loop model, its sequence diagram and the workflow taxonomy. A runbook may evolve freely as the model improves; the invariants here are the durable half.

The `scope` field above names the runbooks this document governs. That list is the single declaration of them: the project layer `AGENTS.md` carries the inventory an agent reads at session start, and `scripts/check_instruction_surfaces.sh` fails when the two disagree.

## Sidequests

A sidequest is an operator-directed work item raised while an iteration is open. The operator invokes `workflow/coding-agent/prompts/sidequest.md`, and the open iteration pauses until the sidequest closes. A sidequest runs the standard lifecycle at its own grain: one handover, one scope gate, one delivery commit, one close.

- **Operator-directed.** The operator names the work. The agent does not open a sidequest on its own.
- **The open iteration pauses; it does not close.** The sidequest's Scope opens with a continuation line naming the interrupted handover. That handover keeps its `Active` status and records the interruption in its Findings. `workflow/coding-agent/prompts/iter.md` resumes the named handover after the sidequest closes.
- **One outcome, one commit.** A sidequest is one vertical slice, landed as one typed commit with one handover, like any iteration.
- **Outside the interrupted scope.** A task inside the open iteration's scope stays that iteration's work; it is a scope amendment, not a sidequest.
- **Roadmap write-back.** A sidequest whose outcome is durable work writes back a roadmap row and marks it at close. A sidequest whose outcome is a fix, check or record that belongs in no roadmap row states that in its close, per the write-back invariant.

## Principles

**Plan before executing.** No file, code, or structural change is produced without a confirmed plan. Proposals wait for operator confirmation before becoming outputs.

**Record decisions where the work lives.** Decisions belong in the documents where they were made (roadmap, architecture docs). The handover points to those documents -- it does not reproduce their content.

**Record a finding when it is found.** It belongs in the record the moment it surfaces, and its destination may be filled later; the row may not wait. The gate reads the record, so a finding held in conversation is not presented to it, and an empty table cannot be told apart from a clean unit.

**Confirm the scope before writing code.** The implementation details -- files, interfaces, naming -- are confirmed by the operator before any code is produced. They are the agreement, not a starting point.

**Documentation is part of the task, not a cleanup step.** Reference documents are updated before implementation begins -- they describe the agreed design the code is written against. If implementation reveals a divergence from the agreed design, correct the document before the iteration ends; do not defer it. A sub-milestone cannot close if any in-scope architecture or concepts document contradicts the system as built.

## The autonomous agent loop

The agent operates as one loop with a milestone phase and an iteration phase. The milestone phase takes its rules from the project's `task-list` convention -- a milestone is a node in the roadmap's tree -- and its procedure from `/milestone-start`, `/plan` and `/milestone-close`. The iteration phase is governed by this document.

## Iteration Invariants

The iteration runs from `workflow/coding-agent/prompts/iter.md`. The prompt owns the procedure: the step sequence, the entry and exit conditions, and the templates. This section holds the invariants the procedure must not break -- the state the repository must be in at every point a commit lands. It is organized by invariant, not by procedure step: the procedure in `/iter` may evolve, and the invariant set below should not change when the runbook changes, only when the system is redesigned.

The principle behind this shape -- a document's invariants must not couple to its runbook, and a loose procedure belongs in the runbook -- is `docs/adr/archive/20260721-adr-settled-policy_declarative_framing.md`'s. That decision retired with the policy form it wrote for, and the shape outlived it: this document states its invariants and does not restate an argument it no longer owns.

### Unit and scope invariants

- **One iteration, one unit.** One iteration is one roadmap task, scoped as one vertical slice, landed as one commit with one handover. Propose no split by default. A slice crosses file kinds and directories, so a document, a template and a record that serve one outcome form one unit. **Split:** each part delivers an outcome of its own, closes on its own handover, and leaves the repository working after it lands; the scope proposal carries a work-unit table -- the unit, its commit type, the owned files, the handover -- released at the scope gate. **Consolidate:** no part delivers an outcome of its own; such a part is work inside one unit. The review cadence does not change the unit count: a document change released one section at a time is one iteration.
- **No output before scope is confirmed.** The scope gate applies to every iteration type without exception. For housekeeping iterations, a target file list and the nature of the change is a sufficient scope proposal -- the gate still applies.
- **The scope gate confirms understood intent.** The agent restates the operator's goal and the problem the work solves before presenting the formal gate, so the gate confirms that the agent understood the intent rather than re-presenting the request.
- **Context sufficiency.** If context is insufficient for a scope proposal (key files missing, roadmap task list unclear, prior handover not available), the agent does not guess at scope; it asks the operator one question at a time until a proposal can be made, then the scope gate presents it.
- **Purpose reconciliation.** Before presenting the scope proposal at the scope gate -- which also carries the acceptance criteria -- check the expressed purpose of the iteration against the current tree: a purpose may already be silently resolved by landed work (fixes, tests, skills, docs) that no record claims. If so, surface it; the scope becomes recording or retiring the existing resolution, not re-implementing it.
- **Multi-iteration sessions.** When a session contains multiple iterations, write the detailed per-step implementation plan only for the active iteration. The handover may list all iterations for orientation. Do not write iteration N+1's plan or its dependencies until iteration N's output is confirmed.
- **Handover Scope section.** The Scope section of the handover reflects the confirmed scope before the iteration proceeds.
- **Release is explicit where a decision is required.** Some steps require explicit operator release and some run without it; the release-gate invariant fixes where a release is required. The runbook attaches the release requirement to a step; this document does not enumerate which steps.

### Gate invariants

- **Two gates.** The iteration has two gates: the **scope gate** and the **release gate**. The scope gate confirms scope and acceptance criteria together on a single operator approval. The release gate is the common acceptance gate the operator-involved workflows share, and after its release the close hands off to `workflow/coding-agent/prompts/wrapup.md`, whose commit step is `workflow/coding-agent/prompts/commit.md`'s.
- **The release gate reads the decisions, not only the work.** The gate reads the findings queue with every destination. It also reads each record check's report on the records this iteration changed. Run `roadmap-maintenance` and `handover-maintenance` before this gate, when the records they read are finished.
- **Gates stop for explicit operator release.** Each gate stops the loop until the operator sends a forward signal. A message that reviews output without a clear forward signal does not release a gate. Packaging changes (`/package-branch`) do not release the release gate -- iteration-end actions do not begin until the operator explicitly confirms after testing.
- **AC satisfiability.** Every criterion is re-read and verified satisfiable given the confirmed scope; a criterion that would fail on a correct implementation is a specification bug -- resolve it now, not at pre-close.

### Acceptance criteria

The iteration derives the criteria at the scope gate and the handover records them. `iter` Step 5 states the authoring bar, the project's `work-log` convention owns the table, its columns and its markers, and `wrapup` B1 verifies each criterion at the close.

### Close invariants

- **Close produces one commit.** At iteration end the iteration is a single commit carrying the work, the handover marked `Closed`, and the roadmap write-back. Every transient commit (`wip:` checkpoints, corrections) and the `Status: Closed` edit fold into it. The commit message matches the iteration type per the `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`. Milestone-close bookkeeping -- compaction, changelog, and promotion -- types `plan`.
- **Scope reconciliation.** Compare the confirmed scope against the Completed table. Every item that was in scope but is not in Completed must be resolved by the deferred-resolution rule. There must be no unaccounted items.
- **Defect resolution.** A finding that names a defect in the surface this iteration changed is fixed in this iteration. It is not an incomplete item, and the deferred-resolution rule does not apply: a defect reached by review is work the iteration now owns, because shipping the change and filing the repair is how a known break reaches the next reader. Fix it, re-run the gate, and record what was fixed. A finding that names a defect outside the changed surface is new work: file it as an open roadmap row with its reason, or rule it out of scope with one Scope sentence. The distinction is whether the iteration made it reachable.
- **Deferred resolution.** Every item in scope but not completed is written back to the roadmap as an open row with its reason, or ruled out of scope with one Scope sentence. No item is left in the handover itself; the handover carries no deferred-item section.
- **Findings publish.** The gate decides each destination. The close publishes each destination with the attribution the operator confirms, and records what the gate missed. An entry the close records as `late` names the gate that should have asked. The close files a recurring late entry as a roadmap row against the gate that missed it. Destinations are the Decisions table, `roadmap.md` (via a named task entry), or `devlog/AGENT_FEEDBACK.md`. Class A (agent experience, friction, poor stack design, poor operator prompting) is tagged `[A]`. Class B (recurring agent mistakes and code smells) is tagged `[O]`. Class C (steering, scope, obstacles, technical findings) goes to the existing destinations. **Attribution is operator-owned.** The tag names who raised the entry, the agent proposes a class, and the operator confirms it. The agent does not classify its own mistakes as another party's.
- **Propagation replay.** When the iteration applied a naming rule, structural rule, or interface change across more than two files, or produced an explicit file table, or used "all", "every", "throughout", or "wherever X appears", a row-by-row replay is required: `file | change planned | status`. Every row carries `completed`, `deferred`, or `not started`; every row must be accounted for before the release gate releases: `completed`, or `deferred`/`not started` with the row in Deferred items. When a replay is not required, the summary still covers what was built, tests produced, AC status per criterion, and recommended manual checks.
- **Scope amendment.** If any implementation gap discovered this iteration affects the scope -- missing flag, unspecified behaviour, ambiguous fixture approach -- amend the scope before closing. Do not leave scope gaps for the next iteration to re-derive.
- **The close's own writes are checked.** The release gate runs both record checks over the tree the iteration leaves, and the close then writes rows, findings, and record closes that did not exist for that run. The close runs both checks again after those writes and fixes what they report before the handover goes to `/commit`. A write-back no check read is a row the next session inherits unchecked.
- **Write-back, mandatory step, nullable value.** The close performs the write-back step and states its outcome. When the iteration completed or rescoped a roadmap task, that row edit rides this commit, marked with its landing note. An iteration that changed no roadmap task writes back nothing, and the close records that as the outcome. The step is never skipped; its value may be None, so the close raises no row to pair with the handover.
