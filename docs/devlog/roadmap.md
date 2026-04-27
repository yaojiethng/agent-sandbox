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
- package-diff index-line stripping + `git apply` (`libs/package_diff.sh`, `scripts/apply_workspace.sh`) — see handover `20260421-07-impl-package_diff_patch_and_index_strip.md`
- INIT_SHA at container init (`libs/snapshot.sh`, `libs/package_diff.sh`) — see handover `20260422-03-impl-init_sha_at_container_init.md`
- Remove checkpoint tags (`start_agent.sh`, `scripts/checkpoint.sh`, `libs/compose.sh`) — see handover `20260422-04-impl-remove_checkpoint_tags.md`
- `package-branch` function + `make apply` path fix (`libs/diff.sh`, `libs/package_branch.sh`, `libs/package_diff.sh`, `scripts/apply_workspace.sh`) — see handover `20260423-02-impl-make_apply_path_resolution.md`
- `make apply` DIFF argument (`scripts/apply_workspace.sh`, `libs/_templates/Makefile.template`, `tests/test_apply_workspace.sh`) — see handover `20260423-03-impl-make_apply_diff_argument.md`
- `make draft` redesign — branch-name folder, `BRANCH_FROM`, `DIFFS` range, `git apply` loop (`scripts/apply_workspace.sh`, `scripts/agent-sandbox.sh`, `libs/_templates/Makefile.template`, `tests/test_apply_workspace.sh`) — see handover `20260423-04-impl-make_draft_redesign.md`

**Pending:**

Units are ordered by dependency. F0 must run first. F1 depends on F0 and E. F2 depends on F1. G is last.

**F0 — path and timestamp audit** — Complete. `SESSION_TS` and `SANITIZED_HOST_BRANCH` are derived once at session start and exported to all downstream consumers. `SESSION_NAME` is removed. Diff output paths, container labels, and environment variables all use the primitive variables directly.

- [x] **F1 — complete `make draft` + `.draft-state`** (`scripts/apply_workspace.sh`, `scripts/agent-sandbox.sh`, `libs/_templates/Makefile.template`, `tests/test_apply_workspace.sh`, `libs/draft.sh`): `make draft` resolves the latest export from `$CHANGES_DIR/` by lexicographic sort; explicit `--session=<path>` accepts any folder. Parses `EXPORT_TIME`, `SANITIZED_HOST_BRANCH`, `SESSION_TS` from folder name. Draft branch name: `draft/<EXPORT_TIME>-<SESSION_TS>-<BRANCH_SUMMARY or SANITIZED_HOST_BRANCH>-<sha6>`. First commit is `.draft-state` with all required fields. Shared draft utilities extracted to `libs/draft.sh`. Same-name collision guard — identical branch names rejected, different names allowed to coexist. See handover `20260423-07-impl-draft_state_and_make_draft_redesign.md`.

- [ ] **F2 — `make confirm` rewrite + `make reject` update + `make sync` removal** (`scripts/apply_workspace.sh`, `libs/_templates/Makefile.template`, `tests/test_apply_workspace.sh`):

  **`make confirm`:** (1) Read `.draft-state` from draft branch — fail with "not on a draft branch" if absent. (2) Drop `.draft-state` commit via `git rebase --onto`. (3) Rebase draft onto target — on conflict print exact recovery commands (`git rebase --continue` / `make confirm` / `git rebase --abort` + `make reject`) and exit. (4) `git merge --ff-only`. (5) Delete draft branch.

  **`make reject`:** Read `source_branch` from `.draft-state` on the draft branch. Check out source branch. Delete draft branch.

  **`make sync` removal:** Remove `SYNC=1` handling and `make sync` target entirely.

  Depends on F1.

- [ ] **G — `.skills/package-diff.md` update**: Add `package-branch` section. Update apply instructions for `make draft` and `make confirm` redesign. Update output paths to reflect new folder structure. Remove references to `.patch` files and `git am`. Depends on F2.

**Acceptance criteria:**

- `SESSION_TS` derived once at session start with delimiter format; no independent `date` calls downstream
- `diff_on_exit` writes to `$CHANGES_DIR/<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>/`
- `package_branch` and `package_diff` write to `$OUTPUT_DIR/bundles/` and `$OUTPUT_DIR/diffs/` respectively with `<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/` naming
- `make draft` resolves latest export from `$CHANGES_DIR/` by lexicographic sort; creates draft branch named `draft/<EXPORT_TIME>-<SESSION_TS>-<branch>-<sha6>`; `.draft-state` is the first commit with all required fields; operator hint printed on completion
- `make confirm`: drops `.draft-state` commit, rebases draft onto target, fast-forward merges, deletes draft branch; prints exact recovery commands on rebase conflict
- `make reject`: reads `source_branch` from `.draft-state` on the branch; returns to source branch; deletes draft branch
- `make apply` applies a single diff uncommitted on both host and container; `DIFF=<path>` override works
- No checkpoint git tags written to repo on session start
- No `ADVANCED_SESSIONS`, no `make sync`, no `SYNC=1`
- `INIT_SHA` written once at container init, readable at `sandbox/.git/INIT_SHA`

**Pre-close design tasks** (required before Trigger B): both resolved this session.

- Mixing `make apply` and `make draft` within a single session — resolved. Paths are structurally separate: `make apply` reads from `$OUTPUT_DIR/diffs/`; `make draft` reads from `$CHANGES_DIR/`. No shared application mechanism.
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
