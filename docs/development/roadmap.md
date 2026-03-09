# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

---

## Milestone Summary

| Milestone | Status |
|---|---|
| [M1 — Barebones Agent Container](#m1-barebones-agent-container) | Complete |
| [M1.1 — Interactive Virtual Workspace / Serve Mode](#m11--interactive-virtual-workspace--serve-mode) | Complete |
| [M1.2 — Sandbox File Isolation & Diff Workflow](#m12--sandbox-file-isolation--diff-workflow) | In progress |
| [M1.3 — Quickstart & Onboarding Workflow](#m13--quickstart--onboarding-workflow) | Not started |
| [M2 — Autonomous Task Execution, Manual Review Workflow](#m2-autonomous-task-execution-manual-review-workflow) | Not started |
| [M3 — Metadata Seeding](#m3-metadata-seeding) | Not started |
| [M4 — Multi-Agent Branch Management](#m4-multi-agent-branch-management) | Not started |
| [M5 — Logging & Audit](#m5-logging--audit) | Not started |
| [M6 — Safe vs Unsafe Mode (Policy Layer)](#m6-safe-vs-unsafe-mode-policy-layer) | Not started |
| [M7 — Skills / Templates](#m7-skills--templates) | Not started |
| [M8 — Full SOP & CI/CD Integration](#m8-full-sop--cicd-integration) | Not started |

---

## Milestones & Tasks

### **M1: Barebones Agent Container**

*Complete.*

Established the core harness: Docker image, per-project config system, workspace output channel, dry-run liveness check, and Makefile targets. The agent runs inside an isolated container in `standard` mode with network access.

---

### **M1.1 — Interactive "Virtual Workspace" / Serve Mode**

*Complete.*

OpenCode runs in server mode inside the container, accessible from the host on a configurable port. This enables interactive prompting via the OpenCode web interface without requiring a local OpenCode installation. Authentication and Windows client access were validated as part of this milestone.

---

### **M1.2 — Sandbox File Isolation & Diff Workflow**

*In progress.*

Establishes how project files enter the sandbox, how secrets are excluded, and how agent changes are captured as a diff and applied back to the host repo. See [`docs/development/m1.2-discussion.md`](m1_2-discussion.md) for design history and implementation notes.

#### Documentation — Update before code changes

- [x] Resolve document ownership: `agent_runtime.md` renamed to `execution_model.md`; owns container internals (entrypoint sequence, snapshot pipeline, mount shape); `agent_workflow.md` owns operator-facing workflow (staging principles, review loop)
- [x] Migrate internal container behaviour from `agent_workflow.md` sections 2.3 and 3.2 into `execution_model.md`
- [x] Update `agent_workflow.md` mount table to reflect `.bootstrap/` + `.workspace/` mount shape; internal container mechanics removed
- [x] Write `execution_model.md`: `.bootstrap/` input channel, snapshot pipeline function boundaries, validation gates, mount shape, diff pipeline, entrypoint sequence
- [x] Update `security.md` trust boundaries and invariants to reflect that `PROJECT_ROOT` is no longer mounted at container runtime
- [x] Update `doc-status.md`: `execution_model.md` at 🔴 Hot, `agent_workflow.md` reclassified to 🟢 Cold, layer table revised to three implementation layers
- [x] Update `system_overview.md`: revised layer model, major components updated for `.bootstrap/`
- [x] Update `documentation-guidelines.md`: revised layer model, root document audience convention added
- [x] Update `readme.md`: revised layer model
- [x] Update `m1_2-discussion.md`: full modularization design decisions recorded

#### Operation 1 — Snapshot: host repo → sandbox (refactor)

- [x] `PROJECT_ROOT` mounted read-only; `.workspace` mounted read-write
- [x] Per-directory `MOUNTS`/`FILES` config removed — full repo mount replaces manual parity maintenance
- [x] Sandbox populated via `git ls-files` — `.gitignore` respected, secrets excluded
- [x] Baseline git commit in `sandbox/` before agent runs
- [x] Autosave checkpoints during session
- [ ] Introduce `.bootstrap/` as read-only input channel for snapshot and brief
- [ ] Migrate `brief.md` mount from `.workspace/brief.md` to `.bootstrap/brief.md` in `start_agent.sh`
- [ ] Extract snapshot functions into `lib/snapshot.sh`: `snapshot_enumerate_files`, `snapshot_copy_files`, `snapshot_validate`, `snapshot_copy_to_sandbox`, `snapshot_init_git`
- [ ] `start_agent.sh`: call `snapshot_enumerate_files` + `snapshot_copy_files` → `.bootstrap/snapshot/`; run `snapshot_validate` (gate 1) before container starts; remove `PROJECT_ROOT` from runtime mount args
- [ ] `container-entrypoint.sh`: source `lib/snapshot.sh`; run `snapshot_validate` (gate 2); call `snapshot_copy_to_sandbox` then `snapshot_init_git`
- [ ] Write `tests/test_snapshot_host.sh` — enumerate + copy against fixture repo; covers gitignored file exclusion, symlink handling, untracked-only repo, dirty working tree
- [ ] Write `tests/test_snapshot_container.sh` — validate + copy_to_sandbox + init_git against fixture snapshot dir
- [ ] Confirm agent cannot read `.workspace` contents (mount shape enforces this after refactor — verify)
- [ ] Verify behaviour with submodules (document or handle)

#### Operation 2 — Diff: sandbox changes → patch applied to host repo

- [x] `patch.diff` generated on exit via `git diff <baseline>..HEAD`
- [x] `apply_workspace_inplace.sh` and `apply_workspace_to_branch.sh` — git validation before apply
- [ ] Validate end-to-end: agent edits → `patch.diff` → `make apply` → clean apply on host
- [ ] Confirm `patch.diff` paths resolve correctly relative to `PROJECT_ROOT`
- [ ] Test apply on clean host working tree

---

### **M1.3 — Quickstart & Onboarding Workflow**

*Not started. Requires design discussion before implementation.*

The operator-facing setup experience has not been fully defined. This milestone covers the end-to-end onboarding workflow: how a new machine is set up, how a first project is registered, and what the `quickstart.md` document should contain. The related `sandbox-onboarding.md` (from a parallel branch) is shelved pending this discussion.

- [ ] Define the onboarding workflow: repo setup, WSL configuration, first project registration
- [ ] Agree on the scope and structure of `docs/operations/quickstart.md`
- [ ] Write `docs/operations/quickstart.md`

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
- [ ] Each agent gets its own branch from the same baseline
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

All tracked items resolved or moved to milestones. No outstanding debt before M2 freeze.

---

## Progress Tracking

- [ ] Each milestone can be marked as complete
- [ ] Individual tasks under each milestone can be checked off as done
- [ ] Agents can read this file to determine the **next actionable task**

---

## Notes

- **Core minimum usable system:** M1 + M1.1 + M1.2
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
