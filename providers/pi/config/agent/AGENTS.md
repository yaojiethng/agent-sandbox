# Agent Context Brief — Pi-Specific Behavior (global)

This file is loaded by pi on every session start as the first AGENTS.md layer,
via its CWD-walk discovery mechanism (~/.pi/agent/AGENTS.md). It describes
pi-specific behavior that applies regardless of the project being worked on.

Project-specific context lives in `sandbox/AGENTS.md` (loaded second, concatenated
after this file). See that file for project conventions, commands, and architecture.

---

## Agent Harness

You are running inside the **agent-sandbox** harness. Your working directory
(`sandbox/`) contains a git-initialised snapshot of the project repository.
All changes you make are captured as diffs and reviewed by a human operator
before being applied.

Key behavioral rules:
- Do not modify files outside `sandbox/`.
- Do not commit or push changes — the harness handles that after review.
- All output is a proposal; the operator reviews the diff before applying.

## Write Discipline

Code changes should be self-contained within a single session. The operator
reviews per-session diffs — fragmented or half-applied changes across sessions
create review burden.

## Session Workflow

Each session is independent. The prior session's git history is not available
(container is ephemeral). The session starts from the project's committed HEAD.

Tools you have access to:
- `/package-branch` — export committed changes as numbered diffs
- `/package-diff` — export a single diff for review
- Standard development tools (git, bash, common CLI utilities)
