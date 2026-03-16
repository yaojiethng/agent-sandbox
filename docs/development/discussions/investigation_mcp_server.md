# Investigation — Dockerized Obsidian MCP Server

**Status:** Resolved. MCP server architecture adopted as the capability layer. Work promoted to M2.1. See Conclusion section.

**Direction:** Direction 2 — Stack supplementation  
**Parent story:** [story_provider_knowledge_store.md](story_provider_knowledge_store.md)

---

> **Required reading before this document:**
> - [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — container lifecycle, mount shape, and entrypoint sequence. This option departs from the current model significantly; understanding the baseline is prerequisite.
> - [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants. Several invariants do not hold under this option as stated.
> - [story_provider_knowledge_store.md](story_provider_knowledge_store.md) — investigation questions this report answers.

---

## Summary

Rather than running an AI agent inside a harness container, this option runs a dockerized MCP server that exposes the vault as a tool interface. Any MCP-compatible agent harness can attach to the server and interact with vault contents through tool calls — the agent never touches the working filesystem directly. The agent retains its own reporting workspace for briefs, state tracking, and progress output, which is a direct mount managed by the harness as now. Isolation of the working content is provided by the container boundary around the MCP server.

This is a fundamentally different architecture from the current provider model. The MCP server is the stable component; the agent harness is a variable. Any harness that supports MCP — Claude Desktop, OpenCode with MCP configuration, or others — can be used without changing the server or vault setup. It does not slot in as a new provider under the existing harness, though OpenCode with MCP configured is a candidate integration path that would partially reuse the current harness model.

---

## Architecture

### Two-workspace model

The agent operates across two distinct workspaces with different access patterns and purposes:

**Working workspace** — owned by the MCP server container. The agent has no direct filesystem path to it; all access is via tool calls. This is where project content lives and where the agent makes changes. The container boundary enforces isolation — the agent's built-in filesystem tools have nothing to reach because no working workspace mount exists in the agent container.

**Reporting workspace** — owned by the agent container. A direct mount, read-write, managed by the harness as now. This is where the agent reads the brief, writes `todo.md`, tracks task state, and logs progress. No MCP involved. Maps directly onto the existing `.workspace/` mount.

```
Agent container
├── .workspace/ mount (reporting — brief in, todo/state/progress out)
│   read-write, direct mount, no MCP
└── HTTP → MCP server container (working — vault/project content)
            ├── MCP server process
            │   └── tool interface (read, write, search, list, ...)
            └── /working mount ← vault or project files
```

This is a refinement of the current harness model, not a replacement. The current harness already has the reporting workspace (`.workspace/`) and the working workspace (`sandbox/` inside the agent container). The structural change is that the working workspace moves out of the agent container into the MCP server container, accessed only via tools. The reporting workspace is unchanged.

**Diff pipeline migration:** Currently the diff runs inside the agent container against `sandbox/`. Under this model it runs against the MCP server's working mount after the session ends — either inside the MCP server container, or by the harness comparing the working mount against the original before teardown. Output still lands in `.workspace/changes/patch.diff` for operator review as now.

**Agent harness candidates:**

- **Claude Desktop (host)** — anecdotally reported to work; chat UI; connects via stdio (spawns container) or HTTP. Not managed by the harness. Reporting workspace equivalent is less well-defined.
- **OpenCode in harness container** — preferred path. OpenCode runs in a container as now, with `.workspace/` mounted as the reporting workspace. No working workspace mount. MCP server runs as a second container on the same Docker network; OpenCode connects via HTTP. Both containers managed by the harness. Whether OpenCode correctly uses MCP tools rather than its built-in filesystem tools when no working mount is present is the primary open question.
- **Other MCP-compatible clients** — any client implementing the MCP protocol is a candidate.

---

## Findings Against Investigation Questions

### 1. Execution model

The harness model changes depending on which agent harness is used. What remains constant across all harness choices is the MCP server container lifecycle: the server is started before the agent session, the agent calls tools during the session, and the server is stopped after.

**Transport options for MCP communication:**

- **stdio:** The agent harness spawns the MCP server container as a subprocess (`docker run -i --rm ...`) and communicates over stdin/stdout. No port exposure required. The container lifecycle is managed by the harness. This is the standard pattern for Claude Desktop + Docker MCP Catalog servers and is the lower-complexity path.
- **HTTP (Streamable HTTP / SSE):** The MCP server listens on a port inside the container; the agent connects via `http://localhost:<port>/mcp` (or across a Docker network for containerised agents). The container must be started separately and kept running. Required for cross-container communication (e.g. OpenCode in a harness container connecting to the MCP server container). Requires port binding to `127.0.0.1` when exposed to host; internal Docker networking when container-to-container.

**Harness-specific execution model notes:**

- **Claude Desktop:** Persistent desktop app; no `start`/`serve`/`dry-run` lifecycle managed by the harness. The harness (if any) only manages the MCP server container. Session boundaries are operator-defined.
- **OpenCode with MCP:** OpenCode runs inside a harness container as normal; the MCP server runs in a separate container on the same Docker network; OpenCode is configured to connect via HTTP. The existing harness `start`/`dry-run` lifecycle applies to the OpenCode container. MCP server lifecycle is managed separately (started before the OpenCode container, stopped after). Whether OpenCode correctly uses MCP tools instead of direct filesystem operations in this configuration is unvalidated — this is the primary open question for this harness path.

### 2. Authentication

Two separate authentication concerns exist and must not be conflated:

**Agent authentication (AI model access):** This depends entirely on which harness is used and is outside the scope of the MCP server investigation. Claude Desktop uses the user's Claude account. OpenCode uses `OPENCODE_API_KEY` or equivalent. These are unchanged harness concerns.

**MCP server authentication (vault access):** The MCP server container controls access to the vault. Two patterns:

- **Filesystem-based MCP servers** (direct vault access via `VAULT_PATH`) — no auth token required. The container mount is the access control mechanism. The server is only reachable by processes that can connect to its stdio pipe or HTTP port.
- **Obsidian Local REST API-based MCP servers** — require the Local REST API plugin running inside Obsidian and an API key injected into the MCP server container as an environment variable. This adds a dependency on the Obsidian desktop application running concurrently, which is not suitable for a harness-managed or automated scenario.

Filesystem-based servers are the appropriate path: no plugin dependency, no running Obsidian instance required, and access control is the container boundary and network exposure.

### 3. MCP server candidates

Several filesystem-based MCP servers for Obsidian vaults are available. These require no Obsidian plugin and operate directly against the vault directory:

| Candidate | Transport | Vault access | Docker support | Notes |
|---|---|---|---|---|
| `mcp/obsidian` (Docker MCP Catalog) | stdio | Via Obsidian REST API plugin | Official Docker image | Requires running Obsidian + plugin; likely not suitable |
| `@mauricio.wolff/mcp-obsidian` (bitbonsai) | stdio | Direct filesystem | npm, no official image | 14 tools, zero deps, path validation, `.obsidian/` excluded |
| `smith-and-web/obsidian-mcp-server` | HTTP/SSE | Direct filesystem | Dockerfile + compose provided | Express.js server; docker-compose workflow documented |
| `obsidian-mcp` (PyPI) | stdio | Direct filesystem | No official image | Python; SQLite search index in `.obsidian/`; image analysis |
| `@modelcontextprotocol/server-filesystem` | stdio | Generic filesystem | Official Docker image (`mcp/filesystem`) | Not Obsidian-specific; no vault-aware search or frontmatter handling |

For this investigation, the relevant candidates are filesystem-based with Docker support. The generic `mcp/filesystem` server is the most auditable (official Anthropic reference implementation) but lacks vault-aware capabilities (tag search, frontmatter queries, markdown-aware edits). Vault-specific servers offer richer tooling but are community-maintained.

A custom MCP server is also viable and may ultimately be the right answer if no existing candidate satisfies both auditability and capability requirements.

### 4. Harness reuse

Harness reuse depends on which agent harness is used.

**Claude Desktop path:** Most existing harness components do not apply. `start_agent.sh`, `container-entrypoint.sh`, the snapshot pipeline, and the diff pipeline are all bypassed. The reporting workspace concept has no clean equivalent since Claude Desktop is not a container managed by the harness. Secrets handling follows the same `.env` pattern. New scripts are needed for MCP server container lifecycle and diff generation against the working mount.

**OpenCode + MCP path (preferred):** High harness reuse. `start_agent.sh` continues to manage the OpenCode container lifecycle. `.workspace/` continues to be mounted as the reporting workspace — unchanged. The snapshot pipeline changes: instead of snapshotting into `sandbox/` inside the OpenCode container, the harness snapshots into the MCP server's working mount before the server starts. `libs/diff.sh` moves to run against the MCP server's working mount after session end rather than inside the agent container. `build_agent.sh` and `libs/image.sh` are unchanged. New work: starting the MCP server as a second container before OpenCode, networking the two containers, and confirming OpenCode uses MCP tools with no working workspace mount present.

The OpenCode + MCP path preserves the most harness logic and operator workflow familiarity. It is the preferred integration model.

### 5. Sandbox constraint compatibility

The two-workspace model resolves the central tension in this section. The current model enforces that the agent never has direct filesystem access to the working content — it works in a container-local `sandbox/` copy, changes are captured as a diff, and the operator reviews before anything touches the host. Under the two-workspace model:

- The working workspace is mounted into the MCP server container, not the agent container
- The agent container has no working workspace mount — its built-in filesystem tools have nothing to reach
- All working content access goes through MCP tool calls, enforced architecturally by the absence of a mount
- The reporting workspace (`.workspace/`) is mounted in the agent container as now — this is the agent's direct read-write surface for briefs and state

This recovers the architectural enforcement property without requiring Strategy B's snapshot complexity. The agent cannot access the working content out-of-band because there is no path to it from the agent container.

The remaining question is whether to mount the live working content directly into the MCP server container, or a sandbox copy:

**Live mount** — the MCP server operates on the actual vault/project. Changes are immediate. The diff pipeline runs after the session against the working mount and the original (tracked via git history or a pre-session snapshot kept by the harness). This is operationally simpler and aligns with how Obsidian users normally work with their vault.

**Sandbox copy** — the harness copies working content into the MCP server container before the session starts, analogous to the current `.bootstrap/snapshot/` → `sandbox/` pattern. Diff is clean and harness-managed. Adds snapshot complexity at the MCP server level.

The live mount is the preferred path for the vault use case given its simplicity and alignment with the current vault workflow. The diff can be generated from git history after the session. The sandbox copy remains an option if stricter pre/post isolation is required.

### 6. Document repository suitability

This is where the option has the strongest potential advantage. MCP-based vault access is designed specifically for the Obsidian use case. Vault-specific MCP servers provide:

- Full-text and tag search across the vault without loading files into the agent's context window
- Targeted read, write, and append operations on individual notes
- Frontmatter and tag management
- File listing, navigation, and deletion
- Section-level editing (some servers)

The agent calls a `search` tool and receives matching results; it calls `read_note` for individual files; it calls `write_note` to apply changes. The agent never needs to enumerate the whole vault or load it into context. This sidesteps the core OpenCode problem (large vault, poor file navigation) by architectural means rather than by relying on the agent's autonomous browsing capability.

Validated capability across well-maintained filesystem-based MCP servers: read, write, append, list, search (text + tag), frontmatter query, delete, move. Binary file handling varies by server — needs verification for attachment-heavy vaults.

---

## Trust Assumption Analysis

The core security question: does this option satisfy the project's security invariants, or does it require explicitly relaxing them?

| Invariant | Current model | This option (OpenCode + MCP, two-workspace) |
|---|---|---|
| Agent has no direct filesystem access to working content | Enforced: `PROJECT_ROOT` not mounted in agent container | Enforced: no working workspace mount in agent container; built-in tools have nothing to reach |
| All changes staged before reaching host | Enforced: `patch.diff` + human review | Preserved: diff generated against working mount after session; written to `.workspace/` for review |
| Agent-produced changes traceable to a run | Enforced via baseline commit + diff | Depends on working content git history + harness session records; recoverable |
| Container does not access host FS outside mounts | Enforced: mount shape is locked | Unchanged for both containers |
| Agent has reporting workspace for state and briefs | Enforced: `.workspace/` mount | Unchanged: `.workspace/` mount in agent container as now |

The two-workspace model recovers all current invariants under the OpenCode + MCP path. The Claude Desktop path does not enforce the reporting workspace invariant and is not the preferred path.

---

## Open Questions

- **MCP server selection** — which server is used determines auditability, capability, and maintenance risk. Criteria: licence, maintenance activity, path traversal protections, binary file handling, ability to run in a minimal container without Obsidian running.

- **Working mount strategy** — live vault mount (simpler, diff from git history post-session) vs sandbox copy in MCP server container (cleaner diff, adds harness complexity). Live mount preferred for vault use case; decision should be made before implementation.

- **OpenCode MCP integration viability** — does OpenCode, when configured with an MCP server and given no working workspace mount, route all file operations through MCP tools? Or does it attempt direct filesystem access and fail silently? This is the primary unknown and needs a live test before the OpenCode + MCP path can be confirmed.

- **Harness integration shape** — if OpenCode + MCP is confirmed viable: does `start_agent.sh` manage both containers, or is MCP server lifecycle separate? How are the two containers networked? Does `container-entrypoint.sh` need changes to remove the sandbox pipeline (which is no longer needed for working content)?

- **Reporting workspace for agent state** — the agent writes `todo.md`, progress notes, and task state to `.workspace/`. These are operator-visible after the run. Convention for what the agent should write here, and what the operator expects to find, should be documented as part of this option's operator workflow — not a blocker but needed before the first prototype.

- **Binary file handling** — vault-specific MCP servers vary in how they handle attachments and images. Needs confirmation for the target vault before MCP server selection is finalised.

---

## Comparison to Other Options

| Dimension | Option A (new provider) | Option B (workspace channel) | Option C (MCP server, two-workspace) |
|---|---|---|---|
| Harness integration | Full provider under M1.7 interface | Existing harness, new mount + entrypoint | Reporting workspace unchanged; working workspace moves to MCP server container |
| Review step | Preserved (diff + apply) | Preserved (diff + apply) | Preserved: diff generated against working mount post-session |
| Security invariants | Fully preserved | Fully preserved | Fully preserved under OpenCode + MCP path |
| Vault navigation | Depends on provider | Agent browses sandbox/; same problem as OpenCode | MCP tools; architecturally sidesteps the problem |
| Trust model | Architectural enforcement | Architectural enforcement | Architectural enforcement (no working mount in agent container) |
| Harness work required | High (new provider) | Medium (mount + entrypoint changes) | Medium (second container, networking, diff pipeline migration) |
| M1.7 dependency | Yes — blocked until M1.7 scope is resolved | No | No — challenges M1.7 current scope; see Broader Applicability |

---

## Broader Applicability — MCP as a General Harness Architecture

This investigation is scoped to the vault use case, but the reasoning it surfaced has broader architectural implications that challenge the current scope of M1.7. This section records those findings. A decision on how to integrate them into the roadmap is a required next step before M1.7 work proceeds.

### Two distinct layers the current harness conflates

The current harness fuses two separate concerns into a single container:

**Provider harness — the reasoning layer.** The layer that runs the model, manages conversation state, makes tool call decisions, and injects context (system prompt, brief, memory). OpenCode, Claude Code, and Claude Desktop all live here. The choice of harness is about capability, UX, cost, and deployment context. A heavyweight harness (Claude Desktop, full IDE integration) makes sense when you want a rich operator experience. A lightweight harness (minimal API-calling process) makes sense for headless autonomous runs, low-resource environments, or parallel agent execution. This layer has no inherent isolation requirement — it is the *reasoning* component.

**MCP server — the capability layer.** The layer that wraps the execution environment: filesystem operations, bash, project-specific tools. This layer should always be isolated per project because isolation is about what the agent can *reach*, not how it *reasons*. The container boundary, scoped mounts, and network policy all belong here.

These were fused in the current harness because it predates MCP — when there was no standard interface between the reasoning layer and the execution environment, combining them in one container was the only practical option.

### What MCP actually contributes

The problems MCP is often presented as solving — isolated execution, constrained workspaces, auditability, resource limits — are not new. Security enforcement comes entirely from the container: `--network=none`, scoped mounts, resource limits. An MCP server does not add a new enforcement layer. Auditability is similarly already present: bash history plus the diff output plus container logs gives a complete record of what ran and what changed without MCP adding anything.

What MCP genuinely contributes:

**Capability declaration.** The server's tool list tells the agent upfront exactly what operations are available. With a raw terminal the agent discovers boundaries by attempting things and receiving errors, wasting tokens. With declared tools the agent knows its operation surface before it starts. A `bash` tool through MCP is functionally equivalent to `docker exec -it -c bash` — the container is the constraint in both cases — but the MCP version declares that surface explicitly rather than leaving the agent to discover it.

**Interface standardisation.** MCP is a common protocol any compatible client can speak. If the capability layer exposes an MCP interface, any MCP-compatible reasoning layer becomes a drop-in client without custom integration work. This directly addresses the provider fragmentation problem M1.7 is trying to solve — but from the opposite direction.

### The per-project MCP server model

Since each project already runs in its own container, the natural model is one MCP server per project, built as part of the container image:

**Base image** — standard MCP server with core tools: bash, read, write, search. Project-agnostic. Maintained once in the harness.

**Project layer** — extends the base image. Declares additional tools that are project dependencies: `run_tests`, `lint`, `build`. These are thin command wrappers surfaced as named tools so the agent knows they exist without being told in the brief.

**Brief** — project conventions, style guidance, unstructured context. Things that require judgment rather than execution.

This splits what is currently all in `agent_context_brief.md` into two: machine-checkable structured tool declarations in the image, and unstructured guidance in the brief. The brief gets shorter and more focused.

### Implication for M1.7

M1.7 as currently scoped modularises the provider harness — extracting shared logic so different agent runtimes can be swapped in via a per-provider script interface. That work assumes the current fused model: one container, one provider, harness and execution environment coupled.

The two-layer model separates them. The provider interface is no longer a custom script per agent runtime — it becomes the MCP protocol itself. Any MCP-compatible reasoning layer is a conforming client. The M1.7 work of defining per-provider scripts and entrypoint contracts may be solving the wrong problem, or may need to be scoped as a transitional step toward this model rather than a target state.

This does not mean M1.7 is wrong to do. The current harness needs modularisation regardless, and that work will expose exactly where the reasoning/capability boundary sits in the existing code. But the *target architecture* M1.7 is building toward needs to be decided before implementation begins, otherwise the extracted interfaces may need to be redesigned immediately after.

**This finding is a blocker on M1.7 proceeding with its current scope.** The execution model may need to be refactored to reflect the two-layer separation before the provider interface can be correctly defined.

---

## Next Steps

Work promoted to M2.1 — Capability Layer Prototype (Vault). See roadmap.

---

## Conclusion

### What the old model was

The original harness ran a single container per project. That container held everything: the agent runtime (OpenCode), the project snapshot in `sandbox/`, the diff pipeline, and the mount shape. The agent had direct filesystem access to its working content via `sandbox/`. The host protected itself by not mounting `PROJECT_ROOT` directly — the agent worked on a copy. Changes were captured as `patch.diff` on exit and reviewed by the operator before reaching the host repository.

This model worked for software development workflows. The agent had a bounded, git-tracked file set it could browse directly. The snapshot pipeline was the isolation mechanism.

### What the investigation revealed

The MCP server investigation surfaced that the harness conflated two concerns with different isolation requirements and different reasons to vary:

**The reasoning layer** — runs the model, manages conversation, injects context, presents an interface to the operator. OpenCode, Claude Code, Claude Desktop, and other agent runtimes live here. The choice of reasoning layer is about capability, cost, UX, and hardware. It should be swappable without changing how project content is accessed.

**The capability layer** — wraps the execution environment, controls what the agent can actually do: read files, write files, run commands, search content. This layer should always be isolated per project and should declare its interface explicitly so the agent knows what tools exist without being told in the brief.

Under the fused model, adding a new reasoning layer (new provider) required understanding the snapshot pipeline, the mount shape, and the diff pipeline — all of which belong to the capability layer. The two concerns were coupled at every level: Dockerfile, entrypoint, scripts, and documentation.

The vault use case made this visible: OpenCode could not navigate a large vault adequately, but the right fix was not a better agent — it was giving any agent a better tool interface to the vault. An MCP server exposing vault operations as tools sidesteps the file navigation problem entirely, regardless of which reasoning layer is used.

### The decision

Adopt the two-layer model as the target architecture. The two-workspace pattern is the concrete realisation:

- **Reporting workspace** (`SANDBOX_DIR/.workspace/`) — owned by the reasoning layer container. The agent reads briefs here, writes progress state, todo lists, and session output. Direct mount, read-write, unchanged from current model.
- **Working workspace** — owned by the capability layer container (MCP server). The agent has no direct filesystem path to it. All access is via tool calls. The container boundary enforces isolation — built-in filesystem tools in the agent have nothing to reach because no working mount exists in the agent container.

The diff pipeline migrates to post-session, run against the capability layer's working mount rather than inside the agent container. Output still lands in `.workspace/changes/` for operator review.

### Why M1.7 was superseded

M1.7 as scoped defined a per-provider script interface: a `providers/<n>/` directory with required scripts and mode declarations. This assumed the fused model — one container, reasoning and execution environment coupled. Under the two-layer model, the reasoning layer interface is the MCP protocol itself. Any MCP-compatible client is a conforming reasoning layer. The work of defining per-provider scripts and entrypoint contracts was solving a problem the two-layer model dissolves.

M1.7's valid components — shared logic extraction from `start_agent.sh` and `container-entrypoint.sh`, execution mode formalisation — are absorbed into M2.3 (Reasoning Layer Modularisation) under the new model, where the scope and boundaries are correctly defined.

### Documents that are now hot

The two-layer decision makes the following architecture documents hot — they describe the old fused model and will need updating as M2 proceeds:

- `execution_model.md` — container lifecycle, mount shape, snapshot pipeline, diff pipeline all change
- `security.md` — trust boundary table gains a new container and new invariants
- `agent_workflow.md` — operator workflow changes when a second container is added

These are not updated now. M1.5 updates only what changes for the directory restructuring. M2 updates them as each sub-milestone is implemented.
