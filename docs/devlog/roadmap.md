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
| [M2.3 — Apply Workflow: Capability Layer Diff Pipeline](#m23--apply-workflow-capability-layer-diff-pipeline) | In progress |
| [M2.4 — Session and Config Persistence](#m24--session-and-config-persistence) | Complete |
| [M2.5 — Vault Capability Layer Prototype](#m25--vault-capability-layer-prototype) | In progress |
| M2.6 — Session Resume Across Provider Implementations | Not started |
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

#### M2.3 — Apply Workflow: Capability Layer Diff Pipeline

**Objective:** Redesign the apply workflow to reflect the two-layer model: git-agnostic unified diffs generated from capability layer `sandbox/`, bidirectional diff flow between host and sandbox, draft branch pattern formalised for operator review.

**Depends on:** M2.1. **Status:** In progress.

**Design references:**
- [`docs/discussions/design_diff_and_branch_packaging_workflow.md`](docs/discussions/design_diff_and_branch_packaging_workflow.md) — current design
- [`docs/discussions/design_apply_workflow_and_baseline_advancement.md`](docs/discussions/design_apply_workflow_and_baseline_advancement.md) — prior design, preserved with SUPERSEDED markers

**Completed:**

The two-layer diff pipeline is fully implemented. `package_diff` produces unified diffs from the capability layer for operator `make apply`; `package_branch` packages sandbox commits as numbered per-commit diffs for `make draft`. The draft/confirm/reject workflow is operational: `make draft` resolves the latest session export, creates a typed draft branch with `.draft-state` as the first commit, and applies patches sequentially via `git apply`; `make confirm` drops the state commit, rebases onto target, and fast-forward merges; `make reject` returns to the source branch cleanly. Session artefact directories use 2-field names (`<SESSION_TS>-<SANITIZED_HOST_BRANCH>`), with `session/` and `autosave/` subfolders, `EXPORT-TIME.txt`, and unified path resolution across both commands. Checkpoint tags and `make sync` are removed. `INIT_SHA` is written once at container init. All diff output has index lines stripped for context-only `git apply`.

The apply workflow is consolidated under `agent-sandbox.sh`: `draft`, `confirm`, `reject`, and `apply` all resolve through the agent-sandbox entry point, and the deprecated `scripts/apply_workspace.sh`, `libs/draft.sh`, and their tests have been removed.

A durable `sandbox/.git/SESSION_STATE` key-value file persists `session_ts` and `init_sha` across the container lifetime, replacing the standalone `INIT_SHA` file and eliminating malformed artefact paths when environment variables are unset.

**Pending — `package-branch` skill amendments:**

Session log analysis identified two instructions in the skill that caused nonproductive agent reasoning. The SESSION_STATE dependency is now resolved; the skill already references `SESSION_STATE` but the following amendments remain:

- [x] Reframe scope description in `package-branch` skill: "all commits since `init_sha`" (container-lifetime boundary, not conversation boundary); apply the same framing to the migration guide scope instruction
- [x] Verify `SESSION_TS` fallback instruction is clear: read from `SESSION_STATE` file first, fall back to env var, note omission if neither is available — do not loop attempting to derive it

**Pending — test suite repair:**

The full test suite run identified pre-existing failures unrelated to the apply_workspace refactor. `test_package_diff.sh` failures are resolved (SESSION_TS/SESSION_STATE fix). These remain:

- [ ] `tests/test_checkpoint.sh` — 8 failures. Root cause: `checkpoint_latest` worktree scoping regression. Investigate and fix independently.
- [ ] `tests/test_build_context.sh` — script error (`libs/build_context.sh` missing). Investigate whether file was deleted or moved.
- [ ] `tests/test_capability_layer.sh` — unclear result. Investigate and fix.
- [ ] `tests/test_provider_entrypoint.sh` — unclear result (missing env vars). Investigate and fix.

**Pending — interactive confirmation flag:**

Both `make apply` and `make draft` lack an operator review step before changes are applied. A shared `--interactive` flag (candidate for shared logic in `libs/session.sh` or equivalent) prints the resolved diff file(s) to be applied — one per line — then prompts for confirmation before proceeding. `make apply` always has one file; `make draft` has one or more. Output format should be consistent between the two commands.

- [ ] Implement `--interactive` flag in `apply_run` and `draft_run` — print resolved diff file list, prompt for confirmation, abort cleanly on rejection; extract print-and-prompt logic as a shared helper
- [ ] Add `--interactive` to `make apply` and `make draft` Makefile targets; update `agent-sandbox.sh` to pass the flag through
- [ ] Test interactive mode for both commands: confirmation proceeds, rejection aborts without applying, file list matches resolved session

**Design note — host→container direction:**

The two-layer model includes a host→container direction: operator runs `package-diff` on the host to push amendments into a running container session. This direction is present in the design but intentionally not implemented — no current use case warrants it. Not planned unless a concrete use case emerges.

**Acceptance criteria:**

- `scripts/apply_workspace.sh` does not exist; `agent-sandbox` is the sole entry point for `draft`, `confirm`, `reject`, `apply`
- `libs/session.sh`, `libs/draft_workflow.sh`, `libs/diff_workflow.sh` exist; `libs/draft.sh` does not exist
- `tests/test_draft_workflow.sh` and `tests/test_diff_workflow.sh` pass clean; `tests/test_apply.sh` and `tests/test_apply_workspace.sh` do not exist
- `grep -rn "apply_workspace" .` returns no results outside `docs/` (i.e. no caller references it and no stale archive links in implementation code)
- `make apply --interactive` and `make draft --interactive` print the resolved diff file list and prompt before applying; aborting at the prompt leaves the project directory unchanged
- diff and draft workflows produce correct artefact paths after tests have been run inside the container — verified by unsetting `$SESSION_TS` in the shell and confirming `SESSION_STATE` is read as fallback
- `sandbox/.git/SESSION_STATE` exists at container init and contains `session_ts` and `init_sha` keys; `sandbox/.git/INIT_SHA` does not exist
- `make test` runs all `tests/test_*.sh` files and exits 0 when all pass, 1 when any fail; `tests/lib/` files are not executed

**Pending — test infrastructure:**

Design complete — see `docs/discussions/spec_test_infrastructure.md`. Depends on the apply_workspace refactor establishing `tests/lib/`, `test_draft_workflow.sh`, and `test_diff_workflow.sh` before these are added. Recommended after test suite repair so the runner has a clean baseline.

- [ ] Write `scripts/run_tests.sh` — discovers and runs all `tests/test_*.sh` files in a subshell, prints per-file pass/fail and totals, exits 1 if any fail; excludes `tests/lib/`
- [ ] Add `make test` target calling `scripts/run_tests.sh`; verify no conflict with existing targets before adding
- [ ] Write `scripts/check_test_coverage.sh` — given changed file paths as arguments, greps `tests/` (excluding `tests/lib/`) for references and prints which test files cover each; explicitly reports files with no coverage

#### M2.5 — Vault Capability Layer Prototype

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first, then add MCP server as enhancement. Unblocks KV5.

**Depends on:** M2.1, M2.2, M2.3. **Status:** In progress.

**Scope:** Validate vault workflow with sandbox-only configuration. Evaluate and select MCP server candidate. Build vault capability layer image. Validate binary file handling and KV5 end-to-end.

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

**Depends on:** M2.3. **Status:** Not started.

**Design reference:** [`docs/discussions/design_session_identity_hash_based.md`](docs/discussions/design_session_identity_hash_based.md)

**Scope:** Implement the hash-based session identity model, two-sig model, and container lifecycle redesign. Work falls into four groups:

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
