# User Story — Knowledge Store Provider

**Status:** Resolved. Work promoted to M2. See Resolution section.

---

> **Required reading before this document:**
> - [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — container lifecycle, mount shape, entrypoint sequence, and diff pipeline.
> - [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants that any solution must satisfy.

---

## Context

OpenCode has inadequate support for repositories composed of large volumes of markdown files. This story investigates what changes to the provider or stack are needed to unblock vault-scale agent work.

---

## Pain Points

**1. Lack of first-class text support (need-to-solve)**
Interactive mode does not support uploading `.md` files directly and has no efficient mechanism for searching or reasoning across large volumes of text files. Context window management, file navigation, and multi-file edits across a vault are not well-handled. This blocks KV5.

**2. Harness workflow constraints (good-to-have)**
The current harness workflow is designed around coding project conventions. Vault-specific conventions (flat file structures, frontmatter, binary attachments, no build artefacts) are not accounted for. This makes the workflow harder to use even with a capable agent. Tracked separately in the roadmap.

This story addresses Pain Point 1 only.

---

## Investigation Findings

Two independent directions for solving Problem 1. They are not mutually exclusive — a provider replacement can be combined with stack supplementation.

### Direction 1 — Replace the provider

Swap OpenCode for a provider with better out-of-the-box support for large markdown-heavy workloads. Requires the provider to conform to the harness provider interface (M1.7) or to replace the harness entirely (Claude Desktop path — see note below).

**Provider candidates:**

| Candidate | Status | Report |
|---|---|---|
| Claude Code | In progress | [investigation_claude_code.md](investigation_claude_code.md) |
| Claude Desktop | Not started | [investigation_claude_desktop.md](investigation_claude_desktop.md) |
| Hermes | Not started | [investigation_hermes.md](investigation_hermes.md) |
| Pi | Not started | [investigation_pi.md](investigation_pi.md) |

**Note on Claude Desktop:** If Claude Desktop is selected, it can potentially replace the agent harness entirely — no harness container, just Claude Desktop connected to a Dockerized MCP server. This eliminates harness integration work but weakens security guarantees and creates platform lock-in. It is a distinct sub-case of Direction 1 and is covered in the MCP server investigation below.

Provider investigations answer a standard set of questions defined in [Investigation Questions](#investigation-questions).

### Direction 2 — Supplement the current stack

Keep OpenCode but address the text support gap by adding capabilities to the stack. Two supplementation options, each investigated separately:

| Option | Status | Report |
|---|---|---|
| Dockerized Obsidian MCP Server | In progress | [investigation_mcp_server.md](investigation_mcp_server.md) |
| Workspace input channel (task briefs + file pre-scoping) | Not started | [investigation_workspace_input_channel.md](investigation_workspace_input_channel.md) |

---

## Constraints

Any candidate provider must support the existing execution modes or declare them explicitly as unsupported:

| Mode | Description |
|---|---|
| `serve` | Interactive terminal wrapped in a webapp; operator connects via browser on an exposed port |
| `start` | Interactive terminal via direct TTY |
| `dry-run` | Liveness check only; confirms the provider initialises correctly |
| `headless` | Non-interactive with task passing — reserved, M2 target |

A provider that does not support `serve` natively must either have an evaluated third-party wrapper or declare the mode unsupported. The diff and apply workflow must remain unchanged from the operator's perspective regardless of provider.

---

## Investigation Questions

All provider candidate investigations (Direction 1) must answer:

1. **Execution model** — does the provider support `start` and `dry-run`? Does it have a native serve/web mode, or does it require a third-party wrapper for `serve`? Is there a viable `headless` invocation path for M2?
2. **Authentication** — what mechanism does the provider use in a containerised environment? Can it be injected via environment variable without interactive setup?
3. **Dockerfile and image** — what does the provider require to install in a minimal Ubuntu container? Are there additional system dependencies beyond what the current image provides?
4. **Harness reuse** — which components of `providers/opencode/` are reusable? Does anything in `libs/` or `scripts/` need to change?
5. **Sandbox constraint compatibility** — can the provider confine file operations to `sandbox/` without host access?
6. **Document repository suitability** — can the provider navigate and edit large flat or nested markdown structures effectively? Does it handle binary file awareness correctly?

---

## Resolution

**Decision date:** M1.5  
**Outcome:** Both investigation directions converge on the two-layer architecture (reasoning layer / capability layer). Work is promoted to M2. This story is closed.

### What was decided

The investigation surfaced that the core problem was not the choice of agent runtime — it was the fused architecture that coupled the agent to its working content. The right fix is architectural: separate the capability layer (what the agent can do) from the reasoning layer (which agent runs). Any MCP-compatible reasoning layer can then work with any capability layer that exposes the right tools.

Full rationale in [`investigation_mcp_server.md`](investigation_mcp_server.md) — Conclusion section. Conceptual model in [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md).

### Where each investigation thread goes

**Direction 1 — Provider candidates (Claude Code, Claude Desktop, Hermes, Pi)**  
These become reasoning layer candidates. Investigations continue as M2 prerequisite work. The evaluation framing changes: candidates no longer need to conform to a per-provider script interface; they need to be MCP-compatible clients. Investigation questions 4 (harness reuse) and 5 (sandbox constraint compatibility) are now answered differently under the two-layer model — update investigation stubs when resuming.

**Direction 2 — MCP server (Dockerized)**  
This is the capability layer prototype and is the primary M2.1 work. `investigation_mcp_server.md` is the design document. Open questions (MCP server selection, working mount strategy) are M2.1 tasks.

**Direction 2 — Workspace input channel**  
Absorbed into the reporting workspace design. The operator input channel (`SANDBOX_DIR/input/`) is implemented in M1.5 as part of the directory restructuring. The `investigation_workspace_input_channel.md` open questions around mount shape and lifecycle are resolved by the M1.5 implementation. The `TASK.md` alignment with M2.5 (autonomous task execution) remains a pending decision in M2.5.

### Story status per use case

| Use case | Status | Where it goes |
|---|---|---|
| Vault (Obsidian) — agent modification workflow (KV5) | Pending M2.1 | Capability layer prototype |
| Website dev — bash-enabled sandbox, live reload | Deferred | M2.2 as bash-enabled capability layer use case |
| General coding — current OpenCode workflow | Unchanged | Continues to work under current model through M1.x |

