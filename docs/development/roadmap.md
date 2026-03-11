# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules — task granularity, cleanup on completion, section removal — are defined in [`docs/development/roadmap_policy.md`](../development/roadmap_policy.md).

---

## Milestone Summary

| Milestone | Status |
|---|---|
| M1 — Barebones Agent Container | [Complete — see changelog](changelog.md) |
| M1.1 — Interactive Virtual Workspace / Serve Mode | [Complete — see changelog](changelog.md) |
| M1.2 — Sandbox File Isolation & Diff Workflow | [Complete — see changelog](changelog.md) |
| M1.3 — Invocation Cleanup & Onboarding Workflow | [Complete — see changelog](changelog.md) |
| M1.4 — Image Staleness Detection | [Complete — see changelog](changelog.md) |
| [M1.5 — Serve Mode & Apply Workflow](#m15--serve-mode--apply-workflow) | Not started |
| [M1.6 — Session Persistence & Agent Configuration](#m16--session-persistence--agent-configuration) | Not started |
| **Single-Agent Coordination** | |
| [M2 — Autonomous Task Execution, Manual Review Workflow](#m2-autonomous-task-execution-manual-review-workflow) | Not started |
| **Multi-Agent Coordination** | |
| [M3 — Metadata Seeding](#m3-metadata-seeding) | Not started |
| [M4 — Agent-Assigned Branch Management](#m4-agent-assigned-branch-management) | Not started |
| **Multi-Agent Orchestration** | |
| [M5.1 — Task Dispatch](#m51-task-dispatch) | Not started |
| [M5.2 — Constraint Enforcement](#m52-constraint-enforcement) | Not started |
| [M5.3 — Review & CI/CD Integration](#m53-review--cicd-integration) | Not started |
| **Standalone** | |
| [M6 — Safe vs Unsafe Mode (Policy Layer)](#m6-safe-vs-unsafe-mode-policy-layer) | Not started |
| [M7 — Skills / Templates](#m7-skills--templates) | Not started |

---

## Upcoming Milestones

### **M1.5 — Serve Mode & Apply Workflow**

**Objective:** Fix a serve mode bug and redesign the apply workflow to preserve agent commit history.

#### Bug 1 — Rebuild serve mode restarts on first Ctrl-C

- [ ] Diagnose: determine whether the restart is caused by signal interception in the container or by the build step unintentionally starting the server
- [ ] Fix restart behaviour so Ctrl-C shuts down cleanly without a second start

#### Workflow Adjustment — Apply workflow loses agent commit history

Current behaviour: the diff pipeline squashes all agent changes into a single `patch.diff` on exit, discarding checkpoint commits made inside the container.

Target behaviour:
- Container exports full commit history from `sandbox/` using `git format-patch` (or equivalent replayable format) rather than a unified diff
- `apply` creates a checkpoint branch from current host HEAD before touching anything
- Agent commits are replayed onto a new named branch (e.g. `agent/<task-id>`), leaving the original branch intact
- Operator ends up with two branches: original state and agent's work
- To revert: return to checkpoint branch; to keep: merge or cherry-pick as desired

Open consideration — patch history: once commits are preserved natively via replay, archiving `patch.diff` with a timestamp may be redundant. Needs to be reasoned out during implementation — decide whether a diff archive is still useful alongside a replayable commit history.

Tasks:
- [ ] Brainstorm and agree on export format (`git format-patch` vs bundle vs other)
- [ ] Parameterise agent branch naming (e.g. `agent/<task-id>`) — single-agent case only; multi-agent coordination stays in M4
- [ ] Update diff pipeline in `lib/diff.sh` — replace `patch.diff` output with replayable commit export
- [ ] Update `apply_workspace.sh` — checkpoint branch creation, replay commits onto named branch
- [ ] Resolve patch history consideration — archive or drop
- [ ] Update `agent_workflow.md` — document new apply workflow and checkpoint/revert pattern
- [ ] Update `execution_model.md` — document new output format replacing `patch.diff`

---

## User Stories

Active investigations not yet promoted to milestones. Full reasoning and open questions in the linked documents.

- [Website Dev Project Onboarding](story_website_dev.md) — port exposure, live reload, XSS risk assessment, safe browse protocol
- [Obsidian Vault Onboarding](../../workflow/knowledge-vault/story.md) — investigation complete; tooling and onboarding guide; checkpoint scripts, vault-init, and LFS test suite produced; integration validation pending (phase 4). Full detail in [knowledge-vault/roadmap](../../workflow/knowledge-vault/roadmap.md).

---

## Documentation

- [ ] Extract completed milestones to a changelog document; add link from roadmap — do this during the next task cleanup and consolidation pass
- [ ] Update `roadmap_policy.md` to document the changelog extraction process

---

### **M1.6 — Session Persistence & Agent Configuration**

**Objective:** Preserve OpenCode session history across container runs, and enable plan-mode write access for documentation and progressive planning workflows.

#### Session DB persistence

OpenCode stores all session history in a SQLite database at `~/.local/share/opencode/opencode.db` inside the container. This is currently discarded on container exit. The fix is to mount a host path into the container at that location so the DB survives across runs.

- [ ] Identify host-side storage location for session DB (per-project or global)
- [ ] Add mount for `~/.local/share/opencode/` into container mount shape
- [ ] Update `execution_model.md` — document session DB mount as a third container mount
- [ ] Verify DB survives container restart and is correctly re-attached on next run

#### Plan mode write access & stage-then-apply loop

OpenCode's plan mode disables `write`, `edit`, and `patch` by default. Tool access is fully configurable per agent via `opencode.json`, so a custom agent with scoped write access (e.g. to `.opencode/plans/` and `docs/`) can be defined without harness changes. The stage-then-apply loop — where the agent progressively commits intermediate states within a single run — is achievable via agent config and `git commit` permissions.

- [ ] Define a custom plan agent in `opencode.json` with write access scoped to plan and doc paths
- [ ] Configure `git commit` permissions for the plan agent to enable in-session checkpointing
- [ ] Document agent config approach in `providers/opencode/quickstart.md`

---

### **M2: Autonomous Task Execution, Manual Review Workflow**

**Objective:** Move from interactive prompting to structured single-task execution with enough logging to verify the agent is doing useful work.

- [ ] Define Task Brief format (`TASK.md` — per-run brief passed alongside `agent_context_brief.md`)
- [ ] Define agent execution lifecycle for a single task run
- [ ] Atomic install for `make install` — write to temp file, verify, then `mv` into place
- [ ] Pre-snapshot validation gate — configurable per-project check run by `start_agent.sh` before building `.bootstrap/`; fail fast before the container starts
- [ ] Store structured logs per agent and task run
- [ ] Capture metadata with each commit (agent_id, task_id, timestamp) — prerequisite for trusting autonomous output

---

## Multi-Agent Coordination

### **M3: Metadata Seeding**
- [ ] Define `.workspace/metadata.json` format:
  - `agent_id`, `task_id`, allowed files, instructions
- [ ] Ensure agent reads metadata to guide task execution
- [ ] Ensure agent respects allowed file constraints

---

### **M4: Agent-Assigned Branch Management**

**Objective:** Each agent gets its own branch from a shared baseline. Branches serve as both the agent's working surface and the snapshot of its work for review and merge.

- [ ] Each agent gets its own branch from the same baseline
- [ ] `apply_workspace.sh --branch=<n>` supports named branches per agent
- [ ] Validate branch contents before merge
- [ ] Merge branch → `main`
- [ ] Evaluate whether to adopt existing checkpoint branch logic (`workflow/knowledge-vault/scripts/`) as the harness-level branch management mechanism, or design purpose-built tooling — see Deferred Decisions

---

## Multi-Agent Orchestration

### **M5.1: Task Dispatch**

**Objective:** Extend the execution model to support coordinated dispatch of multiple task briefs across agents. Design precedes implementation — `execution_model.md` must be updated before any code changes.

- [ ] Design multi-task coordination model — how multiple task briefs are dispatched, sequenced, and tracked across agents
- [ ] Update `execution_model.md` to reflect dispatch model before implementation begins
- [ ] Implement dispatch mechanism in harness

---

### **M5.2: Constraint Enforcement**

**Objective:** Enforce SOP constraints on agent dispatch and output. Partial enforcement may exist earlier from features built in prior milestones; this milestone brings it to a complete and auditable state.

- [ ] Implement automated SOP enforcement scripts covering agent lifecycle, output handling, and secrets
- [ ] Enforce allowed file and task constraints at dispatch time (builds on M3 metadata)
- [ ] Validate agent outputs against constraints before branch merge

---

### **M5.3: Review & CI/CD Integration**

**Objective:** Automate review of agent-produced changes and integrate with CI/CD pipelines.

- [ ] Configure PR / CI/CD checks on agent branches
- [ ] Automated validation of branch contents before merge
- [ ] Full structured audit trail per agent run, task, and commit

---

## Standalone

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

## Deferred Decisions

### Checkpoint tooling — promote to harness scripts/

The checkpoint scripts produced in the vault onboarding story (`workflow/knowledge-vault/scripts/`) are project-agnostic by design. A decision to promote them to `scripts/` as first-class harness tooling is deferred. If promoted: integration testing against at least one non-vault workflow is required before the scripts are treated as general infrastructure.

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
