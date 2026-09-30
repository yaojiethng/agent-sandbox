# Agent Context Brief  --  Pi-Specific Behavior (global)

This file is loaded by pi on every session start as the first AGENTS.md layer, via its CWD-walk discovery mechanism (~/.pi/agent/AGENTS.md). It describes pi-specific behavior that applies regardless of the project being worked on.

Project-specific context lives in `sandbox/AGENTS.md` (loaded second, concatenated after this file). See that file for project conventions, commands, and architecture.

---

## Agent Harness

You are running inside the **agent-sandbox** harness. Your working directory (`sandbox/`) contains a git-initialised snapshot of the project repository. All changes you make are captured as diffs and reviewed by a human operator before being applied.

### Two-layer container architecture

Every session runs two containers. You are inside the **reasoning** (agent runtime) container. A separate **capability** (sandbox) layer container runs the diff pipeline, snapshot, and autosave. Each has its own `/opt/sandbox/lib/` with a different subset of library files  --  a file missing in one container is not necessarily a regression; it may belong only to the other layer.

Key behavioral rules:

- Do not modify files outside `sandbox/`.
- The changes in each iteration (represented by the task list of a single handover) must correspond to a single commit at iteration end with a type prefix per [`docs/operations/git_policy.md`](docs/operations/git_policy.md). `wip:` commits checkpoint in-progress work; squash them into the delivery commit at iteration end. A correction to a closed iteration's work, at the operator's direction, folds into that iteration's commit rather than starting a new one, and carries its record amendments in the same fold. The principles are in [`docs/adr/closed_record_corrections.md`](docs/adr/closed_record_corrections.md) and the record forms in the type policies. To fold a fix into a non-HEAD commit, commit with `git commit --fixup=<hash>` and rebase with `git rebase -i --autosquash`.
- Changes are ported from the container to a draft branch on host; the operator reviews the merge before applying.

## Write Discipline

Code changes should be self-contained within a single iteration. The operator reviews per-iteration diffs  --  fragmented or half-applied changes across iterations create review burden.

Never manually word wrap prose. Do not insert a line break mid-paragraph  --  not at sentence boundaries, nor at a column limit; editors and viewers soft-wrap. See [`documentation_policy.md`](docs/operations/documentation_policy.md) `### Line wrapping`.

When writing code, always take into account the following:

1. Does this need to exist?   -> no: skip it (YAGNI)
2. Already in this codebase?  -> reuse it, don't rewrite
3. Stdlib does it?            -> use it
4. Native platform feature?   -> use it
5. Installed dependency?      -> use it
6. One line?                  -> one line
7. Only then: the minimum that works

Run throwaway verification in `/tmp`, never in the repo tree. The repository is git-tracked; a stray file created during verification surfaces in `git status` and pollutes the diff. A throwaway file is any file you create only to check something and do not keep.

Prefer the `edit` tool for in-place text changes. The `edit` tool reports a miss when its `oldText` does not match; a `sed` one-liner run through the `bash` tool with a missing file operand silently writes nothing. After a `sed` change, verify the write landed.

Before creating any new document, read [`docs/operations/discussion_policy.md`](docs/operations/discussion_policy.md) and [`docs/operations/adr_policy.md`](docs/operations/adr_policy.md).

Tools you have access to:

- `/package-branch`  --  export committed changes as numbered diffs, uncommitted diff, and changed files
- `/task-queue`  --  run a task fan-out as a fork and a join: per-task worktrees, a blocking operator join, the re-queue routes, and the bring-back
- Standard development tools (git, bash, common CLI utilities)

## Communication Standards

General communication guidelines for all agent prose. Full policy: `docs/operations/documentation_policy.md` in the target repo when present.

- Meet ASD-STE100. Delete-test every word, phrase, and sentence: if a reader can delete it without losing required meaning, delete it.
- Active voice. Name the actor: "the seeder copies the repository", never "the repository is copied".
- Short sentences. Aim under 20 words; one idea per sentence.
- One term, one meaning. Pick one word for a thing and keep it; do not rotate synonyms.
- Numbering: a number holds only where it appears. Present one indexable axis per exchange; if sets must co-exist, name each axis.
- Common verbs. Prefer: is, has, uses, copies, reads, writes, runs, starts, stops, shows, checks, rejects. Avoid ornate verbs ("leverages", "facilitates", "encompasses").
- No idioms, no metaphors, no hedging ("somewhat", "fairly", "arguably").
- Place the defined noun phrase before the imperative command: the reader must know exactly what object is being discussed before being told what to do with it. If the sentence uses a term the reader has not met, define it first, in its own clause, then apply it. Avoid thin subjects that rely on a trailing dash clause for definition; the main clause must not depend on its afterthought.
- One paragraph per physical line, however long the line. Never break inside a paragraph -- not at sentence boundaries, not at a column limit. Hard breaks separate blocks only.
- Plain ASCII punctuation. Write a dash as a space-separated hyphen (` - `), or as a double hyphen (`--`) in prose. No non-ASCII symbols, no checkmark or cross emoji.
- Link sparingly. Link what the reader might need next; keep context-only names as plain text. Do not over-link transient documents (handovers, discussion docs, session exports).
- Follow the target document's own conventions; a pattern its rules forbid is a defect in your copy.
- Records state, not session history. A durable record does not narrate the session that produced it: no session ids, no commit hashes, no "as discussed" pointers.

## Fresh Subagent Invocation

When a fresh perspective is needed for code review (e.g. thermo-nuclear review of changes made in the current iteration), invoke a fresh subagent using:

```text
pi -p "Subagent instructions..."
```

The `-p` flag spawns a new subagent with a clean context  --  it does not inherit the current session's conversation history, loaded files, or tool state. Use this when the current agent may have blind spots from extended work on the same code.

The subagent runs in the same container/workspace as the primary agent, with the same tools  --  it **can** persist file edits and run git commits. It starts with a clean conversation context, so it cannot see this session's chat history, in-memory files, or tool state; pass everything it needs in the `-p` argument or on disk. Its output is returned inline. The results should be triaged by the primary agent.

## Running Review Subagents

State the provider, model, and thinking level in the review prompt: the subagent cannot see its invocation flags, and the report needs the attribution. Recommend model choices at the project level, never here. Read the recommendation by role tag from the project-level `AGENTS.md` (for example `_REVIEWER`); each token names the provider, model, and thinking level. When the tag is absent, resolve the model in this order:

1. The project-level `AGENTS.md` role recommendation.
2. The pi default, read from `~/.pi/agent/settings.json` with `jq` (`.defaultProvider`, `.defaultModel`, `.defaultThinkingLevel`), a project-level `.pi/settings.json` override taking precedence. Confirm with the operator that this is the model to use.
3. The provider, model, and thinking level the current chat is using, stated explicitly. Confirm with the operator before dispatching.

The last two rungs confirm with the operator so a fallback never guesses silently. A `No models match pattern` message means pi fell back to the startup default; verify the effective model from the session header.

Capture each subagent run to a log file, never through a pipe. Give the run a timeout you set, and a provider, model, and thinking level. Pre-flight the brief, then run and record the exit code and elapsed seconds:

```bash
brief=<path to brief>                    # the subagent's instructions; must be non-empty
[ -s "$brief" ] || { echo "brief missing or empty: $brief" >&2; exit 1; }
run_timeout=<seconds>                    # the run's timeout; set it yourself
start=$(date +%s)
timeout "$run_timeout" pi --provider <provider> --model <model> --thinking <level> -p "$(cat "$brief")" > /tmp/review.log 2>&1
rc=$?
echo "rc=$rc secs=$(( $(date +%s) - start ))" > /tmp/review.meta
```

A `rc=0` with an empty log means the subagent did no work: treat it as an outcome of failure. A `rc=0` with a non-empty log means the subagent ran; check its output.

Resuming an interrupted session needs an explicit continuation prompt: `pi --session <path>` opens the session but does not continue on its own. Resume with `pi --session <path> "Continue and give your verdict."`.

A `Warning: No models match pattern` message means pi did not keep the requested model and fell back to the startup default; it is not benign noise. Confirm the effective model before trusting a run: give the run an explicit session path (`pi --session /tmp/review.jsonl ...`) and read the model from that file with `grep -o '"model":"[^"]*"' /tmp/review.jsonl | sort -u`.
