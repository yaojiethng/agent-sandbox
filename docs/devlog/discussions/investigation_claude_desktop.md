# Investigation — Claude Desktop as Reasoning Layer Provider

**Status:** Resolved. Recommendation: viable with manual session lifecycle. Prototype required before adoption.

**Direction:** Direction 1 — Provider replacement (special case: may replace harness entirely)
**Parent story:** [story_provider_knowledge_store.md](story_provider_knowledge_store.md)

---

## Required Reading

- [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — container lifecycle, mount shape, and entrypoint sequence.
- [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants.
- [story_provider_knowledge_store.md](story_provider_knowledge_store.md) — the investigation questions this document must answer.
- [investigation_mcp_server.md](investigation_mcp_server.md) — Claude Desktop's viability is partly dependent on the MCP server mount strategy; read this first.

---

## Summary

Claude Desktop is a special case within Direction 1. Unlike other provider candidates, it does not run inside a harness container — it is a desktop application that connects to a Dockerised MCP server. If selected, it replaces the agent harness as the reasoning layer rather than conforming to the `build.sh` / `run.sh` provider interface established in M2.2.

The key trade-offs are:

- Eliminates harness provider integration work, but the diff-and-review pipeline must be driven by the operator rather than by the container lifecycle hook.
- Can be pointed at the existing capability layer sandbox directory via the standard MCP filesystem server, reusing the snapshot pipeline and `staged.diff` mechanism with no changes to `apply_workspace.sh` or the diff pipeline.
- The sandbox container remains the mechanism for snapshot preparation and diff generation; Claude Desktop replaces only the reasoning layer interaction model.
- Creates dependency on Anthropic's desktop product, though the underlying MCP infrastructure is portable.
- Host filesystem security is controlled entirely by MCP server configuration; Claude Desktop itself has no inherent access to host files.

---

## Findings

### 1. How Claude Desktop connects to a sandboxed working environment

Claude Desktop has no native file access. Without MCP server configuration, it operates as a conversational interface only and cannot read or write host files. File access is granted exclusively by connecting Claude Desktop to an MCP server process configured with explicit directory mounts.

The standard integration pattern is:

```
Claude Desktop (MCP client, host process)
    │  stdio
    ▼
MCP server container (e.g. mcp/filesystem, short-lived, operator-managed)
    │  bind mount (read-only or read-write, as configured)
    ▼
SANDBOX_DIR on host (snapshot and workspace paths)
```

Claude Desktop is configured via `claude_desktop_config.json` to launch a Docker container as its MCP server. The container receives explicit bind mounts to the host directories Claude should be able to reach. The MCP filesystem server exposes only the mounted paths; all other host paths are inaccessible.

This is a well-established and Docker-native pattern. The reference `mcp/filesystem` server image is published and maintained by Anthropic.

---

### 2. Mount path compatibility with the existing capability layer

The existing harness snapshot pipeline writes the project snapshot to `SANDBOX_DIR/.agent-input/snapshot/` on the host before any container starts. The diff pipeline writes `staged.diff` to `SANDBOX_DIR/.workspace/changes/` on sandbox container exit.

The MCP filesystem server can be pointed at these same host-side paths directly:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--mount", "type=bind,src=SANDBOX_DIR/.agent-input/snapshot,dst=/projects/snapshot,ro",
        "--mount", "type=bind,src=SANDBOX_DIR/.workspace,dst=/projects/workspace",
        "mcp/filesystem",
        "/projects"
      ]
    }
  }
}
```

Claude Desktop sees the snapshot (read-only) and the workspace (read-write) — the same file surface the capability layer presents. Writes go to `.workspace/`, the same output channel. The existing mount shape is preserved without structural modification.

---

### 3. Apply pipeline compatibility

`apply_workspace.sh` operates on `SANDBOX_DIR/.workspace/changes/staged.diff` on the host. It has no dependency on the capability layer container being involved in the session — it reads from the host path and applies the diff to the project repository. `make apply` works identically in the Claude Desktop path.

`diff.sh` is tied to the sandbox container lifecycle: when the sandbox container exits or is stopped, the entrypoint hook fires and `diff.sh` generates `staged.diff`. This is confirmed behaviour and requires no change for the Claude Desktop path.

---

### 4. Operator model: `make sandbox`

The proposed operator model for Claude Desktop sessions:

1. `make sandbox` — runs the snapshot pipeline and starts the sandbox container. Claude Desktop connects to the MCP filesystem server (managed separately via `claude_desktop_config.json`) which points at the same `SANDBOX_DIR` paths.
2. Work in Claude Desktop — open a new conversation; the MCP server exposes the snapshot and workspace to the agent.
3. End of session — close the conversation in Claude Desktop. Stop the sandbox container. The entrypoint hook fires `diff.sh`, producing `staged.diff`.
4. `make apply` — review and apply `staged.diff` to the host repository. No changes to this step.

This model preserves all harness invariants: snapshot isolation, `PROJECT_DIR` separation, diff-and-review before commit. The operator takes on explicit session lifecycle management; the rest of the workflow is unchanged.

---

### 5. MCP server container lifecycle

The MCP filesystem server is a short-lived container that Claude Desktop launches via `claude_desktop_config.json`. It is independent of the sandbox container. Claude Desktop reads `claude_desktop_config.json` at startup and does not monitor it for changes. If the container image is replaced between sessions but the tag remains the same, Claude Desktop will use the updated image on the next connection without any configuration change.

The sandbox container and the MCP filesystem container are separate: the sandbox container manages the working copy and diff generation; the MCP filesystem container provides Claude Desktop's file access interface over the same host paths.

---

### 6. Behaviour when the MCP server container is stopped

**Application state:** Stopping the MCP container has no effect on Claude Desktop's application state or conversation history. Conversation history is held by Claude Desktop, not by the container.

**Active conversation:** If the MCP container is stopped while a conversation is active, the MCP connection drops and filesystem tool calls will fail. Claude Desktop does not automatically reconnect mid-conversation. Recovery requires starting a new conversation (which triggers a new container launch via `claude_desktop_config.json`) or toggling the connector off/on in the Connectors UI. The intended operator pattern is to stop the container between conversations, not mid-conversation.

**Between conversations:** The MCP server container is launched on conversation open. Stopping the container between conversations is the normal operator flow and is clean.

---

### 7. Server upgrade detection

Claude Desktop has no mechanism to detect that a container image was replaced between sessions. It launches the container using the command in `claude_desktop_config.json` and uses whatever image is currently available under that name. This is the desired behaviour for the short-lived container model: the operator rebuilds images as needed and Claude Desktop transparently uses the current version on the next connection.

---

### 8. Host filesystem security

Claude Desktop has no inherent access to host files without MCP configuration. When an MCP filesystem server is configured, access is strictly bounded to the explicitly mounted directories. One historical path-traversal vulnerability in the `mcp/filesystem` reference server (a `startsWith` prefix check allowing access to sibling directories sharing a name prefix) was identified and patched in the rewrite accompanying the Claude Desktop Extensions release. Operators should ensure they are running a current version of the image.

Practical security posture:

- Mount only `SANDBOX_DIR/.agent-input/snapshot` (read-only) and `SANDBOX_DIR/.workspace` (read-write). `PROJECT_DIR` is not mounted.
- The MCP server process runs with the host user's OS permissions within the mounted paths.
- Claude Desktop sends conversation content — including file contents retrieved via MCP tools — to Anthropic's API as part of the inference request. Gitignored files are excluded from the snapshot by the harness pipeline, providing the same protection as in the standard harness model.

---

## Security Delta vs. Current Harness

| Invariant | Current harness | Claude Desktop path |
|---|---|---|
| Snapshot isolation (gitignored files excluded) | Enforced by `git ls-files` snapshot pipeline | Preserved — harness snapshot pipeline still runs; MCP server mounts the snapshot output |
| Agent cannot reach `PROJECT_DIR` directly | Enforced by container mount rules | Preserved — `PROJECT_DIR` is not mounted into the MCP container |
| Changes staged as diff before operator review | Enforced automatically by diff pipeline on container exit | Preserved — operator stops sandbox container; entrypoint hook runs `diff.sh`; `make apply` unchanged |
| Reproducibility | Automated per run | Not automated; operator initiates each session cycle via `make sandbox` |
| Session auditability | `staged.diff` per run, automatically attributed | Same mechanism; attribution depends on operator managing session boundaries explicitly |
| Agent lifecycle enforcement (nesting depth, output validation) | Enforced by harness | Not applicable; no equivalent in Claude Desktop |

No harness invariants are structurally broken. The diff-and-review cycle and snapshot isolation are both preserved. The change is procedural: the operator drives the session lifecycle explicitly rather than relying on the harness to automate it.

---

## Open Questions (Deferred)

1. **`diff.sh` invocation** — Confirmed. `diff.sh` is tied to the sandbox container: it fires via the entrypoint hook when the container exits or is stopped. No code change required.

2. **MCP server container start trigger** — Deferred. The likely model is Claude Desktop owns the MCP filesystem container lifecycle (launched automatically via `claude_desktop_config.json`), while the operator owns the sandbox container lifecycle (`make sandbox`). The procedure for reconnecting the MCP server after the sandbox container is restarted — and whether this requires a new conversation, a connector toggle, or something else — requires further investigation before the operator procedure can be formalised.

3. **Operator procedure formalisation** — Deferred. The `make sandbox` / `make apply` model is sound in principle; the exact operator steps, edge cases (e.g. forgetting to stop the sandbox before applying), and any supporting wrapper scripts are to be defined during implementation planning.

---

## Constraints

- The operator's ability to review and reject changes before they reach the repository is a system invariant. Any path that does not preserve `staged.diff` and the apply workflow is non-conforming.
- Secrets and gitignored files must not be visible to the agent. Gitignored files must be excluded from the MCP server's accessible paths by construction, via the snapshot pipeline.
- The integration must be replicable without Anthropic-specific infrastructure beyond Claude Desktop itself.

---

## Resolution

**Recommendation: viable, pending prototype and operator procedure definition.**

The core harness invariants — snapshot isolation, `PROJECT_DIR` separation, diff-and-review — are all preserved in the Claude Desktop path without changes to the apply pipeline or the diff mechanism. `make apply` works unchanged. The mount shape maps directly to existing host paths. The security posture is equivalent to the standard harness model provided the operator does not mount `PROJECT_DIR` into the MCP container.

The remaining unknowns are procedural, not structural: how the operator reconnects the MCP server after a sandbox restart, and what wrapper scripts (if any) are needed to make the `make sandbox` cycle ergonomic. These are deferred to implementation planning.

No codebase changes arise from this investigation. The investigation is closed. Next step is a prototype against a test project to validate the operator workflow end-to-end before this path is adopted.

This decision should be recorded in the parent story [story_provider_knowledge_store.md](story_provider_knowledge_store.md) and a roadmap entry created for the prototype work if the parent story graduates.
