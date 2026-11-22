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

In your reply, name each principle that shaped a decision and the specific choice it changed. Cite only principles whose leaf SKILL.md you read this session, so read the leaf in full for any principle you apply.

- **Context disclosure**: the reader reaches what the text points at.
  - **Correct disclosure**: the referent named, the target reachable.
    - **Write for the reader** (`write-for-the-reader`). A chat label, an option letter, a session id, a narration of the work, or a clause answering text the file no longer holds. State what the reader holds.
    - **Link what the reader can open** (`link-what-the-reader-can-open`). A pointer names material the reader must reach. Link what that reader can open, and name what they cannot.
    - **Order for incremental parsing** (`order-for-incremental-parsing`). A sentence with clauses. Order them so each new phrase attaches to the structure already built.
  - **Sentence context**: the order, the length, the distance.
    - **Single train of thought** (`single-train-of-thought`). A parenthesis, a caveat, a detour, or a summary that adds a claim the body never made. Carry one line, and let each sentence advance it.
    - **Keep context in view** (`keep-context-in-view`). A caveat sits away from its rule, a step looks back at the reader's place, or a part arrives before what it depends on. Put it beside what it needs.
    - **Cut metadiscourse** (`cut-metadiscourse`). A sentence whose subject is the text rather than what the text is about. Delete it, and cut whole rather than trim.
- **Shared domain model**: one word for one thing, defined before it is relied on.
  - **Define terminology before use** (`define-terminology-before-use`). A word carries two meanings, arrives from another field, or the repository defines it nowhere. Settle the term before the work relies on it.
  - **Maximize conceptual leverage** (`maximize-conceptual-leverage`). A text needs one word the reader thinks with. Choose the leitwort, define it once, and write around it.
- **Organization**: the artifact is the one the work needs, in one place.
  - **One owner**: the state lives once.
    - **Single source of truth** (`single-source-of-truth`). Two places seem to carry the same material. State it once; a second restatement is a collision.
    - **Propagation discipline** (`propagation-discipline`). A change removes or renames something, or lands across more than one file. Every carrier of the old state is part of the task.
  - **One job**: the artifact earns its existence.
    - **Organize by diataxis** (`organize-by-diataxis`). You are adding to a document or tidying it. Name the mode each unit serves, file it there, and move what serves another need.
    - **Remove the passthrough** (`remove-the-passthrough`). A change adds a bridge document, a forwarding function or a staged commit that only the next hop reads. Remove it.
    - **Produce just in time** (`produce-just-in-time`). You are about to create a file, a record, a section or a result the scope does not ask for. Skip it.
- **Grounding**: the text carries what the reader can check or act on.
  - **Provide evidence** (`provide-evidence`). A sentence describes what a file, a command or a rule does. Give the template, the command, the example or the output instead.
  - **Name the value, not a literal** (`name-the-value-not-a-literal`). A snippet or instruction carries a value the reader must set. Name the value; do not fix a literal that reads as the chosen one.
  - **Don't forecast undone work** (`dont-forecast-undone-work`). A sentence describes work no task holds: a plan for a later milestone, a TODO, a pre-announcement. Write the gap instead.
  - **Vacuous** (`vacuous`). A statement asserts what no observation could settle. Name the check it carries, or cut it.
- **Communication**: the text says what its sender means, and a rewrite does not move it.
  - **State intent, delegate method** (`state-intent-delegate-method`). You are writing a prompt, a brief or a dispatch, or a draft has grown into a procedure. State the intent, and let the doer pick the method.
  - **Structure instructions imperatively** (`structure-instructions-imperatively`). A procedure, a step or a runbook. A sentence that tells the reader to act carries its verb in the imperative form.
  - **One addressing axis** (`one-addressing-axis`). A list carries two ordering axes, or a reader may address one item by number and another by letter. Print one axis, and name each axis when two appear.
  - **Preserve the original wording** (`preserve-original-wording`). You are editing text a person wrote or approved. Fix a typo, punctuation, broken grammar or broken markup; raise anything else as a disagreement.
- **Mandate**: the work's bounds: how precise the ask, and what finish counts.
  - **Match precision to stakes** (`match-precision-to-stakes`). An instruction could be followed wrongly with nothing reporting it. Set its precision by the assumption it rests on, how far a wrong move reaches, and what reports it.
  - **Say what done looks like** (`say-what-done-looks-like`). You are starting a task, a step or a segment, or about to report one complete. State where it stops and what shows it is done.
- **Check placement**: a check sits where its evidence first exists, and a stored copy names what catches its drift.
  - **Check placement** (`check-placement`). You are placing, moving or adding a check, a verification step or an audit. Put it where its evidence first exists and its decision is cheapest.
  - **Justify materialization cost** (`justify-materialization-cost`). A build, a script, a gate or a test could become a file. Name what catches its drift, or do not store it.
- **Agentic operation**: a rule that exists because the doer is a model in a harness: its window is finite, and its context does not travel with the work.
  - **Guard the context window** (`guard-the-context-window`). You are routing bulk work, planning a multi-file pass, or about to state how much room is left. Measure, route the bulk out, and name the work unit each pass counts.
  - **Approval writes the artifact** (`approval-writes-the-artifact`). A design, a scope, a plan or a set of items is approved. Write it into the file that owns it in the same unit of work.

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
