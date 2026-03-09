# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules — task granularity, cleanup on completion, section removal — are defined in [`docs/development/roadmap_policy.md`](../development/roadmap_policy.md).

---

## Milestone Summary

| Milestone | Status |
|---|---|
| [M1 — Barebones Agent Container](#m1-barebones-agent-container) | Complete |
| [M1.1 — Interactive Virtual Workspace / Serve Mode](#m11--interactive-virtual-workspace--serve-mode) | Complete |
| [M1.2 — Sandbox File Isolation & Diff Workflow](#m12--sandbox-file-isolation--diff-workflow) | Complete |
| [M1.3 — Invocation Cleanup & Onboarding Workflow](#m13--invocation-cleanup--onboarding-workflow) | Complete |
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

*Complete.*

Project files enter the sandbox via a host-built snapshot in `.bootstrap/`, constructed before the container starts — the agent never has direct access to `PROJECT_ROOT`. The snapshot pipeline is modular and tested; gitignored files are excluded by construction and submodules are rejected with a clear error. Agent changes are captured via a modular diff pipeline in `lib/diff.sh`, producing `staged.diff` on exit and `autosave.diff` on interval. Apply scripts in `scripts/` consume `staged.diff` and apply cleanly to the host repository via `git apply --3way`.

---

### **M1.3 — Invocation Cleanup & Onboarding Workflow**

*Complete.*

The per-project conf file is removed; project identity and paths are defined in the project-side `Makefile` with `PROJECT_ROOT` as `$(CURDIR)`. The `agent-sandbox` CLI wrapper in `scripts/agent-sandbox.sh` dispatches to provider scripts and apply scripts, handles build-if-missing and `--rebuild`, and is installed via `make install`. `start_agent.sh` and `build_agent.sh` are single-purpose scripts with named flag interfaces; the apply scripts are merged into `apply_workspace.sh` with an optional `--branch` flag. Provider scripts and Dockerfile are flattened under `providers/opencode/`. The operator onboarding workflow and `docs/development/quickstart.md` are written; `providers/opencode/quickstart.md` serves as a debug and command reference for the OpenCode provider.

---

### **M2: Autonomous Task Execution, Manual Review Workflow**

**Objective:** Move from interactive prompting to structured task execution.

- [ ] Define Task Brief format (`TASK.md` — per-run brief passed alongside `agent_context_brief.md`)
- [ ] Define agent execution lifecycle for a single task run
- [ ] Support multi-task execution model
- [ ] Patch history — `apply_workspace.sh` archives `staged.diff` with a timestamp before applying; replaces single overwritten diff with a retrievable history
- [ ] Atomic install for `make install` — write to temp file, verify, then `mv` into place
- [ ] Pre-snapshot validation gate — configurable per-project check run by `start_agent.sh` before building `.bootstrap/`; fail fast before the container starts

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
- [ ] `apply_workspace.sh --branch=<n>` supports named branches per agent
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

## Notes

- **Core minimum usable system:** M1 + M1.1 + M1.2
- M2 introduces structured autonomy
- Manual review remains mandatory until automation is formally trusted
- This roadmap is a living document and may evolve as implementation matures

---

## Known Limitations

- **Submodules not supported** — `snapshot_enumerate_files` detects gitlink entries and aborts with a clear message. Full submodule support (recursive enumeration into nested repos) is deferred; operators must deinitialise submodules before running the harness.

- **Stale git index causes cryptic snapshot failures** — `snapshot_enumerate_files` enumerates files via `git ls-files` against the current index. If tracked files have been deleted from disk but not staged for removal (`git rm`), `snapshot_copy_files` will fail with `cp: cannot stat`. Fix with `git rm --cached <file>` followed by a commit. A future hardening pass should add existence validation in `snapshot_enumerate_files` to produce a clear error rather than a mid-pipeline `cp` failure.

- **Bad diff applied to host repo corrupts future snapshots** — `PROJECT_ROOT` is never mounted during a run and the agent works exclusively in `sandbox/`, so a bad run cannot corrupt the host repo during execution. The risk is after the operator applies a bad diff — the host repo is then in a bad state and future snapshots reflect it. See [Recovery](#recovery) in `docs/development/quickstart.md` for how to reset to a known-good state.

---

## Future Security & Network Hardening (Roadmap Only)

The following are planned improvements and are not yet enforced:

- Restrict outbound network access to required AI endpoints
- Evaluate `--network=none` mode for non-AI execution
- Introduce outbound proxy or domain filtering
- Enforce resource ceilings more strictly
- Add automated isolation validation checks
- Snapshot from a clean git ref rather than working tree — operator designates a commit SHA or tag; a dirty or broken working tree has no effect on what the agent sees

Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../architecture/security.md).

### Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 — Structural Separation — folder ownership, temperature classification, root document audience separation
- [ ] Level 2 — Review Discipline — PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 — Temperature & Freeze Policy — hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 — Change Classification Matrix — explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 — Automated Enforcement — CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents
