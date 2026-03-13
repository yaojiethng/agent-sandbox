# agent-sandbox — Future Milestones

Detail sections for milestones not yet active. Kept separate from [`roadmap.md`](roadmap.md) to keep the active milestone document focused and fast to read.

**Promotion rule:** when a milestone becomes active, move its section from here into `roadmap.md` under `## Upcoming Milestones`. Update the summary table row in `roadmap.md` to point to the local anchor. Remove from this file.

**Re-scoping note:** milestone definitions here are planning targets, not commitments. They are expected to evolve as implementation matures and earlier milestones reveal new constraints. Rewrite sections freely — this file is not a historical record. The changelog is.

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
