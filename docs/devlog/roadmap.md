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

**Objective:** Establish the provider config lifecycle — onboarding-time population, copy-in at session start, copy-out at session end — replacing the implicit image-baking convention with an explicit bind-mount model.

**Depends on:** M2.2. **Status:** Complete. Design settled; implementation artifacts applied. Copy-out workflow validated (normal exit + SIGTERM). Acceptance criteria met — see handover `20260407-03-close-m2_4.md`.

**Scope note:** M2.4 established the infrastructure for state to survive between sessions (home directory bind mount, config copy-in/out). It does not define or validate provider-level session resume — the ability to continue a prior conversation. That is scoped to M2.6.

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

#### M2.7 — Session Identity and Harness Versioning

**Objective:** Establish a stable, content-addressed identity model for sessions, containers, and the harness itself — eliminating stale image regressions, timestamp drift, and the lack of provenance tracing for session artefacts.

**Depends on:** M2.3. **Status:** Active.

**Design reference:** [`docs/discussions/design_session_identity_hash_based.md`](docs/discussions/design_session_identity_hash_based.md)

**Scope:** Implement the hash-based session identity model, two-sig model, container lifecycle redesign, and the settings.json ownership collision fix originally designed under M2.5. Work falls into the following groups:

**1. run_id derivation** (`scripts/start_agent.sh`): Add `RUN_ID` as 6-char hex hash of `${SESSION_TS}:${REPO_COMMIT}:${WORKTREE_ID}`. Replace timestamp-based container naming with run_id-based naming (`sandbox-<project>-<runid>`, `<provider>-<project>-<runid>`).

**2. Docker labels** (`libs/docker-compose.yml`): Add `agent-sandbox.project`, `agent-sandbox.worktree-id`, `agent-sandbox.run-id` labels for container lifecycle management. Retain `agent-sandbox.session-name` for backwards compatibility.

**3. make stop redesign** (`scripts/stop.sh`): Update to filter containers by `project + worktree-id` labels instead of Docker Compose project name. Enables parallel sessions from different worktrees without container collision.

**4. make prune implementation** (`scripts/prune.sh`, `libs/_templates/Makefile.template`): Add `make prune` target with:
   - Targeted cleanup: `project + worktree-id` (same scope as stop)
   - Time-based cleanup: `project + >3 days old` (ignores worktree-id)
   - Cleans: build cache, layer cache, system cache, volume cache

**5. Two-sig model** (`libs/containers.sh`, `scripts/start_agent.sh`): container-sig = hash(libs/ + providers/<n>/base.Dockerfile + providers/<n>/provider.Dockerfile) baked as Docker label agent-sandbox.container-sig at build time, checked at preflight — mismatch triggers rebuild; harness-sig = hash(scripts/ + providers/<n>/setup.sh + providers/*.yml + providers/<n>/*.yml) computed at runtime, compared against SANDBOX_DIR/.harness-sig.ref written at session end — mismatch warns only.

**6. Paired refactor** (`libs/`, `providers/`): move libs/docker-compose.yml and libs/docker-compose.dry-run.yml into providers/ so the harness-sig hash boundary matches the folder boundary. Image rename dropping <project> suffix (sandbox, <provider>-agent) — blocked on prerequisite code review: verify agents.md is not COPY-ed in any provider Dockerfile before proceeding.

**Sub-stories:**

- `story_parallel_sessions_worktree.md` — Resolved. WORKTREE_ID and checkpoint tag namespace implemented in M2.3 Change 1. Container naming updated in M2.7.
- `story_harness_packaging_and_install_versioning.md` — install workflow rewrite; deferred, does not block this milestone.

**7. Context_dir removal** (`libs/containers.sh`, `libs/sandbox.Dockerfile`, `providers/*/provider.Dockerfile`, `tests/test_build_context.sh`):
Remove `build_context_sandbox`, `build_context_agent`, and `_build_context_copy` from `libs/containers.sh`. Once container-sig (item 5) hashes source files at repo-root paths, the temp-directory staging layer is dead code. Pre-scoping findings:

   - **Dead digest pipeline**: `build_image()` computes a digest of context_dir contents and bakes it as `agent-sandbox.digest` Docker label. No code anywhere reads this label back — the stale-detection read side was never implemented (M1.4 design was write-only). The label is metadata residue.
   - **Known drift — package_branch.sh**: `sandbox.Dockerfile` COPYs `package_branch.sh` into the image, but `build_context_sandbox()` does not stage it into the context. Fresh `make build sandbox` would fail with `COPY failed: file not found`. (Reverse in agent build: `package_branch.sh` IS staged but never COPY'd by any `provider.Dockerfile` — harmless waste.)
   - **Dual-maintenance surface**: Adding a file to an image requires edits in both the `build_context_*` file list and the Dockerfile COPY stanza. No cross-reference or test catches drift.
   - **Dogfooding constraint**: Can't naively switch to `$repo_root` as build context because that sends the entire project tree (including tests/, docs/, .git/) to the Docker daemon, busting cache on irrelevant changes. The focused-context behaviour must be preserved — either via `.dockerignore` or by inlining the file list directly in the build caller.
   - **Test file impact**: `tests/test_build_context.sh` (~47 tests) tests context_dir population and digest determinism. It must be either deleted or rewritten to test Dockerfile-based file selection instead.
   - **`_build_context_copy`**: A 5-line wrapper over `cp` that checks source-file existence. Existence failures are already caught at Docker build time (COPY fails on missing source). The check adds no coverage beyond Docker's native behaviour.
   - **Agent context files are also staged for base image builds** (`build_container.sh` line ~70): `build_context_agent` creates a context that is used for both the base image build and the provider image build. The base Dockerfile (`base.Dockerfile`) has no COPY commands — it ignores the context entirely. This is wasteful but harmless (context is small). Worth verifying on removal that the base image doesn't accidentally depend on context files.

**8. Settings.json ownership collision fix** (`libs/provider-entrypoint.sh`, `libs/docker-compose.yml`, `scripts/run_agent.sh`, `providers/pi/config/agent/settings.json`, `providers/pi/provider.Dockerfile`):
Implement the settled design from `docs/devlog/discussions/design_provider_config_ownership_and_loading.md`:

   - Replace `/opt/provider-config` bind mount with `agent/` directory bind mount, `bin/` tmpfs, and `/opt/workflow-host/` mounts for skills/prompts.
   - Remove `_copy_in` and `_copy_out` from `libs/provider-entrypoint.sh`; add `_ensure_harness_keys` (Node.js pre-flight merge).
   - Pre-create `agent/sessions` in `scripts/run_agent.sh` before compose generation.
   - Update `providers/pi/config/agent/settings.json`: add `"packages"` key and `/opt/workflow-host/` paths to `skills`/`prompts` arrays.
   - Verify `provider.Dockerfile` does not COPY `agent/skills/` or `agent/prompts/` (those are now bind-mounted).

**9. Host-container seam testing via dry-run + session-diffs persistence fix** (`scripts/dry_run.sh`, `scripts/dirs.sh`, `libs/docker-compose.yml`, `libs/routing.sh`, `libs/package_branch.sh`):
Fix the session-diffs path resolution mismatch between compose template and `dirs.sh`, then add dry-run tests that assert the host-container seam is intact:

   - **session-diffs persistence fix**: resolve the destination path mismatch between the compose bind mount (`workspace/session-diffs`) and `dirs.sh` resolution (`session-diffs`). Ensure diffs written by sandbox-entrypoint land in the tree `routing.sh` reads from.
   - **dry-run as seam test staging ground**: add a block in `dry_run.sh` that tests the session-diffs path round-trip — write a test diff, verify it appears at the expected host-relative path, read it back.
   - **commit message capture**: extend `package_branch.sh` to embed the commit subject in the diff filename (e.g. `0001-<sha>-<subject>.diff`) or in a companion manifest. Extend the session-diffs pipeline to store commit messages alongside diffs.

**10. Workspace path resolution refactor** (`libs/docker-compose.yml`, `libs/dirs.sh`, `libs/sandbox-entrypoint.sh`, `scripts/start_agent.sh`, `scripts/dry_run.sh`, `libs/routing.sh`, `libs/interactive_session_select.sh`, `scripts/agent-sandbox.sh`, `tests/`):
Unify all workspace path definitions under a single `x-workspace` anchor in the compose template. Retire `libs/dirs.sh` from production code. Write paths to `SESSION_STATE` on container init so consumers read deterministically.

   Design document: [`docs/devlog/discussions/design_workspace_path_resolution.md`](../discussions/design_workspace_path_resolution.md)

   - Add `x-workspace` anchor to `libs/docker-compose.yml` with host/container path pairs.
   - Export host paths in `scripts/start_agent.sh` (no more `dirs_resolve`).
   - Update compose template: replace `_NAME` env vars with absolute path vars; volumes reference anchor values.
   - Update `libs/sandbox-entrypoint.sh`: remove `dirs.sh`, write paths to `SESSION_STATE` after init.
   - Update `scripts/dry_run.sh`: remove `dirs.sh`, read paths from env vars (baked at compose gen time).
   - Update `libs/routing.sh` and `libs/interactive_session_select.sh`: replace `dirs_resolve` with SESSION_STATE reads.
   - Update `scripts/agent-sandbox.sh`: host-side subcommands read from `SESSION_STATE`.
   - Update tests to match new path sources.
   - Create `tests/knowledge/knowledge_workspace_paths.sh` asserting cross-context path agreement.

   **Not in scope:** SESSION_STATE append semantics fix (deferred to M2.6). The sandbox `.git/` is container-ephemeral, so append is safe for now.

**11. Dual-layer seam testing via dry-run** (`scripts/dry_run.sh`, `scripts/dry_run_capability.sh`, `libs/sandbox-entrypoint.sh`, `libs/docker-compose.yml`, `libs/docker-compose.dry-run.yml`, `libs/compose.sh`, `tests/test_capability_layer.sh`):
Design and implement a mechanism for dry-run to assert host-container seam behaviour in both the reasoning layer AND the capability layer. Five sessions:

   - **11a. Design** — produce design document for the full mechanism. [This session.]
   - **11b. Pre-flight script** — add critical-invariant checks to `sandbox-entrypoint.sh` (every-container checks: mounts writable, SESSION_STATE valid, channels accessible). Warn-only for AGENTS.md/brief.md injection. ✅
   - **11c. dry_run_capability.sh** — new script running inside sandbox container. Deep investigation checks. Add bind mount to sandbox service in dry-run overlay. ✅
   - **11d. dry_run.sh rewrite** — rewrite reasoning-layer checks as a separate script. Fully decoupled from capability layer checks. Subsumes old `dry_run.sh`.
   - **11e. Host-side verification** — after both containers exit, verify artifacts written by sandbox are visible on the host, and clean up temp files.

**12. AGENTS.md injection path** (`scripts/start_agent.sh`, `libs/docker-compose.yml`, `libs/sandbox.Dockerfile` or provider Dockerfiles):
AGENTS.md is currently copied into `INPUT_DIR/brief.md` before agent start, which is inefficient — the brief is a one-shot file read at session start, not sent on every turn. The agent should read AGENTS.md from its working directory directly. Fix the injection path to mount AGENTS.md into the agent's CWD instead of copying into INPUT_DIR.

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

- **Bad diff applied to host repo corrupts future snapshots** — `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`, so a bad run cannot corrupt the host repo during execution. The risk is after the operator applies a bad diff — the host repo is then in a bad state and future snapshots reflect it. See [Recovery](#recovery) in `docs/development/quickstart.md` for how to reset to a known-good state.

- **`make start opencode` and `make start hermes` do not share a capability layer** — each provider invocation builds and runs its own capability layer image independently. They should share a single capability layer per project, since the sandbox, snapshot pipeline, and diff pipeline are provider-agnostic. This is a known architectural gap; resolving it requires the capability layer build and lifecycle to be fully decoupled from the provider selection path. The image rename in M2.7 (dropping the `<project>` suffix) is a prerequisite step toward this.

- **Multi-service project composition not supported** — projects that run multiple services (e.g. a web app with a database and test containers) have no mechanism to inject additional services alongside the harness-managed sandbox and agent. A deferred design task is to define a composition method — likely an operator-supplied overlay that `start_agent.sh` merges with the generated base — that lets projects define their own containers without forking the harness template. See `execution_model.md` for the deferred discussion.

### Deferred (not milestone-scoped)

- **Docs restructuring investigation** — The docs/ directory currently mixes architecture/concepts/operations/development/ discussions/devlog into a single tree. Architecture and concepts docs are baked into container images; operations and development docs are coding-agent workflow artifacts that should logically live in a separate namespace. Investigation deferred — no immediate use case warrants it, and the current layout is functional.

### Addressed in upcoming milestones

- **Stale container images** *(M2.7)* — the preflight gate currently checks only whether an image exists, not whether it was built from the current source. M2.7 introduces `container-sig` (hash of `libs/` and provider Dockerfiles, baked as a Docker label) checked at preflight, and `harness-sig` (hash of `scripts/` and compose files) checked at runtime with a warning on drift. See [`design_session_identity_hash_based.md`](discussions/design_session_identity_hash_based.md).

- **No automated Makefile or harness script staleness check** *(M2.7)* — `harness-sig` written to `SANDBOX_DIR/.harness-sig.ref` at session end will detect host-side script drift on subsequent runs. Full install-level isolation is a larger task deferred to [`story_harness_packaging_and_install_versioning.md`](discussions/story_harness_packaging_and_install_versioning.md).

---

### Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 — Structural Separation — folder ownership, temperature classification, root document audience separation
- [ ] Level 2 — Review Discipline — PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 — Temperature & Freeze Policy — hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 — Change Classification Matrix — explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 — Automated Enforcement — CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents
