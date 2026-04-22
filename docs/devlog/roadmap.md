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

**Objective:** Redesign the apply workflow to reflect the two-layer model: git-agnostic unified diffs generated from capability layer `sandbox/`, bidirectional diff flow between host and sandbox, draft branch pattern formalised for operator review.

**Depends on:** M2.1. **Status:** In progress.

**Design references:**
- [`docs/discussions/design_diff_and_branch_packaging_workflow.md`](docs/discussions/design_diff_and_branch_packaging_workflow.md) — current design
- [`docs/discussions/design_apply_workflow_and_baseline_advancement.md`](docs/discussions/design_apply_workflow_and_baseline_advancement.md) — prior design, preserved with SUPERSEDED markers

**Completed:**

- Checkpoint tag + WORKTREE_ID + SESSION_NAME (`start_agent.sh`) — see handover `20260416-04-impl-change1.md`
- Format-patch + session-scoped artefact directory (`libs/diff.sh`) — superseded in part; see handover `20260417-04-impl-m2_3_change2.md`
- draft/confirm/reject/apply (`scripts/apply_workspace.sh`) — superseded in part; see handover for change 3
- Archive HEAD + rsync overlay (`libs/snapshot.sh`) — see handover `20260416-01-impl-snapshot-baseline.md`
- Container naming + Docker labels (`libs/compose.sh`, `scripts/checkpoint.sh`) — superseded in part; see handover for change 5
- package-diff index-line stripping + `git apply` (`libs/package-diff.sh`, `scripts/apply_workspace.sh`) — see handover `20260421-07-impl-package_diff_patch_and_index_strip.md`
- INIT_SHA at container init (`libs/snapshot.sh`, `libs/package-diff.sh`) — see handover `20260422-03-impl-init_sha_at_container_init.md`

**Pending — diff packaging unification:**

Units are ordered by dependency. A and B are independent and can be implemented in either order. C depends on A. E depends on C. F depends on E. D and G are independent of each other but G should be last.

- [x] **A — INIT_SHA at container init** (`libs/snapshot.sh`): In `snapshot_init_git`, write `git rev-list --max-parents=0 HEAD` to `sandbox/.git/INIT_SHA` after baseline commit. Remove any `BASELINE_SHA` write or update logic.

- [ ] **B — Remove checkpoint tags** (`start_agent.sh`, `scripts/checkpoint.sh`): Remove checkpoint git tag creation and pruning from `start_agent.sh`. Remove tag creation, pruning, and lookup from `scripts/checkpoint.sh`; retain `WORKTREE_ID` derivation. Remove `agent-sandbox.checkpoint-tag` from container labels.

- [ ] **C — `package-branch` function** (`libs/diff.sh`): Add `package_branch` — iterates commits since `INIT_SHA`, produces numbered `.diff` files with index lines stripped into `workspace/session-diffs/<branch-name>/`, overwrites on each run. Add `package_diff` — `git diff HEAD` with index lines stripped to `workspace/output/changes.diff`. Update `diff_on_exit` to call `package_branch`. Retain `staged.diff`. Depends on A.

- [ ] **D — `make apply` update** (`scripts/apply_workspace.sh`): Add `DIFF=<path>` argument. Remove pre-staging block. Replace apply call with `grep -v '^index ' "$DIFF" | git -C "$PROJECT_DIR" apply`. Preserve default resolution (latest `.diff` in `workspace/output/` by timestamp).

- [ ] **E — `make draft` redesign** (`scripts/apply_workspace.sh`): Remove checkpoint tag lookup. Add `FROM=<hash>` argument (default: `HEAD`). Replace session-name folder resolution with branch-name folder. Add `DIFFS=<start>..<end>` range argument. Replace `git am` loop with sequential `git apply` loop (index lines stripped), staging and committing each diff. Depends on C.

- [ ] **F — `make confirm` simplification + `make sync` removal** (`scripts/apply_workspace.sh`, `Makefile.template`): Remove rebase invocation from `make confirm`. Remove `SYNC=1` handling. Remove `make sync` target. `make confirm` becomes: read `draft-state`, delete draft branch, clear `draft-state`. Depends on E.

- [ ] **G — `.skills/package-diff.md` update**: Add `package-branch` section. Update apply instructions for `make draft` redesign. Remove references to `.patch` files and `git am`.

**Acceptance criteria:**

- `package-branch` produces numbered `.diff` files in `session-diffs/<branch-name>/` on session exit; no `index` lines present
- `make draft` applies numbered diffs via `git apply`; `FROM` and `DIFFS` arguments work correctly
- `make confirm` cleans up draft branch only — no rebase, no `docker exec`
- `make apply` applies a single diff uncommitted on both host and container; `DIFF=<path>` override works
- No checkpoint git tags written to repo on session start
- No `ADVANCED_SESSIONS`, no `make sync`, no `SYNC=1`
- `INIT_SHA` written once at container init, readable at `sandbox/.git/INIT_SHA`

**Pre-close design tasks** (required before Trigger B): both resolved this session.

- Mixing `make apply` and `make draft` within a single session — resolved. Paths are structurally separate under the new model: `make apply` reads from `workspace/output/`; `make draft` reads from `workspace/session-diffs/<branch-name>/`. No shared application mechanism; no undefined behaviour.
- Mixed session types against the same repo (Claude Chat + OpenCode) — closed as explicitly out of scope. Not intended behaviour. Warrants a story only if it becomes a real use case.


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
