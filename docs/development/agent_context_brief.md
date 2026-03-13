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

**Plan before executing.** Propose a plan and wait for confirmation before producing any file, code, or structural change.

**State assumptions explicitly.** State them before proceeding, not after.

**Diagnose before fixing.** Explain the root cause and confirm your understanding before proposing a fix.

**Scope discipline.** Address only what was asked. Flag adjacent issues separately — never fix them silently.

**One question at a time.** Ask the most important question first.

**Flag violations before editing.** Check a document against relevant rules before touching it.

**Distinguish current from proposed.** Never blur the description of the existing system with a proposal for change.

**Decisions are final.** Do not re-open a decision without a specific technical reason.

**No restatement of completed work.** Reference by name only.

---

## Operating Workflow

The workflow is the procedural realization of the collaboration protocol. It will be refined as the project evolves.

1. **Discuss conceptual requirements** — reason about current behaviour, what needs to change, and why. Surface tensions before proposing solutions.
2. **Agree on implementation** — function boundaries, file locations, naming, design decisions. Do not begin until agreed.
3. **Scan for documentation changes** — identify which documents need updating. Add as a documentation task in the roadmap milestone before touching code.
4. **Perform documentation changes** — update architecture, concepts, and security documents as identified.
5. **Perform code changes** — implement against the agreed design.
6. **Update roadmap** — clean previous update first, then mark new completions. See `roadmap_policy.md`.
7. **Finalize milestone** — collapse completed subsections into conceptual outcome sentences. Keep implementation detail out; it belongs in git history.

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



**Documents** — Markdown, one file per document, correct folder per `documentation_policy.md`.

**Code** — Consistent with the existing provider structure under `providers/`. Language and style conventions are established incrementally.

**Audit findings** — Identify the document or code, state the rule violated, propose the correction.

---

## References

Read these in order at session start. Each answers a distinct question — do not skip.

| Document | Question it answers |
|---|---|
| [`readme.md`](readme.md) | What is this system? |
| this file | How do I work here? |
| [`agents.md`](agents.md) | What can I do in this specific interface? |
| [`docs/development/doc_status.md`](docs/development/doc_status.md) | What should I read this milestone? |
| [`agent_handover.md`](agent_handover.md) | What was happening when the last session ended? |

Policy documents — read before the relevant task type, not at session start:

| Document | Read before |
|---|---|
| [`docs/development/project_index.md`](docs/development/project_index.md) | Re-scoping or architecture layer boundary checks |
| [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md) | Any documentation task |
| [`docs/development/roadmap_policy.md`](docs/development/roadmap_policy.md) | Any roadmap update |
| [`docs/development/task_policy.md`](docs/development/task_policy.md) | Any new task, story, or investigation |
