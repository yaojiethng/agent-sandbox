---
active-milestone: M2.6 — Session Resume and Mount Model Redesign
active-milestone-status: in-progress
---

# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules — task granularity, cleanup on completion, section removal — are defined in [`docs/operations/roadmap_policy.md`](../operations/roadmap_policy.md).

---

## Milestone Summary

| Milestone | Status |
|---|---|
| M1 — Barebones Agent Container | [Complete — see changelog](changelog.md#m1--barebones-agent-container) |
| &nbsp;&nbsp;M1.1 — Interactive Virtual Workspace / Serve Mode | [Complete — see changelog](changelog.md#m11--interactive-virtual-workspace--serve-mode) |
| &nbsp;&nbsp;M1.2 — Sandbox File Isolation & Diff Workflow | [Complete — see changelog](changelog.md#m12--sandbox-file-isolation--diff-workflow) |
| &nbsp;&nbsp;M1.3 — Invocation Cleanup & Onboarding Workflow | [Complete — see changelog](changelog.md#m13--invocation-cleanup--onboarding-workflow) |
| &nbsp;&nbsp;M1.4 — Image Staleness Detection | [Complete — see changelog](changelog.md#m14--image-staleness-detection) |
| &nbsp;&nbsp;M1.5 — Workflow Convergence & Directory Restructuring | [Complete — see changelog](changelog.md#m15--workflow-convergence--directory-restructuring) |
| **M2 — Reasoning/Capability Layer Separation** | **In progress** |
| &nbsp;&nbsp;[M2.1 — General Capability Layer Prototype](changelog.md#m21--general-capability-layer-prototype) | Complete |
| &nbsp;&nbsp;[M2.2 — Reasoning Layer Modularisation](changelog.md#m22--reasoning-layer-modularisation) | Complete |
| &nbsp;&nbsp;[M2.3 — Apply Workflow: Capability Layer Diff Pipeline](changelog.md#m23--apply-workflow-capability-layer-diff-pipeline) | Complete |
| &nbsp;&nbsp;[M2.4 — Session and Config Persistence](#m24--session-and-config-persistence) | Complete |
| &nbsp;&nbsp;[M2.6 — Session Resume and Mount Model Redesign](#m26--session-resume-and-mount-model-redesign) | In progress |
| &nbsp;&nbsp;[M2.7 — Session Identity and Harness Versioning](changelog.md#m27--session-identity-and-harness-versioning) | Complete |
| **M3 — Autonomous Task Execution, Manual Review Workflow** | Not started |
| **Multi-Agent** | |
| &nbsp;&nbsp;M4 — Metadata Seeding | Not started |
| &nbsp;&nbsp;M5 — Agent-Assigned Branch Management | Not started |
| &nbsp;&nbsp;M6.1 — Task Dispatch | Not started |
| &nbsp;&nbsp;M6.2 — Constraint Enforcement | Not started |
| &nbsp;&nbsp;M6.3 — Review & CI/CD Integration | Not started |
| **Standalone** | |
| &nbsp;&nbsp;M7 — Safe vs Unsafe Mode (Policy Layer) | Not started |
| &nbsp;&nbsp;M8 — Skills / Templates | Not started |

---

## User Stories

Open stories under active investigation. Closed stories are removed from this list.

- [`20260522-story-active-prompt_eval_infrastructure.md`](./discussions/20260522-story-active-prompt_eval_infrastructure.md) — How do we test that skills and prompt templates correctly reflect the policy documents they encode? Manual read-through comparison doesn't scale across N skills × M policy sections.

---

## Upcoming Milestones

### M2 — Reasoning/Capability Layer Separation

**Objective:** Separate the harness into a reasoning layer (agent container) and a capability layer (sandbox container, working content, optional MCP server). This is the foundational architectural change that enables vault workflows, webapp workflows, provider swapping, and autonomous task execution. All M1.x architecture documents are hot during this milestone and updated sub-milestone by sub-milestone.

Conceptual model: [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md)
Design rationale: [`investigation_mcp_server.md`](./discussions/investigation_mcp_server.md) — Conclusion

#### M2.4 — Session and Config Persistence

**Objective:** Establish the provider config lifecycle — onboarding-time population, seeding of provider-layer prompts/skills, and session history persistence — ensuring state survives between container restarts across all host filesystem types.

**Work completed:**
- Directory bind mount (M2.7) — session history persists via `sessions/` bind mount; `bin/` cross-device mv issue resolved by owning the directory in the image (see `providers/pi/provider.Dockerfile`) rather than tmpfs, which was removed for simplicity
- Provider-layer prompts/skills seeded from `providers/<n>/config/agent/` via onboarding
- Auth tokens stored as env var references in `auth.json` (ephemeral by design — security feature, prevents write-back of secret values)
- Selective bind mount pattern (`sessions/`, `prompts/`, `skills/` persisted; remaining config ephemeral via copy-in) — resolution for cross-filesystem `utime()`/`EPERM` issue on macOS/Windows Docker Desktop

**Status:** Complete. Design settled; implementation artifacts applied (M2.7+). See handovers `20260407-03-close-m2_4.md`, `20260513-10-impl-settings_json_collision_fix.md`, `20260522-05-design-pi_agent_mount_strategy.md`.

**Scope note:** M2.4 covers config and state persistence infrastructure. It does not define or validate provider-level session resume — the ability to continue a prior conversation. That is scoped to M2.6.

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
> 1. **Worktree mount** — a `git worktree` is created from `PROJECT_DIR` and mounted into the reasoning layer. `PROJECT_DIR/.git` is mounted RO into the capability layer only. Keeps `.git/config` and `.git/hooks/` out of the agent's reach. The agent commits to a real branch in the real repo; the operator reviews with native git tooling. See [`devlog/discussions/20260622-study-settled-security_delta_worktree_model.md`](./discussions/20260622-study-settled-security_delta_worktree_model.md) for full analysis.
> 2. **Snapshot mount** (default) — current model: `baseline.tar` unpacked into an anonymous volume, diff pipeline as sole output path. Maximum isolation. Agent changes flow through staged diffs; operator reviews before apply.

The user chooses the model per session. The default is snapshot mount (backward compatible). M2.6 implements the worktree mount (option 1) for pi as the primary integration target, with the architecture structured so other providers can reuse the wiring.

**Related documents:**
- [`docs/architecture/security.md`](../architecture/security.md) — invariant rewrites required (itemised in `20260622-study-settled-security_delta_worktree_model.md` Part 2)
- [`devlog/discussions/20260622-study-settled-security_delta_worktree_model.md`](./discussions/20260622-study-settled-security_delta_worktree_model.md) — full invariant comparison, residual risk analysis, and required mitigations
- [`devlog/discussions/story_agent_git_surface.md`](./discussions/story_agent_git_surface.md) — agent-in-git design questions (resolved by design: agent commits to a branch, operator reviews)
- [`devlog/discussions/20260522-story-settled-agent_state_persistence.md`](./discussions/20260522-story-settled-agent_state_persistence.md) — persistence model (resolved: mount-based persistence)
- [`devlog/discussions/story_container_layer_model.md`](./discussions/story_container_layer_model.md) — harness base layer design (settled; node harness implemented, python harness deferred — see W1)

---

### Scope

Focus on pi. The architecture should be extensible to other providers (Hermes, opencode) without rewrite. M2.6 proceeds in a fractal sub-milestone numbering scheme — each level nests under its parent (M2.6 → M2.6.n → M2.6.n.m → ...).

> **Ordering:** M2.6.1 and M2.6.2 are complete. M2.6.3 has remaining items. M2.6.4 requires a design session before any mount work begins. No mount work starts until M2.6.3 deliverables are accepted.

---

### M2.6.1 — Foundation (Complete)

- [x] **Autosave and session-save reliability** — Fixed EXIT trap `diff_export` return value capture, added `.export-status` + error logs, lockfile polling. Dry-run checks added. See `20260622-01-impl-m2_6_1_autosave_reliability.md` and `20260622-02-impl-m2_6_1_autosave_dry_run_checks.md`.
- [x] **Security model update** — Three-tier security model documented. 4 story docs closed with Resolution sections. See `20260622-P1-B` commit.
- [x] **Pi session resume** — Confirmed done by operator. No action needed.
- [x] **Repo precondition audit** — 12 findings (5 HIGH, 2 MED, 4 LOW, 1 NONE). Key risks: `snapshot_init_git()` hardcodes copy lifecycle, `start_agent.sh` always `rm -rf` + copy, compose template mounts `.snapshot/` as `read_only`, entrypoint preflight aborts if `baseline.tar` missing. See `20260622-03-study-m2_6_1_repo_audit_preconditions.md` for full table and recommendations.

### M2.6.2 — Volume-based Session Persistence (Complete)

- [x] **Scoping** — Decision model: .run-identity prefactor, named volume, conditional compose teardown, simplified entrypoint gating (check .git/HEAD only). Env var lifecycle documented per variable. See `20260701-02-design-m2_6_2_persistence_scoping.md`.
- [x] **Implementation** — .run-identity in start_agent.sh, named volume in compose template, conditional compose_teardown in compose.sh, volume-aware entrypoint gating, REFRESH flag documentation. See `20260701-03-impl-m2_6_2_persistence.md`.
- [x] **Documentation** — security.md Execution Model Assumptions updated, quickstart.md REFRESH flag and persistence documented, provider_onboarding_guide.md named volume note added, sandbox_lifecycle.md resume path subsection added, sandbox_identity.md .run-identity and env var lifecycle documented.

### M2.6.3 — Document consolidation (Complete)

- [x] **Document consolidation completed.** Single-use spec files rolled into handovers. Worktree mount model ADR written. Mount-model discussion docs superseded. Policy file disambiguation pass resolved: content overlaps trimmed, 3 procedural policies migrated to skill drafts, Step detail sections linked to child policies. Design policy extraction resolved: no standalone document needed — format rules consolidated under `discussion_policy.md#designs`.

### M2.6.4 — Mount Model Design and Implementation (In progress)

The mount model is defined by two axes — delivery (copy vs. mount) × backing (fresh baseline vs. worktree). Canonical record: [`devlog/discussions/20260722-design-active-mount_model.md`](./discussions/20260722-design-active-mount_model.md). Copy + fresh baseline is the current default and the only supported configuration. Mount delivery is not yet implemented. Worktree backing is not supported — mechanism proposed in [`devlog/discussions/20260722-design-active-worktree_mount_mechanism.md`](./discussions/20260722-design-active-worktree_mount_mechanism.md); its security assertion is contingent on implementation and a safety audit.

**Decisions:**
- Tier model replaced by delivery × backing axes; `security.md` asserts only implemented postures; mount-model ADRs consolidated into active design docs pending settlement — see the mount-model design doc, Consolidation note.
- Capability-layer git mediation retired — the agent runs git in the reasoning layer; repository-integrity controls are filesystem- and network-level — see the mechanism design doc.
- Raw project dir backing is a non-goal.

#### Pre-design investigations (complete)

- [x] **Extensibility structure audit** — 10 findings (1 HIGH, 2 MED, 2 LOW, 5 NONE). Key risk: AGENT_HOME bind mounts exist in Pi overlay only — Hermes/OpenCode have no AGENT_HOME persistence. Shared entrypoint is clean (no change needed). Produced documented shared vs. provider boundary. See `20260622-04-study-m2_6_4_extensibility_structure_audit.md` for full table and recommendations.
- [x] **`PROJECT_DIR` mount wiring** — Complete survey: copy mode fully achieved; mount delivery not implemented (3 gaps); worktree not implemented (7 implementation + 4 documentation gaps). See `devlog/discussions/20260722-study-settled-mount_wiring_survey.md`.
- [x] **Unify `make apply` and `make draft` apply logic** — Done (see `20260721-06-impl`). Internal apply logic unified: both now use `_apply_patch_file`/`apply_and_commit`. Command-level unification (combine the two CLI commands) remains open for the design session.
- [x] **Security model reframe** — Tier terminology removed from `security.md`; delivery × backing model adopted. See `20260722-05-design-security_model_reframe.md`.
- **Hermes and opencode session resume** — Deferred. Not investigated unless explicitly needed.

#### Remaining design questions (design session)

- WORKTREE_DIR as baked placeholder vs runtime variable (constraint C2 suggests baked)
- Separate compose overlay vs conditional mount in the base template
- Pi direct bind mounts (prompts/sessions/skills) under mount modes vs copy-in/copy-out
- `--volumes-from` retained or dropped under mount modes
- Role of `make apply` under worktree backing (branch diff vs `staged.diff`)
- Snapshot pipeline under mount/worktree modes — skip, or what does it produce
- Migration path — conditional flag at session start vs separate Makefile target

#### Anticipated tasks (scoped and confirmed by design session)

- Mount delivery enablement — `.snapshot/` mounted RW into the capability layer; agent works in `.snapshot/`; entrypoint redirect (survey gaps G2a–G2c)
- Compose template — conditional mount entries per mode
- Worktree lifecycle — per the mechanism design: `git worktree add/remove`, `refs/agent/` namespace, preflight permission hardening, teardown restore
- `make draft`/`make confirm`/`make reject` — adapt to operate on branches rather than applying diffs
- Migration path — copy-mode sessions continue to work; diff pipeline preserved as optional workflow
- Worktree safety audit — on pass: assert the worktree posture in `security.md`, record the mechanism ADR, settle both design docs (canonical mount-model ADR recorded)

#### W1 — Vault Capability Layer Prototype

**Status:** Deferred. Not a mainline milestone — separate workflow for the Obsidian vault use case. Re-activate when KV5 timeline demands it. See `roadmap_future.md` for task checklist.

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first, then add MCP server as enhancement. Unblocks KV5.

**Hermes python base refactor deferred — see `roadmap_future.md` §W1.**
The shared python-harness base (`src/reasoning/python.dockerfile`) was designed but never built.
Hermes currently builds independently from `python:3.11-slim` rather than inheriting from the harness.
This is non-urgent (Hermes not actively used). If W1 is made to work without Hermes,
consider whether to remove Hermes support entirely rather than maintaining a dormant provider.

#### M2.7 — Session Identity and Harness Versioning

**Status:** Complete. Hash-based identity model (SANDBOX_ID, RUN_ID), container lifecycle (naming, labels, stop/prune), artefact paths, build pipeline simplification (repo-root context, COPY contract tests), two-sig model (container-sig label + preflight), generic pre-flight validation, dual-layer dry-run seam testing, DIFF_TYPE flag, --no-renames flag. See handover chain `20260609-01` through `20260611-04` and changelog entry.

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

- **`docker compose down -v` race with EXIT trap** — When `stop.sh` runs `docker compose down -v`, the `-v` flag removes anonymous volumes referenced by `volumes_from`. If Docker Compose removes those before the sandbox container's EXIT trap finishes writing the session export, the export could be interrupted. Triaged as a plausible error but unlikely to be causing current problems — session-diffs are a bind mount (not affected by `-v`), and anonymous volume references on the agent service do not block the sandbox trap. Recorded for completeness from handover audit finding F3. No milestone assigned.
