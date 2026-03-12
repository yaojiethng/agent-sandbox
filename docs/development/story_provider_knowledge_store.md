# User Story — Knowledge Store Provider

**Status:** Investigation in progress. Prerequisite for KV5 validation tasks.

---

> **Required reading before this document:**
> - [`docs/architecture/execution_model.md`](../../docs/architecture/execution_model.md) — container lifecycle, mount shape, entrypoint sequence, and diff pipeline. The current OpenCode integration uses interactive serve mode (`opencode serve`); understanding this is prerequisite to evaluating any candidate provider.
> - [`docs/architecture/security.md`](../../docs/architecture/security.md) — trust boundaries and security invariants that any provider integration must satisfy.

---

## Pain Point

The current OpenCode provider does not provide adequate support for knowledge-store format repositories. OpenCode struggles with large volumes of markdown files — context window management, file navigation, and multi-file edits across a vault are not well-handled. This blocks KV5, which requires an agent capable of performing useful work against a large vault of markdown files and binary attachments.

---

## Proposed Solution and Investigation Direction

Two complementary approaches are under investigation. Either may be sufficient independently; together they are likely more robust than either alone.

### Option A — Provider replacement

Support a provider interface that provides better support for working with document repositories. This requires:

1. Identifying a candidate provider better suited to large markdown-heavy workloads
2. Verifying the candidate can conform to the harness provider interface
3. Integrating the candidate as a new provider without replacing or breaking OpenCode

The provider interface must be formalised (M1.7) before a new provider can be built cleanly. Investigation of candidates runs in parallel and feeds into that work.

### Option B — Workspace as interactive communication channel

Rather than requiring the provider to browse a large vault autonomously, the operator pre-scopes work by writing a task brief with explicit file paths into a dedicated input channel in `.workspace/`. The agent reads the brief and operates only on the nominated files. This sidesteps the file navigation problem without requiring a new provider — it is viable with OpenCode today and with any future provider.

This requires two design decisions that are currently open:

**1. Container awareness of workspace and sandbox**

Currently the container is aware of `sandbox/` (its working copy of project files) but treats `.workspace/` only as an output channel written to by the diff pipeline. For the agent to actively read from `.workspace/input/`, the provider needs to be started in a working directory or with configuration that makes both `sandbox/` and `.workspace/` visible and their purposes explicit. This is a provider entrypoint concern and intersects with the M1.7 provider interface definition.

Tasks:
- [ ] Define how the provider entrypoint communicates the locations and purposes of `sandbox/` and `.workspace/` to the agent (e.g. via `CLAUDE.md` or equivalent brief placed in `sandbox/` at startup)
- [ ] Verify the agent can read from `.workspace/input/` within its normal file operation scope

**2. Mount shape: input channel, history access, and constraints**

The current mount shape is:

| Host path | Container path | Mode |
|---|---|---|
| `PROJECT_ROOT/.bootstrap/` | `/home/agentuser/.bootstrap/` | read-only |
| `PROJECT_ROOT/.workspace/` | `/home/agentuser/.workspace/` | read-write |

Adding a task brief input channel requires deciding:

- Whether `.workspace/input/` is a sub-path of the existing RW mount (writable by container) or a separate RO mount (container cannot write back) — a separate RO mount is cleaner and safer
- Whether the agent should have access to the full git history of the original repo via `.workspace/` — currently the agent works from a snapshot copy in `sandbox/` specifically to avoid this; whether read access to `.workspace/` changes this exposure needs to be confirmed

Tasks:
- [ ] Investigate and decide: does read access to `.workspace/` expose original repo git history to the agent? (The snapshot-copy design was chosen to prevent this — confirm whether it holds under the proposed input channel)
- [ ] Decide mount shape for the input channel: sub-path of existing RW `.workspace/` mount vs a separate RO mount at a distinct path
- [ ] Update mount shape in `start_agent.sh` and document in `execution_model.md`
- [ ] Define `.workspace/input/` lifecycle: written by operator before run, read by agent during run, cleared by operator after run (or overwritten on next run)

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

Any candidate provider investigation should answer the following:

1. **Execution model** — does the provider support interactive terminal mode (`start`)? Does it have a native serve/web mode, or does it require a third-party wrapper for `serve`? Is there a viable headless invocation path for future M2 work?
2. **Authentication** — what authentication mechanism does the provider use in a containerised environment? Can it be injected via environment variable without interactive setup?
3. **Dockerfile and image** — what does the provider require to install in a minimal Ubuntu container? Are there additional system dependencies beyond what the current image provides?
4. **Harness reuse** — which components of `providers/opencode/` are reusable, and which require provider-specific implementations? Does anything in `lib/` or `scripts/` need to change?
5. **Sandbox constraint compatibility** — can the provider confine file operations to `sandbox/` without host access? Is it compatible with the no-direct-host-access constraint?
6. **Document repository suitability** — can the provider navigate and edit large flat or nested markdown structures effectively? Does it handle binary file awareness correctly?

---

## Candidate Investigations

| Provider | Status | Report |
|---|---|---|
| Claude Code | In progress | [investigation_claude_code.md](investigation_claude_code.md) |
| Claude Desktop + Dockerized MCP | In progress | [investigation_claude_desktop_mcp.md](investigation_claude_desktop_mcp.md) |

---

## Next Steps

**Option A — Provider replacement:**
1. Complete M1.7 provider modularisation — formalises the provider interface candidates must conform to
2. Complete Claude Code investigation — resolve open questions, particularly integration model and wrapper evaluation
3. Identify and investigate additional candidates if Claude Code is not sufficient
4. Select provider and build `providers/<n>/` against the M1.7 interface
5. Validate against a live vault (KV5)

**Option B — Workspace communication channel:**
1. Resolve mount shape design questions (history access exposure, input channel mount approach)
2. Define provider entrypoint awareness of `sandbox/` and `.workspace/`
3. Update mount shape and entrypoint; document in `execution_model.md`
4. Validate against a live vault task (KV5)

**Option C — Claude Desktop + Dockerized MCP:**
1. Decide mount strategy: live vault (Strategy A) vs sandbox copy + diff (Strategy B)
2. Evaluate MCP server candidates (auditability, capability, Docker compatibility)
3. If Strategy B: design harness integration for vault snapshot and diff
4. Prototype against a representative vault; validate tool capability and binary file handling
5. Define operator workflow; validate end-to-end (KV5)
