# agent-sandbox — Future Milestones

Detail sections for milestones not yet active. Kept separate from [`roadmap.md`](roadmap.md) to keep the active milestone document focused and fast to read.

**Promotion rule:** when a milestone becomes active, move its section from here into `roadmap.md` under `## Upcoming Milestones`. Update the summary table row in `roadmap.md` to point to the local anchor. Remove from this file.

**Re-scoping note:** milestone definitions here are planning targets, not commitments. They are expected to evolve as implementation matures and earlier milestones reveal new constraints. Rewrite sections freely — this file is not a historical record. The changelog is.

---

## W1 — Vault Capability Layer Prototype

**Status:** Deferred. Not a mainline milestone — separate workflow for the Obsidian vault use case. Re-activate when KV5 timeline demands it.

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first (direct `sandbox/` mount, no MCP), then add MCP server as an enhancement. Unblocks KV5.

**Depends on:** M2.1 two-container foundation, M2.2 modularised provider scripts, M2.3 apply workflow.

**Hermes python base refactor (non-urgent):** The shared `python-harness` base (`src/reasoning/python.dockerfile`) was designed but never built. Hermes currently builds independently from `python:3.11-slim` rather than inheriting from the harness. If W1 can be implemented without Hermes, consider removing Hermes support entirely rather than maintaining a dormant provider.

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
- [ ] Converting the roadmap to linear-style task tracking
- [ ] Moving next-session seed out of handover and into a next-task subheader in the sub-milestone
- [ ] AC-machinery policy discussion for chores, doc, plan type sessions
- [ ] Process improvements (fast-track criteria, decision recording, stale skill reference) — deferred from M2.7

### Doc Bloat — Rotate Out Stale Handovers and Discussions

**Deferred from `roadmap.md` (not milestone-scoped).**

`devlog/handovers/` and `devlog/discussions/` accumulate every session's output. Most are only relevant during their milestone — once a milestone is closed, the handover detail lives in the changelog. There is no need to keep the full history on `HEAD`. Design a rotate-out process: completed milestone handovers are archived to a git tag or a separate branch, removed from `HEAD`. Roadmap entries, architecture docs, and the changelog are the permanent record. The same applies to resolved stories in `devlog/discussions/` — once graduated to a roadmap entry, the story discussion document can be archived. See `20260428-story-active-sequencing_and_knowledge_persistence.md` which is related.

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

#### Dependency Security

Part of M7 — supply-chain hardening for provider runtime dependencies.

- [x] Pi version pinned in base Dockerfile (current: `@earendil-works/pi-coding-agent@0.75.4`)
- [x] Node base image pinned to specific version (`node:22.22.3-slim`)
- [ ] Consider lockfile for `npm install -g` dependencies (transitive dependency locking)
- [x] Bump policy — operator decides when to bump based on: new functionality needed, critical fix, or security vulnerability. No automation. Bump manually by editing the pinned version in `base.Dockerfile` and rebuilding.

---

### M8 — Skills / Templates
- [ ] Introduce `.skills/` directory
- [ ] Provide templates or skill definitions for agent
- [ ] Integrate skills into agent workflow

---

### M9 — Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 — Structural Separation — folder ownership, temperature classification, root document audience separation
- [ ] Level 2 — Review Discipline — PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 — Temperature & Freeze Policy — hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 — Change Classification Matrix — explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 — Automated Enforcement — CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents


---

## Harness Packaging and Versioning (Standalone)

**Objective:** Self-contain the agent-sandbox binary at install time and introduce semantic versioning to detect and communicate staleness. This is the prerequisite for harness-sig (runtime drift detection).

**Problem:** `make install` writes an `agent-sandbox` CLI script that sources scripts/libs/templates from the repo checkout at runtime. After `git pull`, the installed binary silently executes changed code. No mechanism signals the operator to reinstall.

**Solution path — two complementary changes:**

1. **Self-contained binary.** `make install` packages all scripts, libs, and templates into the binary itself (shar archive or similar). The installed binary has zero runtime dependency on the repo checkout. This eliminates the entire class of host-side drift problems.

2. **Semantic versioning.** A `VERSION` file in the repo root, bumped on meaningful changes. The installed binary writes its version to `~/.config/agent-sandbox/.version` at install time. At `make start`, the harness compares installed version against repo version and warns on mismatch.

   Bump policy:
   - **Patch** (0.x.1): lib/script bugfixes, behaviour-preserving internal changes
   - **Minor** (0.1.x): new features, new flags, new Makefile targets
   - **Major** (1.0): breaking CLI changes, install contract changes, deployment model changes

**Depends on:** M2.7 completion (container-sig, build pipeline cleanup). Not part of any current milestone.

**Preconditions for design:**
- Self-contained binary mechanism selected (shar archive vs compiled language vs proper package manager)
- Version bump policy agreed and documented
- Dogfood vs non-dogfood usage split understood (determines where the comparison target lives)

**Design reference:** [`devlog/discussions/investigation_harness_sig_requirements.md`](./discussions/investigation_harness_sig_requirements.md)

---

## Deferred (Unplanned)

### Harness-sig — Host-Side Staleness Detection

Described in Harness Packaging and Versioning above.
