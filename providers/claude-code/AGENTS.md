# AGENTS.md — Claude Code (agent-sandbox)

## Interface

Claude Code terminal agent. Full filesystem and shell access via native tool set. Operates directly in the project working directory.

---

## Sandbox Context

You are executing inside a container. Your working directory (`sandbox/`) contains a snapshot of the project repository. All changes you make are captured as a diff on container exit and reviewed by a human operator before being applied to the repository.

The agent runtime is explicitly untrusted. The operator has final authority over all outputs.

---

## Input and Output Channels

| Channel | Path | Direction | Notes |
|---|---|---|---|
| Operator files | `~/workspace/input/` | Read | Bind-mounted read-only at session start |
| File output | Working directory (`sandbox/`) | Write | Captured as diff on exit |

---

## Tools

Claude Code provides native file and shell tools. Do not assume capabilities beyond what is confirmed available in the current session.

### Tool Use Preferences

- Prefer targeted file edits over full-file rewrites when only a section has changed.
- Use shell tools (`grep`, `find`, `ls`) for exploration before opening files in full.
- Parallelise independent reads, searches, and checks where safe.
- Do not run `git commit`, `git push`, or any command that mutates git history.

### Discovery Protocol

If project-specific tools or scripts are referenced in documentation but their availability is uncertain, verify with `ls` or `which` before invoking.

---

## Output Mechanism

Write files directly to the working directory. Prefer targeted edits over full-file rewrites when only a section has changed. When producing multiple related files, complete them in a logical sequence and summarise what was written and why at the end.

Do not produce outputs as chat prose when the deliverable is a file — write the file.

---

## Session Start

At session start, read the project-layer `AGENTS.md` at the repository root for the full reading list and workflow conventions.

Then orient to the task:

1. **Read the handover and roadmap** — find the most recent `docs/devlog/handovers/YYYYMMDD-NN-TYPE-*.md` and read it. Then read `docs/devlog/roadmap.md` for the current sub-milestone and pending tasks.
2. **State your scope** — before writing any file, state in chat: what you understand the task to be, which files you intend to read and change, anything explicitly out of scope, and any question that must be resolved before you can begin.
3. **Read before writing** — use `grep` and targeted reads to establish what you need from each file before opening it in full. Do not read entire directories.

Memory persists within a session but not across sessions. The handover and roadmap are the authoritative record of prior session state — do not rely on conversation history from a previous session.

---

## Constraints

- **No commit or push.** Do not run `git commit`, `git push`, or any command that mutates git history.
- **No secrets.** Gitignored files are excluded from the snapshot and are not present in your working directory. Do not attempt to create or infer them.
- **Sandbox boundary.** Work exclusively inside your working directory. Do not attempt to access paths outside it.
