# agent-sandbox — Future Milestones

Detail sections for milestones not yet active. Kept separate from [`roadmap.md`](roadmap.md) to keep the active milestone document focused and fast to read.

**Promotion rule:** when a milestone becomes active, move its section from here into `roadmap.md` under `## Upcoming Milestones`. Update the summary table row in `roadmap.md` to point to the local anchor. Remove from this file.

**Re-scoping note:** milestone definitions here are planning targets, not commitments. They are expected to evolve as implementation matures and earlier milestones reveal new constraints. Rewrite sections freely — this file is not a historical record. The changelog is.

---

## M2 — Reasoning/Capability Layer Separation

**Objective:** Separate the harness into a reasoning layer (agent container, MCP client) and a capability layer (MCP server container, project tool interface). This is the foundational architectural change that enables vault workflows, webapp workflows, provider swapping, and autonomous task execution. All M1.x architecture documents are hot during this milestone and updated sub-milestone by sub-milestone.

Conceptual model: [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md)  
Design rationale: [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md) — Conclusion

---

### M2.1 — Capability Layer Prototype: Vault (MCP server, Obsidian)

**Objective:** Build and validate the first capability layer container for the Obsidian vault use case. This proves the two-layer model in practice and unblocks KV5.

**Open decisions (must resolve before implementation):**
- Working mount strategy: live vault mount (simpler, diff from git history post-session) vs sandbox copy in MCP server container (cleaner diff, harness-managed). Live mount preferred; confirm before starting.
- MCP server selection: evaluate candidates against criteria (licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency). See `investigation_mcp_server.md` — MCP server candidates table.

**Tasks:**
- [ ] Decide working mount strategy (live vs sandbox copy)
- [ ] Evaluate MCP server candidates; select one for prototype
- [ ] Build MCP server container image: base image + selected server + vault mount at `/working`
- [ ] Configure OpenCode to connect to MCP server via HTTP; confirm no working mount in OpenCode container
- [ ] Validate: OpenCode routes vault operations through MCP tools, not built-in filesystem tools
- [ ] Validate: reporting workspace works end-to-end — agent reads brief from `input/`, writes `todo.md` and progress to `.workspace/`, operator finds expected output after session
- [ ] Validate: binary file handling (vault attachments) under selected MCP server
- [ ] Design harness integration: MCP server container lifecycle (start before agent, stop after), Docker network configuration, `start_agent.sh` changes for two-container orchestration
- [ ] Implement harness integration
- [ ] Define post-session diff generation against working mount; write to `.workspace/changes/`
- [ ] Update `execution_model.md` — two-container model, capability layer lifecycle, new mount shape
- [ ] Update `security.md` — trust boundary table for two containers
- [ ] Update `agent_workflow.md` — operator workflow with two containers
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to live vault

---

### M2.2 — Capability Layer Prototype: General (bash-enabled sandbox)

**Objective:** Build a general-purpose capability layer for coding and webapp workflows using bash tools. This proves the capability layer model generalises beyond vault-specific MCP servers and enables the website dev workflow.

**Known requirements (from website dev story open questions):**
- Port exposure for live reload (dev server)
- Bash tool interface (run commands, read/write files)
- XSS risk assessment for serve mode when the agent is running a live web server

**Tasks:**
- [ ] Design bash-enabled MCP server container: tool surface (bash, read, write, run_server), port exposure model
- [ ] Assess XSS risk: agent-controlled content served on an exposed port — determine acceptable mitigations
- [ ] Build bash-enabled capability layer container
- [ ] Validate with a webapp project: live reload, port accessible from host, agent makes changes visible immediately
- [ ] Update `execution_model.md` — document capability layer variants (vault vs general)
- [ ] Deferred breakdown: full task list to be defined once M2.1 harness integration pattern is established

---

### M2.3 — Reasoning Layer Modularisation

**Objective:** Extract shared harness logic from the OpenCode-specific scripts so that any MCP-compatible reasoning layer can be added without rewriting shared infrastructure. The provider interface under the two-layer model is the MCP protocol — per-provider work is limited to container configuration and mode support.

**Depends on:** M2.1 harness integration pattern established (so extraction reflects the correct two-container boundary).

**Tasks:**
- [ ] Audit `providers/opencode/start_agent.sh` — extract shared logic (snapshot, mount construction, env loading, MCP server lifecycle) into `lib/`; leave only OpenCode-specific invocation
- [ ] Audit `container-entrypoint.sh` — extract shared startup sequence into sourced lib; leave only provider exec step
- [ ] Document execution modes formally in `execution_model.md`: `serve`, `start`, `dry-run`, `headless` (reserved)
- [ ] Define what a conforming reasoning layer provider must supply: mode support declarations, container config, MCP client configuration
- [ ] Validate OpenCode provider conforms after refactor
- [ ] Deferred breakdown: Claude Code provider integration — full task list after M2.3 shared logic extraction is complete and [investigation_claude_code.md](../discussions/investigation_claude_code.md) open questions are resolved

---

### M2.4 — Apply Workflow: Capability Layer Diff Pipeline

**Objective:** Redesign the apply workflow to reflect the two-layer model: diff generated post-session from capability layer working mount, agent commit history preserved, checkpoint branch pattern formalised.

**Depends on:** M2.1 capability layer implementation (diff pipeline mechanics depend on how the working mount is structured).

**Known design (from M1.6 scoping, now reframed):**
- Export full commit history from capability layer working content using `git format-patch` or equivalent
- `apply` creates a checkpoint branch from current host HEAD before touching anything
- Agent commits replayed onto a named branch (`agent/<task-id>`); original branch intact
- Resolve: archive `patch.diff` or drop in favour of replayable commit history

**Tasks:**
- [ ] Confirm checkpoint branch pattern as the standard apply convention (resolves Deferred Decision)
- [ ] Agree on export format (`git format-patch` vs bundle vs other)
- [ ] Parameterise agent branch naming (`agent/<task-id>`) — single-agent case
- [ ] Implement diff pipeline in capability layer (or harness post-session script)
- [ ] Update `apply_workspace.sh` — checkpoint branch creation, replay commits
- [ ] Resolve patch history consideration — archive or drop
- [ ] Update `agent_workflow.md` and `execution_model.md`

---

### M2.5 — Session Persistence (Reasoning Layer)

**Objective:** Preserve OpenCode session history across container runs. Provider-specific to the OpenCode reasoning layer; scoped here as a reasoning layer concern separate from the capability layer.

**Depends on:** M2.3 (reasoning layer modularisation, so session DB mount is cleanly scoped to the provider).

**Tasks:**
- [ ] Identify host-side storage location for session DB (per-project, in `SANDBOX_DIR`)
- [ ] Add mount for `~/.local/share/opencode/` into reasoning layer container
- [ ] Update `execution_model.md` — document session DB mount
- [ ] Verify DB survives container restart and is correctly re-attached on next run

---

## M3 — Autonomous Task Execution, Manual Review Workflow

**Objective:** Move from interactive prompting to structured single-task execution with enough logging to verify the agent is doing useful work. Requires the two-layer foundation from M2.

**Depends on:** M2 two-layer architecture (headless mode requires the capability layer tool interface; task briefs are the operator input channel from M1.5).

- [ ] Define Task Brief format (`TASK.md` — per-run brief placed in `SANDBOX_DIR/input/` before the run; aligns with the M1.5 input channel)
- [ ] Define agent execution lifecycle for a single headless task run
- [ ] Atomic install for `make install` — write to temp file, verify, then `mv` into place
- [ ] Pre-snapshot validation gate — configurable per-project check run by `start_agent.sh` before building `.bootstrap/`; fail fast before the container starts
- [ ] Store structured logs per agent and task run
- [ ] Capture metadata with each commit (agent_id, task_id, timestamp) — prerequisite for trusting autonomous output

---

## Multi-Agent Coordination

### M4 — Metadata Seeding
- [ ] Define `.workspace/metadata.json` format:
  - `agent_id`, `task_id`, allowed files, instructions
- [ ] Ensure agent reads metadata to guide task execution
- [ ] Ensure agent respects allowed file constraints

---

### M5 — Agent-Assigned Branch Management

**Objective:** Each agent gets its own branch from a shared baseline. Branches serve as both the agent's working surface and the snapshot of its work for review and merge.

- [ ] Each agent gets its own branch from the same baseline
- [ ] `apply_workspace.sh --branch=<n>` supports named branches per agent
- [ ] Validate branch contents before merge
- [ ] Merge branch → `main`
- [ ] Evaluate whether to adopt existing checkpoint branch logic (`workflow/knowledge-vault/scripts/`) as the harness-level branch management mechanism, or design purpose-built tooling — see Deferred Decisions

---

## Multi-Agent Orchestration

### M6.1 — Task Dispatch

**Objective:** Extend the execution model to support coordinated dispatch of multiple task briefs across agents. Design precedes implementation — `execution_model.md` must be updated before any code changes.

- [ ] Design multi-task coordination model — how multiple task briefs are dispatched, sequenced, and tracked across agents
- [ ] Update `execution_model.md` to reflect dispatch model before implementation begins
- [ ] Implement dispatch mechanism in harness

---

### M6.2 — Constraint Enforcement

**Objective:** Enforce SOP constraints on agent dispatch and output. Partial enforcement may exist earlier from features built in prior milestones; this milestone brings it to a complete and auditable state.

- [ ] Implement automated SOP enforcement scripts covering agent lifecycle, output handling, and secrets
- [ ] Enforce allowed file and task constraints at dispatch time (builds on M4 metadata)
- [ ] Validate agent outputs against constraints before branch merge

---

### M6.3 — Review & CI/CD Integration

**Objective:** Automate review of agent-produced changes and integrate with CI/CD pipelines.

- [ ] Configure PR / CI/CD checks on agent branches
- [ ] Automated validation of branch contents before merge
- [ ] Full structured audit trail per agent run, task, and commit

---

## Standalone

### M7 — Security and Network hardening (Policy Layer)
- [ ] Introduce `.config/workflow.yaml`
  - Configure network access
  - Configure resource limits (`--memory`, `--cpus`)
  - Define allowed directories and workflow rules
- [ ] Enforce policy configuration in container startup
  - Add automated isolation validation checks
- [ ] Implement `safe` mode: `--network=none` enforcement
  - Evaluate `--network=none` mode for non-AI execution
- [ ] Implement `restricted` mode: Restrict outbound network access
  - Introduce outbound proxy or domain filtering to required AI endpoints

---

### M8 — Skills / Templates
- [ ] Introduce `.skills/` directory
- [ ] Provide templates or skill definitions for agent
- [ ] Integrate skills into agent workflow

