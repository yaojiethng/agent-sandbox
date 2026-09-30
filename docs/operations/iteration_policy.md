# Iteration Policy

The authoritative workflow for the iteration in agent-sandbox. The iteration is the unit of work that turns a scoped sub-milestone into delivered code and a closed handover; the milestone workflow that plans it is in [`milestone_policy.md`](milestone_policy.md). The loop model is in [`autonomous_agent_loop.md`](../concepts/autonomous_agent_loop.md). Principles here are stable; the child documents that govern each subprocess will evolve as the project matures.

Read this document at the start of any iteration. Read the relevant child document before performing that subprocess.

| Phase | Step | Governing document |
|---|---|---|
| **Milestone** | 1. Close prior milestone | [`roadmap_policy.md`](roadmap_policy.md#top-level-milestone-close) -- Top-level milestone close |
| | **Gate 1** | select next milestone |
| | 2. Orient to next milestone | `roadmap.md` |
| | **Gate 2** | select sub-milestone (also entry point from roadmap maintenance when a sub-milestone closes) |
| | 3. Open or revise stories | [`story_policy.md`](story_policy.md#when-to-open-a-story) |
| | 4. Investigate or design | [`discussion_policy.md`](discussion_policy.md) |
| | 5. Resolve stories | [`discussion_policy.md`](discussion_policy.md) -- Stories |
| | **Gate 3** | release sub-milestone for execution |
| **Iteration** | 1. Open handover ... 9. Seed, with the scope gate and the release gate | [`/iter`](../../workflow/coding-agent/prompts/iter.md) runs the steps; [Iteration Invariants](#iteration-invariants) holds the rules |

## Loop workflow prompts

The workflows run as invocable runbooks under `workflow/coding-agent/prompts/` (each runbook is a workflow prompt). The procedure lives in the runbooks; this policy holds the invariants the runbooks must not break. See the ADR [`coding_agent_loop_workflow.md`](../adr/coding_agent_loop_workflow.md) for the taxonomy and the state diagram. A runbook may evolve freely as the model improves; the invariants here are the durable half.

- `/iter` -- the iteration workflow: [`iter.md`](../../workflow/coding-agent/prompts/iter.md).
- `/sequential-work` and `/parallel-work` -- the `/iter` work-loop expansions, owned by M3.2.3: [`sequential-work.md`](../../workflow/coding-agent/prompts/sequential-work.md), [`parallel-work.md`](../../workflow/coding-agent/prompts/parallel-work.md). `/auto` (smart dispatcher) and `/goal` (loose-goal decomposition) are M4's.
- `/milestone-start` -- opens a milestone: [`milestone-start.md`](../../workflow/coding-agent/prompts/milestone-start.md).
- `/milestone-close` -- closes a milestone or sub-milestone: [`milestone-close.md`](../../workflow/coding-agent/prompts/milestone-close.md).
- `/plan` -- milestone planning: [`plan.md`](../../workflow/coding-agent/prompts/plan.md).
- `/wrapup` -- the consolidated close for the active-operator prompts: [`wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md).

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

## The autonomous agent loop

The agent operates as one loop with a milestone phase and an iteration phase. The loop model, its sequence diagram, and the workflows that drive its transitions are in [`autonomous_agent_loop.md`](../concepts/autonomous_agent_loop.md). The milestone phase is governed by [`milestone_policy.md`](milestone_policy.md). The iteration phase is governed by this policy.

---

## Iteration Invariants

The iteration runs from [`/iter`](../../workflow/coding-agent/prompts/iter.md). The prompt owns the procedure: the step sequence, the entry and exit conditions, and the templates. This section holds the invariants the procedure must not break -- the state the repository must be in at every point a commit lands. It is organized by invariant, not by procedure step: the procedure in `/iter` may evolve, and the invariant set below should not change when the runbook changes, only when the system is redesigned.

**Decoupling principle.** The runbook and the invariants are independent layers. The runbook is expected to evolve as the model improves. The invariant set below should be insensitive to runbook changes: a change to `/iter` should never *require* a change here. Improving the invariant set is welcome and autonomous; what signals coupling is not that it was edited, but *why* -- an edit forced by a runbook rename or renumber is entanglement, while an edit stating a better durable rule is healthy evolution.

**Two forms of rule.** Policy may state an invariant (a property of the state, holding at every commit gate) or a canonical procedure (a deterministic code-block guaranteed to satisfy an invariant). A loose procedure -- one with a large agent-decision space where the shape is not canonical -- is not stated here; it lives in `/iter` and references these invariants rather than restating them.

### Unit and scope invariants

- **One iteration, one unit.** One iteration is one roadmap task, scoped as one vertical slice, landed as one commit with one handover. Propose no split by default. A slice crosses file kinds and directories, so a policy file, a template and a record that serve one outcome form one unit. **Split:** each part delivers an outcome of its own, closes on its own handover, and leaves the repository working after it lands; the scope proposal carries a work-unit table -- the unit, its commit type, the owned files, the handover -- released at the scope gate. **Consolidate:** no part delivers an outcome of its own; such a part is work inside one unit. The work-unit table an autonomous run's proposal carries is defined in [`sequential-work.md`](../../workflow/coding-agent/prompts/sequential-work.md). The review cadence does not change the unit count: a policy change released one section at a time is one iteration.
- **No output before scope is confirmed.** The scope gate applies to every iteration type without exception. For housekeeping iterations, a target file list and the nature of the change is a sufficient scope proposal -- the gate still applies.
- **The scope gate confirms understood intent.** The agent restates the operator's goal and the problem the work solves before presenting the formal gate, so the gate confirms that the agent understood the intent rather than re-presenting the request.
- **Context sufficiency.** If context is insufficient for a scope proposal (key files missing, roadmap task list unclear, prior handover not available), the agent does not guess at scope; it asks the operator one question at a time until a proposal can be made, then the scope gate presents it.
- **Purpose reconciliation.** Before presenting the scope proposal at the scope gate -- which also carries the acceptance criteria -- check the expressed purpose of the iteration against the current tree: a purpose may already be silently resolved by landed work (fixes, tests, skills, docs) that no record claims. If so, surface it; the scope becomes recording or retiring the existing resolution, not re-implementing it.
- **Multi-iteration sessions.** When a session contains multiple iterations, write the detailed per-step implementation plan only for the active iteration. The handover may list all iterations for orientation. Do not write iteration N+1's plan or its dependencies until iteration N's output is confirmed.
- **Handover Scope section.** The Scope section of the handover reflects the confirmed scope before the iteration proceeds.
- **Release is explicit where a decision is required.** Some steps require explicit operator release and some run without it; the release-gate invariant fixes where a release is required. The runbook attaches the release requirement to a step; the policy does not enumerate which steps.

### Gate invariants

- **Two gates.** The iteration has two gates: the **scope gate** and the **release gate**. The scope gate confirms scope and acceptance criteria together on a single operator approval. The release gate is the common acceptance gate the operator-involved workflows share, and after its release the close hands off to [`/wrapup`](../../workflow/coding-agent/prompts/wrapup.md) Part B.
- **Gates stop for explicit operator release.** Each gate stops the loop until the operator sends a forward signal. A message that reviews output without a clear forward signal does not release a gate. Packaging changes (`/package-branch`) do not release the release gate -- iteration-end actions do not begin until the operator explicitly confirms after testing.
- **AC satisfiability.** Every criterion is re-read and verified satisfiable given the confirmed scope; a criterion that would fail on a correct implementation is a specification bug -- resolve it now, not at pre-close.

### Acceptance-criteria invariants

- **Acceptance criteria describe a delta.** An AC is an observable change -- verified by running the system, never by reading source alone. See Principles.
- **Universal preconditions are not ACs.** Universal preconditions (`make test passes clean`, `bash -n passes`) gate every iteration equally and add no iteration-specific information. Omit them from the AC table; verify them as prerequisites before pre-close instead.
- **Criteria the agent cannot verify** -- manual review, head -N, operator-only access -- are marked `Operator`; criteria with a runnable command are marked `Agent [x]` (pass) or `Agent [ ]` (fail, expected in pre-state).
- **The `Not yet defined.` marker is replaced before implementation.** The handover is the canonical location for acceptance criteria; a criterion left as `Not yet defined.` when the scope gate releases is not confirmed.

### Record-state invariants

- **Record decisions live.** A decision is recorded in the handover's Decisions table as it is made, with the document where it was recorded. If a decision is only in chat, it does not exist for the next iteration.
- **Write Findings immediately.** A bug, contradiction, design gap, blocker, or new file entering scope goes to Findings at once -- not accumulated.
- **Open exchanges are recorded before the next commit.** An exchange is a conversation with the operator whose result is not yet resolved. Write its results to a record before committing: the iteration's handover when the exchange resolves inside the iteration, a `devlog/discussions/` record when it opens its own question. Until the iteration closes the record is provisional; commit it as `wip:` per [`git_policy.md`](git_policy.md#transient-commits-fold-into-the-delivery-commit).
- **Verify record writes landed.** When announcing a record write (a finding row, a decision, a task, a roadmap row), grep the row key or content claimed. A claimed record that is not verified to exist is a record defect: the write is not done until the grep finds it.
- **Record a document-relevant change when you make it.** Record a change to an invariant, interface, or contract when you make it, not at iteration close. If the record waits for close, a stale document governs the work in the meantime.
- **Findings is the shared agent-managed recording surface.** Entries are classified at the review/publish step at iteration end. Attribution is operator-owned; the agent proposes a class and the operator confirms it.

### Close invariants

- **Close produces one commit.** At iteration end the iteration is a single commit carrying the work, the handover marked `Closed`, and the roadmap write-back. Every transient commit (`wip:` checkpoints, corrections) and the `Status: Closed` edit fold into it. The commit message matches the iteration type per [`git_policy.md`](git_policy.md). Milestone-close bookkeeping -- compaction, changelog, and promotion -- types `plan`.
- **Scope reconciliation.** Compare the confirmed scope against the Completed table. Every item that was in scope but is not in Completed must appear in Deferred items. There must be no unaccounted items.
- **Carry-forward resolution.** Every Carried forward item must have a resolution: completed (in Completed table), re-deferred (in Deferred items with reason), or escalated to the roadmap (a named entry). A carried-forward item in none of the three is dropped -- find it and triage it.
- **Findings review/publish.** Route each Findings entry to its destination: the Decisions table, Deferred items, What's Next (via Carried forward), `roadmap.md` (via a named task entry), or [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md). Class A (agent experience, friction, poor stack design, poor operator prompting) is tagged `[A]`. Class B (recurring agent mistakes and code smells) is tagged `[O]`. Class C (steering, scope, blockers, technical findings) goes to the existing destinations. The `[A]`/`[O]` tag names who raised the entry. **Attribution is operator-owned.** The agent proposes a class; the operator confirms it. The agent does not classify its own mistakes as another party's. The Findings section must be empty or contain only entries with a `Triaged to:` annotation before the handover can be closed.
- **Propagation replay.** When the iteration applied a naming rule, structural rule, or interface change across more than two files, or produced an explicit file table, or used "all", "every", "throughout", or "wherever X appears", a row-by-row replay is required: `file | change planned | status`. Every row carries `completed`, `deferred`, or `not started`; every row must be accounted for before the release gate releases: `completed`, or `deferred`/`not started` with the row in Deferred items. When a replay is not required, the summary still covers what was built, tests produced, AC status per criterion, and recommended manual checks.
- **Scope amendment.** If any implementation gap discovered this iteration affects the scope -- missing flag, unspecified behaviour, ambiguous fixture approach -- amend the scope before closing. Do not leave scope gaps for the next iteration to re-derive.
- **Seed what's next.** Populate What's Next as source material for the next iteration's orientation, not a continuation directive: the next agent creates its own handover before acting on anything written here. Deferred items take priority when identifying the next iteration's scope. If a completed sub-milestone was the last in the major milestone, write "/milestone-close required before next iteration".

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

A sub-milestone follows the sequence `active -> pre-close -> close`. The close procedure runs from [`/milestone-close`](../../workflow/coding-agent/prompts/milestone-close.md).

- A sub-milestone is `active` while substantive work is in progress.
- A sub-milestone is `pre-close` when its implementation is complete.
- A sub-milestone is `close` when its close completes. At close, no new decisions are made. Substantive work does not occur after close.

**Probation decisions are operator-owned.** For an entry under `probation` in `devlog/AGENT_FEEDBACK.md`, the operator decides dismiss / maintain / escalate. The agent does not decide a probation entry. Escalation of far-reaching correctness work defers the sub-milestone close until the escalated work is complete. Low-urgency escalation is filed as a named task at the top of the next sub-milestone. There is no dedicated `close-blocked` state; a deferred close keeps the sub-milestone `active` until pre-close passes.

---

## File Tracking

There is no document registry. The docs tree itself is the authoritative file list. The iteration-scoped list is the active handover's Hot files section, governed by [`handover_policy.md`](handover_policy.md).

---

## Child Documents

| Document | Governs |
|---|---|
| [`milestone_policy.md`](milestone_policy.md) | Milestone workflow: milestone planning, story and investigation process |
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
