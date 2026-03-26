# Two-Layer Architecture — Reasoning and Capability Layers

**Status:** Adopted. Implemented in M2.

---

> **Context:** This document records the conceptual model and the decision. Implementation details are distributed across [`execution_model.md`](../architecture/execution_model.md), [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md), and [`container_model.md`](../architecture/container_model.md). The reasoning behind this decision is in [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md) — Conclusion section.

---

## The Model

The harness separates into two layers with different responsibilities and different reasons to vary.

**Reasoning layer** — runs the model, manages conversation, injects context, presents an interface to the operator. The choice of reasoning layer (OpenCode, Claude Code, or any MCP-compatible client) depends on capability, cost, UX, and deployment context. It should be swappable without changing how project content is accessed.

**Capability layer** — owns the sandbox and controls what working content the agent can reach. It is always present as a container. It holds the sandbox — a copy of the working content prepared by the harness before the session, following the same copy pattern as M1.x. It exposes working content to the reasoning layer and optionally mediates access via an MCP server.

The layers are separate because they vary independently. The capability layer varies by project type — the tool surface and sandbox contents are determined by what the project requires. The reasoning layer varies by operator preference — model, interface, cost profile. Fusing them coupled both concerns into the same container image and Dockerfile.

---

## Capability Layer Configurations

The capability layer container is always present. What varies is whether an MCP server process runs inside it and how working content is exposed to the reasoning layer.

**Sandbox only** — the capability layer exposes the sandbox as a volume mount to the reasoning layer, also mounted as the sandbox. The reasoning layer accesses working content directly via its built-in tools. No MCP server runs. Appropriate when the diff is sufficient evidence of what happened; no per-command audit trail is available in this configuration.

**Sandbox + MCP, no direct mount** — the capability layer runs an MCP server that exposes working content as a tool interface. The reasoning layer has no direct volume mount to the sandbox; all access is mediated by the MCP server, which validates every call. Appropriate when audit trail, hooks, or workflow-specific tooling are required without direct filesystem access.

**Sandbox + MCP + direct mount** — the capability layer runs an MCP server and also exposes the sandbox as a volume mount to the reasoning layer as the sandbox. The reasoning layer has both direct filesystem access and MCP tools for structured operations (search, frontmatter queries, tag operations). Appropriate for vault workflows where rich tooling is valuable alongside direct access.

**Hooks and audit trail** attach to the MCP server when present. They have no attachment point in the sandbox-only configuration. If a workflow requires them, the appropriate MCP configuration is selected.

---

## Why the Layers Are Separate

The capability layer must always be isolated per project — it holds the working content and defines what the agent can reach. The reasoning layer needs isolation from the host but not necessarily per-project isolation; its concern is model behaviour and conversation state, not filesystem access.

The MCP protocol is the interface when a capability layer MCP server is present. Any MCP-compatible reasoning layer is a conforming client without custom integration work. When no MCP server is present, the interface is the volume mount alone. Either way, the reasoning layer is swappable without changing the capability layer configuration.

---

## Diff Pipeline

The diff pipeline runs post-session against the sandbox in the capability layer container. The harness generates the diff after the session ends and writes it to the output channel for operator review. The operator workflow — review diff, apply to host repository — is unchanged from M1.x. Implementation details are in `execution_model.md`.

---

## Architecture Documents

The following documents implement this conceptual model:

| Document | Responsibility |
|---|---|
| [`execution_model.md`](../architecture/execution_model.md) | Directory layout, invocation model, index to mechanism documents |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot pipeline, git baseline, diff pipeline, input channels, apply workflow |
| [`container_model.md`](../architecture/container_model.md) | Compose generation, mount shape rationale, container lifecycle, entrypoint sequences |
| [`tool_interface.md`](../architecture/tool_interface.md) | External contract: command shapes, naming, mount guarantees, execution modes |
| [`security.md`](../architecture/security.md) | Trust boundaries and security invariants |

Changes to any of these documents should be checked against this conceptual model before being accepted.
