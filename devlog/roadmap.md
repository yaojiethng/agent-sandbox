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
| W1 — Vault Capability Layer Prototype | Deferred |
| M2.6 — Session Resume Across Provider Implementations | Not started |
| M2.7 — Session Identity and Harness Versioning | [Complete — see changelog](changelog.md) |
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

#### W1 — Vault Capability Layer Prototype

**Status:** Deferred. Not a mainline milestone — separate workflow for the Obsidian vault use case. Re-activate when KV5 timeline demands it. See `roadmap_future.md` for task checklist.

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first, then add MCP server as enhancement. Unblocks KV5.

**Hermes python base refactor deferred — see `roadmap_future.md` §W1.**
The shared python-harness base (`src/reasoning/python.dockerfile`) was designed but never built.
Hermes currently builds independently from `python:3.11-slim` rather than inheriting from the harness.
This is non-urgent (Hermes not actively used). If W1 is made to work without Hermes,
consider whether to remove Hermes support entirely rather than maintaining a dormant provider.

#### M2.6 — Session Resume and Mount Model Redesign

**Objective:** Replace the snapshot-copy + diff-pipeline model with a mount-based workflow where the agent works directly on a persistent repo branch. The agent's changes live on disk at all times — no fragile `git apply`, no anonymous docker volumes, no autosave-as-primary-persistence. Session resume becomes: mount the repo, create a branch, start the agent on that branch.

**Depends on:** M2.4 (bind mount infrastructure), M2.7 (session identity, RUN_ID, container lifecycle).

---

### Motivation

The current snapshot + diff pipeline model has known failure modes:
- `git apply` on exported diffs fails under various conditions (binary files, rename detection, index-line SHA mismatches between container and host)
- Autosave and session-save mechanisms are fragile — the EXIT trap discards `diff_export` return values, and anonymous docker volumes mean uncommitted work is lost on container death
- The review workflow requires an export → review → apply cycle that fights git rather than using it

A mount-based model addresses these by making the agent's working tree a real git checkout on the host filesystem. The agent commits to a branch; the operator reviews and merges with native git tooling.

---

### Security Model Amendment

The current security invariant "`PROJECT_ROOT` must not be mounted into the container at runtime" is replaced by a user-choice model:

> The sandbox inherits the security posture of the underlying repo. agent-sandbox cannot enforce that a repo has no secrets — if the user mounts a repo, the user is responsible for ensuring secrets are not present. The harness provides two mounting options at different security/convenience trade-offs:
> 1. **Worktree mount** — a `git worktree` is created from `PROJECT_DIR` and mounted into the reasoning layer. `PROJECT_DIR/.git` is mounted RO into the capability layer only. Keeps `.git/config` and `.git/hooks/` out of the agent's reach. The agent commits to a real branch in the real repo; the operator reviews with native git tooling. See [`docs/discussions/security_delta_worktree_model.md`](../discussions/security_delta_worktree_model.md) for full analysis.
> 2. **Snapshot mount** (default) — current model: `baseline.tar` unpacked into an anonymous volume, diff pipeline as sole output path. Maximum isolation. Agent changes flow through staged diffs; operator reviews before apply.

The user chooses the model per session. The default is snapshot mount (backward compatible). M2.6 implements the worktree mount (option 1) for pi as the primary integration target, with the architecture structured so other providers can reuse the wiring.

**Related documents:**
- [`docs/architecture/security.md`](../architecture/security.md) — invariant rewrites required (itemised in `security_delta_worktree_model.md` Part 2)
- [`docs/discussions/security_delta_worktree_model.md`](../discussions/security_delta_worktree_model.md) — full invariant comparison, residual risk analysis, and required mitigations
- [`docs/discussions/story_agent_git_surface.md`](../discussions/story_agent_git_surface.md) — agent-in-git design questions (resolved by design: agent commits to a branch, operator reviews)
- [`docs/discussions/story_agent_state_persistence.md`](../discussions/story_agent_state_persistence.md) — persistence model (resolved: mount-based persistence)
- [`docs/discussions/story_container_layer_model.md`](../discussions/story_container_layer_model.md) — harness base layer design (settled; node harness implemented, python harness deferred — see W1)

---

### Scope

Focus on pi. The architecture should be extensible to other providers (Hermes, opencode) without rewrite. M2.6 proceeds in two phases.

> **Phase ordering:** Phase 1 fixes existing broken behaviour and prepares the ground. Phase 2 requires a design session before any mount work begins. No mount work starts until Phase 1 deliverables are accepted.

---

### Phase 1 — Foundation

Fix what's broken under the current (snapshot) model before introducing new workflows.

- [x] **Autosave and session-save reliability** — Fixed EXIT trap `diff_export` return value capture, added `.export-status` + error logs, lockfile polling. Dry-run checks added. See `20260622-01` and `20260622-02` handovers.
- [x] **Security model update** — Three-tier security model documented. 4 story docs closed with Resolution sections. See `20260622-P1-B` commit.
- [x] **Pi session resume** — Confirmed done by operator. No action needed.

#### Prefactors (before Phase 2 design, can overlap with Phase 1)

- [x] **Repo precondition audit** — 12 findings (5 HIGH, 2 MED, 4 LOW, 1 NONE). Key risks: `snapshot_init_git()` hardcodes copy lifecycle, `start_agent.sh` always `rm -rf` + copy, compose template mounts `.snapshot/` as `read_only`, entrypoint preflight aborts if `baseline.tar` missing. See `20260622-03-study-repo_audit_preconditions.md` for full table and recommendations.
- Review `investigation_git_worktrees.md` — the worktree feasibility investigation. Confirm its conclusions still hold given the current codebase state (M2.7 changes to path resolution, RUN_ID, container lifecycle). Any new blockers discovered here feed into the Phase 2 design session.
- Ensure the test suite (now 404 tests, 0 failures) covers the autosave and EXIT trap paths well enough to detect regressions when Phase 2 changes the model. If coverage is thin, add tests as part of the autosave reliability task.

---

### Phase 2 — Mount Model Design and Implementation

Requires a design session. The security model must be updated (Phase 1) before the design session can proceed. All design decisions, mount path specifications, and compose template changes are scoped during the design session, not here.

#### Pre-design investigations (inform the design session)

- [x] **Extensibility structure audit** — 10 findings (1 HIGH, 2 MED, 2 LOW, 5 NONE). Key risk: AGENT_HOME bind mounts exist in Pi overlay only — Hermes/OpenCode have no AGENT_HOME persistence. Shared entrypoint is clean (no change needed). Produced documented shared vs. provider boundary. See `20260622-04-study-extensibility_structure_audit.md` for full table and recommendations.
- **`PROJECT_DIR` mount wiring** — Investigate how the mount is specified (Makefile variable? CLI flag? config file?). The mount path must work across Linux, macOS (virtiofs), and Windows (9p/WSL2). The compose template needs a conditional volume entry.
- **Unify `make apply` and `make draft`?** — Currently `apply` applies a single diff uncommitted to HEAD (mid-session sync), while `draft` takes all committed changes and creates a reviewable branch. Under the worktree model the agent commits directly to a branch — the distinction between "apply an uncommitted diff" and "turn commits into a reviewable branch" may no longer be meaningful. Consider combining into a single command that always works off a target ref, with an option to apply in-place instead of creating a draft branch. Trade-off: `make apply` is useful as a recovery path when `make draft` fails (selectively apply individual diffs). Record the decision for the design session.
- **Hermes and opencode session resume** — Deferred. Not investigated unless explicitly needed.

#### Anticipated tasks (scoped and confirmed by design session)

- Compose template — conditional mount for the worktree directory
- Worktree lifecycle — create/remove worktrees, branch naming, operator review workflow
- `make draft`/`make confirm`/`make reject` — adapt to operate on existing branches rather than applying diffs
- Migration path — existing snapshot-model sessions continue to work; diff pipeline preserved as optional workflow

#### M2.7 — Session Identity and Harness Versioning

**Status:** Complete. Hash-based identity model (SANDBOX_ID, RUN_ID), container lifecycle (naming, labels, stop/prune), artefact paths, build pipeline simplification (repo-root context, COPY contract tests), two-sig model (container-sig label + preflight), generic pre-flight validation, dual-layer dry-run seam testing, DIFF_TYPE flag, --no-renames flag. See handover chain `20260609-01` through `20260611-04` and changelog entry.

**Deferred from M2.7:**
- Harness-sig — deferred to `roadmap_future.md`
- Process improvements (fast-track criteria, decision recording, stale skill reference) — deferred, not milestone-scoped

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

- **`make start opencode` and `make start hermes` do not share a capability layer** — each provider invocation builds and runs its own capability layer image independently. They should share a single capability layer per project, since the sandbox, snapshot pipeline, and diff pipeline are provider-agnostic. This is a known architectural gap; resolving it requires the capability layer build and lifecycle to be fully decoupled from the provider selection path.

- **Multi-service project composition not supported** — projects that run multiple services (e.g. a web app with a database and test containers) have no mechanism to inject additional services alongside the harness-managed sandbox and agent. A deferred design task is to define a composition method — likely an operator-supplied overlay that `start_agent.sh` merges with the generated base — that lets projects define their own containers without forking the harness template. See `execution_model.md` for the deferred discussion.

### Deferred (not milestone-scoped)

- **Doc bloat: rotate out stale handovers and discussions** — `devlog/handovers/` and `devlog/discussions/` accumulate every session's output. Most are only relevant during their milestone — once a milestone is closed, the handover detail lives in the changelog. There is no need to keep the full history on `HEAD`. Design a rotate-out process: completed milestone handovers are archived to a git tag or a separate branch, removed from `HEAD`. Roadmap entries, architecture docs, and the changelog are the permanent record. The same applies to resolved stories in `devlog/discussions/` — once graduated to a roadmap entry, the story discussion document can be archived. See `story_sequencing_and_knowledge_persistence.md` which is related.
- **Docs directory restructuring** — The `docs/` directory currently mixes architecture/concepts/operations/development/discussions/devlog into a single tree. Architecture and concepts docs are baked into container images; operations and development docs are coding-agent workflow artifacts that should logically live in a separate namespace. Deferred — not urgent.

- **`docker compose down -v` race with EXIT trap** — When `stop.sh` runs `docker compose down -v`, the `-v` flag removes anonymous volumes referenced by `volumes_from`. If Docker Compose removes those before the sandbox container's EXIT trap finishes writing the session export, the export could be interrupted. Triaged as a plausible error but unlikely to be causing current problems — session-diffs are a bind mount (not affected by `-v`), and anonymous volume references on the agent service do not block the sandbox trap. Recorded for completeness from handover audit finding F3. No milestone assigned.

### Addressed in upcoming milestones

- **Host-side harness staleness** *(deferred)* — after `git pull`, the installed `agent-sandbox` CLI may silently execute changed scripts/libs from the repo checkout. `container-sig` does not detect this (it detects image staleness, not CLI staleness). A self-contained binary with semantic versioning is needed to close this gap. Scoped as a standalone future milestone in [`roadmap_future.md`](roadmap_future.md) §Harness Packaging and Versioning.
