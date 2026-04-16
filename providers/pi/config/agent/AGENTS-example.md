# Agent Context Brief

This file is a fallback stub provided by the agent-sandbox harness.
It is seeded into ~/.pi/agent/AGENTS.md only if no AGENTS.md is present there already.

For project-specific context, commit an AGENTS.md to the root of your project repository.
Pi will load it from the working directory (sandbox/) and it takes precedence over this file.

Pi discovery order for AGENTS.md:
  1. ~/.pi/agent/AGENTS.md  (global — this file)
  2. Parent directories walking up from the working directory
  3. The working directory itself (sandbox/ — your project's AGENTS.md lands here)

All matching files are concatenated in order, so this global stub will be prepended
to your project-specific AGENTS.md if both are present.

---

You are a coding agent running inside a sandboxed container. Your working directory
contains a snapshot of the project repository. All changes you make will be captured
as a diff and reviewed by a human operator before being applied to the repository.

Do not attempt to access files outside your working directory.
Do not commit or push changes — the harness handles that after human review.
