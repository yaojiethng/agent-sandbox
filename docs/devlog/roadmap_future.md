# agent-sandbox — Future Milestones

Detail sections for milestones not yet active. Kept separate from [`roadmap.md`](roadmap.md) to keep the active milestone document focused and fast to read.

**Promotion rule:** when a milestone becomes active, move its section from here into `roadmap.md` under `## Upcoming Milestones`. Update the summary table row in `roadmap.md` to point to the local anchor. Remove from this file.

**Re-scoping note:** milestone definitions here are planning targets, not commitments. They are expected to evolve as implementation matures and earlier milestones reveal new constraints. Rewrite sections freely — this file is not a historical record. The changelog is.

---

## M2.4 — Session Persistence (Reasoning Layer)

**Objective:** Preserve OpenCode session history across container runs. Provider-specific to the OpenCode reasoning layer; scoped here as a reasoning layer concern separate from the capability layer.

**Depends on:** M2.2 (reasoning layer modularisation, so session DB mount is cleanly scoped to the provider).

**Tasks:**
- [ ] Identify host-side storage location for session DB (per-project, in `SANDBOX_DIR`)
- [ ] Add mount for `~/.local/share/opencode/` into reasoning layer container
- [ ] Update `execution_model.md` — document session DB mount
- [ ] Verify DB survives container restart and is correctly re-attached on next run

---

## M2.5 — Vault Capability Layer Prototype

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first (direct `sandbox/` mount, no MCP), then add MCP server as an enhancement. Unblocks KV5.

**Depends on:** M2.1 two-container foundation, M2.2 modularised provider scripts, M2.3 apply workflow.

**Tasks:**
- [ ] Validate vault workflow with sandbox-only configuration: agent accesses vault files directly via `sandbox/`, diff reviewed and applied to vault repo
- [ ] Evaluate MCP server candidates; select one (criteria: licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency — see [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md) candidates table)
- [ ] Build vault capability layer image: extends base capability layer image, adds selected MCP server
- [ ] Configure OpenCode to connect to MCP server; validate it routes vault operations through MCP tools when server is present
- [ ] Validate binary file handling (vault attachments) under selected MCP server
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to vault repo
- [ ] Update `execution_model.md` — document capability layer variants (general vs vault+MCP)

---

## M3 — Autonomous Task Execution, Manual Review Workflow

**Objective:** Move from interactive prompting to structured single-task execution with enough logging to verify the agent is doing useful work. Requires the two-layer foundation from M2.

**Depends on:** M2 two-layer architecture (headless mode requires the capability layer tool interface; task briefs are the operator input channel from M1.5).

- [ ] Define Task Brief format (`TASK.md` — per-run brief placed in `SANDBOX_DIR/.agent-input/input/` before the run; aligns with the M1.5 input channel)
- [ ] Define agent execution lifecycle for a single headless task run
- [ ] Atomic install for `make install` — write to temp file, verify, then `mv` into place
- [ ] Pre-snapshot validation gate — configurable per-project check run by `start_agent.sh` before building `.agent-input/`; fail fast before the container starts
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
- [ ] Evaluate whether to adopt existing checkpoint branch logic (`workflow/knowledge-vault/scripts/`) as the harness-level branch management mechanism, or design purpose-built tooling — decision depends on M2.4 checkpoint branch pattern outcome

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


---

## Deferred (Unplanned)

### Capability Layer — Live Mount

The current model standardises on a sandbox copy in the capability layer container for all workflows. A live mount of the host project directory directly into the capability layer container is a potential UX improvement — changes would be visible on the host immediately during a session rather than after the operator applies the diff. This may also be useful for coding workflows where incremental visibility is valuable. Deferred until the copy pattern has been validated at scale and a concrete use case justifies the added complexity in the diff pipeline.

---

### Pipeline Replacement — Git Worktree Model

**Candidate for post-M2.3 architectural revision.**

Investigation documented in [`docs/devlog/discussions/investigation_git_worktrees.md`](discussions/investigation_git_worktrees.md).

**What it is:** Replace the snapshot + diff + apply pipeline with a `git worktree` per session. The agent's working directory is a real git worktree on a dedicated branch inside PROJECT_DIR's repo. On session end, the branch is already committed — no diff generation, no apply script. The operator reviews via `git log`/`git diff` and merges or discards the branch.

**Why deferred:** Requires the operator to accept three assumptions that are not universally true today: (1) commit history is clean (no secrets ever committed); (2) the agent container runs with `--network=none` (no remote git operations); (3) main branch protection via filesystem-level read-only ref locking is acceptable. Under those assumptions, the model is technically clean and architecturally simpler.

**Key feasibility findings:**
- Gitignore filtering is naturally preserved — worktrees contain only tracked files, `.env` and secrets don't materialise in the worktree directory.
- Remote blocking: `--network=none` on the agent container. Single-line compose change.
- Main branch protection: `git pack-refs --all` + `chmod a-w .git/packed-refs` after worktree creation; restored after session exit. Syscall-level, cannot be bypassed by the agent.
- The capability layer's join phase simplifies to "commit pending changes" — the full diff pipeline is eliminated.
- `staged.diff` review artefact is replaced by `git diff main..agent/session` — richer, no dedicated tooling needed.

**Pipeline comparison:**

| Step | Current (snapshot+diff) | Worktree |
|---|---|---|
| Enumerate project files | `git ls-files` | (not needed) |
| Copy files to sandbox | `cp -a` → `.snapshot/` → Docker volume | (not needed) |
| Init git in sandbox | `git init` + baseline commit | (not needed) |
| Agent works | in Docker volume | in worktree (bind mount) |
| Commit pending on exit | yes | yes |
| Generate diff | `git diff BASELINE..HEAD` | (not needed) |
| Generate patches | `git format-patch` (M2.3) | (not needed) |
| Apply to PROJECT_DIR | `git am` or `git apply` | (not needed — already there) |
| Operator review | reads `staged.diff` file | `git log`/`git diff` on branch |

**Promote when:** M2.3 is complete and validated, and the operator confirms the three assumptions hold for their workflow.
