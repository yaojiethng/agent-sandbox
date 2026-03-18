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
| [M1.5 — Workflow Convergence & Directory Restructuring](#m15--workflow-convergence--directory-restructuring) | In progress |
| M1.7 — Provider Modularisation | Superseded by M2 — see [investigation_mcp_server.md](../discussions/investigation_mcp_server.md) Conclusion |
| **Two-Layer Architecture** | |
| [M2 — Reasoning/Capability Layer Separation](#m2--reasoningcapability-layer-separation) | Not started |
| **Single-Agent Coordination** | |
| [M3 — Autonomous Task Execution, Manual Review Workflow](#m3--autonomous-task-execution-manual-review-workflow) | Not started |
| **Multi-Agent Coordination** | |
| [M4 — Metadata Seeding](#m4--metadata-seeding) | Not started |
| [M5 — Agent-Assigned Branch Management](#m5--agent-assigned-branch-management) | Not started |
| **Multi-Agent Orchestration** | |
| [M6.1 — Task Dispatch](#m61--task-dispatch) | Not started |
| [M6.2 — Constraint Enforcement](#m62--constraint-enforcement) | Not started |
| [M6.3 — Review & CI/CD Integration](#m63--review--cicd-integration) | Not started |
| **Standalone** | |
| [M7 — Safe vs Unsafe Mode (Policy Layer)](#m7--safe-vs-unsafe-mode-policy-layer) | Not started |
| [M8 — Skills / Templates](#m8--skills--templates) | Not started |

---

## Upcoming Milestones

### **M1.5 — Workflow Convergence & Directory Restructuring**

**Objective:** Close the M1.x architecture by completing the directory restructuring and operator input channel, resolving open user stories, and recording the workflow convergence decision. M1.5 closes when the directory restructuring is implemented and documented, the input channel is in place, and all story resolution tasks are marked complete or explicitly deferred to M2.

Serve mode fix is complete. Two-layer architecture decision is recorded — conceptual model in [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md), full reasoning in [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md).

#### Directory restructuring

Harness artefacts currently live inside `PROJECT_ROOT`, polluting the project's git tree. The fix separates the project repo from the harness workspace as sibling directories under a common `WORKDIR`.

**Terminology change:**
- `PROJECT_ROOT` → `PROJECT_DIR` (the git repo, unchanged in content)
- New: `SANDBOX_DIR` — sibling to `PROJECT_DIR`, harness-owned, contains all harness artefacts

**New layout:**
```
WORKDIR/
├── project-dir/          ← PROJECT_DIR (git repo, clean)
└── project-dir-sandbox/  ← SANDBOX_DIR (harness workspace, gitignored)
    ├── Makefile
    ├── .env
    ├── input/            ← operator input channel (see below)
    ├── .bootstrap/       ← snapshot and brief (built at run time)
    └── .workspace/       ← reporting workspace (agent output)
```

`SANDBOX_DIR` defaults to `<parent-of-PROJECT_DIR>/<project-dir-name>-sandbox/`. Overridable via config.

- [ ] Update `start_agent.sh` — derive `SANDBOX_DIR` from `PROJECT_DIR` by convention (overridable); write `.bootstrap/` and `.workspace/` into `SANDBOX_DIR`; rename internal variables from `PROJECT_ROOT` to `PROJECT_DIR`
- [ ] Update `--root` flag to `--project` on `start_agent.sh` and the CLI wrapper
- [ ] Update `libs/` path derivation where `PROJECT_ROOT` is referenced
- [ ] Update `execution_model.md` — new directory layout, updated terminology, updated mount shape table
- [ ] Update `agent_workflow.md` — updated operator directory layout and pre-run setup instructions
- [ ] Note: onboarding skill update is a separate follow-on task; it must be written to be modular so future directory convention changes do not require a full skill rewrite

#### Operator input channel

Add a dedicated read-only input channel for the operator to pass task files, briefs, and file path lists to the agent before a run. The agent reads from this channel during the run; it cannot write back.

**Mount addition:**
```
Host: SANDBOX_DIR/input/    →    Container: /home/agentuser/.input/    (read-only)
```

The entrypoint copies contents of `.bootstrap/` and `.input/` into `sandbox/` at startup alongside the project snapshot, making them available to the agent as ordinary files.

- [ ] Add `SANDBOX_DIR/input/` as a separate RO container mount in `start_agent.sh`
- [ ] Update `container-entrypoint.sh` — copy `input/` contents into `sandbox/` at startup
- [ ] Update `execution_model.md` — document input channel as a third container mount
- [ ] Define input channel lifecycle in `agent_workflow.md`: written by operator before run, read by agent during run, operator clears or overwrites before next run
- [ ] Confirm: does read access to `.workspace/` expose original repo git history? (Snapshot copy design was chosen to prevent this — verify it holds under the new layout)

#### Story resolution

- [x] Resolve [Obsidian Vault Onboarding](../discussions/story_obsidian_vault_onboarding.md) — KV1–KV4 complete. KV5 (agent modification workflow) requires two-layer architecture; promoted to M2.1. Harness-agnostic directory prerequisite addressed in directory restructuring above.
- [x] Resolve [Website Dev Project Onboarding](../discussions/story_website_dev.md) — port exposure, live reload, XSS risk assessment. Deferred to M2.2 as a bash-enabled capability layer use case. No M1.5 implementation required; open questions are M2.2 scope.
- [x] Resolve [Knowledge Store Provider](../discussions/story_provider_knowledge_store.md) — investigation complete; two-layer architecture adopted; work promoted to M2. Story closed.

#### Workflow convergence gate

- [x] Decision recorded: workflow convergence gate deferred to post-M2. The conceptual workflow (operator initiates run, agent produces diff, operator reviews and applies) is unchanged. The backing implementation changes under the two-layer model — diff pipeline migrates to the capability layer in M2. Checkpoint branch pattern remains operative. Formal apply convention decision deferred to M2.4 when the capability layer diff pipeline is designed.

---

## Deferred Decisions

### Checkpoint tooling — promote to harness scripts/

The checkpoint scripts produced in the vault onboarding story (`workflow/knowledge-vault/scripts/`) are project-agnostic by design. A decision to promote them to `scripts/` as first-class harness tooling is deferred. If promoted: integration testing against at least one non-vault workflow is required before the scripts are treated as general infrastructure.

### Checkpoint branch pattern — adopt as harness-level apply convention

The vault workflow established a checkpoint branch pattern: create a dated branch from current HEAD before each agent session; apply the diff after review; roll back to the checkpoint branch if the diff is rejected. This pattern is operationally validated through KV4. A decision to formalise it as the standard `apply` convention is deferred to M2.4, where the capability layer diff pipeline redesign will determine whether the checkpoint pattern composes with or supersedes the current `patch.diff` model.

### Pre-session checkpoint automation

Whether to automate checkpoint creation before each agent session (e.g. as part of `make start`) is deferred until the manual checkpoint workflow is validated at scale. Revisit after M2.4 apply workflow is stable.

### Onboarding skill modularisation

The sandbox-onboarding skill currently produces a Makefile placed at `PROJECT_ROOT`. Under the new directory layout the Makefile moves to `SANDBOX_DIR`. The skill update is a follow-on task after M1.5 directory restructuring is complete. **Requirement:** the updated skill must be written to be modular — directory convention variables should be isolated so that future layout changes do not require a full skill rewrite.

---

### **M2 — Reasoning/Capability Layer Separation**

**Objective:** Separate the harness into a reasoning layer (agent container, MCP client) and a capability layer (MCP server container, project tool interface). This is the foundational architectural change that enables vault workflows, webapp workflows, provider swapping, and autonomous task execution. All M1.x architecture documents are hot during this milestone and updated sub-milestone by sub-milestone.

Conceptual model: [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md)  
Design rationale: [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md) — Conclusion

---

#### **M2.1 — Capability Layer Prototype: Vault (MCP server, Obsidian)**

**Objective:** Build and validate the first capability layer container for the Obsidian vault use case. This proves the two-layer model in practice and unblocks KV5.

**Open decisions (must resolve before implementation):**
- Working mount strategy: live vault mount (simpler, diff from git history post-session) vs sandbox copy in MCP server container (cleaner diff, harness-managed). Live mount preferred; confirm before starting.
- MCP server selection: evaluate candidates against criteria (licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency). See `investigation_mcp_server.md` — MCP server candidates table.

**Tasks:**
- [ ] Decide working mount strategy (live vs sandbox copy)
- [ ] Evaluate MCP server candidates; select one for prototype
- [ ] Build MCP server container image: base image + selected server + vault mount at `/working`
- [ ] Configure OpenCode to connect to MCP server via HTTP; confirm no working mount in OpenCode container
- [ ] Validate: OpenCode routes vault operations through MCP tools, not built-in filesystem tools
- [ ] Validate: reporting workspace works end-to-end — agent reads brief from `input/`, writes `todo.md` and progress to `.workspace/`, operator finds expected output after session
- [ ] Validate: binary file handling (vault attachments) under selected MCP server
- [ ] Design harness integration: MCP server container lifecycle (start before agent, stop after), Docker network configuration, `start_agent.sh` changes for two-container orchestration
- [ ] Implement harness integration
- [ ] Define post-session diff generation against working mount; write to `.workspace/changes/`
- [ ] Update `execution_model.md` — two-container model, capability layer lifecycle, new mount shape
- [ ] Update `security.md` — trust boundary table for two containers
- [ ] Update `agent_workflow.md` — operator workflow with two containers
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to live vault

---

#### **M2.2 — Capability Layer Prototype: General (bash-enabled sandbox)**

**Objective:** Build a general-purpose capability layer for coding and webapp workflows using bash tools. This proves the capability layer model generalises beyond vault-specific MCP servers and enables the website dev workflow.

**Known requirements (from website dev story open questions):**
- Port exposure for live reload (dev server)
- Bash tool interface (run commands, read/write files)
- XSS risk assessment for serve mode when the agent is running a live web server

**Tasks:**
- [ ] Design bash-enabled MCP server container: tool surface (bash, read, write, run_server), port exposure model
- [ ] Assess XSS risk: agent-controlled content served on an exposed port — determine acceptable mitigations
- [ ] Build bash-enabled capability layer container
- [ ] Validate with a webapp project: live reload, port accessible from host, agent makes changes visible immediately
- [ ] Update `execution_model.md` — document capability layer variants (vault vs general)
- [ ] Deferred breakdown: full task list to be defined once M2.1 harness integration pattern is established

---

#### **M2.3 — Reasoning Layer Modularisation**

**Objective:** Extract shared harness logic from the OpenCode-specific scripts so that any MCP-compatible reasoning layer can be added without rewriting shared infrastructure. The provider interface under the two-layer model is the MCP protocol — per-provider work is limited to container configuration and mode support.

**Depends on:** M2.1 harness integration pattern established (so extraction reflects the correct two-container boundary).

**Tasks:**
- [ ] Audit `providers/opencode/start_agent.sh` — extract shared logic (snapshot, mount construction, env loading, MCP server lifecycle) into `libs/`; leave only OpenCode-specific invocation
- [ ] Audit `container-entrypoint.sh` — extract shared startup sequence into sourced lib; leave only provider exec step
- [ ] Document execution modes formally in `execution_model.md`: `serve`, `start`, `dry-run`, `headless` (reserved)
- [ ] Define what a conforming reasoning layer provider must supply: mode support declarations, container config, MCP client configuration
- [ ] Validate OpenCode provider conforms after refactor
- [ ] Deferred breakdown: Claude Code provider integration — full task list after M2.3 shared logic extraction is complete and [investigation_claude_code.md](../discussions/investigation_claude_code.md) open questions are resolved

---

#### **M2.4 — Apply Workflow: Capability Layer Diff Pipeline**

**Objective:** Redesign the apply workflow to reflect the two-layer model: diff generated post-session from capability layer working mount, agent commit history preserved, checkpoint branch pattern formalised.

**Depends on:** M2.1 capability layer implementation (diff pipeline mechanics depend on how the working mount is structured).

**Known design (from M1.6 scoping, now reframed):**
- Export full commit history from capability layer working content using `git format-patch` or equivalent
- `apply` creates a checkpoint branch from current host HEAD before touching anything
- Agent commits replayed onto a named branch (`agent/<task-id>`); original branch intact
- Resolve: archive `patch.diff` or drop in favour of replayable commit history

**Tasks:**
- [ ] Confirm checkpoint branch pattern as the standard apply convention (resolves Deferred Decision)
- [ ] Agree on export format (`git format-patch` vs bundle vs other)
- [ ] Parameterise agent branch naming (`agent/<task-id>`) — single-agent case
- [ ] Implement diff pipeline in capability layer (or harness post-session script)
- [ ] Update `apply_workspace.sh` — checkpoint branch creation, replay commits
- [ ] Resolve patch history consideration — archive or drop
- [ ] Update `agent_workflow.md` and `execution_model.md`

---

#### **M2.5 — Session Persistence (Reasoning Layer)**

**Objective:** Preserve OpenCode session history across container runs. Provider-specific to the OpenCode reasoning layer; scoped here as a reasoning layer concern separate from the capability layer.

**Depends on:** M2.3 (reasoning layer modularisation, so session DB mount is cleanly scoped to the provider).

**Tasks:**
- [ ] Identify host-side storage location for session DB (per-project, in `SANDBOX_DIR`)
- [ ] Add mount for `~/.local/share/opencode/` into reasoning layer container
- [ ] Update `execution_model.md` — document session DB mount
- [ ] Verify DB survives container restart and is correctly re-attached on next run

---

### **M3 — Autonomous Task Execution, Manual Review Workflow**

**Objective:** Move from interactive prompting to structured single-task execution with enough logging to verify the agent is doing useful work. Requires the two-layer foundation from M2.

**Depends on:** M2 two-layer architecture (headless mode requires the capability layer tool interface; task briefs are the operator input channel from M1.5).

- [ ] Define Task Brief format (`TASK.md` — per-run brief placed in `SANDBOX_DIR/input/` before the run; aligns with the M1.5 input channel)
- [ ] Define agent execution lifecycle for a single headless task run
- [ ] Atomic install for `make install` — write to temp file, verify, then `mv` into place
- [ ] Pre-snapshot validation gate — configurable per-project check run by `start_agent.sh` before building `.bootstrap/`; fail fast before the container starts
- [ ] Store structured logs per agent and task run
- [ ] Capture metadata with each commit (agent_id, task_id, timestamp) — prerequisite for trusting autonomous output

---

## Multi-Agent Coordination

### **M4 — Metadata Seeding**
- [ ] Define `.workspace/metadata.json` format:
  - `agent_id`, `task_id`, allowed files, instructions
- [ ] Ensure agent reads metadata to guide task execution
- [ ] Ensure agent respects allowed file constraints

---

### **M5 — Agent-Assigned Branch Management**

**Objective:** Each agent gets its own branch from a shared baseline. Branches serve as both the agent's working surface and the snapshot of its work for review and merge.

- [ ] Each agent gets its own branch from the same baseline
- [ ] `apply_workspace.sh --branch=<n>` supports named branches per agent
- [ ] Validate branch contents before merge
- [ ] Merge branch → `main`
- [ ] Evaluate whether to adopt existing checkpoint branch logic (`workflow/knowledge-vault/scripts/`) as the harness-level branch management mechanism, or design purpose-built tooling — see Deferred Decisions

---

## Multi-Agent Orchestration

### **M6.1 — Task Dispatch**

**Objective:** Extend the execution model to support coordinated dispatch of multiple task briefs across agents. Design precedes implementation — `execution_model.md` must be updated before any code changes.

- [ ] Design multi-task coordination model — how multiple task briefs are dispatched, sequenced, and tracked across agents
- [ ] Update `execution_model.md` to reflect dispatch model before implementation begins
- [ ] Implement dispatch mechanism in harness

---

### **M6.2 — Constraint Enforcement**

**Objective:** Enforce SOP constraints on agent dispatch and output. Partial enforcement may exist earlier from features built in prior milestones; this milestone brings it to a complete and auditable state.

- [ ] Implement automated SOP enforcement scripts covering agent lifecycle, output handling, and secrets
- [ ] Enforce allowed file and task constraints at dispatch time (builds on M4 metadata)
- [ ] Validate agent outputs against constraints before branch merge

---

### **M6.3 — Review & CI/CD Integration**

**Objective:** Automate review of agent-produced changes and integrate with CI/CD pipelines.

- [ ] Configure PR / CI/CD checks on agent branches
- [ ] Automated validation of branch contents before merge
- [ ] Full structured audit trail per agent run, task, and commit

---

## Standalone

### **M7 — Safe vs Unsafe Mode (Policy Layer)**
- [ ] Introduce `.config/workflow.yaml`
  - Configure network access
  - Configure resource limits (`--memory`, `--cpus`)
  - Define allowed directories and workflow rules
- [ ] Enforce policy configuration in container startup
- [ ] Implement `safe` mode: `--network=none` enforcement

---

### **M8 — Skills / Templates**
- [ ] Introduce `.skills/` directory
- [ ] Provide templates or skill definitions for agent
- [ ] Integrate skills into agent workflow

---

## Notes

- **Core minimum usable system:** M1 + M1.1 + M1.2
- M2 introduces the two-layer architecture; all current single-container architecture docs are hot during M2
- M3 introduces structured autonomy on top of the two-layer foundation
- Manual review remains mandatory until automation is formally trusted
- This roadmap is a living document and may evolve as implementation matures

---

## Known Limitations

- **Submodules not supported** — `snapshot_enumerate_files` detects gitlink entries and aborts with a clear message. Full submodule support (recursive enumeration into nested repos) is deferred; operators must deinitialise submodules before running the harness.

- **Stale git index causes cryptic snapshot failures** — `snapshot_enumerate_files` enumerates files via `git ls-files` against the current index. If tracked files have been deleted from disk but not staged for removal (`git rm`), `snapshot_copy_files` will fail with `cp: cannot stat`. Fix with `git rm --cached <file>` followed by a commit. A future hardening pass should add existence validation in `snapshot_enumerate_files` to produce a clear error rather than a mid-pipeline `cp` failure.

- **Bad diff applied to host repo corrupts future snapshots** — `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`, so a bad run cannot corrupt the host repo during execution. The risk is after the operator applies a bad diff — the host repo is then in a bad state and future snapshots reflect it. See [Recovery](#recovery) in `docs/development/quickstart.md` for how to reset to a known-good state.

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
