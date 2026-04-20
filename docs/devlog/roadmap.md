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
| M2.5 — Vault Capability Layer Prototype | Not started |
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

**Objective:** Redesign the apply workflow to reflect the two-layer model: diff generated post-session from capability layer `sandbox/`, agent commit history preserved, checkpoint and draft branch pattern formalised.

**Depends on:** M2.1. **Status:** In progress. Changes 1, 2, and 4 complete; Changes 3, 5, and 6 pending.

**Design reference:** [`docs/discussions/design_apply_workflow_and_baseline_advancement.md`](docs/discussions/design_apply_workflow_and_baseline_advancement.md)

**Change status:**

| Change | Description | Status |
|--------|--------------|--------|
| Change 1 | Checkpoint tag (`start_agent.sh`) | ✓ Complete |
| Change 2 | Format-patch + session artefacts (`libs/diff.sh`) | ✓ Complete |
| Change 3 | draft/confirm/reject (`apply_workspace.sh`) | ✓ Complete |
| Change 4 | Archive HEAD + rsync overlay (`libs/snapshot.sh`) | ✓ Complete |
| Change 5 | Container naming + Docker labels (`libs/compose.sh`, `scripts/checkpoint.sh`) | Pending |
| Change 6 | Baseline advancement (`make confirm SYNC=1`, `make sync`) | Pending |

**Change 1 implementation (complete):**

Checkpoint tag creation with worktree namespace, SESSION_NAME derivation, and REPO_COMMIT capture:
- **Host side (`start_agent.sh`):** Derives `WORKTREE_ID` from PROJECT_DIR path; creates `agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS` tag before snapshot runs; prunes to 5 most recent per worktree; derives `SESSION_NAME` as `<sanitized-branch>-<timestamp>`; exports `REPO_COMMIT` (full HEAD SHA) for future image labeling; exports `SESSION_NAME` for docker-compose (injection in Change 2). Note: `checkpoint-latest.ref` written by this implementation is superseded by container label lookup in Change 5 — checkpoint tag is retrieved via `checkpoint.sh` tag lookup at apply time.
- **Tests:** 19 tests in `tests/test_start_agent.sh` — 7 checkpoint tests, 6 SESSION_NAME tests, 3 WORKTREE_ID tests, 2 REPO_COMMIT tests. All pass.

See handover `20260416-04-impl-change1.md` for full implementation details.

**Change 2 implementation (complete):**

Format-patch generation and session-scoped artefact directory:
- **Container side (`libs/diff.sh`):** Added `diff_format_patch` function to generate per-commit `.patch` files via `git format-patch`. Updated `diff_on_exit` and `diff_on_autosave` to accept optional `SESSION_NAME` argument; artefacts written under `.workspace/session-diffs/<session-name>/` with fallback to root `CHANGES_DIR/` for backwards compatibility. # renamed from changes/ in M2.3
- **Container side (`libs/sandbox-entrypoint.sh`):** EXIT trap and autosave loop pass `${SESSION_NAME:-}` to diff functions.
- **Compose (`libs/docker-compose.yml`):** `SESSION_NAME` injected into sandbox container environment.
- **Tests:** 11 new tests in `tests/test_diff.sh` (24 total) covering `diff_format_patch` and session-scoped artefacts. All pass.

See handover `20260417-04-impl-m2_3_change2.md` for full implementation details.

**Change 4 implementation (complete):**

The snapshot baseline now correctly reflects the operator's working tree state:
- **Host side (`start_agent.sh`):** After `snapshot_copy_worktree`, runs `git archive HEAD > baseline.tar` in `.snapshot/`. Produces exactly the committed state — no working tree changes, no untracked files.
- **Container side (`snapshot_init_git` in `libs/snapshot.sh`):** Two-step init: (1) unpack `baseline.tar`, stage and commit as baseline; (2) rsync overlay from `.snapshot/` with `--delete`. Index reflects HEAD; working tree reflects operator's on-disk state.

Correctly handles all cases: untracked files show as `??`, unstaged edits show as `M`, unstaged deletions show as `D`, clean files stay clean. See handover `20260416-01-impl-snapshot-baseline.md` for full design rationale.

**Four changes in scope:**

- **Change 1 — Checkpoint tag** (`start_agent.sh`): Create `agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS` tag before each session. Derive `WORKTREE_ID` from PROJECT_DIR path, `SESSION_NAME` as `<sanitized-branch>-<timestamp>`, and `REPO_COMMIT` as full HEAD SHA. Prune to last 5 checkpoint tags per worktree.

- **Change 2 — Format-patch + session artefacts** (`libs/diff.sh`, `start_agent.sh`): Add `diff_format_patch`; write per-commit `.patch` files to `.workspace/session-diffs/<session-name>/patches/`. Move `staged.diff` into the same session-scoped directory. Both artefacts produced on every session exit. # renamed from changes/ in M2.3

- **Change 3 — draft/confirm/reject** (`scripts/apply_workspace.sh`, `Makefile.template`): Replace `make apply` with `make draft` (resolves session via latest fallback or explicit `SESSION=<n>`; creates `agent/draft/<session-name>` from checkpoint tag via `checkpoint.sh` lookup; applies patches via `git am --3way` with author reset; aborts cleanly on failure), `make confirm [TARGET=<branch>]` (rebases draft onto target, fast-forward merges, linear history always), `make reject` (discards draft branch). `draft-state` holds active draft state. `make apply` retained as legacy fallback. Note: `SYNC=1` flag and `make sync` are Change 6 additions — Change 3 does not touch baseline advancement.

- **Change 4 — Archive HEAD + rsync overlay** (`libs/snapshot.sh`, `start_agent.sh`): Replaced naive rsync-only snapshot with two-step design: (1) host produces `baseline.tar` via `git archive HEAD`; (2) container unpacks tar, commits as baseline, then overlays rsync copy with `--delete`. Baseline commit now represents exactly HEAD — independent of working tree state. Residual limitation: negation patterns in global gitignore / `.git/info/exclude` not supported by rsync `--exclude-from` — documented.

- **Change 5 — Container naming + Docker labels** (`libs/compose.sh`, `scripts/checkpoint.sh`): Explicit `container_name:` in generated compose derived from session identity. Container labels set at session start: `agent-sandbox.project-dir`, `agent-sandbox.session-name`, `agent-sandbox.checkpoint-tag`. Introduces `scripts/checkpoint.sh` consolidating tag creation, pruning, lookup, and `WORKTREE_ID` derivation — sourced by `start_agent.sh`, `apply_workspace.sh`, and advancement script. Removes `checkpoint-latest.ref` dependency; all checkpoint and container lookups use label queries or `checkpoint.sh`. Prerequisite for Change 6 and for parallel worktree session safety.

- **Change 6 — Baseline advancement** (`scripts/advance_baseline.sh`, `Makefile.template`): Implements `make confirm SYNC=1` (tight per-confirm advancement, validates container session label) and `make sync` (loose catch-up, applies all unadvanced sessions in timestamp order). Container located by `agent-sandbox.project-dir` label. `ADVANCED_SESSIONS` inside the container is the idempotency guard. Requires clean sandbox working tree; conflicts surface via `git am --abort`. Depends on Change 5.

#### M2.5 — Vault Capability Layer Prototype

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first, then add MCP server as enhancement. Unblocks KV5.

**Depends on:** M2.1, M2.2, M2.3. **Scope:** Validate vault workflow with sandbox-only configuration. Evaluate and select MCP server candidate. Build vault capability layer image. Validate binary file handling and KV5 end-to-end.

#### M2.6 — Session Resume Across Provider Implementations

**Objective:** Define and implement true session persistence — the ability to resume a prior conversation — for each supported provider. M2.4 established that state survives between sessions; M2.6 defines what resuming that state actually means per provider and how the harness supports it.

**Depends on:** M2.4. **Scope:** Investigation-first. Characterise session file format, export mechanism, and resume invocation for pi, Hermes, and opencode. Design harness support based on findings. Known starting points:

- **pi**: requires explicit `pi export` to write session files; resume requires session ID and specific invocation flags. Neither is currently triggered or passed by the harness.
- **Hermes**: assumed to live-load conversation history from home directory on startup — not validated.
- **opencode**: session persistence mechanism unknown. Requires investigation before any design work.

Each provider may result in a different integration pattern. Investigation findings should be recorded as named investigation documents before implementation begins.

#### M2.7 — Session Identity and Harness Versioning
Objective: Establish a stable, content-addressed identity model for sessions, containers, and the harness itself — eliminating stale image regressions, timestamp drift, and the lack of provenance tracing for session artefacts.
Depends on: M2.3. Status: Not started.
Scope: Implement the primitive set and two-sig model defined in docs/discussions/story_session_identity_and_harness_versioning.md. Work falls into three groups (container naming moved to M2.3 Change 5):

Primitive set (scripts/start_agent.sh): single canonical SESSION_TS at top of script replacing any downstream date calls; REPO_COMMIT captured and exported; WORKTREE_ID derived from short hash of PROJECT_DIR absolute path and exported. Note: WORKTREE_ID and updated checkpoint tag namespace (agent-checkpoint/<worktree-id>/<timestamp>) already implemented in M2.3 Change 1.
Two-sig model (libs/containers.sh, scripts/start_agent.sh): container-sig = hash(libs/ + providers/<n>/base.Dockerfile + providers/<n>/provider.Dockerfile) baked as Docker label agent-sandbox.container-sig at build time, checked at preflight — mismatch triggers rebuild; harness-sig = hash(scripts/ + providers/<n>/setup.sh + providers/*.yml + providers/<n>/*.yml) computed at runtime, compared against SANDBOX_DIR/.harness-sig.ref written at session end — mismatch warns only.
Paired refactor (libs/, providers/): move libs/docker-compose.yml and libs/docker-compose.dry-run.yml into providers/ so the harness-sig hash boundary matches the folder boundary. Image rename dropping <project> suffix (sandbox, <provider>-agent) — blocked on prerequisite code review: verify agents.md is not COPY-ed in any provider Dockerfile before proceeding.

Sub-stories:

story_parallel_sessions_worktree.md — Resolved. WORKTREE_ID and checkpoint tag namespace implemented in M2.3 Change 1; container naming implemented in M2.3 Change 5. No open design questions remain.
story_harness_packaging_and_install_versioning.md — install workflow rewrite; deferred, does not block this milestone.

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

- **Stale container images** *(M2.7)* — the preflight gate currently checks only whether an image exists, not whether it was built from the current source. M2.7 introduces `container-sig` (hash of `libs/` and provider Dockerfiles, baked as a Docker label) checked at preflight, and `harness-sig` (hash of `scripts/` and compose files) checked at runtime with a warning on drift. See [`story_session_identity_and_harness_versioning.md`](discussions/story_session_identity_and_harness_versioning.md).

- **No automated Makefile or harness script staleness check** *(M2.7)* — `harness-sig` written to `SANDBOX_DIR/.harness-sig.ref` at session end will detect host-side script drift on subsequent runs. Full install-level isolation is a larger task deferred to [`story_harness_packaging_and_install_versioning.md`](discussions/story_harness_packaging_and_install_versioning.md).

---

### Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 — Structural Separation — folder ownership, temperature classification, root document audience separation
- [ ] Level 2 — Review Discipline — PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 — Temperature & Freeze Policy — hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 — Change Classification Matrix — explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 — Automated Enforcement — CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents