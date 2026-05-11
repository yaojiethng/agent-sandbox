# AGENTS.md — <Provider Name> (<project name>)

<!--
  This is the reference template for provider-layer AGENTS.md files.
  Copy this file to providers/<n>/config/AGENTS.md and fill in the
  provider-specific sections. Remove all comment blocks before committing.

  Authoring rules:
  - This file orients the agent to its immediate environment: container
    context, input/output channels, and provider-specific tools or commands.
  - Do not include project workflow, session conventions, collaboration
    principles, or reading lists — those belong in the project-layer AGENTS.md
    at the repository root.
  - Do not duplicate content from the project-layer AGENTS.md. Link to it
    where context is needed.
  - Keep this file short. An agent reading it should finish in under 60 seconds
    of context consumption.

  See docs/concepts/agent_workflow.md — Agent Context Model for the two-layer
  model this file participates in.
  See docs/operations/provider_onboarding_guide.md for the authoring step.
-->

## Interface

<!--
  One paragraph. Describe what this interface is and its primary constraint.
  Examples:
  - "Pi terminal agent running inside a container. Full filesystem and shell access."
  - "Claude Chat (claude.ai). Artifacts are available. No direct filesystem access."
-->

---

## Sandbox Context

<!--
  Describe the container environment the agent is running in.
  Cover:
  - Where the working directory is and what it contains
  - What the agent's relationship is to the host repository (snapshot, not live)
  - What happens to outputs on exit (diff pipeline, operator review)
  - That the agent runtime is explicitly untrusted
-->

You are executing inside a container. Your working directory (`sandbox/`) contains a snapshot of the project repository. All changes you make are captured as a diff on container exit and reviewed by a human operator before being applied to the repository.

The agent runtime is explicitly untrusted. The operator has final authority over all outputs.

---

## Input and Output Channels

<!--
  List the paths the agent should read from and write to.
  Standard paths (adjust if the provider differs):
-->

| Channel | Path | Direction | Notes |
|---|---|---|---|
| Task input / operator files | `~/workspace/input/` | Read | Bind-mounted read-only at session start |
| File output | Working directory (`sandbox/`) | Write | Captured as diff on exit |
| <!--Provider-specific channel, e.g. chat UI--> | <!-- path or N/A --> | <!-- Read/Write --> | <!-- notes --> |

---

## Tools

<!--
  List the tools available in this provider. Be explicit — agents should not
  assume tools exist if they are not listed here or discovered in the session.

  Example structure (adapt to provider):
-->

### Available Tools

| Tool | Purpose |
|---|---|
| <!-- tool name --> | <!-- what it does --> |

### Tool Use Preferences

<!--
  Provider-specific tool use guidance. Examples:
  - Prefer `edit` over `write` for existing files
  - Parallelise independent reads and searches
  - Use `bash` for grep, find, ls — not for git mutations
-->

### Discovery Protocol

<!--
  If the provider supports skills or extensions that may be present but are
  not guaranteed, describe how the agent should check for them at session start.
  Omit this section if the provider has a fixed, known toolset.
-->

---

## Output Mechanism

<!--
  Describe how the agent delivers file and document outputs in this interface.
  Examples:
  - "Write files directly to the working directory. Prefer targeted edits over
    full-file rewrites when only a section has changed."
  - "All document and file outputs are produced as artifacts, one artifact per
    file. Inline chat prose is not a substitute for an artifact when the output
    is intended for the repository."
-->

---

## Session Start

<!--
  Provider-specific session initialisation instructions only.
  Do not repeat the project-layer reading list — link to AGENTS.md at repo root.
  Cover only what is specific to this interface:
  - How the operator signals session start (if non-standard)
  - Any provider-specific checks or orientation steps
  - File access constraints specific to this interface
-->

At session start, read the project-layer `AGENTS.md` at the repository root for the full reading list and workflow conventions.

<!-- Add any provider-specific session start steps below. -->

---

## Constraints

<!--
  Provider-specific constraints only. Do not repeat sandbox boundary rules
  that are already in the project-layer AGENTS.md.
  Examples:
  - Memory persistence (or lack of it) across sessions
  - File access gates specific to this interface
  - Commands that must never be run in this provider
-->
