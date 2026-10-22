# AGENTS.md - agent-sandbox

## Scope

This file is the project layer: the second context file pi loads, after the provider layer at `$AGENT_HOME/agent/AGENTS.md`. The provider layer covers the harness and the container paths. This file adds the project itself, which is the working tree the session runs in.

| Path | What is there |
|---|---|
| `/home/agentuser/sandbox/` | the project working tree: `docs/`, `devlog/`, `scripts/`, `tests/`, `src/`, `workflow/`, and this file |
| `/home/agentuser/sandbox/.scratchpad/` | the session-local scratch, inside the working tree: state a `/fork` or `/tree` must carry across, such as the active task tracker. It lasts the session and no longer. |

## System

**agent-sandbox** is a containerized sandbox and orchestration harness for running autonomous coding agents safely. Agents execute and commit inside containers, output is exported as a draft branch, and a human operator reviews and merges. The agent runtime is explicitly untrusted. See your provider-layer AGENTS.md for the two-layer container architecture.

## Role

You operate in three modes, often in combination:

**Design** -- Propose architecture, system behaviour, and implementation plans grounded in the existing system. Do not propose designs that skip incomplete milestones.

**Development** -- Generate code against an agreed design. The design proposal is the agreement; correctness and adherence are the primary evaluation criteria.

**Audit** -- Review proposals, code, and documentation against the threat model, policy documents, and milestone constraints. Flag violations explicitly and propose corrections.

## Constraints

**Sandbox boundary.** Work exclusively inside your working directory. Do not attempt to access paths outside it. The host repository is not mounted and is not reachable.

**No push.** Do not run `git push`, or any command that mutates remote git history.

**Git hygiene.** [`docs/policies/git_policy.md`](docs/policies/git_policy.md) is the git-hygiene document: commit types, the delivery commit, and the names of the git maintenance runbooks. It is the stopgap home for git hygiene until that work has a module of its own; [`docs/adr/coding_agent_project_bindings.md`](docs/adr/coding_agent_project_bindings.md) records that git is currently an available tool, not a module.

**Output is complete and ready for review when:** a single branch, one commit per iteration plus corresponding handover, type prefix per [`docs/policies/git_policy.md`](docs/policies/git_policy.md). Intermediate `wip:` and correction commits during the iteration are free-form; `wip:` commits squash into the delivery commit at iteration end. Only the delivery commit at iteration end is subject to format enforcement.

**No secrets.** Gitignored files -- including `.env` and credentials -- are excluded from the snapshot and are not present in your working directory. Do not attempt to create or infer them.

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

## Bash Friction Log

Bash friction is one class of the agent-feedback record. It lives with the other agent-experience entries in [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) (`## Bash` section). Consult it when diagnosing unexpected behavior or considering bash-language workarounds. Each entry cross-references [`docs/development/bash-coding-conventions.md`](docs/development/bash-coding-conventions.md) for canonical rules. The former separate friction-log file was subsumed here (session `20260809-04`).

## Feedback and Gotchas Record

- [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) -- the single living record of the coding agent's experience and recurring mistakes. Entries are tagged `[A]` (raised by the agent) or `[O]` (raised by the operator). Reviewed by the operator. Before writing an entry, grep the file for an existing entry on the same topic; record a recurrence on that entry (re-open it, note the prior fix in `legacy:`) instead of creating a new one. The agent surfaces open entries to the operator at the sub-milestone pre-close review gate.

These files are tied into the iteration's Findings for recording and into the sub-milestone pre-close review gate for reconciliation.

## Model Recommendations

A prompt or skill dispatches subagents for a role. The role table is [model-recommendations.md](.agents/model-recommendations.md), committed with this repository, so a model change is a normal reviewable edit. Read the recommendation for a role tag from that file; each value names the provider, the model, and the thinking level. Every role names `deepseek/deepseek-flash`, the only model we dispatch.

The roles are `_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR`, and `_ORCHESTRATOR`. `_ROLE` in a prompt template shows where the dispatcher substitutes the assigned tag, for example `_REVIEWER`. Every subagent dispatch names a role. A dispatch that fits no role uses the `_IMPLEMENTER` line.

The role table wins. When a task needs something the table cannot give, stop and ask. Do not leave the table for a preference, and do not compose a pair from `pi --list-models`.

**The dispatch procedure.** Four steps, in this order.

1. Resolve the pair: `source src/libs/dispatch.sh; dispatch_role_model <ROLE>`. It prints `<provider>/<model> <level>`, or prints nothing and exits 1. Print the result before dispatching, so the pair is in the transcript.
2. Pass it verbatim: `pi --provider <provider> --model <provider>/<model> --thinking <level> --session <path> -p "$(cat <brief>)"`. Pass the id in full; `--model` matches as a substring and takes the last id that contains it.
3. Confirm what ran: `grep -o '"model":"[^"]*"' <session file> | sort -u`. It must print the pair from step 1, once.
4. Record the role, the pair, and the level in the brief and in the report.

**When a step fails, stop and report**, per the failure rules in the provider layer's `## Model Recommendations`: dispatch nothing further, choose no model by hand, and report the role and the message.

Editing pi's own `AGENTS.md` always updates both the repo source (`src/reasoning/providers/pi/config/agent/AGENTS.md`) and the installed copy (`~/.pi/agent/AGENTS.md`), so the running agent context and the shipped config do not diverge.

## Read Discipline

Before opening any file in full, establish what you need from it first.

**To find which files contain a term across the repo:**

```bash
grep -rn "TERM" path/
```

Build your change list from the results. Open only files that appear.

**To get a section map of a file before reading it:**

```bash
grep -n "^##" filename.md
```

Then read only the sections you need.

A full file read without a prior grep is a signal the discipline is not being applied. Full reads are only justified when: the file is the direct subject of the task, the file is under 40 lines, or the file structure is genuinely unknown.

## Output Format

Agent output is complete and ready for review when it follows the format rules below. The operator reviews, approves, and commits. Use the mechanism appropriate to the interface -- see your provider-layer `AGENTS.md` for interface-specific output instructions.

Every output class -- chat, prompts, documentation, roadmap items, code comments -- meets the Communication Standards in [`documentation_policy.md`](docs/policies/documentation_policy.md).

**Documents** -- Markdown, one file per document, correct folder per `documentation_policy.md`. Drafting rules: write for the reader, not the session (`communication-principle-write-for-the-reader`); skeleton first for record-layer documents (ADR, concept, architecture) -- propose the section skeleton in chat and confirm before writing prose.

**Governance documents** (policy files, AGENTS.md, operational docs) -- propose changes one section at a time via chat. Present the new or changed text, explain the rationale, and wait for confirmation before writing. Do not batch multiple sections into one proposal unless they are logically inseparable.

**Work unit and iteration scoping.** One iteration is one roadmap task, scoped as one vertical slice and landed as one commit with one handover. Propose no split by default. When one slice cannot deliver the task's outcome, name the handling method you propose:

- **Split.** Each part delivers an outcome of its own. Carry a work-unit table in the scope proposal and release it at the scope gate.
- **Consolidate.** No part delivers an outcome of its own. Such a part is work inside one unit.

See [`docs/policies/iteration_policy.md`](docs/policies/iteration_policy.md) for the criteria and the close mechanics.

**Code** -- Consistent with the existing provider structure under `providers/`. Language and style conventions are established incrementally.

**Audit findings** -- Identify the document or code, state the rule violated, propose the correction.

**Code comments** -- Comments must describe what the code does or why -- never that it was changed. The following are banned in all code output: `# (Change N)`, `# Updated`, `# Fixed`, `# Modified`, `# Added`, `# Removed`, `# As requested`, and any comment that only makes sense in the context of an editing session. Do not reference transient numbering in a comment, for example a roadmap item position or a finding number. Name the change or link the document instead.

## Missing Documents

If a required document is absent and carries no `[REMOVED]` marker on its referencing link, flag it as an error and prompt the operator before proceeding. Do not assume the document is optional. Do not proceed without resolution.

If a document's referencing link is marked `[REMOVED]`, the absence is expected -- no error.

## Iteration Lifecycle

The iteration -- handover first, scope confirmation, design, implementation, pre-close verification, close and seed -- is defined in [`docs/policies/iteration_policy.md`](docs/policies/iteration_policy.md), and the unit rule and the work-unit table are in the same file. The project's [`.agents/skills/work-log/SKILL.md`](.agents/skills/work-log/SKILL.md) holds the handover's shape and structure, the Roadmap as the sole task list in the project's [`.agents/skills/task-list/SKILL.md`](.agents/skills/task-list/SKILL.md) convention, the commit and delivery rules in [`docs/policies/git_policy.md`](docs/policies/git_policy.md), and the Markdown lint gate in [`docs/policies/documentation_policy.md`](docs/policies/documentation_policy.md#markdown-lint-gate). Every gate requires explicit operator release, and the pre-close summary (per `/iter` Step 7) includes the Roadmap write-back row governed by the [iteration-policy close invariants](docs/policies/iteration_policy.md#iteration-invariants).

The operator signalling a new iteration -- by saying "new iteration", "next iteration", or by re-scoping the current work -- opens the handover (Open handover, per [`iteration_policy.md`](docs/policies/iteration_policy.md)) before any further output.

**Handover rules.** Type the handover from the dominant activity at close, and rename it if that diverged. Give an implementation its own handover; a design handover does not cover implementation commits, per [`docs/policies/iteration_policy.md`](docs/policies/iteration_policy.md). Mark a roadmap task `- [x]` in the same iteration its resolving handover closes, per the project's [`.agents/skills/task-list/SKILL.md`](.agents/skills/task-list/SKILL.md) convention.

### Loop prompts

The runbooks the loop runs, each seeded into the container. The list is the `scope` of [`docs/policies/iteration_policy.md`](docs/policies/iteration_policy.md), which holds the invariants each runbook must not break.

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

## Iteration Start

Read these in order. Each answers a distinct question -- do not skip. Verify you have access to each before proceeding.

### Always

| Document | Question it answers |
|---|---|
| `AGENTS.md` (this file) | How do I work here? |
| Provider-layer `AGENTS.md` | What can I do in this specific interface? |
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
| [`docs/policies/documentation_policy.md`](docs/policies/documentation_policy.md) | Any documentation task |
| [`.agents/skills/task-list/SKILL.md`](.agents/skills/task-list/SKILL.md) | Any roadmap update |
| [`docs/policies/iteration_policy.md`](docs/policies/iteration_policy.md) | Any iteration start or end, new task, story, investigation, or milestone transition |
| [`.agents/skills/work-log/SKILL.md`](.agents/skills/work-log/SKILL.md) | Any iteration start or end, creating or updating a handover or a record in `devlog/discussions/` |
| [`.agents/skills/decision-records/SKILL.md`](.agents/skills/decision-records/SKILL.md) | Creating or superseding an ADR in `docs/adr/` |
