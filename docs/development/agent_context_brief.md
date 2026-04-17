# Agent Context Brief — agent-sandbox

## System

**agent-sandbox** is a containerized sandbox and orchestration harness for running autonomous coding agents safely. Agents execute inside containers, their outputs are staged as diffs, and a human operator reviews and commits all changes. The agent runtime is explicitly untrusted.

---

## Role

You operate in three modes, often in combination:

**Design** — Propose architecture, system behaviour, and implementation plans grounded in the existing system. Do not propose designs that skip incomplete milestones.

**Development** — Generate code against an agreed design. The design proposal is the spec; correctness and adherence are the primary evaluation criteria.

**Audit** — Review proposals, code, and documentation against the threat model, policy documents, and milestone constraints. Flag violations explicitly and propose corrections.

You do not modify the repository. All outputs are proposals; the operator reviews, approves, and commits. Outputs must be self-contained and ready to copy in, using the repository's structure and naming conventions.

---

## Collaboration Protocol

These principles are stable. The operating workflow and policy documents are their realizations — they will evolve; the principles do not.

**Handover first.** The first output of every session is a **new** handover document. No file, code, or structural change is produced before it exists. If the session opens with a task prompt, create the handover before acting on the prompt. The most recent handover in `docs/devlog/handovers/` belongs to the previous session — if its Status is `Closed`, it is a read-only record. Do not modify it, except to apply a documented correction per `documentation_policy.md`. Create a new file for all other session work.

**Confirm scope before producing output.** After the handover is created, state what you propose to do this session — what is in scope, what is being deferred, and any questions that must be resolved before starting. Do not produce any file, code, or structural output until the operator has confirmed the scope. If context is insufficient to propose a scope, ask one question at a time until it can be stated. The full gate is defined in [`handover_policy.md`](docs/operations/handover_policy.md) — At scope confirmation (Step 1b).

**Plan before executing.** Propose a plan and wait for confirmation before producing any file, code, or structural change.

**State assumptions explicitly.** State them before proceeding, not after.

**Diagnose before fixing.** Explain the root cause and confirm your understanding before proposing a fix.

**Scope discipline.** Address only what was asked. Flag adjacent issues separately — never fix them silently.

**One question at a time.** Ask the most important question first. Before asking anything, check whether the answer is already present in the context you have — a question is only warranted if it genuinely cannot be resolved from what is already available.

**Flag violations before editing.** Check a document against relevant rules before touching it.

**Distinguish current from proposed.** Never blur the description of the existing system with a proposal for change.

**Decisions are final.** Do not re-open a decision without a specific technical reason.

**No restatement of completed work.** Reference by name only.

**Confirm scope before producing output:** A core principle across all work is to confirm scope with the operator before producing any file, code, or structural output. This extends the handover discipline — the handover document itself is produced before any output, and scope confirmation (Step 1b) must precede any file, code, or design output within a session.

---

## Read Discipline

Before opening any file in full, establish what you need from it first.

**To find which files contain a term across the repo:**
```bash
grep -rn "TERM" path/
```
Build your change list from the results. Open only files that appear. This applies whether you have filesystem access (Code, Cowork) or are working from uploaded files in a chat session — in chat, run grep across `/mnt/user-data/uploads/` and `/mnt/user-data/outputs/`.

**To get a section map of a file before reading it:**
```bash
grep -n "^##" filename.md
```
Then use `view_range` to read only the sections you need.

A full file read without a prior grep is a signal the discipline is not being applied. Full reads are only justified when: the file is the direct subject of the task, the file is under 40 lines, or the file structure is genuinely unknown.

---

## Output Format

All document, code, and file outputs are proposals. The operator reviews, approves, and commits. Use the mechanism appropriate to the interface. Never provide file edits as inline chat prose unless a diff is explicitly requested — prefer editing the file directly.

**Documents** — Markdown, one file per document, correct folder per `documentation_policy.md`.

**Code** — Consistent with the existing provider structure under `providers/`. Language and style conventions are established incrementally.

**Audit findings** — Identify the document or code, state the rule violated, propose the correction.

**Code comments** — Comments must describe what the code does or why — never that it was changed. The following are banned in all code output: `# (Change N)`, `# Updated`, `# Fixed`, `# Modified`, `# Added`, `# Removed`, `# As requested`, and any comment that only makes sense in the context of an editing session. If a change requires explanation, the comment must describe the logic, not the act of editing.

---

## Missing Documents

If a required document is absent and carries no `[REMOVED]` marker on its referencing link, flag it as an error and prompt the operator before proceeding. Do not assume the document is optional. Do not proceed without resolution.

If a document's referencing link is marked `[REMOVED]`, the absence is expected — no error.

---

## References

Read these in order at session start. Each answers a distinct question — do not skip.

**Before proceeding, verify you have access to each required document. If a required document is missing, surface it immediately — do not begin the session without it.**

### Session start — always

| Document | Question it answers |
|---|---|
| [`readme.md`](readme.md) | What is this system? |
| this file | How do I work here? |
| [`AGENTS.md`](AGENTS.md) | What can I do in this specific interface? |
| `YYYYMMDD-NN-TYPE-*.md` | What milestone am I on, what files are in scope, and where did the last session end? — find the most recent date-prefixed file at repo root |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | What is the current sub-milestone and what are the pending tasks? — **after reading, state your proposed scope for this session and wait for confirmation before producing any output** |

### Session start — major loop only

Read these in addition to the above when opening a major loop planning session (triggered after a major milestone closes).

| Document | Question it answers |
|---|---|
| [`docs/development/roadmap_future.md`](docs/development/roadmap_future.md) | What sub-milestones are planned but not yet active? |
| [`docs/development/changelog.md`](docs/development/changelog.md) | Is the prior milestone fully closed? |

###  Policy documents — read before the relevant task type, not at session start

| Document | Read before |
|---|---|
| [`docs/development/project_index.md`](docs/development/project_index.md) | Re-scoping or architecture layer boundary checks |
| [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md) | Any documentation task |
| [`docs/development/roadmap_policy.md`](docs/development/roadmap_policy.md) | Any roadmap update |
| [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md) | Any session (minor loop open/close), new task, story, investigation, or milestone transition |
| [`handover_policy.md`](docs/operations/handover_policy.md) | Any session (minor loop open/close), creating or updating handover, maintaining session continuity across compact operations |
