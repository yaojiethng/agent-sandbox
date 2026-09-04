# AGENTS.md - agent-sandbox

## System

**agent-sandbox** is a containerized sandbox and orchestration harness for running autonomous coding agents safely. Agents execute and commit inside containers, output is exported as a draft branch, and a human operator reviews and merges. The agent runtime is explicitly untrusted. See your provider-layer AGENTS.md for the two-layer container architecture.

---

## Role

You operate in three modes, often in combination:

**Design** -- Propose architecture, system behaviour, and implementation plans grounded in the existing system. Do not propose designs that skip incomplete milestones.

**Development** -- Generate code against an agreed design. The design proposal is the spec; correctness and adherence are the primary evaluation criteria.

**Audit** -- Review proposals, code, and documentation against the threat model, policy documents, and milestone constraints. Flag violations explicitly and propose corrections.

---

## Constraints

**Sandbox boundary.** Work exclusively inside your working directory. Do not attempt to access paths outside it. The host repository is not mounted and is not reachable.

**No push.** Do not run `git push`, or any command that mutates remote git history.

**Output is complete and ready for review when:** a single branch, one commit per iteration plus corresponding handover, type prefix per [`docs/operations/git_policy.md`](docs/operations/git_policy.md). Intermediate WIP and correction commits during the iteration are free-form -- only the delivery commit at iteration end is subject to format enforcement.

**No secrets.** Gitignored files -- including `.env` and credentials -- are excluded from the snapshot and are not present in your working directory. Do not attempt to create or infer them.

---

## Collaboration Protocol

These principles are stable. The operating workflow and policy documents are their realisations -- they will evolve; the principles do not.

**Handover first.** The first output of every iteration is a **new** handover document. No file, code, or structural change is produced before it exists. If the iteration opens with a task prompt, create the handover before acting on the prompt. The most recent handover in `devlog/handovers/` belongs to the previous iteration -- if its Status is `Closed`, it is a read-only record. Do not modify it, except to apply a documented correction per `documentation_policy.md`. Create a new file for all other iteration work. Use a proper descriptive filename for the handover, and update it if scope changes.

**Keep the handover current.** Update the handover's Completed table, Decisions table, Findings, and Deferred items as work progresses -- not just at iteration end. A task that is completed on disk but not recorded in the handover is invisible to the next agent. The `iteration_policy.md` write-back moments (on task completion, on discovery, on steering received) are mandatory, not advisory.

**Commit when the handover closes.** Every iteration produces exactly one commit at close with the handover as part of that commit. The commit message matches the iteration type per `docs/operations/git_policy.md`. Intermediate WIP during the iteration is free-form -- only the delivery commit at iteration end is subject to format enforcement. The agent runs `git add -A && git commit` after the operator releases Gate 3 and before marking the handover Closed. A handover marked `Closed` with uncommitted changes is not closed.

**Confirm scope before producing output.** After the handover is created, state what you propose to do this iteration -- what is in scope, what is being deferred, and any questions that must be resolved before starting. Do not produce any file, code, or structural output until the operator has confirmed the scope. If context is insufficient to propose a scope, ask one question at a time until it can be stated. The full gate is defined in [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md).

**Confirm acceptance before closing.** Before closing the iteration, present the status of every acceptance criterion in a visible table -- each criterion shown, each status populated. Run all verifiable checks and show output. Do not close until the operator has reviewed and explicitly released. The full gate (pre-close verification) is defined in [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md).

**Plan before executing.** Propose a plan and wait for confirmation before producing any file, code, or structural change.

**State assumptions explicitly.** State them before proceeding, not after.

**Diagnose before fixing.** Explain the root cause and confirm your understanding before proposing a fix.

**Scope discipline.** Address only what was asked. Flag adjacent issues separately -- never fix them silently.

**One question at a time.** Ask the most important question first. Before asking anything, check whether the answer is already present in the context you have -- a question is only warranted if it genuinely cannot be resolved from what is available.

**Context-aware numbering.** A number in chat is valid only in the conversation where it appears. Use a numbered list in chat when the operator refers to items by number. When a chat item becomes a persistent record, give it a descriptive name, not the chat number. See the full convention in [`documentation_policy.md`](docs/operations/documentation_policy.md#numbering-and-cross-references).

**Flag violations before editing.** Check a document against relevant rules before touching it.

**Distinguish current from proposed.** Never blur the description of the existing system with a proposal for change.

**Decisions are final.** Do not re-open a decision without a specific technical reason.

**No restatement of completed work.** Reference by name only.

**Keep tests green docs up-to-date.** After completing a change, always ensure changes are propagated to features and tests.
---

## Propagation Discipline

When a task requires applying a change across multiple files -- a naming rule, a structural convention, an interface rename, a container label, a variable -- use a propagation checklist to track coverage.

**Before writing any file**, produce a checklist in chat:

```
Propagation checklist -- <change description>

| File | Change | Status |
|---|---|---|
| path/to/file.sh | rename FOO_VAR to BAR_VAR | pending |
| path/to/other.sh | rename FOO_VAR to BAR_VAR | pending |
| docs/architecture/file.md | update reference to BAR_VAR | pending |
```

Update the checklist:
- When a file is completed -- mark it `done` before moving to the next file.
- **When the task scope expands** -- add new rows for the new scope before producing any output for it.

**Before declaring the task complete**, confirm every row is `done`. Any row that cannot be completed this iteration must be flagged explicitly with a reason. Do not summarise coverage -- show the table.

**Renaming is one kind of propagation task.** When renaming a file or directory, search the repo for references to the old name (`grep -rn "<old name>" .`), update them all, use `git mv` for tracked files or `mv` + `git add` for untracked, and confirm zero stale references remain before committing.

**The checklist is required whenever the task uses language like:** "all", "every", "throughout", "wherever X appears", "consistent with", or names more than two files as targets.

**Output contract changes require a propagation checklist regardless of task language.** A change that alters an output format, file layout, API surface, or any contract consumed by other code or documented in `docs/` must be accompanied by a checklist covering all consumers -- tests, docs, downstream scripts, fixtures, and knowledge tests -- even if the task is phrased as a single-file edit.

---

## Bash Friction Log

Bash friction is one class of the agent-feedback record. It lives with the other agent-experience entries in [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) (`## Bash` section). Consult it when diagnosing unexpected behavior or considering bash-language workarounds. Each entry cross-references [`docs/development/bash-coding-conventions.md`](docs/development/bash-coding-conventions.md) for canonical rules. The former separate friction-log file was subsumed here (session `20260809-04`).

## Feedback and Gotchas Files

Two persistent records live in `devlog/`:

- [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) -- agent-experience feedback, recorded by the agent, reviewed by the operator. The agent surfaces open entries to the operator at the sub-milestone pre-close review gate.
- [`devlog/GOTCHAS.md`](devlog/GOTCHAS.md) -- recurring agent mistakes and code smells, recorded by the operator. At iteration start (Step 1), the agent reads the open gotchas and avoids or re-checks those patterns during the iteration. A sweep applies a gotcha fix across recent code at sub-milestone cleanup. When gotchas accumulate, fold the recurring patterns into a skill.

These files are tied into the iteration's Findings for recording and into the sub-milestone pre-close review gate for reconciliation.

**Roadmap as sole task list.** The roadmap is the sole task list. When an iteration generates a task, update the roadmap at iteration end. Do not leave a task in the handover alone. Authoritative rule: [`roadmap_policy.md`](docs/operations/roadmap_policy.md#when-the-roadmap-is-touched).

---

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

In interfaces without filesystem access (e.g. Claude Chat), run grep across uploaded files at `/mnt/user-data/uploads/` and `/mnt/user-data/outputs/` and apply the same discipline to deciding which sections to request from the operator.

---

## Output Format

Agent output is complete and ready for review when it follows the format rules below. The operator reviews, approves, and commits. Use the mechanism appropriate to the interface -- see your provider-layer `AGENTS.md` for interface-specific output instructions.

**Documents** -- Markdown, one file per document, correct folder per `documentation_policy.md`. Drafting rules: records state, not session history; skeleton first for record-layer documents (ADR, concept, architecture) -- propose the section skeleton in chat and confirm before writing prose; prose meets ASD-STE100 -- active voice, short sentences, one term one meaning, common verbs, no hedging, delete-test every sentence. All three defined in `documentation_policy.md` -- Editing Guidelines and Conventions.

**Governance documents** (policy files, AGENTS.md, operational docs) -- propose changes one section at a time via chat. Present the new or changed text, explain the rationale, and wait for confirmation before writing. Do not batch multiple sections into one proposal unless they are logically inseparable.

**Code** -- Consistent with the existing provider structure under `providers/`. Language and style conventions are established incrementally.

**Audit findings** -- Identify the document or code, state the rule violated, propose the correction.

**Code comments** -- Comments must describe what the code does or why -- never that it was changed. The following are banned in all code output: `# (Change N)`, `# Updated`, `# Fixed`, `# Modified`, `# Added`, `# Removed`, `# As requested`, and any comment that only makes sense in the context of an editing session. Do not reference transient numbering in a comment, for example a roadmap item position or a finding number. Name the change or link the document instead.

---

## Missing Documents

If a required document is absent and carries no `[REMOVED]` marker on its referencing link, flag it as an error and prompt the operator before proceeding. Do not assume the document is optional. Do not proceed without resolution.

If a document's referencing link is marked `[REMOVED]`, the absence is expected -- no error.

---

## Iteration Start

Read these in order. Each answers a distinct question -- do not skip. Verify you have access to each before proceeding.

### Always

| Document | Question it answers |
|---|---|
| `AGENTS.md` (this file) | How do I work here? |
| Provider-layer `AGENTS.md` | What can I do in this specific interface? |
| `YYYYMMDD-NN-TYPE-*.md` (most recent) | What milestone am I on, what files are in scope, and where did the last iteration end? |
| [`devlog/roadmap.md`](devlog/roadmap.md) | What is the current sub-milestone and what are the pending tasks? -- after reading, state your proposed scope and wait for confirmation before producing any output |

### Major loop only

Read these in addition to the above when opening a major loop planning iteration.

| Document | Question it answers |
|---|---|
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | What sub-milestones are planned but not yet active? |
| [`devlog/changelog.md`](devlog/changelog.md) | Is the prior milestone fully closed? |

### Policy documents - read before the relevant task type, not at iteration start

| Document | Read before |
|---|---|
| [`docs/development/project_index.md`](docs/development/project_index.md) | Re-scoping or architecture layer boundary checks |
| [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md) | Any documentation task |
| [`docs/operations/roadmap_policy.md`](docs/operations/roadmap_policy.md) | Any roadmap update |
| [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md) | Any iteration start or end, new task, story, investigation, or milestone transition |
| [`docs/operations/handover_policy.md`](docs/operations/handover_policy.md) | Any iteration start or end, creating or updating a handover |
| [`docs/operations/discussion_policy.md`](docs/operations/discussion_policy.md) | Creating or renaming any file in `devlog/discussions/` |
| [`docs/operations/adr_policy.md`](docs/operations/adr_policy.md) | Creating or superseding an ADR in `docs/adr/` |
