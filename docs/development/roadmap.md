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
| M2.1 — General Capability Layer Prototype | [Complete — see changelog](changelog.md) |
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

#### M2.2 — Reasoning Layer Modularisation

**Objective:** Extract shared harness logic from OpenCode-specific scripts so that any reasoning layer provider can be added without rewriting shared infrastructure. Introduce a base reasoning image that amortises slow build steps across all projects.

**Depends on:** M2.1. **Scope:** Audit and split `start_agent.sh` and `container-entrypoint.sh` into shared libs vs provider-specific invocation. Document execution modes formally. Define conforming provider interface. Validate OpenCode conforms. Claude Code provider integration deferred until shared logic extraction is complete and [`investigation_claude_code.md`](../discussions/investigation_claude_code.md) open questions are resolved.

**Base reasoning image:** Extract slow layers from the reasoning layer Dockerfile into a shared `opencode-base` image (apt-get, npm install, useradd). Per-project reasoning images use `FROM opencode-base` and only add `COPY context/` + `ENTRYPOINT` — making per-project builds near-instant. Base image is built once per host and rebuilt only when opencode-ai or system packages change. M2.1 constraint: reasoning layer Dockerfile must not bake in project-specific content (already enforced — recorded in M2.1 decisions).

**Deferred from M2.1:**
- Modularise `start_agent.sh` across providers
- Decouple agent-sandbox's own sandboxing from tool implementation (`make install` vs `make start`)

**Tasks:**

### Shared logic extraction
- [ ] Audit `providers/opencode/start_agent.sh` — extract shared logic (snapshot, mount construction, env loading, container lifecycle) into `libs/`; leave only OpenCode-specific invocation
- [ ] Audit `container-entrypoint.sh` — extract shared startup sequence into sourced lib; leave only provider exec step; move from `providers/opencode/` to `libs/` or shared location
- [ ] Evaluate checkpoint scripts in `workflow/knowledge-vault/scripts/` for promotion to `scripts/` as first-class harness tooling; integration testing against at least one non-vault workflow required before treating as general infrastructure

### Provider interface
- [ ] Document execution modes formally in `execution_model.md`: `serve`, `start`, `dry-run`, `headless` (reserved)
- [ ] Define what a conforming reasoning layer provider must supply: mode support declarations, container config
- [ ] Validate OpenCode provider conforms after refactor

### Base image
- [ ] Extract slow layers (apt-get, npm install, useradd) from `providers/opencode/Dockerfile` into a shared `opencode-base` image
- [ ] Update per-project reasoning layer Dockerfile to `FROM opencode-base`; verify per-project builds are near-instant after base image is built
- [ ] Document base image build and rebuild workflow in `quickstart.md`

### Deferred breakdown
- [ ] Claude Code provider integration — full task list after M2.2 shared logic extraction is complete and [`investigation_claude_code.md`](../discussions/investigation_claude_code.md) open questions are resolved
- [ ] Claude Desktop provider integration — full task list after M2.2 shared logic extraction is complete and [`investigation_claude_desktop.md`](../discussions/investigation_claude_desktop.md) open questions are resolved

**Acceptance criteria:**
- `make build agent` completes in under 10 seconds for a project after `opencode-base` is built on the host
- A second provider can be added by creating `providers/<name>/` with a Dockerfile and mode support — no changes to shared libs required
- OpenCode provider passes `make dry-run` after refactor

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