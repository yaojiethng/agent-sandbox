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
- [x] Confirm interactive edits generate valid `patch.diff`
- [x] `start-agent.sh` updated with `--serve` and `--build` flags
- [x] Validate end-to-end interactive workflow (serve → edit → patch → review)

---

### **M2: Autonomous Task Execution, Manual Review Workflow**

**Objective:** Move from interactive prompting to structured task execution.

- [ ] Define Task Brief format
- [ ] Define agent execution lifecycle (single task run)
- [ ] Standardize patch validation workflow
- [ ] Support multi-task execution model
- [ ] Introduce patch history instead of single `patch.diff`
- [ ] Review `.workspace/patch.diff` manually
- [ ] Apply patch to `src/` and `tests/` manually
- [ ] Verify output correctness


---

### **M3: Metadata Seeding**
- [ ] Define `.workspace/metadata.json` format:
  - `agent_id`, `task_id`, allowed files, instructions
- [ ] Ensure agent reads metadata to guide task execution
- [ ] Ensure agent respects allowed file constraints


---

### **M4: Git Branch Staging**
- [ ] Implement `apply_workspace.sh` script
- [ ] Apply `patch.diff` to agent-specific git branch
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
- [ ] Formalize safe vs unsafe execution definitions


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

## Progress Tracking

- [ ] Each milestone can be marked as complete
- [ ] Individual tasks under each milestone can be checked off as done
- [ ] Agents can read this file to determine the **next actionable task**

---

## Notes

- **Core Minimum usable system:** M1 + M1.5
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
