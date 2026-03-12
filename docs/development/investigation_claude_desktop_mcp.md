# Investigation — Claude Desktop + Dockerized MCP Server

**Status:** In progress. Architecture is well-understood; key open questions are harness integration model and trust assumption validation.

**Parent story:** [story_provider_knowledge_store.md](story_provider_knowledge_store.md)

---

> **Required reading before this document:**
> - [`docs/architecture/execution_model.md`](../../docs/architecture/execution_model.md) — container lifecycle, mount shape, and entrypoint sequence. This option departs from the current model significantly; understanding the baseline is prerequisite.
> - [`docs/architecture/security.md`](../../docs/architecture/security.md) — trust boundaries and security invariants. Several invariants do not hold under this option as stated.
> - [story_provider_knowledge_store.md](story_provider_knowledge_store.md) — investigation questions this report answers.

---

## Summary

Rather than running an AI agent inside a harness container, this option runs Claude Desktop on the host and points it at a dockerized MCP server that mounts the vault. The agent never touches the filesystem directly — all vault interactions are mediated by the MCP server's tool interface. Isolation is provided by the container boundary around the MCP server and vault mount, not by the harness sandbox model.

This is a fundamentally different architecture from the current provider model. It does not slot in as a new provider under the existing harness — it is a separate workflow with different trust assumptions, lifecycle, and operator responsibilities. The primary assumption is that Claude Desktop confines all vault interaction to MCP tool calls and does not access the filesystem outside of them.

---

## Architecture

```
Host
├── Claude Desktop (MCP client, runs on host)
│   └── connects via stdio or HTTP to:
│
└── Docker container
    ├── MCP server process
    │   └── vault tool interface (read, write, search, list, delete)
    └── /vault mount  ←  vault directory (read-write)
        (maps to vault on host or a sandbox copy)
```

Claude Desktop is configured with a `claude_desktop_config.json` entry pointing to the MCP server. The server exposes vault operations as MCP tools. Claude calls tools; the server executes filesystem operations against `/vault` inside the container; results return to Claude via the MCP protocol.

---

## Findings Against Investigation Questions

### 1. Execution model

This option has no execution modes in the harness sense. Claude Desktop is a persistent desktop application, not a container started and stopped by the harness. There is no `start`, `serve`, `dry-run`, or `headless` invocation managed by the harness — the operator launches Claude Desktop directly and interacts with it.

What the harness can own is the MCP server container lifecycle: starting and stopping the container, managing the vault mount, and capturing any changes made through the MCP server. This is a narrower scope than current provider management.

**Transport options for MCP communication:**

- **stdio:** Claude Desktop spawns the container as a subprocess (`docker run -i --rm ...`) and communicates over stdin/stdout. This is the simplest configuration and is how most containerized MCP servers in the Docker MCP Catalog work. No port exposure required. The container is started and stopped by Claude Desktop automatically.
- **HTTP (Streamable HTTP / SSE):** The MCP server listens on a port inside the container; Claude Desktop connects via `http://localhost:<port>/mcp`. The container must be started separately and kept running. Requires port binding to `127.0.0.1` per the current network exposure model.

stdio is the lower-complexity path and is well-supported. HTTP is appropriate if the MCP server needs to persist across multiple Claude Desktop sessions without restarting.

### 2. Authentication

Claude Desktop is a standalone Anthropic application authenticating against the Anthropic API using the user's Claude account. No API key or harness-injected secret is required for the AI model itself. The MCP server may or may not require authentication depending on implementation:

- **Filesystem-based MCP servers** (direct vault access via `VAULT_PATH`) — no auth token required. The container boundary is the access control.
- **Obsidian Local REST API-based MCP servers** — require the Local REST API plugin running inside Obsidian and an API key injected into the MCP server container as an environment variable. This adds a dependency on the Obsidian desktop application running concurrently, which is likely not desirable in a headless or automated scenario.

Filesystem-based servers are the appropriate path here: no plugin dependency, no running Obsidian instance required, and access control is purely the container mount.

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

This option does not reuse the harness provider model. The harness components that do not apply:

- `start_agent.sh` — no agent container to start; replaced by `docker run` or `docker-compose` for the MCP server
- `container-entrypoint.sh` — not applicable; MCP server has its own entrypoint
- Snapshot pipeline (`lib/snapshot.sh`) — not used; the vault is mounted directly, not snapshotted
- Diff pipeline (`lib/diff.sh`) — not used; there is no sandbox git baseline or `patch.diff` output

The harness components that remain relevant:

- `scripts/apply_workspace.sh` — not applicable as-is, but the operator workflow of reviewing and applying changes before they reach the canonical vault may still apply depending on mount strategy (see Mount Shape below)
- Secrets handling model — applicable; MCP server API keys (if any) follow the same `.env` pattern

The harness would need new scripts for: starting and stopping the MCP server container, managing the vault mount, and (if a review step is desired) capturing a diff of vault changes after a session.

### 5. Sandbox constraint compatibility

**This is the central departure from the current security model.** The current model enforces that the agent never has direct filesystem access — it works in a container-local `sandbox/` copy, changes are captured as a diff, and the operator reviews before anything touches the host repository. Under this option:

- The vault is mounted directly into the MCP server container, not copied into a sandbox
- Changes made via MCP tool calls are applied to the mount immediately and persistently
- There is no diff-and-review step unless one is explicitly constructed around the vault's git history

The trust assumption this option rests on: **Claude Desktop will only access the vault via MCP tool calls, and will not attempt to access the filesystem directly.** This is a reasonable assumption for Claude Desktop in its normal operating mode (it has no native filesystem access outside of MCP), but it is a behavioural trust assumption about the application, not an architectural enforcement. It is notably different from the current model, where the architectural isolation enforces the constraint regardless of agent behaviour.

Two mount strategies are possible, with different tradeoffs:

**Strategy A — Mount the live vault directly**

The host vault is mounted into the MCP server container. Changes via MCP tools are applied directly and immediately. No review step. Operator relies on git history for rollback if needed.

This is the simplest path and aligns with how Obsidian users normally work. It abandons the staged-diff review model entirely.

**Strategy B — Mount a sandbox copy; diff on session end**

Before starting the MCP server container, the harness copies the vault into a sandbox directory (analogous to the current `.bootstrap/snapshot/` → `sandbox/` copy). The MCP server mounts the sandbox copy, not the live vault. On session end, the harness produces a diff between the original and the modified sandbox copy and writes it to `.workspace/changes/patch.diff`. The operator reviews and applies as normal.

This preserves the review model and re-aligns with the current security invariants. It adds harness complexity (the snapshot and diff logic needs to apply at the vault level, not the git-tracked project level) and means the vault mounted in the container is not the live vault — which may affect search index behaviour and other server-side state.

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

| Invariant | Current model | This option |
|---|---|---|
| Agent has no direct filesystem access | Enforced architecturally (no mount of `PROJECT_ROOT`) | Trust-based: Claude Desktop has no native FS access, but relies on application behaviour |
| All changes staged before reaching host | Enforced: patch.diff + human review | Strategy A: not enforced. Strategy B: enforced, with additional harness work |
| Agent-produced changes traceable to a run | Enforced via baseline commit + diff | Depends on vault git history; not enforced by harness |
| Container does not access host FS outside mounts | Enforced: mount shape is locked | Unchanged for MCP server container |

With Strategy A, two of the four invariants are not enforced. This is a deliberate architectural trade-off, not a gap — the option simply has a different trust model. The question is whether that trade-off is acceptable for the knowledge-vault use case, where the vault is not a software repository and the stakes of unreviewed changes are lower.

With Strategy B, the invariants are recovered at the cost of harness complexity and some operational friction.

---

## Open Questions

- **MCP server selection** — which server is used determines auditability, capability, and maintenance risk. Criteria to evaluate: licence, maintenance activity, path traversal protections, binary file handling, and whether it can run in a minimal Alpine/Ubuntu container without the Obsidian application running.

- **Mount strategy** — Strategy A (live vault) vs Strategy B (sandbox copy + diff). This is the primary design decision and has security model implications. Should be decided before any implementation proceeds.

- **Trust assumption acceptability** — is the behavioural trust assumption on Claude Desktop (no out-of-band FS access) sufficient for this use case, or must it be enforced architecturally? The answer likely depends on how sensitive the vault contents are and how much the operator values the review step.

- **Harness integration shape** — what does the operator workflow look like? If Strategy B, the harness needs scripts for vault snapshot, MCP server container lifecycle, and diff generation. If Strategy A, the operator workflow is largely outside the harness: start the container manually (or via a Makefile target), run Claude Desktop, stop the container.

- **Session lifecycle** — Claude Desktop is a persistent app, not a run-and-exit process. How does the operator know when a "session" is over and changes should be reviewed (if Strategy B)? This needs a defined convention.

- **Binary file handling** — vault-specific MCP servers vary in how they handle attachments and images. Needs confirmation for the target vault.

---

## Comparison to Other Options

| Dimension | Option A (new provider) | Option B (workspace channel) | Option C (Claude Desktop + MCP) |
|---|---|---|---|
| Harness integration | Full provider under M1.7 interface | Existing harness, new mount + entrypoint | Partial or none; separate workflow |
| Review step | Preserved (diff + apply) | Preserved (diff + apply) | Strategy A: none. Strategy B: recoverable |
| Vault navigation | Depends on provider | Agent browses sandbox/; same problem as OpenCode | MCP tools; architecturally sidesteps the problem |
| Operator experience | Terminal / browser (existing) | Terminal / browser (existing) | Claude Desktop (chat UI) |
| Trust model | Architectural enforcement | Architectural enforcement | Behavioural trust (Strategy A) or architectural (Strategy B) |
| Harness work required | High (new provider) | Medium (mount + entrypoint changes) | Low (Strategy A) or Medium (Strategy B) |
| M1.7 dependency | Yes | No | No |

---

## Next Steps

1. Decide mount strategy (Strategy A vs Strategy B) — gates all subsequent work
2. Evaluate MCP server candidates against selection criteria
3. If Strategy B: design harness integration (vault snapshot, container lifecycle scripts, diff generation)
4. Prototype: start MCP server container with vault mount, connect Claude Desktop, validate tool capability against a representative vault
5. Validate binary file handling
6. If satisfactory: define operator workflow and document in knowledge-vault story
