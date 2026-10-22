# Agent Context Brief  --  Pi-Specific Behavior (global)

This file is loaded by pi on every session start as the first AGENTS.md layer, via its CWD-walk discovery mechanism (`$AGENT_HOME/agent/AGENTS.md`). It describes pi-specific behavior that applies regardless of the project being worked on.

Project-specific context lives in `sandbox/AGENTS.md` (loaded second, concatenated after this file). See that file for project conventions, commands, and architecture.

## Scope

The paths this layer covers. Each is part of the container, so a reference to one of them resolves for any install of this image. The project layer covers the working tree the session runs in.

| Path | What is there |
|---|---|
| `$AGENT_HOME/` | `/home/agentuser/.pi`, the agent's own config home. Put configuration there, not in a project-level `.pi`. |
| `/opt/workflow/agent/prompts/` | the harness prompts and the coding-agent workflow prompts, merged into one root |
| `/opt/workflow/agent/skills/` | the skill root |
| `/opt/sandbox/docs/reference/` | the reference layer: contracts, states and sequences, the interface index |
| `/opt/sandbox/lib/` | the harness libraries |
| `/opt/sandbox/bin/` | the entrypoint and preflight scripts |
| `/home/agentuser/workspace/input/` | the operator's handover files, read-only |
| `/home/agentuser/workspace/output/` | where the session writes its result |
| `/home/agentuser/workspace/session-diffs/` | the session diff output |

## Agent Harness

You are running inside the **agent-sandbox** harness. Your working directory (`sandbox/`) contains a git-initialised snapshot of the project repository. All changes you make are captured as diffs and reviewed by a human operator before being applied.

### Two-layer container architecture

Every session runs two containers. You are inside the **reasoning** (agent runtime) container. A separate **capability** (sandbox) layer container runs the diff pipeline, snapshot, and autosave. Each has its own `/opt/sandbox/lib/` with a different subset of library files  --  a file missing in one container is not necessarily a regression; it may belong only to the other layer.

Key behavioral rules:

- Do not modify files outside `sandbox/`, with one exception: `$AGENT_HOME/`, the config home this layer owns.
- Changes are ported from the container to a draft branch on host; the operator reviews the merge before applying.

## Write Discipline

Code changes should be self-contained within a single iteration. The operator reviews per-iteration diffs  --  fragmented or half-applied changes across iterations create review burden.

An approval that produces an artifact edits the file that is its source of truth, in the same unit of work, per `principle-approval-writes-the-artifact` at `$AGENT_HOME/agent/skills/principle-approval-writes-the-artifact/SKILL.md`. With version control the write is cheap to undo; a decision held in the conversation cannot be reverted, resumed or checked. A decision kept only in the conversation is re-derived later, and its re-derivation fails no gate.

Never manually word wrap prose. Do not insert a line break mid-paragraph  --  not at sentence boundaries, nor at a column limit; editors and viewers soft-wrap. See the `docs` convention, `.agents/skills/docs/SKILL.md` `## What a document may contain`.

When writing code, always take into account the following:

1. Does this need to exist?   -> no: skip it (YAGNI)
2. Already in this codebase?  -> reuse it, don't rewrite
3. Stdlib does it?            -> use it
4. Native platform feature?   -> use it
5. Installed dependency?      -> use it
6. One line?                  -> one line
7. Only then: the minimum that works

Run throwaway verification in `.scratchpad/`, the session-local scratch, never elsewhere in the repo tree. `.scratchpad/` is gitignored, so a stray file there does not surface in `git status` or pollute the diff. A throwaway file is any file you create only to check something and do not keep.

Prefer the `edit` tool for in-place text changes. The `edit` tool reports a miss when its `oldText` does not match; a `sed` one-liner run through the `bash` tool with a missing file operand silently writes nothing. After a `sed` change, verify the write landed.

Before creating any new document, check the project layer for the policy that governs the document type.

Tools you have access to:

- `/package-branch`  --  export the branch as numbered per-commit diffs, an uncommitted diff, and the changed-file set, taken at the branch point (merge-base of init_sha and HEAD) so a rebased history applies cleanly; the script states the branch point and reports when it moved
- `/task-queue`  --  run a task fan-out as a fork and a join: per-task worktrees, a blocking operator join, the re-queue routes, and the bring-back
- `/package-eval-snapshot`  --  save the session for a future eval: the transcript frozen as it stands, a complete repository bundle, the operator turn stream, the session facts and a credential scan, all under the workspace output directory
- Standard development tools (git, bash, common CLI utilities)

## Communication Standards

General communication guidelines for all agent prose. The standard is the `communication-principle-*` corpus under `$AGENT_HOME/agent/skills/`, one judgement per skill. Each line below names the skill that holds it, and this section states no rule of its own.

- Keep the sentence that changes a decision and delete the one that does not: `communication-principle-cut-what-carries-nothing`.
- Write so the reader attaches each phrase as it arrives: `communication-principle-attach-as-you-read`.
- Define a term before the work relies on it: `principle-define-terminology-before-use`.
- Write for the reader, not the session that produced it: `communication-principle-write-for-the-reader`.
- Name a value rather than fixing a literal the reader must set: `communication-principle-name-the-value-not-a-literal`.
- State the primary data, not a value derived from it: `communication-principle-only-derive-what-you-own`.
- Print one addressing axis per presentation: `communication-principle-one-addressing-axis`.
- Choose the word that carries the most distinction and loses none: `communication-principle-maximize-conceptual-leverage`.
- Give every word one meaning and every thing one word: `communication-principle-align-the-mental-model`.
- Carry one line of reasoning through the document: `communication-principle-single-train-of-thought`.

Each skill named above is at `$AGENT_HOME/agent/skills/<name>/SKILL.md`.

The judgements that fire on a whole artifact rather than a sentence: `communication-principle-show-dont-describe` when an instruction or a claim of compliance is written, `communication-principle-dont-forecast-undone-work` when a record describes work no task holds, `communication-principle-keep-a-subject-near` when a caveat or a definition moves, and `communication-principle-hand-off-by-naming-the-boundary` at a prompt's last step.

The judgement behind a numbered list: `communication-principle-one-addressing-axis`. How a document points at another: `communication-principle-link-what-the-reader-can-open`. Where a project states a numbering scheme or a reference form of its own, that convention is the project's, and this layer names no path to it. Line wrapping and the character set: the `docs` convention's `## What a document may contain`, which the `doc-wrap` and `doc-ascii` lint rules catch.

Report honestly. A claim about an unobservable state is an inference and is marked as one, and no capacity claim is made without a signal in the environment.

Follow the target document's own conventions; a pattern its rules forbid is a defect in your copy.

Read a finished instruction as a literal reader: if the words allow the reader to infer a task, an action or a conclusion the writer did not intend, one of the judgements above failed, and the sentence is rephrased with that one.

## Fresh Subagent Invocation

When a fresh perspective is needed for code review (e.g. thermo-nuclear review of changes made in the current iteration), invoke a fresh subagent using:

```text
pi -p "Subagent instructions..."
```

The `-p` flag spawns a new subagent with a clean context  --  it does not inherit the current session's conversation history, loaded files, or tool state. Use this when the current agent may have blind spots from extended work on the same code.

The subagent runs in the same container/workspace as the primary agent, with the same tools  --  it **can** persist file edits and run git commits. It starts with a clean conversation context, so it cannot see this session's chat history, in-memory files, or tool state; pass everything it needs in the `-p` argument or on disk. Its output is returned inline. The results should be triaged by the primary agent.

**What any dispatch must hold.**

- **The brief goes to a file**, and the file must be non-empty. Pre-flight it: `[ -s "$brief" ] || { echo "brief missing or empty: $brief" >&2; exit 1; }`.
- **Pin the role, and the pair its line resolves to**, and state the role, the provider, the model and the thinking level in the brief, because the subagent cannot see its invocation flags. The pair comes from the resolver in `**Which model.**`, never from a hand read of the file.
- **Give the run a timeout you set**, and record the exit code and the elapsed seconds.
- **Log to a file, never a pipe.** A run's log is its only evidence.

  ```bash
  run_timeout=<seconds>                    # the run's timeout; set it yourself
  start=$(date +%s)
  timeout "$run_timeout" pi --provider <provider> --model <id> --thinking <level> \
    --session <path> -p "$(cat "$brief")" >"$log" 2>&1
  rc=$?
  ```

- **An empty log is a failure.** A `rc=0` with an empty log means the subagent did no work. Treat it as an outcome of failure, not as a run with nothing to report.
- **Trust no summary over the artifact.** Review the diff or the report yourself; a "done" from a subagent is a claim.

Resuming an interrupted session needs an explicit continuation prompt: `pi --session <path>` opens the session but does not continue on its own. Resume with `pi --session <path> "Continue and give your verdict."`.

### Keeping a subagent alive

A subagent must not outlive the tool call that launched it. A process started with `&` is orphaned when that call returns, and its work is lost with no error and a short log. Run it in the foreground of the call that needs its result.

To run subagents in parallel, put every one of them inside a single call and let that call own them:

```bash
start=$(date +%s)
for name in a b; do
  timeout "$run_timeout" pi --provider <provider> --model <model> --thinking <level> \
    -p "$(cat "$brief_$name")" > ".scratchpad/$name.log" 2>&1 &
done
wait
echo "secs=$(( $(date +%s) - start ))"
```

Each subagent gets its own brief file and its own log. Give the call a timeout larger than the per-agent timeout times the count, so the call is the outer bound rather than a second accidental cap. Nothing is orphaned, because the call does not return until every child has finished.

A run can still be truncated by its own timeout. The signature is a short log with no report, and a subject tree that is partially patched. Score the tree rather than the report in that case, and say so.

## Running Review Subagents

A review dispatch has one mechanism: the `pi-reviewer-dispatch` skill at `$AGENT_HOME/agent/skills/pi-reviewer-dispatch/SKILL.md`. It states the reviewer contract and runs the pinned pair. Read it before dispatching a review. This section carries only what that skill cannot.

**Attribution.** State the provider, model, and thinking level in the review prompt: the subagent cannot see its invocation flags, and the report needs the attribution. Record the role, or the words `startup default`, beside the pair. Recommend model choices in the role table, never here.

**Which model.** Every dispatch takes its pair and level from the role line in `model-recommendations.md` (for example `_REVIEWER`). Every role names `deepseek/deepseek-flash`; there is one model, so a second seat is a second run of the same model, not a second family.

1. Resolve the pair: `source src/libs/dispatch.sh; dispatch_role_model <ROLE>`. It prints `<provider>/<model> <level>`, or prints nothing and exits 1.
2. Pass it verbatim, in full: `--provider <provider> --model <provider>/<model> --thinking <level>`.
3. Confirm what ran: `grep -o '"model":"[^"]*"' <session file> | sort -u` prints the pair from step 1, once.
4. Record the role, the pair, and the level beside the seat in the brief.

**When a step fails, stop and report.** Step 1 exits 1 for a missing file, a role with no line, and a line naming no model, and it prints which on stderr. `No models match pattern` means the id was wrong; do not retry with a shortened id. A step 3 output that differs from step 1 voids the run. In every case, dispatch nothing further, choose no model by hand, and report the role and the message.

**The full id.** Pass the model id in full, provider prefix included: `--model` matches as a substring over the provider's list and takes the last id that contains it, so a short name can run a different model than the one intended. A `No models match pattern` message means pi fell back to the startup default, and a partial match is silent, so verify the effective model from the session file either way: give the run an explicit session path, then read the model with `grep -o '"model":"[^"]*"' <session file> | sort -u`.
