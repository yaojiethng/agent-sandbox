# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

---

## Milestones & Tasks

### **M1: Barebones Agent Container**
- [x] Create project folder structure
  - `src/`, `tests/`, `.workspace/changes/`, `logs/`
- [x] Build minimal Docker image (`ubuntu:22.04`, Node, Git)
  - Dockerfile and `start-agent.sh` working
- [x] Mount `src/`, `tests/` as read-only; `.workspace/` as read-write
- [x] Spin up agent container
  - Dry-run/liveness check implemented
  - Container can run in `safe` mode
- [x] Agent output channel established via `.workspace/`
  - `patch.diff` generated on container exit

---

### M1.5 — Interactive “Virtual Workspace” / Serve Mode

*Sub-milestone: must be complete before M2 begins. Bridges the gap between a working sandbox (M1) and structured autonomous execution (M2) by providing interactive access to the agent inside the container.*

- [x] Run OpenCode inside container in **server mode**:
  - Command: `opencode serve --hostname 0.0.0.0 --port $SERVE_PORT`
  - Default `$SERVE_PORT=46553`, configurable via env variable
  - Docker publishes port as `127.0.0.1:$SERVE_PORT:$SERVE_PORT`
- [x] Configure authentication for serve mode (if required)
- [x] Access OpenCode from **Windows client or desktop app** using `localhost` (automatically routed by docker / wsl2) to prompt agent manually
- [x] Container filesystem isolation test completed:
  - `.workspace` read-write
  - `src` and `tests` read-only
  - No host filesystem visibility beyond mounts
- [x] `start-agent.sh` updated with `--serve` and `--build` flags
- [x] Standardize patch validation workflow
  - interactive edits generate valid `patch.diff`
  - Apply patch with `make apply`
- [x] Validate end-to-end interactive workflow (serve → edit → patch → review)

---

# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

---

## Milestones & Tasks

### **M1: Barebones Agent Container**
- [x] Create project folder structure
- [x] Build minimal Docker image (`ubuntu:24.04`, Node, Git)
  - Dockerfile and `start_agent.sh` working
- [x] Dynamic mount construction — `MOUNTS` and `FILES` per project config
  - Replaces hardcoded `src/`, `tests/` mounts
  - `.workspace` always mounted rw, implicit
- [x] Spin up agent container
  - Dry-run/liveness check implemented
  - Container runs in `standard` mode (network access allowed)
  - `safe` mode reserved for M6 (no-network)
- [x] Agent output channel established via `.workspace/`
  - `patch.diff` generated on container exit
- [x] Per-project config system
  - `projects/<project>/opencode.conf` — machine-agnostic config
  - `projects/<project>/opencode.<machine>.conf` — machine-specific `PROJECT_ROOT`
  - `projects/<project>/.env` — machine-specific env vars (`SERVE_PORT`, `OPENCODE_SERVER_PASSWORD`)
  - `projects/_template/` — onboarding template for new projects
- [x] `Makefile` at repo root with `start`, `serve`, `build`, `dry-run`, `apply`, `apply-branch` targets
- [x] Dockerfile hardened
  - `project/` and `sandbox/` created as `agentuser` for correct mount ownership
  - `WORKDIR` set to `sandbox/`
  - File permissions preserved on copy (`cp -p`)
  - `core.fileMode=false` in git config


---

### M1.5 — Interactive "Virtual Workspace" / Serve Mode

*Sub-milestone: must be complete before M2 begins. Bridges the gap between a working sandbox (M1) and structured autonomous execution (M2) by providing interactive access to the agent inside the container.*

- [x] Run OpenCode inside container in **server mode**:
  - Command: `opencode serve --hostname 0.0.0.0 --port $SERVE_PORT`
  - Default `$SERVE_PORT=46553`, configurable via `.env`
  - Docker publishes port as `127.0.0.1:$SERVE_PORT:$SERVE_PORT`
- [x] `OPENCODE_SERVER_PASSWORD` forwarded to container from `.env`
- [x] Configure authentication for serve mode (if required)
- [x] Access OpenCode from **Windows client or desktop app** using **WSL IP** to prompt agent manually
- [x] Container filesystem isolation verified:
  - `.workspace` read-write
  - Project files read-only via declared mounts
  - No host filesystem visibility beyond mounts
- [x] `start_agent.sh` updated with `--serve`, `--build`, `--machine` flags
- [x] Validate end-to-end interactive workflow (serve → edit → patch → review)

---

### M1.6 — Git Bundle Workflow

*Sub-milestone: must be complete before M2 begins. Replaces raw file copy with a git-based sandbox to enable clean diff generation and reliable patch application.*

- [ ] `start_agent.sh`: validate `PROJECT_ROOT` is a git repo with at least one commit
- [ ] `start_agent.sh`: create temp commit from unstaged changes, bundle at depth=2 (patch C + temp), reset `HEAD~1`
- [ ] `container-entrypoint.sh`: replace file copy + `git init` with `git clone --depth=1` from bundle
- [ ] `container-entrypoint.sh`: reset `HEAD~1` inside container so agent sees patch C + unstaged changes as working tree
- [ ] `container-entrypoint.sh`: record bundle root hash for diff generation
- [ ] `container-entrypoint.sh`: run `git clean -fdX` after clone to remove gitignored files (e.g. `.env`)
- [ ] `container-entrypoint.sh`: checkout `development` branch (modular — branch naming to be parameterised in future)
- [ ] `stage_diffs`: change from `git diff --cached` to `git diff $BUNDLE_ROOT..HEAD` to capture multiple agent commits
- [ ] `apply_workspace_inplace.sh`: validate git repo before applying, error with setup instructions if not
- [ ] `apply_workspace_to_branch.sh`: same validation
- [ ] Validate end-to-end: patch C → agent changes → `make apply` → clean apply on host


---

### **M2: Autonomous Task Execution, Manual Review Workflow**

**Objective:** Move from interactive prompting to structured task execution.

- [ ] Define Task Brief format
- [ ] Define agent execution lifecycle (single task run)
- [ ] Standardize patch validation workflow
- [ ] Support multi-task execution model
- [ ] Introduce patch history instead of single `patch.diff`
- [ ] Review `.workspace/patch.diff` manually
- [ ] Apply patch to project manually via `make apply`
- [ ] Verify output correctness


---

### **M3: Metadata Seeding**
- [ ] Define `.workspace/metadata.json` format:
  - `agent_id`, `task_id`, allowed files, instructions
- [ ] Ensure agent reads metadata to guide task execution
- [ ] Ensure agent respects allowed file constraints


---

### **M4: Multi-Agent Branch Management**
- [ ] Parameterise branch naming in `container-entrypoint.sh` (e.g. `agent/<task-id>`)
- [ ] Each agent gets its own branch from the same bundle root
- [ ] `apply_workspace_to_branch.sh` supports named branches per agent
- [ ] Validate branch contents before merge
- [ ] Merge branch → `main`


---

### **M5: Logging & Audit**
- [ ] Store structured logs per agent and task
- [ ] Capture metadata with each commit
- [ ] Maintain workspace snapshots for review


---

### **M6: Safe vs Unsafe Mode (Policy Layer)**
- [ ] Introduce `.config/workflow.yaml`
  - Configure network access
  - Configure resource limits (`--memory`, `--cpus`)
  - Define allowed directories and workflow rules
- [ ] Enforce policy configuration in container startup
- [ ] Implement `safe` mode: `--network=none` enforcement


---

### **M7: Skills / Templates**
- [ ] Introduce `.skills/` directory
- [ ] Provide templates or skill definitions for agent
- [ ] Integrate skills into agent workflow


---

### **M8: Full SOP & CI/CD Integration**
- [ ] Implement automated SOP enforcement scripts
- [ ] Validate changes automatically before merge
- [ ] Configure PR / CI/CD checks
- [ ] Full logging and audit trail


---

## Documentation Debt

The following documents have been started or are needed but not yet complete. Address before M2 freeze.

- [ ] `docs/concepts/agent_workflow.md` — update to reflect current workflow:
  - Per-project config system
  - Bundle-based sandbox
  - `make` targets as primary interface
  - `standard` vs `safe` mode distinction
- [ ] `docs/operations/quickstart.md` — verify reflects current setup steps
- [ ] `docs/architecture/system_overview.md` — verify reflects M1 + M1.5 + M1.6 architecture
- [ ] `docs/architecture/agent_runtime.md` — document container lifecycle: bundle → clone → reset → agent → diff
- [ ] `agent-context-brief.md` — add collaboration protocol section (plan-first, scope discipline, etc.)

---

## Progress Tracking

- [ ] Each milestone can be marked as complete
- [ ] Individual tasks under each milestone can be checked off as done
- [ ] Agents can read this file to determine the **next actionable task**

---

## Notes

- **Core minimum usable system:** M1 + M1.5 + M1.6
- M2 introduces structured autonomy
- Manual review remains mandatory until automation is formally trusted
- This roadmap is a living document and may evolve as implementation matures


---

## Future Security & Network Hardening (Roadmap Only)

The following are planned improvements and are not yet enforced:

- Restrict outbound network access to required AI endpoints
- Evaluate `--network=none` mode for non-AI execution
- Introduce outbound proxy or domain filtering
- Enforce resource ceilings more strictly
- Add automated isolation validation checks

Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../architecture/security.md).

### Governance Hardening

Implementation checklist for [`docs/development/documentation-guidelines.md`](documentation-guidelines.md). Levels represent progressive enforcement maturity.
- [x] Level 1 — Structural Separation (Layered docs)
- [ ] Level 2 — Review Discipline (PR template + checklist)
- Level 3 — Change Classification Matrix
  - Explicit classification of doc changes.
- Level 4 — Layer Mutation Restrictions
  - Agents cannot mutate foundational layers.
- Level 5 — Architecture Freeze Policy
  - Milestone-based invariant locking.
