# Agent Context Brief — Pi-Specific Behavior (global)

This file is loaded by pi on every session start as the first AGENTS.md layer, via its CWD-walk discovery mechanism (~/.pi/agent/AGENTS.md). It describes pi-specific behavior that applies regardless of the project being worked on.

Project-specific context lives in `sandbox/AGENTS.md` (loaded second, concatenated after this file). See that file for project conventions, commands, and architecture.

---

## Agent Harness

You are running inside the **agent-sandbox** harness. Your working directory (`sandbox/`) contains a git-initialised snapshot of the project repository. All changes you make are captured as diffs and reviewed by a human operator before being applied.

### Two-layer container architecture

Every session runs two containers. You are inside the **reasoning** (agent runtime) container. A separate **capability** (sandbox) layer container runs the diff pipeline, snapshot, and autosave. Each has its own `/opt/sandbox/lib/` with a different subset of library files — a file missing in one container is
not necessarily a regression; it may belong only to the other layer.

Key behavioral rules:
- Do not modify files outside `sandbox/`.
- The changes in each session (represented by the task list of a single handover) must correspond to a single commit at session close with a type prefix per [`docs/operations/git_policy.md`](docs/operations/git_policy.md). Intermediate WIP and correction commits during the session are acceptable.
- Changes are ported from the container to a draft branch on host; the operator reviews the merge before applying.

## Write Discipline

Code changes should be self-contained within a single session. The operator reviews per-session diffs — fragmented or half-applied changes across sessions
create review burden.

When writing code, always take into account the following:

1. Does this need to exist?   → no: skip it (YAGNI)
2. Already in this codebase?  → reuse it, don't rewrite
3. Stdlib does it?            → use it
4. Native platform feature?   → use it
5. Installed dependency?      → use it
6. One line?                  → one line
7. Only then: the minimum that works

Before creating any new document, read [`docs/operations/discussion_policy.md`](docs/operations/discussion_policy.md) and [`docs/operations/adr_policy.md`](docs/operations/adr_policy.md).

**Handover rules**

- Close → done. No commits after close. Open a new handover for new work.
- Type must match dominant activity at close. Rename if it diverged.
- Implementation needs its own handover. A design handover does not cover impl commits.
- Every session updates the roadmap checkboxes for completed tasks.

Each session is independent. The prior session's git history is not available (container is ephemeral). The session starts from the project's committed HEAD.

Tools you have access to:
- `/package-branch` — export committed changes as numbered diffs
- `/package-diff` — export a single diff for review
- Standard development tools (git, bash, common CLI utilities)

## Fresh Subagent Invocation

When a fresh perspective is needed for code review (e.g. thermo-nuclear review of changes made in the current session), invoke a fresh subagent using:

```
pi -p "Subagent instructions..."
```

The `-p` flag spawns a new subagent with a clean context — it does not inherit the current session's conversation history, loaded files, or tool state. Use this when the current agent may have blind spots from extended work on the same code.

The subagent's output is returned inline. It cannot persist files to the sandbox or make git commits — it is a read-only reviewer. The results should be triaged by the primary agent.