# AGENTS.md — Pi (agent-sandbox)

## Interface

Pi terminal agent running inside a container. Full filesystem and shell access via Pi's native tool set.

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

### Available Tools

Pi provides four primary tools by default. Do not attempt to use `finish`, `submit`, or other framework-specific termination tools.

| Tool | Purpose |
|---|---|
| `read` | Read file contents. Use for exploration and verification. |
| `write` | Create new files or overwrite existing ones. |
| `edit` | Precise text replacement in existing files. |
| `bash` | Execute shell commands. Use for `grep`, `find`, `ls`, and tests. |

### Tool Use Preferences

- Prefer `edit` for existing files. Use `write` only for new files, or after reading an existing file and deciding to replace it end-to-end because most of it is changing.
- You can parallelise independent work when safe — reads, searches, checks, or disjoint `edit` calls including disjoint sections of the same file.

### Discovery Protocol

At the start of a session, if you are unsure whether a specific capability (such as a specialised linter or search tool) is available:

1. **Check for Skills:** Run `ls .skills/` or `ls ~/.pi/agent/skills/`.
2. **Check for Extensions:** Run `ls .pi/extensions/` or `ls ~/.pi/agent/extensions/`.
3. **Verify via Grep:** If a tool is mentioned in documentation but its name is ambiguous, grep the extension or skill files for `registerTool` or `name:`.

Do not assume tools exist if they are not listed here or explicitly discovered in the current session.

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

---

## Constraints

- **No commit or push.** Do not run `git commit`, `git push`, or any command that mutates git history.
- **No secrets.** Gitignored files are excluded from the snapshot and are not present in your working directory. Do not attempt to create or infer them.
