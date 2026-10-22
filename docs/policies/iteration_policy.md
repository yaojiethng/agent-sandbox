---
description: "Owns the iteration grain: the invariants the runbooks must not break, the two gates, the acceptance-criteria model, and the close rules. This document states the rules; `/iter` runs the procedure."
scope: ["/iter", "/sidequest", "/milestone-start", "/milestone-close", "/plan", "/scope", "/document", "/wrapup"]
reader: [agent]
---

# Iteration Policy

Milestones are nodes in the roadmap's tree, so their structure and states are the project's `task-list` convention's, and the loop model is in `docs/adr/coding_agent_loop_workflow.md`.

Read this document at the start of any iteration.

| Phase | Step | Governing document |
|---|---|---|
| **Milestone** | 1. Close prior milestone | the `roadmap-maintenance` skill -- the top-level milestone close |
| | **Gate 1** | select next milestone |
| | 2. Orient to next milestone | `roadmap.md` |
| | **Gate 2** | select sub-milestone (also entry point from roadmap maintenance when a sub-milestone closes) |
| | 3. Open or revise stories | the `work-log` convention, `.agents/skills/work-log/SKILL.md` -- The four types |
| | 4. Investigate or design | the `work-log` convention, `.agents/skills/work-log/SKILL.md` -- The four types |
| | 5. Resolve stories | the `work-log` convention, `.agents/skills/work-log/SKILL.md` -- A story graduates |
| | **Gate 3** | release sub-milestone for execution |
| **Iteration** | 1. Open handover ... 9. Seed, with the scope gate and the release gate | `workflow/coding-agent/prompts/iter.md` runs the steps; [Iteration Invariants](#iteration-invariants) holds the rules |

## Loop workflow prompts

The workflows run as invocable runbooks under `workflow/coding-agent/prompts/` (each runbook is a workflow prompt). The procedure lives in the runbooks; this policy holds the invariants the runbooks must not break. See the ADR `docs/adr/coding_agent_loop_workflow.md` for the taxonomy and the state diagram. A runbook may evolve freely as the model improves; the invariants here are the durable half.

The `scope` field above names the runbooks this policy governs. That list is the single declaration of them: the project layer `AGENTS.md` carries the inventory an agent reads at session start, and `scripts/check_instruction_surfaces.sh` fails when the two disagree.

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

**Confirm the scope before writing code.** The implementation details -- files, interfaces, naming -- are confirmed by the operator before any code is produced. They are the agreement, not a starting point.

**Documentation is part of the task, not a cleanup step.** Reference documents are updated before implementation begins -- they describe the agreed design the code is written against. If implementation reveals a divergence from the agreed design, correct the document before the iteration ends; do not defer it. A sub-milestone cannot close if any in-scope architecture or concepts document contradicts the system as built.

**Acceptance criteria describe a delta.** Every AC describes something observable that was false or absent before the iteration and true or present after it. The operator verifies by running the system -- never by reading source alone. "Not file state" prohibits criteria verifiable only by reading source; it does not prohibit operator-runnable file-existence checks (`ls path` after a rename), which are observable behaviour.

Principles owned by other layers and echoed here:

- **All outputs are proposals** (the operator reviews, approves, and commits) -- owned by the project `AGENTS.md` Output Format.
- **Resolve open questions before advancing** (surface explicitly; the iteration does not advance past an unanswered scope or design question) -- owned by `workflow/coding-agent/prompts/iter.md` as the iteration variant.
- **Scope is fixed at confirmation** (adjacent issues go to Findings, deferred) -- owned by `workflow/coding-agent/prompts/iter.md`.
- **Roadmap reflects reality** (completed items marked promptly) -- owned by the project's `task-list` convention.
- **Tests for non-trivial logic** -- owned by the `testing` convention-skill, `.agents/skills/testing/SKILL.md`.

## The autonomous agent loop

The agent operates as one loop with a milestone phase and an iteration phase. The loop model, its sequence diagram, and the workflows that drive its transitions are in [`autonomous_agent_loop.md`](../reference/autonomous_agent_loop.md). The milestone phase takes its rules from the project's `task-list` convention  -  a milestone is a node in the roadmap's tree  -  and its procedure from `/milestone-start`, `/plan` and `/milestone-close`. The iteration phase is governed by this policy.

## Iteration Invariants

The iteration runs from `workflow/coding-agent/prompts/iter.md`. The prompt owns the procedure: the step sequence, the entry and exit conditions, and the templates. This section holds the invariants the procedure must not break -- the state the repository must be in at every point a commit lands. It is organized by invariant, not by procedure step: the procedure in `/iter` may evolve, and the invariant set below should not change when the runbook changes, only when the system is redesigned.

The principle behind this shape -- a policy's invariants must not couple to its runbook, and a loose procedure belongs in the runbook -- is `docs/adr/policy_declarative_framing.md`'s. This policy states its invariants and does not restate it.

### Unit and scope invariants

- **One iteration, one unit.** One iteration is one roadmap task, scoped as one vertical slice, landed as one commit with one handover. Propose no split by default. A slice crosses file kinds and directories, so a policy file, a template and a record that serve one outcome form one unit. **Split:** each part delivers an outcome of its own, closes on its own handover, and leaves the repository working after it lands; the scope proposal carries a work-unit table -- the unit, its commit type, the owned files, the handover -- released at the scope gate. **Consolidate:** no part delivers an outcome of its own; such a part is work inside one unit. The review cadence does not change the unit count: a policy change released one section at a time is one iteration.
- **No output before scope is confirmed.** The scope gate applies to every iteration type without exception. For housekeeping iterations, a target file list and the nature of the change is a sufficient scope proposal -- the gate still applies.
- **The scope gate confirms understood intent.** The agent restates the operator's goal and the problem the work solves before presenting the formal gate, so the gate confirms that the agent understood the intent rather than re-presenting the request.
- **Context sufficiency.** If context is insufficient for a scope proposal (key files missing, roadmap task list unclear, prior handover not available), the agent does not guess at scope; it asks the operator one question at a time until a proposal can be made, then the scope gate presents it.
- **Purpose reconciliation.** Before presenting the scope proposal at the scope gate -- which also carries the acceptance criteria -- check the expressed purpose of the iteration against the current tree: a purpose may already be silently resolved by landed work (fixes, tests, skills, docs) that no record claims. If so, surface it; the scope becomes recording or retiring the existing resolution, not re-implementing it.
- **Multi-iteration sessions.** When a session contains multiple iterations, write the detailed per-step implementation plan only for the active iteration. The handover may list all iterations for orientation. Do not write iteration N+1's plan or its dependencies until iteration N's output is confirmed.
- **Handover Scope section.** The Scope section of the handover reflects the confirmed scope before the iteration proceeds.
- **Release is explicit where a decision is required.** Some steps require explicit operator release and some run without it; the release-gate invariant fixes where a release is required. The runbook attaches the release requirement to a step; the policy does not enumerate which steps.

### Gate invariants

- **Two gates.** The iteration has two gates: the **scope gate** and the **release gate**. The scope gate confirms scope and acceptance criteria together on a single operator approval. The release gate is the common acceptance gate the operator-involved workflows share, and after its release the close hands off to `workflow/coding-agent/prompts/wrapup.md` Part B.
- **The release gate reads the decisions, not only the work.** The gate reads the findings queue with every destination. It also reads each record check's report on the records this iteration changed. Run `roadmap-maintenance` and `handover-maintenance` before this gate, when the records they read are finished.
- **Gates stop for explicit operator release.** Each gate stops the loop until the operator sends a forward signal. A message that reviews output without a clear forward signal does not release a gate. Packaging changes (`/package-branch`) do not release the release gate -- iteration-end actions do not begin until the operator explicitly confirms after testing.
- **AC satisfiability.** Every criterion is re-read and verified satisfiable given the confirmed scope; a criterion that would fail on a correct implementation is a specification bug -- resolve it now, not at pre-close.

### Acceptance-criteria invariants

The iteration derives the acceptance criteria; the handover records them. What makes one well-formed is stated here. The project's `work-log` convention owns the table that holds them, its columns, and its canonical markers.

- **An acceptance criterion describes a delta.** It is an observable change -- verified by running the system, never by reading source alone.
- **Universal preconditions are not ACs.** Universal preconditions (`make test passes clean`, `bash -n passes`) gate every iteration equally and add no iteration-specific information. Omit them from the AC table; verify them as prerequisites before pre-close instead.
- **Every criterion is traceable.** For a bugfix the delta is implicit, and the original error log is the anchor. For a feature or rework the delta traces to a story pain point, a requirement, or a design decision. A criterion that traces to nothing concrete is likely not needed.
- **Verify at the weakest sufficient level.** Preference order: unit test, then integration test, then manual script, then an operator-run command with documented expected output. Use the minimal level that reliably asserts the delta.
- **A rename or delete carries a paired negative check.** The positive check asserts the new path exists; the negative asserts the old one does not. Both are required.
- **A rename checks its companion files.** After the criteria are written, grep for tests, knowledge tests and fixtures matching the old path pattern, and include or defer each explicitly.
- **A recurring bug class gets one generic guard.** A bug representing a class -- a bash trap, a common mis-pattern, something review often misses -- gets one repo-wide check, not a per-file test. A one-off logic error does not need one.
- **A criterion is marked `Operator` when the agent cannot verify it** -- manual review, `head -N`, operator-only access -- and `Agent [x]` (pass) or `Agent [ ]` (fail, expected in pre-state) when it has a runnable command.
- **The `Not yet defined.` marker is replaced before implementation.** The project's `work-log` convention owns the marker; the rule here is that a criterion still carrying it when the scope gate releases is not confirmed.

### Record-state invariants

- **Record decisions live.** A decision is recorded in the handover's Decisions table as it is made, with the document where it was recorded. If a decision is only in chat, it does not exist for the next iteration.
- **Write Findings immediately, with its destination.** A bug, contradiction, design gap, obstacle, or new file entering scope gets its entry at once. The entry carries `Triaged to:` when it is written. When the destination needs the finished work, the entry carries `Triaged to: late`.
- **Open exchanges are recorded before the next commit.** An exchange is a conversation with the operator whose result is not yet resolved. Write its results to a record before committing: the iteration's handover when the exchange resolves inside the iteration, a `devlog/discussions/` record when it opens its own question. Until the iteration closes the record is provisional; commit it as `wip:` per [`git_policy.md`](git_policy.md#transient-commits-fold-into-the-delivery-commit).
- **Verify record writes landed.** When announcing a record write (a finding row, a decision, a task, a roadmap row), grep the row key or content claimed. A claimed record that is not verified to exist is a record defect: the write is not done until the grep finds it.
- **Record a document-relevant change when you make it.** Record a change to an invariant, interface, or contract when you make it, not at iteration close. If the record waits for close, a stale document governs the work in the meantime.
- **Findings is the shared agent-managed recording surface.** Entries are classified at the review/publish step at iteration end. Attribution is operator-owned; the agent proposes a class and the operator confirms it. Every entry carries `Triaged to:` before the handover reaches the release gate. `late` is the destination for a finding whose disposition needs the finished work.

### Close invariants

- **Close produces one commit.** At iteration end the iteration is a single commit carrying the work, the handover marked `Closed`, and the roadmap write-back. Every transient commit (`wip:` checkpoints, corrections) and the `Status: Closed` edit fold into it. The commit message matches the iteration type per [`git_policy.md`](git_policy.md). Milestone-close bookkeeping -- compaction, changelog, and promotion -- types `plan`.
- **Scope reconciliation.** Compare the confirmed scope against the Completed table. Every item that was in scope but is not in Completed must be resolved by the deferred-resolution rule. There must be no unaccounted items.
- **Defect resolution.** A finding that names a defect in the surface this iteration changed is fixed in this iteration. It is not an incomplete item, and the deferred-resolution rule does not apply: a defect reached by review is work the iteration now owns, because shipping the change and filing the repair is how a known break reaches the next reader. Fix it, re-run the gate, and record what was fixed. A finding that names a defect outside the changed surface is new work: file it as an open roadmap row with its reason, or rule it out of scope with one Scope sentence. The distinction is whether the iteration made it reachable.
- **Deferred resolution.** Every item in scope but not completed is written back to the roadmap as an open row with its reason, or ruled out of scope with one Scope sentence. No item is left in the handover itself; the handover carries no deferred-item section.
- **Findings publish.** The gate decides each destination. The close publishes each destination with the attribution the operator confirms, and records what the gate missed. An entry the close records as `late` names the gate that should have asked. The close files a recurring late entry as a roadmap row against the gate that missed it. Destinations are the Decisions table, `roadmap.md` (via a named task entry), or `devlog/AGENT_FEEDBACK.md`. Class A (agent experience, friction, poor stack design, poor operator prompting) is tagged `[A]`. Class B (recurring agent mistakes and code smells) is tagged `[O]`. Class C (steering, scope, obstacles, technical findings) goes to the existing destinations. **Attribution is operator-owned.** The tag names who raised the entry, the agent proposes a class, and the operator confirms it. The agent does not classify its own mistakes as another party's.
- **Propagation replay.** When the iteration applied a naming rule, structural rule, or interface change across more than two files, or produced an explicit file table, or used "all", "every", "throughout", or "wherever X appears", a row-by-row replay is required: `file | change planned | status`. Every row carries `completed`, `deferred`, or `not started`; every row must be accounted for before the release gate releases: `completed`, or `deferred`/`not started` with the row in Deferred items. When a replay is not required, the summary still covers what was built, tests produced, AC status per criterion, and recommended manual checks.
- **Scope amendment.** If any implementation gap discovered this iteration affects the scope -- missing flag, unspecified behaviour, ambiguous fixture approach -- amend the scope before closing. Do not leave scope gaps for the next iteration to re-derive.
- **Write-back, mandatory step, nullable value.** The close performs the write-back step and states its outcome. When the iteration completed or rescoped a roadmap task, that row edit rides this commit, marked with its landing note. An iteration that changed no roadmap task writes back nothing, and the close records that as the outcome. The step is never skipped; its value may be None, so the close raises no row to pair with the handover.

### Canonical procedures

The procedures below are deterministic code-blocks guaranteed to satisfy the invariants above. A procedure with a large decision space is not canonical and lives in `/iter`, not here.

- **Squash to one delivery commit.** Given a commit range `base..HEAD`, land one delivery commit that satisfies the close-produces-one-commit invariant:

```bash
git reset --soft <base>          # keep the work staged
git add -A
git commit -m "<type>: ..."      # one typed commit
```

A clean committed range uses the same fold; `/wrapup` runs the squash where the pile lands. The close edit and write-back are staged into the same commit, never a separate one.

### Sub-milestone close

The milestone's structure, states and close rules are the project's `task-list` convention's; the close procedure runs from `workflow/coding-agent/prompts/milestone-close.md`. This policy does not restate them.

**Probation decisions are operator-owned.** For an entry under `probation` in `devlog/AGENT_FEEDBACK.md`, the operator decides dismiss / maintain / escalate. The agent does not decide a probation entry.

## File Tracking

There is no document registry. The docs tree itself is the authoritative file list. The scope proposal owns the iteration's file list and presents it at the scope gate.
