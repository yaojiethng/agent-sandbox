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

Establishes how project files enter the sandbox, how secrets are excluded, and how agent changes are captured and validated as a diff.

The git bundle workflow (originally M1.6) was designed and partially implemented but rejected. It required creating temporary commits on the host repository during every agent run, which mutated the user's working tree and caused state parity failures between the container and host. The current approach — mounting `PROJECT_ROOT` read-only and copying files via `git ls-files` inside the entrypoint — achieves the same isolation and diff goals without touching the host repo. See `agent_runtime.md` for full details.

- [x] `PROJECT_ROOT` mounted read-only; `.workspace` mounted read-write
- [x] Per-directory `MOUNTS`/`FILES` config removed — full repo mount replaces manual parity maintenance
- [x] Sandbox populated via `git ls-files` — `.gitignore` respected, secrets excluded
- [x] Baseline git commit in `sandbox/` before agent runs
- [x] `patch.diff` generated on exit via `git diff <baseline>..HEAD`
- [x] Autosave checkpoints during session
- [x] `apply_workspace_inplace.sh` and `apply_workspace_to_branch.sh` — git validation before apply
- [ ] Validate end-to-end: agent edits → `patch.diff` → `make apply` → clean apply on host
- [ ] Confirm `patch.diff` paths resolve correctly relative to `PROJECT_ROOT`
- [ ] Test with dirty and clean host working tree
- [ ] Verify untracked-only repo copies correctly into sandbox
- [ ] Verify behaviour with submodules (document or handle)
- [ ] Verify symlink handling
- [ ] Confirm agent cannot read `.workspace` contents via the ro mount
- [ ] Confirm gitignored files are absent from `sandbox/` after copy
- [ ] Confirm `brief.md` present in `sandbox/` when `AGENT_BRIEF` is set

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
