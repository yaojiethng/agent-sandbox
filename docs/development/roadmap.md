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
| M1.5 — Workflow Convergence & Directory Restructuring | [Complete — see changelog](changelog.md) |
| **Two-Layer Architecture** | |
| [M2 — Reasoning/Capability Layer Separation](#m2--reasoningcapability-layer-separation) | In progress |
| **Single-Agent Coordination** | |
| [M3 — Autonomous Task Execution, Manual Review Workflow](roadmap_future.md#m3--autonomous-task-execution-manual-review-workflow) | Not started |
| **Multi-Agent Coordination** | |
| [M4 — Metadata Seeding](roadmap_future.md#m4--metadata-seeding) | Not started |
| [M5 — Agent-Assigned Branch Management](roadmap_future.md#m5--agent-assigned-branch-management) | Not started |
| **Multi-Agent Orchestration** | |
| [M6.1 — Task Dispatch](roadmap_future.md#m61--task-dispatch) | Not started |
| [M6.2 — Constraint Enforcement](roadmap_future.md#m62--constraint-enforcement) | Not started |
| [M6.3 — Review & CI/CD Integration](roadmap_future.md#m63--review--cicd-integration) | Not started |
| **Standalone** | |
| [M7 — Safe vs Unsafe Mode (Policy Layer)](roadmap_future.md#m7--safe-vs-unsafe-mode-policy-layer) | Not started |
| [M8 — Skills / Templates](roadmap_future.md#m8--skills--templates) | Not started |

---

## Upcoming Milestones

### M2 — Reasoning/Capability Layer Separation

**Objective:** Separate the harness into a reasoning layer (agent container) and a capability layer (sandbox container, working content, optional MCP server). This is the foundational architectural change that enables vault workflows, webapp workflows, provider swapping, and autonomous task execution. All M1.x architecture documents are hot during this milestone and updated sub-milestone by sub-milestone.

Conceptual model: [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md)
Design rationale: [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md) — Conclusion

#### M2.1 — General Capability Layer Prototype

**Objective:** Split the current single container into a capability layer container and a reasoning layer container. Prove the two-container model works end-to-end with a sandbox-only configuration (no MCP server) against a generic coding project. This is the foundation all subsequent M2 sub-milestones build on.

Architecture docs updated: [`tool_interface.md`](../architecture/tool_interface.md), [`execution_model.md`](../architecture/execution_model.md), [`security.md`](../architecture/security.md), [`agent_workflow.md`](../concepts/agent_workflow.md), [`quickstart.md`](../operations/quickstart.md).

**Decisions:**

| Decision | Rationale | Recorded in |
|---|---|---|
| Docker Compose per project: `start_agent.sh` writes `docker-compose.yml` + `.env` into `SANDBOX_DIR` from template | Declarative orchestration replaces imperative `docker run`; `.env` separates machine-specific from project-specific | `tool_interface.md` |
| Image naming: `<project>-agent-sandbox` (capability), `<project>-opencode-agent` (reasoning) | Docker Compose accepts hyphens natively | `tool_interface.md` |
| Compose baked vs `.env` split: structure baked, host paths + credentials in `.env` | Stable project structure vs machine-specific runtime are different concerns | `tool_interface.md` |
| Mode overrides: base compose has no ports; serve/dry-run add via `-f` flags | Ports not exposed when not in serve mode | `tool_interface.md` |
| Build command: `make build [sandbox\|agent\|all]` | Granular rebuild; staleness integrated per-image | `tool_interface.md` |
| Two-image staleness: separate `image-files.txt`, check both, warn separately | Images go stale independently | `tool_interface.md` |
| Capability Dockerfile in `SANDBOX_DIR`, project-controlled; default template in `libs/_template/` | Projects control their own dev environment | `tool_interface.md` |
| Dry-run guarantees: both containers start, reasoning writes to sandbox, graceful termination, diff written | Defines what a successful dry-run proves | `tool_interface.md` |
| Dogfood first: agent-sandbox's own repo gets real compose file before template is produced | Template derived from working version, not the reverse | This roadmap |
| `start_agent.sh` remains entry point: gains `docker compose up/down` | Compose handles container orchestration only; all other behaviour retained | This roadmap |

**Documentation — completed.** Architecture docs (`tool_interface.md`, `execution_model.md`, `security.md`), conceptual docs (`agent_workflow.md`), operator docs (`quickstart.md`), and project index updated to reflect the two-container model, mount shape, trust boundaries, and naming conventions.

**Tasks:**

### Capability layer container
- [ ] `libs/_template/dockerfile-default.sandbox` — default capability layer Dockerfile template
- [ ] `Dockerfile.sandbox` — generated into `SANDBOX_DIR` from default template; project can override; compose references project-level file
- [ ] `scripts/sandbox-entrypoint.sh` — capability layer entrypoint: snapshot validate (gate 2), copy snapshot to `sandbox/`, git init + baseline SHA, EXIT trap → diff pipeline, autosave loop, `wait`

### Reasoning layer container
- [ ] `providers/opencode/Dockerfile` — set working dir to `/home/agentuser/project/`, place `AGENTS.md` via Dockerfile, remove snapshot/diff libs, no CMD default
- [ ] `providers/opencode/container-entrypoint.sh` — assess whether still needed; if brief injection moves to Dockerfile and no other startup steps remain, eliminate; document decision

### Orchestration & lifecycle
- [ ] `docker-compose.yml` in agent-sandbox's own `SANDBOX_DIR` — dogfood version; created first, template derived from it
- [ ] `libs/_template/docker-compose.yml.template` — compose template for onboarded projects; derived from dogfood
- [ ] `libs/_template/docker-compose.serve.yml.template` — serve mode override (ports block)
- [ ] `libs/_template/docker-compose.dry-run.yml.template` — dry-run mode override
- [ ] `providers/opencode/start_agent.sh` — two-container lifecycle via `docker compose up/down`; writes compose + `.env` + mode overrides into `SANDBOX_DIR` from templates; snapshot pipeline writes to `SANDBOX_DIR/.snapshot/`; preserves git checkpoint, validation, env loading; `make build [sandbox|agent|all]` dispatch

### Path alignment
- [ ] `libs/snapshot.sh` — update all `.agent-input/` path references to `.snapshot/`
- [ ] `libs/diff.sh` — verify no path changes needed (operates on `sandbox/` and `.workspace/changes/`); grep and confirm

### Build & staleness
- [ ] `libs/image.sh` — separate `image-files.txt` per image (capability in `SANDBOX_DIR`, reasoning in `providers/opencode/`), per-image staleness check, per-image rebuild, warn separately; update tests

### Dry-run
- [ ] `scripts/dry_run.sh` — catalogue existing checks; confirm which to preserve, which to drop; update for two-container dry-run

### Validation
- [ ] End-to-end test: agent runs, modifies files in `sandbox/`, `staged.diff` lands in `.workspace/changes/`, diff applies cleanly to host repo

**Acceptance criteria:**
- `make start` brings up two containers via `docker compose up`; capability layer starts first (service dependency)
- Agent modifies a file in `sandbox/`; `staged.diff` appears in `SANDBOX_DIR/.workspace/changes/` after session ends
- `make apply` applies the diff cleanly to the host repo
- `make serve` exposes port via compose override
- `make dry-run` runs both containers, reasoning writes to sandbox, graceful termination, diff written
- Capability layer exits cleanly and triggers diff pipeline
- Reasoning layer cannot see `SANDBOX_DIR/.snapshot/`; capability layer cannot see `.workspace/agent-input/` or `.workspace/agent-output/`
- `make build sandbox|agent|all` builds correct images; staleness warns per-image

**Deferred to M2.2+:**
- Modularise `start_agent.sh` across providers — provider-specific extraction is M2.2 scope
- Decouple agent-sandbox's own sandboxing from tool implementation (`make install` vs `make start`) — cross-cuts M2.1 and M2.2

#### M2.2 — Reasoning Layer Modularisation

**Objective:** Extract shared harness logic from OpenCode-specific scripts so that any reasoning layer provider can be added without rewriting shared infrastructure.

**Depends on:** M2.1. **Scope:** Audit and split `start_agent.sh` and `container-entrypoint.sh` into shared libs vs provider-specific invocation. Document execution modes formally. Define conforming provider interface. Validate OpenCode conforms. Claude Code provider integration deferred until shared logic extraction is complete and [`investigation_claude_code.md`](../discussions/investigation_claude_code.md) open questions are resolved.

#### M2.3 — Apply Workflow: Capability Layer Diff Pipeline

**Objective:** Redesign the apply workflow to reflect the two-layer model: diff generated post-session from capability layer `sandbox/`, agent commit history preserved, checkpoint branch pattern formalised.

**Depends on:** M2.1. **Scope:** Formalise checkpoint branch pattern as standard apply convention (composing with or superseding `patch.diff` model). Resolve checkpointing method (clean git ref vs working tree). Evaluate pre-session checkpoint automation. Implement diff pipeline in capability layer. Update `apply_workspace.sh` for checkpoint branches.

#### M2.4 — Session Persistence (Reasoning Layer)

**Objective:** Preserve OpenCode session history across container runs.

**Depends on:** M2.2. **Scope:** Provider-specific reasoning layer concern. Identify host-side storage, add session DB mount, verify persistence across restarts.

#### M2.5 — Vault Capability Layer Prototype

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first, then add MCP server as enhancement. Unblocks KV5.

**Depends on:** M2.1, M2.2, M2.3. **Scope:** Validate vault workflow with sandbox-only configuration. Evaluate and select MCP server candidate. Build vault capability layer image. Validate binary file handling and KV5 end-to-end.

---

## Future Milestones

Detail sections for M2 onward are in [`roadmap_future.md`](roadmap_future.md). The summary table above links directly to each section.

Milestone definitions in `roadmap_future.md` are planning targets and expected to evolve. When a milestone becomes active, its section is promoted into this file under `## Upcoming Milestones`.

---

## Notes

- **Core minimum usable system:** M1 + M1.1 + M1.2
- M2 introduces the two-layer architecture; all current single-container architecture docs are hot during M2
- M3 introduces structured autonomy on top of the two-layer foundation
- Manual review remains mandatory until automation is formally trusted
- Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../architecture/security.md).

---

## Known Limitations

- **Submodules not supported** — `snapshot_enumerate_files` detects gitlink entries and aborts with a clear message. Full submodule support (recursive enumeration into nested repos) is deferred; operators must deinitialise submodules before running the harness.

- **Stale git index causes cryptic snapshot failures** — `snapshot_enumerate_files` enumerates files via `git ls-files` against the current index. If tracked files have been deleted from disk but not staged for removal (`git rm`), `snapshot_copy_files` will fail with `cp: cannot stat`. Fix with `git rm --cached <file>` followed by a commit. A future hardening pass should add existence validation in `snapshot_enumerate_files` to produce a clear error rather than a mid-pipeline `cp` failure.

- **Bad diff applied to host repo corrupts future snapshots** — `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`, so a bad run cannot corrupt the host repo during execution. The risk is after the operator applies a bad diff — the host repo is then in a bad state and future snapshots reflect it. See [Recovery](#recovery) in `docs/development/quickstart.md` for how to reset to a known-good state.

---

### Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 — Structural Separation — folder ownership, temperature classification, root document audience separation
- [ ] Level 2 — Review Discipline — PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 — Temperature & Freeze Policy — hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 — Change Classification Matrix — explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 — Automated Enforcement — CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents
