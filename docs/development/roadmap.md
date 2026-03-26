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

**Objective:** Extract shared harness logic from OpenCode-specific scripts so that any reasoning layer provider can be added without rewriting shared infrastructure.

**Depends on:** M2.1. **Scope:** Move `start_agent.sh` to `scripts/` as the provider-agnostic entry point. Define the provider interface (`build.sh` and `run.sh` under `providers/<name>/`). Rename `build_agent.sh` to `build.sh`. Validate OpenCode conforms. Base image split and Claude Code/Desktop provider integrations are deferred.

**Design decisions:**
- `scripts/start_agent.sh` is the provider-agnostic entry point: pre-flight, `.env` loading, snapshot pipeline, brief resolution, then dispatches to `providers/<name>/run.sh`. All harness-level checks run here once; provider scripts receive exported env vars and do not re-derive paths or image names. Rationale: isolates harness concerns from provider invocation; a second provider sources the same pre-flight by calling `start_agent.sh`.
- Provider interface is `build.sh`, `run.sh`, `docker-compose.serve.yml`, and `.env.example` under `providers/<name>/`. Each is independently managed. `start_agent.sh` calls only `run.sh`; the operator calls `build.sh` explicitly via `make build`. Rationale: build and run have different trigger points; no wrapper needed.
- `providers/opencode/build_agent.sh` renamed to `providers/opencode/build.sh`. Rationale: aligns with provider interface naming; no functional change.
- `scripts/build_sandbox.sh` unchanged. Rationale: already at correct location; capability layer build is project-controlled via `Dockerfile.sandbox` in `SANDBOX_DIR`.
- Serve overlay moves to `providers/<n>/docker-compose.serve.yml` — static file in repo, not copied to `SANDBOX_DIR`. Rationale: provider-specific; no project-specific values; operator never manages it.
- Provider `.env` stubs sourced from `providers/<n>/.env.example` — iterated by `onboard.sh` at onboard time. Rationale: adding a provider requires no changes to `onboard.sh`.
- `onboard.sh` has no `--provider` flag — onboarding is project setup, provider selected at run time. Rationale: clean separation of concerns.
- Provider selection via Make variables (`PROVIDER=hermes`) not trailing words. Rationale: idiomatic Make; no goals-string parsing needed.
- `--rebuild` is a flag on run targets (`REBUILD=1`), not a separate subcommand. Rationale: scoped to containers required for the run target; simpler command surface.
- `build` with no `PROVIDER` iterates `providers/*/build.sh` glob. Rationale: adding a provider requires no changes to `agent-sandbox.sh`.
- `make build-all`, `make build-sandbox`, `make build-agent` removed — superseded by `make build PROVIDER=<n>`.
- Hermes is the one additional provider for M2.2. Pi and Claude Desktop remain informal future candidates, not committed roadmap items.
- Base image split deferred. BuildKit layer cache sufficient for reasoning layer builds. Revisit if operators report slow builds.
- `dirs.sh` unchanged. Removing it would break the host/container sync contract for `dry_run.sh`.
- Mode vocabulary (`standard`, `dry-run`, `serve`) standardised in harness docs. Each provider declares supported modes in `run.sh` and errors clearly on unsupported mode. `start_agent.sh` passes mode through without validating it.
- `container-entrypoint.sh` was deleted in M2.1 — audit task is resolved; no action.
- Checkpoint scripts in `workflow/knowledge-vault/scripts/` deferred — integration testing against a non-vault workflow required before promotion.

**Tasks:**

### Documentation
- [x] Update `docs/architecture/execution_model.md` — provider interface section; `scripts/start_agent.sh` path references; `providers/<n>/run.sh` reference
- [x] Update `docs/architecture/tool_interface.md` — execution modes section; path references; corrected command shapes; container naming table; corrected `.env` table
- [x] Define conforming provider interface in `execution_model.md`

### Shared logic extraction
- [x] Move `providers/opencode/start_agent.sh` to `scripts/start_agent.sh`; strip compose block; dispatch to `providers/opencode/run.sh`
- [x] Create `providers/opencode/run.sh`
- [x] Rename `providers/opencode/build_agent.sh` to `providers/opencode/build.sh`

### Container lifecycle library
- [x] Create `libs/containers.sh` — image/container naming, build helpers, preflight
- [x] Update `scripts/agent-sandbox.sh` — `--rebuild` flag; no default provider; `build` iterates providers glob; `require_run_args`/`rebuild_if_requested` helpers; `rebuild` subcommand removed
- [x] Update `libs/_templates/docker-compose.yml.template` — `OPENCODE_SERVER_PASSWORD` removed from agent environment block; `container_name` pinned to image name

### Provider interface validation
- [x] Validate OpenCode provider conforms: `make dry-run PROVIDER=opencode` passes after refactor

### Refactoring
- [x] `onboard.sh` — provider-agnostic; iterates `providers/*/env.example` for `.env` stubs; no `--provider` flag
- [x] `scripts/start_agent.sh` — pass required variables as explicit args to `run.sh` instead of exporting `.env` variables into the environment
- [x] `scripts/agent-sandbox.sh` — `PROVIDER=` Make variable; `REBUILD=1` flag; build iterates providers glob

### Compose template refactor
- [x] Move serve overlay to `providers/<n>/docker-compose.serve.yml` — static file in repo, not generated into `SANDBOX_DIR`; `providers/opencode/run.sh` updated to reference it from `$SCRIPT_DIR/`
- [x] Delete `libs/_templates/docker-compose.serve.yml.template`
- [x] Create `providers/opencode/docker-compose.serve.yml` — OpenCode serve overlay with `OPENCODE_SERVER_PASSWORD`
- [x] Create `providers/opencode/.env.example` — `OPENCODE_SERVER_PASSWORD=` stub

### Hermes provider integration
- [x] Create `providers/hermes/Dockerfile` — Hermes image; `terminal.backend: local` set in config at build time
- [x] Create `providers/hermes/build.sh` — provider interface
- [x] Create `providers/hermes/run.sh` — `standard`, `dry-run`, `serve` modes
- [x] Create `providers/hermes/docker-compose.serve.yml` — Open WebUI companion service
- [x] Create `providers/hermes/.env.example` — placeholder
- [ ] Validate: `make dry-run PROVIDER=hermes` passes
- [ ] Validate: `make serve PROVIDER=hermes` launches Open WebUI

### Deferred breakdown
- [ ] Claude Desktop provider integration — investigation resolved; viable pending prototype; full task list at implementation time
- [ ] Pi provider integration — investigation resolved; `start`, `dry-run` supported; `serve` unsupported (RPC bridge is a future path); full task list at implementation time
- [ ] Open WebUI ↔ Hermes API connection in serve mode — serve overlay launches Open WebUI but connection to Hermes backend needs follow-up once Hermes API surface is confirmed

**Acceptance criteria:**
- `make dry-run PROVIDER=opencode` passes after refactor
- `make dry-run PROVIDER=hermes` passes
- `make serve PROVIDER=opencode` resolves serve overlay from `providers/opencode/` (not `SANDBOX_DIR`)
- `agent-sandbox onboard` produces `.env` with stubs from all `providers/*/env.example`; no `docker-compose.serve.yml` in `SANDBOX_DIR`
- `make build PROVIDER=hermes` builds `hermes-agent-<project>` image
- `make build` builds sandbox + all providers
- A second provider can be added under `providers/<n>/` with `build.sh`, `run.sh`, `docker-compose.serve.yml`, `.env.example` — no changes to `scripts/` or `libs/` required
- `scripts/start_agent.sh` contains no compose invocation; all compose calls are in `providers/<n>/run.sh`

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