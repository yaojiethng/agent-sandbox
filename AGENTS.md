# AGENTS.md - agent-sandbox

## Scope

You are working on the project **agent-sandbox**. These are the working directories you should use.

| Directory | What is there |
|---|---|
| `/home/agentuser/sandbox/` | the project working tree: `docs/`, `devlog/`, `scripts/`, `tests/`, `src/`, `workflow/`, and this file |
| `/home/agentuser/sandbox/.scratchpad/` | the session-local scratch, inside the working tree: state a `/fork` or `/tree` must carry across, such as the active task tracker. It lasts the session and no longer. |

This file is loaded second, after `$AGENT_HOME/agent/AGENTS.md`. If you are asked to edit either `AGENTS.md`, read [`instruction-surface-conventions.md`](docs/development/instruction-surface-conventions.md#the-layers) first: it states where a section belongs and what an edit to either file must do.

## System

**agent-sandbox** is a containerized sandbox and orchestration harness for running autonomous coding agents safely. Agents execute and commit inside containers, output is exported as a draft branch, and a human operator reviews and merges. The agent runtime is explicitly untrusted. See your provider-layer AGENTS.md for the two-layer container architecture.

## Constraints

Run throwaway verification in `.scratchpad/`, the session-local scratch, never elsewhere in the repo tree. `.scratchpad/` is gitignored, so a stray file there does not surface in `git status` or pollute the diff. A throwaway file is any file you create only to check something and do not keep; an instrument a later session has to reuse is not throwaway, and where each kind belongs is the [`write-locations`](/opt/workflow/agent/skills/write-locations/SKILL.md) skill.

**Git hygiene.** [`.agents/skills/git-discipline/SKILL.md`](.agents/skills/git-discipline/SKILL.md) is the git-hygiene document: the commit message, the commit types, the branch names, the fold rules, and the names of the git maintenance runbooks. It is the stopgap home for git hygiene until that work has a module of its own; [`docs/adr/coding_agent_project_bindings.md`](docs/adr/coding_agent_project_bindings.md) records that git is currently an available tool, not a module.

**Output is complete and ready for review when:** a single branch, one commit per iteration plus corresponding handover, type prefix per the `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`. Intermediate `wip:` and correction commits during the iteration are free-form; `wip:` commits squash into the delivery commit at iteration end. Only the delivery commit at iteration end is subject to format enforcement.

## Collaboration Protocol

These principles are stable. The operating workflow and policy documents are their realisations -- they will evolve; the principles do not.

**State assumptions explicitly.** State them before proceeding, not after.

**Diagnose before fixing.** Explain the root cause and confirm your understanding before proposing a fix.

**Scope discipline.** Address what was asked. An issue inside the artifact you are changing is a carrier, not an adjacent issue: a reference to the thing you just deleted is part of the deletion. An issue outside that artifact is flagged, never fixed silently.

**Propagation is part of the task.** A change is not done while a carrier still asserts the old state. See the [`principle-propagation-discipline`](src/reasoning/providers/pi/config/agent/skills/principle-propagation-discipline/SKILL.md) skill before declaring such a change complete.

**One question at a time.** Ask the most important question first. Before asking anything, check whether the answer is already present in the context you have -- a question is only warranted if it genuinely cannot be resolved from what is available.

**Context-aware numbering.** The numbering rule is the project convention [`.agents/skills/numbering/SKILL.md`](.agents/skills/numbering/SKILL.md): a number for an ordered unit, an identity code for an unordered one, and grouped chat labels so one token names one item. A chat item that becomes a durable artifact is stated, not labelled.

**Flag violations before editing.** Check a document against relevant rules before touching it.

**Distinguish current from proposed.** Never blur the description of the existing system with a proposal for change.

**Decisions are final.** Do not re-open a decision without a specific technical reason.

**No restatement of completed work.** Reference by name only.

**Keep tests green docs up-to-date.** After completing a change, always ensure changes are propagated to features and tests

## Propagation Discipline

When a task applies a change across multiple files -- a naming rule, a structural convention, an interface rename, a container label, a variable -- produce a propagation checklist before writing the first file, show it in chat, and confirm every row before declaring the task complete. The trigger list, the format, and the audit that verifies coverage are in the [`propagation-check`](src/reasoning/agent/skills/propagation-check/SKILL.md) skill.

## Instruction Surface

What is read before any work starts is the two `AGENTS.md` files and one line per skill and per prompt; everything else is read only when a file is opened. That index has grown faster than the corpus it indexes, so it is the budget this section governs.

- **The index is the budget.** A description is one trigger sentence. A subject that needs a paragraph to be found is a subject that needs narrowing, not a longer description.
- **Rules live where the work happens.** A rule is stated once, in the file a reader is already in when they need it, and cited from everywhere else. A rule reachable only by search is a routing defect.
- **The check, not the story.** An instruction says what to do and how that is verified. Rationale stays only where a reader would otherwise take the wrong action; history belongs in `devlog/`.
- **Add by replacing.** A rule, skill, prompt or reference document lands with the removal of something of comparable size in the same commit, or one sentence naming why nothing can be removed.
- **A budget is a number.** The gate behind this section holds the caps for the two files and for descriptions and fails the tree past them.

## Feedback and Gotchas Record

- [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) -- the single living record of the coding agent's experience and recurring mistakes. Entries are tagged `[A]` (raised by the agent) or `[O]` (raised by the operator). Reviewed by the operator. Before writing an entry, grep the file for an existing entry on the same topic; record a recurrence on that entry (re-open it, note the prior fix in `legacy:`) instead of creating a new one. The agent surfaces open entries to the operator at the sub-milestone pre-close review gate.

Bash friction is one class of that record, held in its `## Bash` section: consult it when diagnosing unexpected shell behaviour or weighing a workaround, and take the canonical rule from the [`code-review-bash/patterns/`](workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/) entry a finding cites by id.

This file is tied into the iteration's Findings for recording and into the sub-milestone pre-close review gate for reconciliation.

## Model Recommendations

The role table is [model-recommendations.md](.agents/model-recommendations.md), committed with this repository, so a model change is an ordinary reviewable edit. Its values are the operator's, and the harness only resolves them.

The roles are `_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR_CODE`, `_ADVISOR_DOCS`, and `_ORCHESTRATOR`. An advisor takes the role of the artifact it reviews: source code, tests and configuration take `_ADVISOR_CODE`, and prose takes `_ADVISOR_DOCS`. `_ROLE` in a prompt template shows where the dispatcher substitutes the assigned tag, for example `_REVIEWER`. Every dispatch names a role; one that fits no role uses the `_IMPLEMENTER` line.

The table wins. When a task needs something it cannot give, stop and ask. Do not leave it for a preference, and do not compose an assignment from `pi --list-models`.

The resolver, the invocation and the failure rules belong to the `dispatch` skill. It reads this table, and a dispatch never names a model of its own.

## Output Format

Agent output is complete and ready for review when it follows the format rules below. The operator reviews, approves, and commits. Use the mechanism appropriate to the interface -- see `$AGENT_HOME/agent/AGENTS.md` for interface-specific output instructions.

Every output class -- chat, prompts, documentation, roadmap items, code comments -- meets the Communication Standards in `$AGENT_HOME/agent/AGENTS.md`, which indexes the `communication-principle-*` corpus.

**Documents** -- Markdown, one file per document, correct folder and header per the `docs` convention, `.agents/skills/docs/SKILL.md`. Drafting rule: skeleton first for an ADR, a concept document or an architecture document -- propose the section skeleton in chat and confirm before writing prose.

**Governance documents** (policy files, AGENTS.md, operational docs) -- propose changes one section at a time via chat. Present the new or changed text, explain the rationale, and wait for confirmation before writing. Do not batch multiple sections into one proposal unless they are logically inseparable.

**Work unit and iteration scoping.** One iteration is one roadmap task, scoped as one vertical slice and landed as one commit with one handover. Propose no split by default. When one slice cannot deliver the task's outcome, name the handling method you propose:

- **Split.** Each part delivers an outcome of its own. Carry a work-unit table in the scope proposal and release it at the scope gate.
- **Consolidate.** No part delivers an outcome of its own. Such a part is work inside one unit.

See [`docs/reference/iteration_protocol.md`](docs/reference/iteration_protocol.md) for the criteria and the close mechanics.

**Code** -- Consistent with the existing provider structure under `providers/`. Language and style conventions are established incrementally.

**Audit findings** -- Identify the document or code, state the rule violated, propose the correction.

**Code comments** -- Comments must describe what the code does or why -- never that it was changed. The following are banned in all code output: `# (Change N)`, `# Updated`, `# Fixed`, `# Modified`, `# Added`, `# Removed`, `# As requested`, and any comment that only makes sense in the context of an editing session. Do not reference transient numbering in a comment, for example a roadmap item position or a finding number. Name the change or link the document instead.

## Missing Documents

If a required document is absent and carries no `[REMOVED]` marker on its referencing link, flag it as an error and prompt the operator before proceeding. Do not assume the document is optional. Do not proceed without resolution.

If a document's referencing link is marked `[REMOVED]`, the absence is expected -- no error.

## Iteration Lifecycle

A design settles an incomplete milestone first, per the roadmap's `Depends on:` lines. The iteration -- handover first, scope confirmation, design, implementation, pre-close verification, close and seed -- is defined in [`docs/reference/iteration_protocol.md`](docs/reference/iteration_protocol.md), and the unit rule and the work-unit table are in the same file. The project's [`.agents/skills/work-log/SKILL.md`](.agents/skills/work-log/SKILL.md) holds the handover's shape and structure, the Roadmap as the sole task list in the project's [`.agents/skills/task-list/SKILL.md`](.agents/skills/task-list/SKILL.md) convention, the commit and delivery rules in the `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`, and the Markdown lint gate in [`doc-maintenance`](workflow/coding-agent/skills/doc-maintenance/SKILL.md) `## The lint rule set`. Every gate requires explicit operator release, and the pre-close summary (per `/iter` Step 7) includes the Roadmap write-back row governed by the [iteration-policy close invariants](docs/reference/iteration_protocol.md#iteration-invariants).

The operator signalling a new iteration -- by saying "new iteration", "next iteration", or by re-scoping the current work -- opens the handover (Open handover, per [`iteration_protocol.md`](docs/reference/iteration_protocol.md)) before any further output.

**Handover rules.** Type the handover from the dominant activity at close, and rename it if that diverged. Give an implementation its own handover; a design handover does not cover implementation commits, per [`docs/reference/iteration_protocol.md`](docs/reference/iteration_protocol.md). Mark a roadmap task `- [x]` in the same iteration its resolving handover closes, per the project's [`.agents/skills/task-list/SKILL.md`](.agents/skills/task-list/SKILL.md) convention.

### Loop prompts

The runbooks the loop runs, each seeded into the container. The list is the `scope` of [`docs/reference/iteration_protocol.md`](docs/reference/iteration_protocol.md), which holds the invariants each runbook must not break.

| Prompt | Runs from |
|---|---|
| `/iter` | [`iter.md`](workflow/coding-agent/prompts/iter.md) |
| `/sidequest` | [`sidequest.md`](workflow/coding-agent/prompts/sidequest.md) |
| `/milestone-start` | [`milestone-start.md`](workflow/coding-agent/prompts/milestone-start.md) |
| `/milestone-close` | [`milestone-close.md`](workflow/coding-agent/prompts/milestone-close.md) |
| `/plan` | [`plan.md`](workflow/coding-agent/prompts/plan.md) |
| `/scope` | [`scope.md`](workflow/coding-agent/prompts/scope.md) |
| `/document` | [`document.md`](workflow/coding-agent/prompts/document.md) |
| `/wrapup` | [`wrapup.md`](workflow/coding-agent/prompts/wrapup.md) |
| `/commit` | [`commit.md`](workflow/coding-agent/prompts/commit.md) |

## Iteration Start

Read these in order. Each answers a distinct question -- do not skip. Verify you have access to each before proceeding.

### Always

| Document | Question it answers |
|---|---|
| `AGENTS.md` (this file) | How do I work here? |
| `$AGENT_HOME/agent/AGENTS.md` | What can I do in this specific interface? |
| `YYYYMMDD-NN-TYPE-*.md` (most recent) | What milestone am I on, what files are in scope, and where did the last iteration end? |
| [`devlog/roadmap.md`](devlog/roadmap.md) | What is the current sub-milestone and what are the pending tasks? -- after reading, state your proposed scope and wait for confirmation before producing any output |

### Milestone planning

Read these in addition to the above when opening a milestone planning iteration.

| Document | Question it answers |
|---|---|
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | What sub-milestones are planned but not yet active? |
| [`devlog/changelog.md`](devlog/changelog.md) | Is the prior milestone fully closed? |

### Policy documents and convention-skills - read before the relevant task type, not at iteration start

| Document | Read before |
|---|---|
| [`docs/reference/system_overview.md`](docs/reference/system_overview.md) | Architecture layer boundary or freeze status checks |
| [`.agents/skills/docs/SKILL.md`](.agents/skills/docs/SKILL.md) | Any documentation task |
| [`.agents/skills/task-list/SKILL.md`](.agents/skills/task-list/SKILL.md) | Any roadmap update |
| [`docs/reference/iteration_protocol.md`](docs/reference/iteration_protocol.md) | Any iteration start or end, new task, story, investigation, or milestone transition |
| [`.agents/skills/work-log/SKILL.md`](.agents/skills/work-log/SKILL.md) | Any iteration start or end, creating or updating a handover or a record in `devlog/discussions/` |
| [`.agents/skills/decision-records/SKILL.md`](.agents/skills/decision-records/SKILL.md) | Creating or superseding an ADR in `docs/adr/` |
