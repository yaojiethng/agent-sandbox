# agent-sandbox -- Future Milestones

Detail sections for milestones not yet active. Kept separate from [`roadmap.md`](roadmap.md) to keep the active milestone document focused and fast to read.

**Promotion rule:** when a milestone becomes active, move its section from here into `roadmap.md` under `## Upcoming Milestones`. Update the summary table row in `roadmap.md` to point to the local anchor. Remove from this file.

**Re-scoping note:** milestone definitions here are planning targets, not commitments. They are expected to evolve as implementation matures and earlier milestones reveal new constraints. Rewrite sections freely -- this file is not a historical record. The changelog is.

---

## W1 -- Vault Capability Layer Prototype

**Status:** Deferred. Not a mainline milestone -- separate workflow for the Obsidian vault use case. Re-activate when KV5 timeline demands it.

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first (direct `sandbox/` mount, no MCP), then add MCP server as an enhancement. Unblocks KV5.

**Depends on:** M2.1 two-container foundation, M2.2 modularised provider scripts, M2.3 apply workflow.

**Hermes python base refactor (non-urgent):** The shared `python-harness` base (`src/reasoning/python.dockerfile`) was designed but never built. Hermes currently builds independently from `python:3.11-slim` rather than inheriting from the harness. If W1 can be implemented without Hermes, consider removing Hermes support entirely rather than maintaining a dormant provider.

**Tasks:**

- [ ] Validate vault workflow with sandbox-only configuration: agent accesses vault files directly via `sandbox/`, diff reviewed and applied to vault repo
- [ ] Evaluate MCP server candidates; select one (criteria: licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency -- see [`investigation_mcp_server.md`](discussions/investigation_mcp_server.md) candidates table)
- [ ] Build vault capability layer image: extends base capability layer image, adds selected MCP server
- [ ] Configure OpenCode to connect to MCP server; validate it routes vault operations through MCP tools when server is present
- [ ] Validate binary file handling (vault attachments) under selected MCP server
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to vault repo
- [ ] Update `execution_model.md` -- document capability layer variants (general vs vault+MCP)

---

## Multi-Agent Coordination

### M4 -- Metadata Seeding

Suggestion, not a scheduled task (subsumed under the Roadmap-mechanism rewrite study in `roadmap.md`): if a labelled task record is adopted, its shape carries `agent_id`, `task_id`, allowed files, and instructions.

- [ ] Ensure agent reads metadata to guide task execution
- [ ] Ensure agent respects allowed file constraints

---

### M5 -- Agent-Assigned Branch Management

**Objective:** Each agent gets its own branch from a shared baseline. Branches serve as both the agent's working surface and the snapshot of its work for review and merge.

- [ ] Each agent gets its own branch from the same baseline
- [ ] `apply_workspace.sh --branch=<n>` supports named branches per agent
- [ ] Validate branch contents before merge
- [ ] Merge branch -> `main`
- [ ] Evaluate whether to adopt existing checkpoint branch logic (`workflow/knowledge-vault/scripts/`) as the harness-level branch management mechanism, or design purpose-built tooling -- decision depends on M2.4 checkpoint branch pattern outcome

---

## Multi-Agent Orchestration

### M6.1 -- Task Dispatch

**Objective:** Extend the execution model to support coordinated dispatch of multiple task briefs across agents. Design precedes implementation -- `execution_model.md` must be updated before any code changes.

- [ ] Design multi-task coordination model -- how multiple task briefs are dispatched, sequenced, and tracked across agents
- [ ] Update `execution_model.md` to reflect dispatch model before implementation begins
- [ ] Implement dispatch mechanism in harness

---

### M6.2 -- Constraint Enforcement

**Objective:** Enforce SOP constraints on agent dispatch and output. Partial enforcement may exist earlier from features built in prior milestones; this milestone brings it to a complete and auditable state.

- [ ] Implement automated SOP enforcement scripts covering agent lifecycle, output handling, and secrets
- [ ] Enforce allowed file and task constraints at dispatch time (builds on M4 metadata)
- [ ] Validate agent outputs against constraints before branch merge

---

### M6.3 -- Review & CI/CD Integration

**Objective:** Automate review of agent-produced changes and integrate with CI/CD pipelines.

- [ ] Configure PR / CI/CD checks on agent branches
- [ ] Automated validation of branch contents before merge
- [ ] Full structured audit trail per agent run, task, and commit

---

## Standalone

### M7 -- Security and Network hardening (Policy Layer)

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

Part of M7 -- supply-chain hardening for provider runtime dependencies.

- [x] Pi version pinned in base Dockerfile (current: `@earendil-works/pi-coding-agent@0.86.0`)
- [x] Node base image pinned to specific version (`node:22.22.3-slim`)
- [ ] Consider lockfile for `npm install -g` dependencies (transitive dependency locking)
- [x] Bump policy -- operator decides when to bump based on: new functionality needed, critical fix, or security vulnerability. No automation. Bump manually by editing the pinned version in `base.Dockerfile` and rebuilding.

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

**Design reference:** [`devlog/discussions/investigation_harness_sig_requirements.md`](./discussions/investigation_harness_sig_requirements.md)

---

## Deferred (Unplanned)

### Harness-sig -- Host-Side Staleness Detection

Described in Harness Packaging and Versioning above.

### Doc Language Cleanup -- STE-Clean Sweep

**Deferred (workflow session `20260809-03`).** Bring the remaining docs, policies, and agent files to the Simple Technical English (ASD-STE100) standard: objective and technical, disambiguated from conversational context, no dead prose, one concept per sentence. New and changed policy is already drafted to this standard (see the agent-feedback/gotchas finalized-workflow artifact); the sweep applies it to the existing body of docs/policies/agent files. Large scope; deferred here.

### Copy-Model Seeding -- Host-Side Volume Seed (M2.6.5 follow-up) -- DONE 20260901-14

**Deferred decision `20260818-02` (keep RO-mount-at-start); dependency landed; discovery validated `20260901-13`; implemented `20260901-14` -- entry retained as record.** Seed the volume host-side before the sandbox container starts (one-shot `docker compose create` + `docker cp` through the volume mount), no snapshot mount, fresh and resume compose files identical, staging exists only during the seed step. Serialization: git-enumerated tar under the `.agent-sandbox-seed/` sentinel; container-side init reconstructs index=HEAD/worktree=disk. Model: [`docs/concepts/copy_delivery.md`](../docs/concepts/copy_delivery.md). All three subtasks below are resolved: compose template carries no SNAPSHOT_DIR mount, the `baseline.tar` preflight gate is removed with the mount, and the `snapshot_dir`/SNAPSHOT_DIR env + session-state writes are retired repo-wide (incl. dirs.sh and the knowledge diagnostics).

- [ ] Drop the always-mounted `SNAPSHOT_DIR` from the compose template -- no conditional mount needed once seeding is host-side
- [ ] Re-scope the unconditional preflight `baseline.tar` gate (entrypoint ~line 177) to fresh-init only -- vestigial on resume, where the volume's git state is authoritative
- [ ] Re-examine `snapshot_dir`/SNAPSHOT_DIR env + session_state writes once the mount disappears

Records: design record `20260730-design-settled-mount_model.md`, handover `20260818-02` (copy-in mechanism decision). The entrypoint branch inversion (if `! -d .git` -> init; else -> resume bookkeeping) is not filed here -- it belongs to the M2.6.6 delivery implementation scope.

### M2.6.7 -- Interface Contract Compatibility (Complete)

**Design settled 20260919-03.** P0 landed 20260919-04 (version constant, image label, record stamps, warn-only preflight check). Doc consolidation landed 20260919-05: one interface concept doc (`docs/concepts/sandbox_host_interface.md`, renamed from the correspondence model) + one lifecycle architecture doc (`sandbox_lifecycle.md`). One version `INTERFACE_CONTRACT_VERSION` declared in `src/libs/interface_contract.sh`, stamped into tier-3 images at build (declaration 1) and into the record (`.compose` label set + `SESSION_STATE` key, declaration 2); comparison layered by surface: host<->container + record at start/resume preflight, container<->container at the agent entrypoint. P2 landed default-warn 20260919-06: flag `interface_contract_strict()` + preflight policy enforcement + agent-entrypoint `_check_container_contract`; container-sig untouched. 20260919-07 removed the flag entirely per operator direction: the contract is authoritative with no runtime escape hatch (an override would be a backdoor that weakens the contract and grows the maintenance surface); preflight refuses on a drift or missing label; the agent entrypoint hard-stops on a container<->container mismatch; a missing record key/file still warns (upgrade path). Container-sig rollover P0-P3, old check stripped only after the new is proven. 20260919-08 retired container-sig (P3): `container_sig`/`current_sig`/`image_baked_sig`, the label bake and `_check_container_sig` removed, `src/libs/container_sig.sh` and `tests/libs/sig_helpers.sh` deleted, install xargs note dropped, `image_digest` relocated to `src/build/image.sh`. ADR `docs/adr/interface_contract_compatibility.md` (closed -- authoritative; container-sig retired P3). Discussion `devlog/discussions/20260919-design-interface_contract_compatibility.md` (settled). M2.6.7 complete.

### Environment-Change Persistence -- Install Layers Across Runs (Not in scope, current model)

**Deferred / not-in-scope (design walk `20260818-02`, persistence-model decision).** The current model (copy and bind-mount) does not persist environment changes across runs: apt installs, `pi update --self`, `pi install` live in the per-run container writable layer, torn down at every run end (per-run writable-layer parity). Persisting them is explicitly NOT in scope for the current model -- containers are per-run; persistence is delivered exclusively by mounted sources. It would be nice to have. Candidate, parked, if per-run install cost proves punishing: a persisted install-cache volume fed per run (durable-by-designation), not a second writable layer.
