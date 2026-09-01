# Two-Container Separation

**Current:** 2026-09-01

*Decision settled when the MCP-server investigation resolved (promoted to M2.1); recorded here 2026-09-01 — the original settlement date is unrecoverable from the squashed git history.*

## 2026-09-01 -- Reasoning and capability layers are separate containers

**Decision:** The harness separates into two containers with different responsibilities and different reasons to vary. The **capability layer** is always present as a container: it owns the sandbox, controls what working content the agent can reach, and is isolated per project. The **reasoning layer** runs the model, manages conversation, injects context, and presents the operator interface; it is isolated from the host but not per-project, and is swappable without changing how project content is accessed. The MCP server is an optional capability-layer interface, giving three configurations (sandbox only; sandbox + MCP, no direct mount; sandbox + MCP + direct mount); hooks and audit trails attach to the MCP server when present and have no attachment point in the sandbox-only configuration.

**Rationale:** The two layers have different isolation requirements and vary for different reasons: the capability layer varies by project type — its tool surface and sandbox contents are determined by what the project requires — while the reasoning layer varies by operator preference — model, interface, cost, deployment context. The separation was surfaced by the MCP-server investigation ([`investigation_mcp_server.md`](../../devlog/discussions/investigation_mcp_server.md), Conclusion): the original harness conflated the two concerns in one container, so adding a new reasoning layer required understanding the snapshot pipeline, mount shape, and diff pipeline — all capability-layer concerns — coupled at the Dockerfile, entrypoint, scripts, and documentation level. Conceptual model: [two_layer_model.md](../concepts/two_layer_model.md).

**Rejected alternatives:**
- *Fused single-container harness (status quo ante)* — one container held the
  agent runtime, project snapshot, diff pipeline, and mount shape; the concerns were coupled everywhere, and every provider addition paid the capability layer's comprehension cost. See historical entry.
- *Full MCP inversion (server as the only stable component, agent harness a
  pure variable)* — considered in the investigation; the adopted direction keeps the harness provisioning both containers, with MCP as an optional capability-layer interface rather than a replacement architecture.

**Edge cases / drivers:** Parallel sessions of one project each need their own isolated capability layer (see [sandbox_delivery_model.md](sandbox_delivery_model.md) for the delivery model and [session_identifier.md](session_identifier.md) for the identity factor that distinguishes them). Audit-trail and hook workflows require the MCP configuration — the sandbox-only configuration cannot carry them.
Provider onboarding must not require capability-layer knowledge.

## 2026-09-01 -- M1-era (pre-M2): fused single-container harness

**Decision:** One container per project held everything: the agent runtime (OpenCode), the project snapshot in `sandbox/`, the diff pipeline, and the mount shape. The agent had direct filesystem access to working content on a copy; the host protected itself by not mounting `PROJECT_ROOT` directly.

**Reason superseded by 2026-09-01 (settled M2.1):** The investigation into MCP-server capability delivery showed the container conflated two concerns with different isolation requirements and different reasons to vary. Every new reasoning layer had to absorb capability-layer complexity; the boundary between "what the project needs" and "what the operator prefers" had no place to live. The two-container split gives each concern its own container, its own variation axis, and its own interface.
