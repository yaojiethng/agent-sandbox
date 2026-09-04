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
- The changes in each iteration (represented by the task list of a single handover) must correspond to a single commit at iteration end with a type prefix per [`docs/operations/git_policy.md`](docs/operations/git_policy.md). Intermediate WIP and correction commits during the iteration are acceptable.
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

Before creating any new document, read [`docs/operations/discussion_policy.md`](docs/operations/discussion_policy.md) and [`docs/operations/adr_policy.md`](docs/operations/adr_policy.md).

**Handover rules**

- Close -> done. No commits after close. Open a new handover for new work.
- Type must match dominant activity at close. Rename if it diverged.
- Implementation needs its own handover. A design handover does not cover impl commits.
- Every iteration updates the roadmap checkboxes for completed tasks.

Each iteration is independent. The prior iteration's git history is not available (container is ephemeral). The iteration starts from the project's committed HEAD.

Tools you have access to:
- `/package-branch`  --  export committed changes as numbered diffs, uncommitted diff, and changed files
- Standard development tools (git, bash, common CLI utilities)

## Technical Writing Rules

Apply these to all prose you write: documentation, comments, chat deliverables, handovers. Full policy: `docs/operations/documentation_policy.md` in the target repo when present.

- Meet ASD-STE100. Delete-test every word, phrase, and sentence: if a reader can delete it without losing required meaning, delete it.
- Active voice. Name the actor: "the seeder copies the repository", never "the repository is copied".
- Short sentences. Aim under 20 words; one idea per sentence.
- One term, one meaning. Pick one word for a thing and keep it; do not rotate synonyms.
- Common verbs. Prefer: is, has, uses, copies, reads, writes, runs, starts, stops, shows, checks, rejects. Avoid ornate verbs ("leverages", "facilitates", "encompasses").
- No idioms, no metaphors, no hedging ("somewhat", "fairly", "arguably").
- Place the defined noun phrase before the imperative command: the reader must know exactly what object is being discussed before being told what to do with it. If the sentence uses a term the reader has not met, define it first, in its own clause, then apply it. Avoid thin subjects that rely on a trailing dash clause for definition; the main clause must not depend on its afterthought.
- One paragraph per physical line, however long the line. Never break inside a paragraph -- not at sentence boundaries, not at a column limit. Hard breaks separate blocks only.
- Plain ASCII punctuation. Write a dash as a space-separated hyphen (` - `), or as a double hyphen (`--`) in prose. No non-ASCII symbols, no checkmark or cross emoji.
- Link sparingly. Link what the reader might need next; keep context-only names as plain text. Do not over-link transient documents (handovers, discussion docs, session exports).
- Records state, not session history. A durable record does not narrate the session that produced it: no session ids, no commit hashes, no "as discussed" pointers.

## Fresh Subagent Invocation

When a fresh perspective is needed for code review (e.g. thermo-nuclear review of changes made in the current iteration), invoke a fresh subagent using:

```
pi -p "Subagent instructions..."
```

The `-p` flag spawns a new subagent with a clean context  --  it does not inherit the current session's conversation history, loaded files, or tool state. Use this when the current agent may have blind spots from extended work on the same code.

The subagent runs in the same container/workspace as the primary agent, with the same tools  --  it **can** persist file edits and run git commits. It starts with a clean conversation context, so it cannot see this session's chat history, in-memory files, or tool state; pass everything it needs in the `-p` argument or on disk. Its output is returned inline. The results should be triaged by the primary agent.