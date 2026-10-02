# agent-sandbox -- Future Milestones

Detail sections for milestones not yet active. Kept separate from [`roadmap.md`](roadmap.md) to keep the active milestone document focused and fast to read.

**Promotion rule:** when a milestone becomes active, move its section from here into `roadmap.md` under `## Upcoming Milestones`. Update the summary table row in `roadmap.md` to point to the local anchor. Remove from this file.

**Re-scoping note:** milestone definitions here are planning targets, not commitments. They are expected to evolve as implementation matures and earlier milestones reveal new constraints. Rewrite sections freely -- this file is not a historical record. The changelog is.

---

## W1 -- Vault Capability Layer Prototype

**Status:** Deferred. Not a mainline milestone -- separate workflow for the Obsidian vault use case. Re-activate when the KV5 timeline demands it.

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first (direct `sandbox/` mount, no MCP), then add MCP server as an enhancement. Unblocks KV5.

**Depends on:** the M2 two-layer foundation, closed in [`changelog.md`](changelog.md#m2--reasoningcapability-layer-separation).

**Hermes python base refactor (non-urgent):** The shared `python-harness` base was designed but never built. Hermes currently builds independently from `python:3.11-slim` rather than inheriting from the harness. If W1 can be implemented without Hermes, consider removing Hermes support entirely rather than maintaining a dormant provider.

**Tasks:**

- [ ] Validate vault workflow with sandbox-only configuration: agent accesses vault files directly via `sandbox/`, diff reviewed and applied to vault repo
- [ ] Evaluate MCP server candidates; select one (criteria: licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency -- see [`20260312-study-settled-mcp_server.md`](discussions/20260312-study-settled-mcp_server.md) candidates table)
- [ ] Build vault capability layer image: extends base capability layer image, adds selected MCP server
- [ ] Configure OpenCode to connect to MCP server; validate it routes vault operations through MCP tools when server is present
- [ ] Validate binary file handling (vault attachments) under selected MCP server
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to vault repo
- [ ] Update `execution_model.md` -- document capability layer variants (general vs vault+MCP)

---

## Multi-Agent Coordination

### M4 - Multi-Agent Coordination

Umbrella for the multi-agent milestones: coordinated dispatch of multiple task briefs across agents, the per-agent branch surface, and the metadata that feeds both. Metadata seeding is the parent milestone's first occupant, carried as `M4.1`. The name records the milestone's subject, and `### M5 - Multi-Agent Coordination (post-M4)` names what follows the M4 tracks.

---

### M4.1 -- Metadata Seeding

- [ ] Read the seeded metadata to guide task execution
- [ ] Respect the seeded allowed-file constraints
- [ ] Decide the regular mutation-run frequency (the M3.1 mutation tier is operator-triggered only until this row sets a cadence)
- [ ] Process the 2026-09-26 mutation-run survivors (62 rows with verdict `survived` in `tests/mutations/runs/20260926-184023-mutation_run.jsonl`): triage each survivor - re-run under the fixed-bite discipline or retire the row - and write the outcome back to the catalog. Dumped here by operator direction at the M3.1 close (2026-09-27), because the survivor set is the mutation tier's first real output and the tier's cadence and processing policy belong to M4.1

---

### M4.2 -- Agent-Assigned Branch Management

**Objective:** Each agent gets its own branch from a shared baseline. Branches serve as both the agent's working surface and the snapshot of its work for review and merge.

- [ ] Each agent gets its own branch from the same baseline
- [ ] `apply_workspace.sh --branch=<n>` supports named branches per agent
- [ ] Validate branch contents before merge
- [ ] Merge branch -> `main`
- [ ] Evaluate whether to adopt existing checkpoint branch logic (`workflow/knowledge-vault/scripts/`) as the harness-level branch management mechanism, or design purpose-built tooling -- decision depends on M2.4 checkpoint branch pattern outcome

---

### M4.3 -- Task Dispatch

**Objective:** Extend the execution model to support coordinated dispatch of multiple task briefs across agents. Design precedes implementation -- `execution_model.md` must be updated before any code changes.

- [ ] Design multi-task coordination model -- how multiple task briefs are dispatched, sequenced, and tracked across agents
- [ ] Update `execution_model.md` to reflect dispatch model before implementation begins
- [ ] Implement dispatch mechanism in harness

**Deferred capability home:** the `pi-subagents` orchestration capabilities not needed by the task-queue primitive (background and detached execution, retained resume and steering, acceptance gates, watchdog, mission schedules, TUI fleet, external-CLI runners, recursion guard) are evaluated here against a future delegation use case, not grafted onto the operator-bottleneck task-queue. They are scope without a task row; the rows that split them out land before the implementation.

---

### M4.4 -- Constraint Enforcement

**Objective:** Enforce SOP constraints on agent dispatch and output. Partial enforcement may exist earlier from features built in prior milestones; this milestone brings it to a complete and auditable state.

- [ ] Implement automated SOP enforcement scripts covering agent lifecycle, output handling, and secrets
- [ ] Enforce allowed file and task constraints at dispatch time (builds on M4.1 metadata)
- [ ] Validate agent outputs against constraints before branch merge

---

### M4.5 -- Review & CI/CD Integration

**Objective:** Automate review of agent-produced changes and integrate with CI/CD pipelines.

- [ ] Configure PR / CI/CD checks on agent branches
- [ ] Automated validation of branch contents before merge
- [ ] Full structured audit trail per agent run, task, and commit

---

### M4.6 -- Background Work (parallel-work)

Multiple well-specified work tasks run once, in the background, with the operator releasing the plan once up front and not gating each unit. Each task is one unit run; the `work` family runs several at once, unattended, and collects the results for later merge. The work-unit and merge responsibilities from the dispatch prompts `workflow/coding-agent/drafts/parallel-work.md` and `workflow/coding-agent/drafts/sequential-work.md` (own worktree and branch per track, primary holds verification and merge) carry over.

**Source:** the retired T1 `parallel-auto` row, relocated here under the M4 umbrella and renamed with the `-work` family (M3.2.3).

- [ ] Build the background-work surface on `workflow/coding-agent/drafts/parallel-work.md`

### M4.7 -- The `/auto` Smart Dispatcher

`/auto` becomes a generalized dispatcher (Option A): given a roadmap task list (possibly out of order, subtasks each carrying an execution rank), it resolves the execution order, picks the dispatch shape per the work structure, and orchestrates. It parks any unit that genuinely needs operator input. The curated dispatch shapes (`sequential-work`, `parallel-work`, `task-queue`, `fanout`) are its building blocks. M3.2.3 reserves the `/auto` keyword with a stub; M4 implements the dispatcher. Design precedes implementation -- the semantics record and the ADR section are written before code changes.

- [ ] Implement the `/auto` smart dispatcher

**Tentative workshape definition for autonomous dispatch units (persisted from the 2026-10-02 planning session; adapt on implementation).** One unit is roughly one fresh-context session: a narrow vertical slice through the layers the task touches, demoable or verifiable on its own rather than a horizontal layer cut. Sizing is a token-budget heuristic: estimate the work's tokens, and the unit budget is about a quarter of the context window -- 250k tokens against a 1M window -- with the total-work estimate divided by that budget naming the unit count. The durable destination the slice derives from is the roadmap row; this repo does not use specs and tickets, so a borrowed definition naming those adapts to the roadmap row and the handover scope instead. File-edit overlap is not the independence criterion: commits legitimately touch the same file (roadmap write-backs, fan-out subtasks), and a violation is work whose parts deliver no outcome of their own, not work that shares a file. `workflow/coding-agent/drafts/parallel-work.md` already carries a tracks-level independence test; whether the unit-level test cross-references it is the implementer's call at M4 time. Scope of this definition: the autonomous dispatch milestones (M4); M3 continues using the roadmap task list as the single unit of work, with the close self-check and the reviewer counterparty verifying that the iteration's confirmed scope lands as one unit in one commit.

### M4.8 -- `/goal` (Loose-Goal Decomposition)

`/goal` is the Option B capability, reworked from the removed and stale external extension: given a loose goal, it decomposes the goal into units itself and schedules every unit it can run, asking the operator only when a unit genuinely needs a decision. It is distinct from `/auto` (Option A), which takes a provided task decomposition and resolves its order and shape. `/goal` is the decomposition-and-schedule engine that runs autonomously until no non-operator-blocked unit remains.

- [ ] Rebuild `/goal` as a first-class prompt or extension

### M5 - Multi-Agent Coordination (post-M4)

**Objective:** the coordination surface that outlives the M4 tracks: agents talking to each other, and two agents holding one task at once. M4.3's dispatch model and M4.4's constraint enforcement are the prerequisites; M5 owns what runs after them land.

- [ ] Cross-agent message queue
- [ ] Coordination (parallel writes) on a complex task

---

## Standalone

### M7 - Security and Network Hardening (Policy Layer)

- [ ] Introduce `.config/workflow.yaml`
  - [ ] Configure network access
  - [ ] Configure resource limits (`--memory`, `--cpus`)
  - [ ] Define allowed directories and workflow rules
- [ ] Enforce policy configuration in container startup
  - [ ] Add automated isolation validation checks
- [ ] Implement `safe` mode: `--network=none` enforcement
  - [ ] Evaluate `--network=none` mode for non-AI execution
- [ ] Implement `restricted` mode: Restrict outbound network access
  - [ ] Introduce outbound proxy or domain filtering to required AI endpoints

#### Dependency Security

Part of M7 -- supply-chain hardening for provider runtime dependencies.

- [x] Pi version pinned in the provider base Dockerfile; the pin moves with the `pi-bump` unit that owns it
- [x] Node base image pinned to specific version (`node:22.22.3-slim`)
- [ ] Consider lockfile for `npm install -g` dependencies (transitive dependency locking)
- [x] Bump cadence policy -- the operator decides when to bump, on new functionality needed, a critical fix, or a security vulnerability, with no automation. The bump edits the pinned version in `src/reasoning/providers/pi/base.dockerfile` and rebuilds.

---

### M8 -- Skills / Templates

- [ ] Introduce `.skills/` directory
- [ ] Provide templates or skill definitions for agent
- [ ] Integrate skills into agent workflow

---

### M9 -- Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 -- Structural Separation -- folder ownership, temperature classification, root document audience separation
- [ ] Level 2 -- Review Discipline -- PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 -- Temperature & Freeze Policy -- hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 -- Change Classification Matrix -- explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 -- Automated Enforcement -- CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents

---

## Harness Packaging and Versioning (Standalone)

**Objective:** Self-contain the agent-sandbox binary at install time and introduce semantic versioning to detect and communicate staleness. This is the prerequisite for harness-sig (runtime drift detection).

**Problem:** `make install` writes an `agent-sandbox` CLI script that sources scripts/libs/templates from the repo checkout at runtime. After `git pull`, the installed binary silently executes changed code. No mechanism signals the operator to reinstall.

**Solution path -- two complementary changes:**

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

**Design reference:** [`devlog/discussions/20260522-study-superseded-harness_sig_requirements.md`](./discussions/20260522-study-superseded-harness_sig_requirements.md)

---

## Deferred (Unplanned)

### Doc Language Cleanup -- STE-Clean Sweep

**Deferred (workflow session `20260809-03`).** Bring the remaining docs, policies, and agent files to the Simple Technical English (ASD-STE100) standard: objective and technical, disambiguated from conversational context, no dead prose, one concept per sentence. New and changed policy is already drafted to this standard (see the agent-feedback/gotchas finalized-workflow artifact); the sweep applies it to the existing body of docs/policies/agent files. Large scope; deferred here.

### Copy-Model Seeding -- Host-Side Volume Seed (M2.6.5 follow-up, complete)

The volume is seeded host-side before the sandbox container starts, so the entrypoint mounts no snapshot directory: the compose template carries no `SNAPSHOT_DIR` mount, the `baseline.tar` preflight gate is removed with the mount, and the `snapshot_dir` environment and session-state writes are retired repo-wide. Model: [`docs/concepts/copy_delivery.md`](../docs/concepts/copy_delivery.md); design record [`20260730-design-settled-mount_model.md`](./discussions/20260730-design-settled-mount_model.md). Handovers `20260818-02` (the copy-in decision) and `20260901-14` (the implementation). The entrypoint branch inversion (`if ! -d .git` then init, else resume bookkeeping) belongs to the M2.6.6 delivery scope and is not filed here.

### M2.6.7 -- Interface Contract Compatibility (complete)

One version constant, one image label, one warn-only preflight check, and a hard stop on a container-to-container mismatch; a missing record key still warns, which is the upgrade path. Interface concept doc `docs/concepts/sandbox_host_interface.md`, lifecycle architecture doc `docs/architecture/sandbox_lifecycle.md`, ADR `docs/adr/interface_contract_compatibility.md`. Handovers `20260919-03` (design), `20260919-04` (implementation) and `20260919-05` (documentation); design record [`20260919-design-settled-interface_contract_compatibility.md`](./discussions/20260919-design-settled-interface_contract_compatibility.md). The `container-sig` mechanism this sub-milestone superseded was retired at `20260919-08`.

### Environment-Change Persistence -- Install Layers Across Runs (Not in scope, current model)

**Deferred / not-in-scope (design walk `20260818-02`, persistence-model decision).** The current model (copy and bind-mount) does not persist environment changes across runs: apt installs, `pi update --self`, `pi install` live in the per-run container writable layer, torn down at every run end (per-run writable-layer parity). Persisting them is explicitly NOT in scope for the current model -- containers are per-run; persistence is delivered exclusively by mounted sources. It would be nice to have. Candidate, parked, if per-run install cost proves punishing: a persisted install-cache volume fed per run (durable-by-designation), not a second writable layer.
