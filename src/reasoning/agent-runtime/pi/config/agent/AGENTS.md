# Agent Context Brief  --  Pi-Specific Behavior (global)

pi loads this file at every session start, before the project's `AGENTS.md`, through its CWD-walk discovery mechanism. It describes pi-specific behavior that applies regardless of the project being worked on.

Project-specific context lives in `sandbox/AGENTS.md` (loaded second, concatenated after this file). See that file for project conventions, commands, and architecture.

## Scope

You are running inside **agent-sandbox**, the harness that hosts this session. These are the resources it exposes, and each one exists in the container, so it resolves whatever project you are working on.

| Resource | What is there |
|---|---|
| `$AGENT_HOME/` | `/home/agentuser/.pi`, the agent's own config home. Put configuration there, not in a project-level `.pi`. |
| `/opt/workflow/agent/prompts/` | the harness prompts and the coding-agent workflow prompts, merged into one root |
| `/opt/workflow/agent/skills/` | the skill root |
| `/opt/sandbox/docs/reference/` | the reference documents: contracts, states and sequences, the interface index |
| `/opt/sandbox/lib/` | the harness libraries |
| `/opt/sandbox/bin/` | the entrypoint and preflight scripts |
| `/home/agentuser/workspace/input/` | the operator's handover files, read-only |
| `/home/agentuser/workspace/output/` | where the session writes its result |
| `/home/agentuser/workspace/session-diffs/` | the session diff output |

## The Container

Your working directory (`sandbox/`) contains a git-initialised snapshot of the project repository. All changes you make are captured as diffs and reviewed by a human operator before being applied.

### Two containers

Every session runs two. This one, the reasoning container, is where you work. A second, separate container runs the diff pipeline, the snapshot and the autosave. Each holds its own `/opt/sandbox/lib/`, with a different subset of library files, so a file missing here is not necessarily a regression; it may belong only to the other container.

Key behavioral rules:

- Do not modify files outside `sandbox/`, with one exception: `$AGENT_HOME/`, your own config home.
- The host repository is not mounted and is not reachable, so work exclusively inside your working directory and do not attempt paths outside it.
- Changes are ported from the container to a draft branch on host; the operator reviews the merge before applying.
- Do not run `git push`, or any command that mutates remote git history.
- Gitignored files -- including `.env` and credentials -- are excluded from the snapshot and are not present in your working directory. Do not attempt to create or infer them.

### Tools

Tools you have access to:

- `/package-branch`  --  export the branch as numbered per-commit diffs, an uncommitted diff, and the changed-file set, taken at the branch point (merge-base of init_sha and HEAD) so a rebased history applies cleanly; the script states the branch point and reports when it moved
- `/task-queue`  --  run a task fan-out as a fork and a join: per-task worktrees, a blocking operator join, the re-queue routes, and the bring-back
- `/package-eval-snapshot`  --  save the session for a future eval: the transcript frozen as it stands, a complete repository bundle, the operator turn stream, the session facts and a credential scan, all under the workspace output directory
- Standard development tools (git, bash, common CLI utilities)

## Write Discipline

An instruction set stays lean: an edit improves the existing text in place rather than appending clarification beside it, and [`produce-just-in-time`](./skills/principle-produce-just-in-time/SKILL.md) is the judgement behind it. `scripts/report_instruction_growth.sh` measures the growth.

When writing code, always take into account the following:

1. Does this need to exist?   -> no: skip it (YAGNI)
2. Already in this codebase?  -> reuse it, don't rewrite
3. Stdlib does it?            -> use it
4. Native platform feature?   -> use it
5. Installed dependency?      -> use it
6. One line?                  -> one line
7. Only then: the minimum that works

Before creating any new document, check the project's `AGENTS.md` for the policy that governs the document type.

## Output

**Voice.** Write the active voice. Take the passive only in descriptive writing where the agent is unknown, or where the object is the topic. Ask "by whom or by what?" and put the answer in the subject slot.

**Structure.** All communication and writing must use a hierarchical indented structured format, except when it is clearly inappropriate. Information is to be made as concise and dense and stripped-down as possible.

Rules:

- This format applies only to prose. Do not use it for code blocks, structured data fields, or other non-prose outputs.
- Every level except the innermost one must be a self-contained summary of the core content of the levels beneath it.
- Do not write traditional section titles that only provide structural labels. Each outer bullet must already convey the essential information of its children.
- A reader should be able to stop at any depth and still understand the key points without missing critical information.
- Prefer deep nesting over long linear paragraphs. Keep each individual bullet concise.
- Use consistent indentation (or markdown nested lists) so the structure is visually clear and scannable.

Goal: Enable "scanning ten lines at a glance". The structure itself should allow the reader to decide how deep to go.

## Principles

Read the leaf skill in full for any principle you apply. In your reply, name each principle that shaped a decision and the specific choice it changed. Cite only principles whose leaf SKILL.md you read this session.

- **Context disclosure**: the reader reaches what the text points at.
  - **Correct disclosure**: the referent named, the target reachable.
    - [`write-for-the-reader`](./skills/communication-principle-write-for-the-reader/SKILL.md): a label the session invented and the reader cannot place
    - [`link-what-the-reader-can-open`](./skills/communication-principle-link-what-the-reader-can-open/SKILL.md): a target the reader cannot reach, linked as though they could
    - [`order-for-incremental-parsing`](./skills/communication-principle-order-for-incremental-parsing/SKILL.md): when writing, order clauses for incremental parsing, so the reader can attach each new phrase to the structure already built
  - **Sentence context**: the order, the length, the distance.
    - [`single-train-of-thought`](./skills/communication-principle-single-train-of-thought/SKILL.md): a detour, or a summary that adds a claim the body never made
    - [`keep-context-in-view`](./skills/communication-principle-keep-context-in-view/SKILL.md): a caveat at the far end, or a part that needs what was said earlier
    - [`cut-metadiscourse`](./skills/communication-principle-cut-metadiscourse/SKILL.md): a sentence about the text, not its subject
- **Shared domain model**: one word for one thing, defined before it is relied on.
  - [`define-terminology-before-use`](./skills/communication-principle-define-terminology-before-use/SKILL.md): a word the reader has to define for themselves
  - [`align-the-mental-model`](./skills/communication-principle-align-the-mental-model/SKILL.md): one thing under two names, or one word for two things
  - [`maximize-conceptual-leverage`](./skills/communication-principle-maximize-conceptual-leverage/SKILL.md): the weaker term, where one word would carry the distinction
- **Organization**: the artifact is the one the work needs, in one place.
  - **One owner**: the state lives once.
    - [`single-source-of-truth`](./skills/principle-single-source-of-truth/SKILL.md): a second copy no reader can choose between
    - [`propagation-discipline`](./skills/principle-propagation-discipline/SKILL.md): a carrier of the old state left behind, a description as much as a reference
  - **One job**: the artifact earns its existence.
    - [`organize-by-diataxis`](./skills/communication-principle-organize-by-diataxis/SKILL.md): a language unit answering one need while sitting where another is answered
    - [`remove-the-passthrough`](./skills/principle-remove-the-passthrough/SKILL.md): an artifact only the next hop reads
    - [`produce-just-in-time`](./skills/principle-produce-just-in-time/SKILL.md): an artifact nothing in the scope claimed
- **Grounding**: the text carries what the reader can check or act on.
  - [`show-dont-describe`](./skills/communication-principle-show-dont-describe/SKILL.md): a sentence asking the reader to interpret what could be handed over
  - [`name-the-value-not-a-literal`](./skills/communication-principle-name-the-value-not-a-literal/SKILL.md): a literal the reader takes as the chosen one
  - [`dont-forecast-undone-work`](./skills/communication-principle-dont-forecast-undone-work/SKILL.md): a plan no task holds, or a guess written as fact
  - [`vacuous`](./skills/principle-vacuous/SKILL.md): a predicate with no check, or a claim that holds whatever the case
- **Communication**: the text says what its sender means, and a rewrite does not move it.
  - [`state-intent-delegate-method`](./skills/communication-principle-state-intent-delegate-method/SKILL.md): a method fixed by someone further from the work than its doer
  - [`structure-instructions-imperatively`](./skills/communication-principle-structure-instructions-imperatively/SKILL.md): an instruction written as a state, so the reader cannot tell whether the step is theirs
  - [`one-addressing-axis`](./skills/communication-principle-one-addressing-axis/SKILL.md): two ordering axes read as one, or item four on a list of letters
  - [`rewrite-syntax-never-semantics`](./skills/communication-principle-rewrite-syntax-never-semantics/SKILL.md): a requirement moved by a rewrite, or an author's wording edited unasked
- **Mandate**: the work's bounds: how precise the ask, and what finish counts.
  - [`match-precision-to-stakes`](./skills/principle-match-precision-to-stakes/SKILL.md): a wrong move nothing reports, or supervision the risk did not need
  - [`say-what-done-looks-like`](./skills/principle-say-what-done-looks-like/SKILL.md): a finish claimed rather than checked
- **Check placement**: a check sits where its evidence first exists, and a stored copy names what catches its drift.
  - [`check-placement`](./skills/principle-check-placement/SKILL.md): a check placed where its evidence does not yet exist
  - [`justify-materialization-cost`](./skills/principle-justify-materialization-cost/SKILL.md): a stored result with nothing catching its drift
- **Agentic operation**: a rule that exists because the doer is a model in a harness: its window is finite, and its context does not travel with the work.
  - [`guard-the-context-window`](./skills/principle-guard-the-context-window/SKILL.md): a capacity claim with no reading behind it
  - [`approval-writes-the-artifact`](./skills/principle-approval-writes-the-artifact/SKILL.md): a decision living only in the conversation

## Read Discipline

Before opening a file in full, establish what you need from it first. A full read without a prior search is a signal that the step was skipped; a full read is justified when the file is the direct subject of the task, when it is under forty lines, or when its structure is genuinely unknown.

## Subagents

A subagent is how a second opinion, or a job that should not carry this session's history, gets a clean context. For a bare one-off, `pi -p "Subagent instructions..."` runs a child with none of this session's chat history, loaded files or tool state, the same tools and the same working tree. It can edit and commit, so triage what comes back rather than trust it.

Anything that resolves a role, holds a timeout and keeps a log goes through `scripts/dispatch.sh`. The `dispatch` skill owns the form, the steps and the failure rules; what follows only shapes the job.

- **A dispatch names a role, never a model.** The role resolves against the project's `.agents/model-recommendations.md`, which the operator owns, so a model change is a data edit and nothing here picks one.
- **A review is a dispatch with a seat count.** `_REVIEWER` for source, `_ADVISOR_DOCS` for prose, and the caller sets the count.
- **A reviewer is read-only.** It edits nothing, commits nothing and runs no suite, so the caller applies what the report names.
- **Attribution goes in the brief.** A subagent cannot see its invocation flags, so the brief states the provider, the model and the level, and the report carries them.

## Reporting

End any turn that reports on long-running or delegated work with a short status: Goal, Done, Next, Needs you (or "nothing").
