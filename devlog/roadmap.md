# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules — task granularity, cleanup on completion, section removal — are defined in [`docs/operations/roadmap_policy.md`](../operations/roadmap_policy.md).

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
| M2.2 — Reasoning Layer Modularisation | [Complete — see changelog](changelog.md) |
| M2.3 — Apply Workflow: Capability Layer Diff Pipeline | [Complete — see changelog](changelog.md) |
| [M2.4 — Session and Config Persistence](#m24--session-and-config-persistence) | Complete |
| [M2.5 — Vault Capability Layer Prototype](#m25--vault-capability-layer-prototype) | Deferred — see M2.5 section |
| M2.6 — Session Resume Across Provider Implementations | Not started |
| M2.7 — Session Identity and Harness Versioning | Active |
| **Single-Agent Coordination** | |
| [M3 — Autonomous Task Execution, Manual Review Workflow](roadmap_future.md#m3--autonomous-task-execution-manual-review-workflow) | Not started |
| **Multi-Agent Coordination** | |
| [M4 — Metadata Seeding](roadmap_future.md#m4--metadata-seeding) | Not started |
| [M5 — Agent-Assigned Branch Management](roadmap_future.md#m5--agent-assigned-branch-management) | Not started |
| **Multi-Agent Orchestration** | |
| [M6.1 — Task Dispatch](roadmap_future.md#m61--task-dispatch) | Not started |
| [M6.2 — Constraint Enforcement](roadmap_future.md#m62--constraint-enforcement) | Not started |
| [M6.3 — Review & CI/CD Integration](roadmap_future.md#m63--review--cicd-integration) | Not started |

---

## User Stories

Open stories under active investigation. Closed stories are removed from this list.

- [`story_prompt_evals.md`](docs/discussions/story_prompt_evals.md) — How do we test that skills and prompt templates correctly reflect the policy documents they encode? Manual read-through comparison doesn't scale across N skills × M policy sections.
| **Standalone** | |
| [M7 — Safe vs Unsafe Mode (Policy Layer)](roadmap_future.md#m7--safe-vs-unsafe-mode-policy-layer) | Not started |
| [M8 — Skills / Templates](roadmap_future.md#m8--skills--templates) | Not started |

---

## Upcoming Milestones

### M2 — Reasoning/Capability Layer Separation

**Objective:** Separate the harness into a reasoning layer (agent container) and a capability layer (sandbox container, working content, optional MCP server). This is the foundational architectural change that enables vault workflows, webapp workflows, provider swapping, and autonomous task execution. All M1.x architecture documents are hot during this milestone and updated sub-milestone by sub-milestone.

Conceptual model: [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md)
Design rationale: [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md) — Conclusion

#### M2.4 — Session and Config Persistence

**Objective:** Establish the provider config lifecycle — onboarding-time population, seeding of provider-layer prompts/skills, and session history persistence — ensuring state survives between container restarts across all host filesystem types.

**Work completed:**
- Directory bind mount (M2.7) — session history persists via `sessions/` bind mount; `bin/` cross-device mv issue resolved by owning the directory in the image (see `providers/pi/provider.Dockerfile`) rather than tmpfs, which was removed for simplicity
- Provider-layer prompts/skills seeded from `providers/<n>/config/agent/` via onboarding
- Auth tokens stored as env var references in `auth.json` (ephemeral by design — security feature, prevents write-back of secret values)
- Selective bind mount pattern (`sessions/`, `prompts/`, `skills/` persisted; remaining config ephemeral via copy-in) — resolution for cross-filesystem `utime()`/`EPERM` issue on macOS/Windows Docker Desktop

**Status:** Complete. Design settled; implementation artifacts applied (M2.7+). See handovers `20260407-03-close-m2_4.md`, `20260513-10-impl-settings_json_collision_fix.md`, `20260522-05-design-pi_agent_mount_strategy.md`.

**Scope note:** M2.4 covers config and state persistence infrastructure. It does not define or validate provider-level session resume — the ability to continue a prior conversation. That is scoped to M2.6.

#### M2.5 — Vault Capability Layer Prototype

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first, then add MCP server as enhancement. Unblocks KV5.

**Depends on:** M2.1, M2.2, M2.3. **Status:** Deferred.

**Scope:** Validate vault workflow with sandbox-only configuration. Evaluate and select MCP server candidate. Build vault capability layer image. Validate binary file handling and KV5 end-to-end.

All tasks are shelved. Re-activate when KV5 timeline demands it.

**Tasks:**

- [ ] Validate vault workflow with sandbox-only configuration: agent accesses vault files directly via `sandbox/`, diff reviewed and applied to vault repo
- [ ] Evaluate MCP server candidates; select one (criteria: licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency — see [`investigation_mcp_server.md`](docs/discussions/investigation_mcp_server.md) candidates table)
- [ ] Build vault capability layer image: extends base capability layer image, adds selected MCP server
- [ ] Configure OpenCode to connect to MCP server; validate it routes vault operations through MCP tools when server is present
- [ ] Validate binary file handling (vault attachments) under selected MCP server
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to vault repo
- [ ] Update `execution_model.md` — document capability layer variants (general vs vault+MCP)

#### M2.6 — Session Resume Across Provider Implementations

**Objective:** Define and implement true session persistence — the ability to resume a prior conversation — for each supported provider. M2.4 established that state survives between sessions; M2.6 defines what resuming that state actually means per provider and how the harness supports it.

**Depends on:** M2.4. **Scope:** Investigation-first. Characterise session file format, export mechanism, and resume invocation for pi, Hermes, and opencode. Design harness support based on findings. Known starting points:

- **pi**: requires explicit `pi export` to write session files; resume requires session ID and specific invocation flags. Neither is currently triggered or passed by the harness.
- **Hermes**: assumed to live-load conversation history from home directory on startup — not validated.
- **opencode**: session persistence mechanism unknown. Requires investigation before any design work.

Each provider may result in a different integration pattern. Investigation findings should be recorded as named investigation documents before implementation begins.

**Related story:** [`story_agent_state_persistence.md`](docs/devlog/discussions/story_agent_state_persistence.md) — Agent state under AGENT_HOME must survive across container restarts. The bind mount approach fails on cross-filesystem mounts (utime/EPERM). Defines the persistence model that M2.6's session resume mechanism depends on.

#### M2.7 — Session Identity and Harness Versioning

**Objective:** Establish a stable, content-addressed identity model for sessions, containers, and the harness itself — eliminating stale image regressions, timestamp drift, and the lack of provenance tracing for session artefacts.

**Depends on:** M2.3. **Status:** Active.

**Design reference:** [`devlog/discussions/design_session_identity_hash_based.md`](devlog/discussions/design_session_identity_hash_based.md)

**Scope:** Implement the hash-based session identity model, two-sig model, container lifecycle redesign, and build pipeline cleanup. Items restructured per planning session 20260513-11.

---

### Track A — Container Identity & Lifecycle

- [x] **SANDBOX_ID and RUN_ID derivation** — Add `SANDBOX_ID = sha256(SANDBOX_DIR:HOST_HEAD_SHA)[:8]` and `RUN_ID = sha256(SESSION_TS:SANDBOX_ID)[:6]` to `scripts/start_agent.sh`. Rename `REPO_COMMIT` → `HOST_HEAD_SHA`. Remove `WORKTREE_ID` and `worktree_id_derive()`. Add `{{RUN_ID}}` and `{{HOST_HEAD_SHA}}` substitutions to `libs/compose.sh`. Depends on: nothing.
- [x] **Image naming** — `sandbox_image_name()` and `agent_image_name()` use project name only (no `SANDBOX_ID` suffix). Images are tagged by harness code identity, not project repo state. Provenance is carried by Docker labels, not tags. This item is design-validation only — no code change needed.
- [x] **Container naming with RUN_ID** — Container names use `RUN_ID` instead of `SESSION_TS`. Format: `sandbox-<project>-<RUN_ID>`, `<provider>-<project>-<RUN_ID>`. Depends on: item 1.
- [x] **Docker labels** — Add `agent-sandbox.project-name`, `agent-sandbox.sandbox-dir`, `agent-sandbox.host-head-sha`, `agent-sandbox.host-branch`, `agent-sandbox.session-ts`, `agent-sandbox.run-id` to `x-session-labels`. Depends on: item 1.
- [x] **SESSION_STATE** — Write `host_head_sha` to SESSION_STATE alongside `init_sha` and `session_ts` in `src/capability/snapshot.sh`. Depends on: item 1.
- [x] **make stop redesign** — Filter by `project-name` + `sandbox-dir` labels (default), with optional `--run-id` for run-specific stop and `--prune` for post-stop cleanup. Depends on: item 4.
- [x] **make prune** — New script: targeted cleanup scoped to project + sandbox instance. Age threshold: `PRUNE_AGE_DAYS=3` (hardcoded variable at top of script). Covers containers, images, volumes uniformly. CLI dispatch in agent-sandbox.sh. Makefile target. Depends on: item 6.
- [x] **Artefact paths** — Session export: `<SESSION_TS>-<BRANCH>-<RUN_ID>`. Output export: replace optional `SESSION_TS` suffix with `RUN_ID`. Draft branch: `draft/<RUN_ID>-<BRANCH_SLUG>-<FROM_SHA:0:6>`. Depends on: item 1.

### Track B — Build Pipeline & Staleness Detection

- [ ] Context_dir removal — Remove `build_context_*` and `build_image`. Use repo root as build context. Replace ~47 tests in `test_build_context.sh` with COPY contract tests. Depends on: nothing.
- [ ] Two-sig model — Container-sig: hash `/opt/sandbox/` + `/opt/workflow/` at build time, baked as Docker label, checked at preflight. Depends on: item 7.
    - Harness-sig: deferred to `roadmap_future.md`.

---

- [x] Settings.json ownership collision fix — Provider config lifecycle established: `agent/` directory bind mount replaces `/opt/provider-config`; `_ensure_harness_keys` handles pre-flight settings merge; `PROVIDER_CONFIG_DIR` removed from all provider Dockerfiles.
- [x] Session-diffs persistence + dry-run seam — Session-diffs path resolution aligned between compose template and runtime; `diff_export` returns error codes; `package_branch.sh` added to sandbox image; commit messages embedded in diff filenames.
- [x] Workspace path resolution refactor — Workspace paths unified under `x-workspace` anchor; `libs/dirs.sh` retired from production code; `SESSION_STATE` written on container init. Design document: [`design_workspace_path_resolution.md`](../discussions/design_workspace_path_resolution.md). Not in scope: SESSION_STATE append semantics fix (deferred to M2.6).
- [ ] Dual-layer seam testing — Full dry-run pipeline asserting host-container seam in both layers.
    - [x] Core mechanism — Capability-layer checks, pre-flight verification, dry-run rewrite, and host-side assertion pipeline.
    - [ ] Subsume docker-dependent tests from `test_capability_layer.sh` — Migrate remaining checks; deprecation notice.
- [ ] AGENTS.md injection cleanup — Brief.md injection removed; pre-flight checks updated.
    - [x] Remove redundant brief.md injection.
    - [x] Update pre-flight checks for `sandbox/AGENTS.md` and `AGENT_HOME/AGENTS.md`.
    - [x] Provider-specific pre-flight hook — Source provider-specific check script at startup, before agent runs.
    - [x] Audit shared reasoning layer for Pi-specific logic — 6 shared libs audited; only `provider-entrypoint.sh` has Pi-specific logic (now provider-aware). Compose template has hardcoded Pi paths (lines 102, 106) — deferred (outside pre-flight scope).
    - [x] Design hook mechanism — Convention: `/opt/sandbox/bin/provider-preflight.sh` (fixed name); sourced by shared entrypoint if present. Staged by `build_context_agent`; file exists only if provider defines one.
    - [x] Implement hook in `provider-entrypoint.sh` — Source provider pre-flight script after generic preflight, before agent runs.
    - [x] Move `_ensure_harness_keys` from shared entrypoint to Pi-specific preflight — Extracted merge logic into `providers/pi/preflight.sh`; staged as `provider-preflight.sh` in build context.
    - [x] Add warn-on-skip and verify-keys-after-merge to Pi preflight — Proposals 1 and 2 from session findings. Both in `providers/pi/preflight.sh`.
    - [ ] Add generic pre-flight validation to shared entrypoint — Validate AGENT_HOME bind mount, critical file presence (Proposal 3).
    - [x] Rename knowledge test — `knowledge_provider_config_cycle.sh` → `knowledge_pi_config_cycle.sh`; remove old copy-in/copy-out tests, add merge test (Proposal 4).
- [ ] Autosave and session-save reliability — Autosave subshell has no resilience; EXIT trap discards `diff_export` return value. Scope permanent solution — test save behaviour within dry-run.
- [ ] Makefile variable or CLI flag for diff type — Add `DIFF_TYPE` variable for non-interactive `make apply`.
- [ ] Git diff `--no-renames` index conflict — `git diff --no-renames` produces `new file mode` entries for rename targets that already exist in the index, which `git apply` rejects. A proper fix (e.g. generating `diff --git` entries instead of `new file mode` across rename boundaries) is needed for the `--no-renames` fallback path in `package_branch`. Limitation documented in `story-patch_application_failures.md` §Finding 2.

### Process Improvements (from dispatch refactoring learnings)

- [ ] Add fast-track criteria for chore/mechanical sessions — Gate 2 can be collapsed for purely mechanical changes (guard pattern hardening, `set -euo pipefail` cleanup). Document in `iteration_policy.md`.
- [ ] Record decision rationale inline during sessions — Update `handover_policy.md` to recommend updating the Decisions table as decisions are made, not only at close.
- [ ] Remove `subagent_type=Explore` reference from `improve-codebase-architecture` skill — The tool does not exist in this harness.

### Track C — Universal Bind Mount Permission Strategy (UID Mapping)

**Design reference:** [`docs/devlog/discussions/design_settings_permissions_group_bind.md`](../discussions/design_settings_permissions_group_bind.md)
**Container layer spec:** [`docs/devlog/discussions/spec_container_layer_redesign.md`](../discussions/spec_container_layer_redesign.md)

- [x] Design session and surface area scoping (2026-05-23)
- [x] Onboard.sh control flow refactor, tests, hardening (2026-05-23)

**Implementation phases (each produces a self-contained commit):**

#### Phase 1 — Build pipeline threading (no behaviour change)

- [ ] `libs/build.sh` — `build_sandbox()` and `build_agent()` accept `--uid`/`--gid` flags
- [ ] `scripts/start_agent.sh` — export `HOST_UID=$(id -u)` / `HOST_GID=$(id -g)`
- [ ] `scripts/run_agent.sh` — propagate host IDs to compose generation

No behaviour change until Phase 2 consumes the values.

#### Phase 2 — Dockerfiles + compose (both paths functional)

- [ ] 3 harness Dockerfiles: add `ARG HOST_UID=1000` / `ARG HOST_GID=1000`, UID collision handling via `usermod` rename, numeric `chown -R ${HOST_UID}:${HOST_GID}`
    - [ ] `libs/Dockerfile.harness-node` (or `harness/reasoning/nodes/node.Dockerfile` per chore session)
    - [ ] `libs/Dockerfile.harness-python` (or `harness/reasoning/nodes/python.Dockerfile` per chore session)
    - [ ] `libs/sandbox.Dockerfile` (unchanged layer position)
- [ ] `libs/docker-compose.yml`: add `user: "${HOST_UID:-1000}:${HOST_GID:-1000}"` to both services
- [ ] Compose convention: only the base compose template sets `user:`. Verify provider compose overlays don't set `user:`.

At this point both UID Mapping and ACL paths are functional — rollback-safe.

#### Phase 3 — Onboard cleanup + ACL removal (after verification)

Only once UID Mapping is verified (build + test on WSL, macOS, Windows DD):

- [ ] `scripts/onboard.sh`: remove `setfacl` lines from `_run_onboard()` and `_provision_providers()`
- [ ] `providers/pi/onboard.sh`: no permission-fixing code (already clean; verify)
- [ ] `tests/test_onboard.sh`: remove `CAN_RUN_FULL` guard (setfacl no longer needed)
- [ ] Documentation updates per design doc §4.5 (quickstart, security.md, execution_model.md, Dockerfile headers, compose header)

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

- **Bad diff applied to host repo corrupts future snapshots** — `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`, so a bad run cannot corrupt the host repo during execution. The risk is after the operator applies a bad diff — the host repo is then in a bad state and future snapshots reflect it. See [Recovery](#recovery) in `docs/development/quickstart.md` for how to reset to a known-good state.

- **`make start opencode` and `make start hermes` do not share a capability layer** — each provider invocation builds and runs its own capability layer image independently. They should share a single capability layer per project, since the sandbox, snapshot pipeline, and diff pipeline are provider-agnostic. This is a known architectural gap; resolving it requires the capability layer build and lifecycle to be fully decoupled from the provider selection path. The image rename in M2.7 (dropping the `<project>` suffix) is a prerequisite step toward this.

- **Multi-service project composition not supported** — projects that run multiple services (e.g. a web app with a database and test containers) have no mechanism to inject additional services alongside the harness-managed sandbox and agent. A deferred design task is to define a composition method — likely an operator-supplied overlay that `start_agent.sh` merges with the generated base — that lets projects define their own containers without forking the harness template. See `execution_model.md` for the deferred discussion.

### Deferred (not milestone-scoped)

- **Docs restructuring investigation** — The docs/ directory currently mixes architecture/concepts/operations/development/ discussions/devlog into a single tree. Architecture and concepts docs are baked into container images; operations and development docs are coding-agent workflow artifacts that should logically live in a separate namespace. Investigation deferred — no immediate use case warrants it, and the current layout is functional.

- **`docker compose down -v` race with EXIT trap** — When `stop.sh` runs `docker compose down -v`, the `-v` flag removes anonymous volumes referenced by `volumes_from`. If Docker Compose removes those before the sandbox container's EXIT trap finishes writing the session export, the export could be interrupted. Triaged as a plausible error but unlikely to be causing current problems — session-diffs are a bind mount (not affected by `-v`), and anonymous volume references on the agent service do not block the sandbox trap. Recorded for completeness from handover audit finding F3. No milestone assigned.

### Addressed in upcoming milestones

- **Stale container images** *(M2.7)* — M2.7 introduces `container-sig` (hash of `/opt/sandbox/` + `/opt/workflow/` at build time, baked as Docker label) checked at preflight with a warning. See [`devlog/discussions/design_session_identity_hash_based.md`](devlog/discussions/design_session_identity_hash_based.md).

- **Host-side harness staleness** *(deferred)* — after `git pull`, the installed `agent-sandbox` CLI may silently execute changed scripts/libs from the repo checkout. `container-sig` does not detect this (it detects image staleness, not CLI staleness). A self-contained binary with semantic versioning is needed to close this gap. Scoped as a standalone future milestone in [`roadmap_future.md`](roadmap_future.md) §Harness Packaging and Versioning.
