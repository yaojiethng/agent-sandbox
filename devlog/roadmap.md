---
active-milestone: M2.6 - Session Persistence
active-milestone-status: in-progress
---

# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules - task granularity, cleanup on completion, section removal - are defined in [`docs/operations/roadmap_policy.md`](../docs/operations/roadmap_policy.md).

---

## Milestone Summary

| Milestone | Status |
|---|---|
| M1 - Barebones Agent Container | [Complete - see changelog](changelog.md#m1--barebones-agent-container) |
| &nbsp;&nbsp;M1.1 - Interactive Virtual Workspace / Serve Mode | [Complete - see changelog](changelog.md#m11--interactive-virtual-workspace--serve-mode) |
| &nbsp;&nbsp;M1.2 - Sandbox File Isolation & Diff Workflow | [Complete - see changelog](changelog.md#m12--sandbox-file-isolation--diff-workflow) |
| &nbsp;&nbsp;M1.3 - Invocation Cleanup & Onboarding Workflow | [Complete - see changelog](changelog.md#m13--invocation-cleanup--onboarding-workflow) |
| &nbsp;&nbsp;M1.4 - Image Staleness Detection | [Complete - see changelog](changelog.md#m14--image-staleness-detection) |
| &nbsp;&nbsp;M1.5 - Workflow Convergence & Directory Restructuring | [Complete - see changelog](changelog.md#m15--workflow-convergence--directory-restructuring) |
| **M2 - Reasoning/Capability Layer Separation** | **In progress** |
| &nbsp;&nbsp;[M2.1 - General Capability Layer Prototype](changelog.md#m21--general-capability-layer-prototype) | Complete |
| &nbsp;&nbsp;[M2.2 - Reasoning Layer Modularisation](changelog.md#m22--reasoning-layer-modularisation) | Complete |
| &nbsp;&nbsp;[M2.3 - Apply Workflow: Capability Layer Diff Pipeline](changelog.md#m23--apply-workflow-capability-layer-diff-pipeline) | Complete |
| &nbsp;&nbsp;[M2.4 - Session and Config Persistence](changelog.md#m24--session-and-config-persistence) | Complete |
| &nbsp;&nbsp;[M2.6 - Session Persistence](#m26--session-persistence) | In progress |
| &nbsp;&nbsp;[M2.7 - Session Identity and Harness Versioning](changelog.md#m27--session-identity-and-harness-versioning) | Complete |
| **M3 - Autonomous Task Execution, Manual Review Workflow** | Not started |
| **Multi-Agent** | |
| &nbsp;&nbsp;M4 - Metadata Seeding | Not started |
| &nbsp;&nbsp;M5 - Agent-Assigned Branch Management | Not started |
| &nbsp;&nbsp;M6.1 - Task Dispatch | Not started |
| &nbsp;&nbsp;M6.2 - Constraint Enforcement | Not started |
| &nbsp;&nbsp;M6.3 - Review & CI/CD Integration | Not started |
| **Standalone** | |
| &nbsp;&nbsp;M7 - Safe vs Unsafe Mode (Policy Layer) | Not started |
| &nbsp;&nbsp;M8 - Skills / Templates | Not started |

---

## User Stories

Open stories under active investigation. Closed stories are removed from this list.

- [`20260522-story-active-prompt_eval_infrastructure.md`](./discussions/20260522-story-active-prompt_eval_infrastructure.md) - How do we test that skills and prompt templates correctly reflect the policy documents they encode? Manual read-through comparison doesn"t scale across N skills x M policy sections.

---

## Upcoming Milestones

### M2 - Reasoning/Capability Layer Separation

**Objective:** Separate the harness into a reasoning layer (agent container) and a capability layer (sandbox container, working content, optional MCP server). This is the foundational architectural change that enables vault workflows, webapp workflows, provider swapping, and autonomous task execution. All M1.x architecture documents are hot during this milestone and updated sub-milestone by sub-milestone.

Conceptual model: [`docs/concepts/two_layer_model.md`](../docs/concepts/two_layer_model.md)
Design rationale: [`investigation_mcp_server.md`](./discussions/investigation_mcp_server.md) - Conclusion

#### M2.4 - Session and Config Persistence

**Objective:** Establish the provider config lifecycle - onboarding-time population, seeding of provider-layer prompts/skills, and session history persistence - ensuring state survives between container restarts across all host filesystem types.

**Work completed:**

- Directory bind mount (M2.7) - session history persists via `sessions/` bind mount; `bin/` cross-device mv issue resolved by owning the directory in the image (see `providers/pi/provider.Dockerfile`) rather than tmpfs, which was removed for simplicity
- Provider-layer prompts/skills seeded from `providers/<n>/config/agent/` via onboarding
- Auth tokens stored as env var references in `auth.json` (ephemeral by design - security feature, prevents write-back of secret values)
- Selective bind mount pattern (`sessions/`, `prompts/`, `skills/` persisted; remaining config ephemeral via copy-in) - resolution for cross-filesystem `utime()`/`EPERM` issue on macOS/Windows Docker Desktop

**Status:** Complete. Design settled; implementation artifacts applied (M2.7+). See handovers `20260407-03-close-m2_4.md`, `20260513-10-impl-settings_json_collision_fix.md`, `20260522-05-design-pi_agent_mount_strategy.md`.

**Scope note:** M2.4 covers config and state persistence infrastructure. It does not define or validate provider-level session resume - the ability to continue a prior conversation. That is scoped to M2.6.

#### M2.6 - Session Persistence

**Objective:** Make the agent"s working state survive container stop/start cycles. Two implementation paths offer different security/convenience trade-offs - both are valid and may coexist per session.

**Foundation** (M2.6.1-M2.6.2): The shared infrastructure both paths depend on - session identity, volume lifecycle, container persistence, compose primitives.

**Path A - Copy Model** (M2.6.5): Volume-backed sandbox. Snapshot pipeline copies host state into a Docker volume at session start. Agent works in the volume. Volume persists across stop/start. Highest isolation.

**Path B - Mount Model** (M2.6.6): Host-backed sandbox. A host directory (`.sandbox` in `SANDBOX_DIR`) is bind-mounted into the container. Agent works directly on the host filesystem. No copy overhead, no diff pipeline. Higher convenience, lower isolation.

**Depends on:** M2.4 (bind mount infrastructure), M2.7 (session identity, SESSION_ID, container lifecycle).

##### M2.6 - General cross-cutting track

Completed work, at contract level (history in handovers/changelog):

- [x] **Session lifecycle invariant** - a single teardown dispatch (`session_teardown`/`session_destroy`) covers standard, serve, and failure paths, including a sandbox health-check timeout; `docker compose down` preserves named volumes, so session data survives stop/start and `resume` re-attaches the same `SESSION_ID`-stable volume; compose networks are labelled and removed with the session; shutdown prints the copy-paste resume command.
- [x] **Session identity + registry contract** - single canonical `SESSION_ID = sha256(canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS)[:6]` ([`session_identifier.md`](../docs/adr/session_identifier.md)); `.compose/<session-id>.yml` is the registry of truth for resume and prune (a run with no matching record is prunable; worktrees never touched); docker labels (sandbox-dir, session-id) bake the canonical path independent of `--sandbox` spelling; compose is generated from a base plus a delivery overlay per mode (`SANDBOX_TYPE=copy|mount`) and the merged file persists under `.compose/` for inspection.
- [x] **CLI surface** - `agent-sandbox start|dry-run|stop|resume|prune` with unified `--help` before arg validation; `make start` always starts a NEW session (interactive config wizard; `SERVE=1` toggles serve mode); `make resume` inventories the registry (`--session-id=<id>` silent; `--list`; `--interactive`; `PROVIDER=` filter); `onboard --refresh` re-syncs derived paths in place and never clobbers an existing sandbox.
- [x] **Copy delivery + diff export contract** - the sandbox volume is seeded host-side before container start via a git-enumerated tar (baseline `git archive` + tracked/untracked members; `.snapshot/`/`SNAPSHOT_DIR` retired); diff export is git-verbatim with `--no-renames` by default; empty diffs skip with a warning; empty directories are not carried (git cannot represent them - accepted). Model: [`copy_delivery.md`](../docs/concepts/copy_delivery.md). **Being replaced by the helper-container seed - see open entry below.**
- [x] **Build + dry-run interface** - standard invocation: provider ENTRYPOINT is the harness wrapper, agent binary via `CMD`, and `command:` is the single extension point across standard/serve/dry-run; image build fails closed with a descriptive error; dry-run runs each bearer container's readiness self-checks, writes per-container diagnostics, and gates on a hard image-staleness check; readiness probes are unit-tested in isolation. Design: [`20260828-design-settled-dry_run_phase_split.md`](./discussions/20260828-design-settled-dry_run_phase_split.md).
- [x] **Test harness + conventions** - tests run under the production `set -euo pipefail` runtime with an assert-helper quartet; non-gating gates: `make lint`, `make test-smoke`, `make lib-liveness`; a test belongs under `make test` when the seam is maintained code - knowledge tests only for unmodifiable seams; entry points are dual-use guarded with a four-class shell-flag policy; `container_sig` fails closed on missing source paths.
- [x] **Vocabulary** - [`session`](../docs/concepts/terminology.md#session) (one container lifecycle, identified by `SESSION_ID`) and [`iteration`](../docs/concepts/terminology.md#iteration) (one work cycle - handover + commit) are reserved technical terms; `RUN_ID`/`unit` retired; bundle flags/vars renamed `BUNDLE_*`; all consumers swept.
- [x] **Documentation records** - ADRs are living, component-scoped rationale records (dated entries, append-and-demote, failure-locus rejections, optional requirements preamble); six per-principle ADRs live in `docs/adr/` and are registered in `project_index.md`; concept docs are standalone behavioral-contract explainers (interface level; defect history and internal command sequences live in the ADR); drafting follows skeleton-first, records-state steering with STE100 quick rules.
- **Decision - handover close = the commit:** `iteration_policy.md` Step 8 ("The close is the commit"); enforced by GOTCHAS entry.

Open:

- [ ] **SERVE mode integration (standalone item)** - SERVE is not in regular use and may be out of date; the serve overlays (hermes/opencode) were rebased to the standard invocation interface (prefixing the binary in `command:`) but NOT docker-tested (operator: not convenient); pi currently lacks feature integration to support server mode. Scope: verify/enable `make serve` per provider (uses + retest + rebase correctness), add pi server-mode feature support, reconcile with the standard `command:` interface. Elevation from `20260828-02` finding. A real-session smoke test (`make start`) confirms standard mode post-standardization, but serve remains unverified.
- [x] **Harness version identity (image + worktree + host) - DESIGN SETTLED `20260901-02`; IMPLEMENTED `20260904-07` (handover 20260904-07)** - the `make resume LIST=1` slowness (`record_image_stale` -> 2xN docker inspects), the `[IMAGE_STALE]` marker / preflight warnings, the `container-sig`/`harness-sig`/`image-sig` proliferation, silent host-CLI drift, and the deferred digest-tracking are ONE root problem: no serializable, increasing version on any of the three surfaces (container image content, git worktree checkout, host installed CLI). Story `20260831-*-image_and_harness_version_identity` frames it (Resolved); design stub settled + ADR `harness_versioning.md` recorded (**Status: settled** = decision recorded; **task stays open until impl lands**). Mechanism: image-surface = docker digest (record as `agent-sandbox.agent-image-digest`/`sandbox-image-digest`); worktree = plain `$REPO_ROOT` HEAD (absorbed into interface-contract thread, no record field); host = symlink install (self-locating dispatcher, no separate version; semver deferred to packaging); freshness signal retired; dry-run = always-current-source + digest roundtrip gate; `container-sig` reframed as interim leaky contract check (scoped for deletion). **Next: impl iteration** - record labels, symlink install, dry-run digest roundtrip, retire list-time staleness + `record_image_stale`, temporary container-sig transition double-check then removal; closes the ADR.
- [ ] **Interface-contract compatibility (deferred design thread, raised `20260901-02`)** - the real need behind the retired freshness signal: the host checkout driving a session and the wiring baked into the image must speak the same SHAPE (bind-mount folder shape, `SANDBOX_DIR` format, onboard command shape, host/container command semantics - the change-class-1/2/3 High band). Two contract points host-vs-container framing misses: (1) intra-session container<->container drift (agent vs sandbox images buildable independently via `--targets=agent|sandbox`); (2) session-record schema as a resume-breaking contract (`.compose/<session-id>.yml` + in-worktree `SESSION_STATE` written by host, read by both host-resume/list and container-entrypoint). Planned mechanism: an explicit interface/contract version declared+compared by each co-resident copy (bumped only when the cross-boundary contract changes; immune to doc edits); `container-sig` is the interim implementation.
- [ ] **Dry-run semantics overhaul (raised `20260901-02`)** - dry-run is the operator's e2e/diagnostic for CURRENT source: it must always build/run current source, so a stale container even after a fresh build is an ERROR, not a warning. `[IMAGE_STALE]` was a stopgap for un-refactored dry-run. Gate = structural phase-3 record verification + a digest roundtrip (running image repo-digest == just-built-from-current-source digest). `--fast`/headless (cached/skip build) is deferred into this refactor's scope, not the version-identity design. Also test `resume` semantics (dry-run controls its container fully, so it is a good resume testbed).
- [ ] **Delete the sed-extraction probe layer; source the guarded scripts directly in tests** - `scripts/prune.sh`, `scripts/onboard.sh`, `scripts/start_agent.sh` now carry dual-use guards (flag parsing inside `main()`), so the bounded sed-extraction probes in `tests/test_prune.sh` (`_env_field_probe`), `tests/test_onboard.sh` (`_template_version_probe`), and `tests/test_start_agent.sh` (`_wsl_path_probe`) are redundant and break silently on function renames. Source each script and call its functions directly; delete the probe layer. Surfaced in handover `20260901-10`; recorded as follow-up in AGENT_FEEDBACK (dual-use guards entry, probation).
- [x] **Testing-policy cleanup (handover `20260902-01`)** - **done `20260904-08`.** discovery_ prefix: resolved by removal `20260904-06` (both probes retired with the legacy seed pipeline they probed). `test_list_no_sig_when_field_empty`: verified registered and passing. Mechanical liveness checks: `scripts/check_test_liveness.sh` (`make test-liveness`) - every `test_*()` registered via `run_test`, every target resolves, docker stub + stub-lib prerequisite liveness; registration rule added to `docs/development/testing_policy.md`.
- [ ] **Mount worktree with full git history (future clone strategy, M2.6 general - not active delivery)** - materialize the mount worktree WITH full git history (common ancestor with PROJECT_DIR -> git-based port-back becomes possible alongside the diff pipeline). General M2.6 sequencing note, not part of the M2.6.6 delivery task set (relocated out of M2.6.6 so that sub-milestone can compact); design and implement once the base mount delivery is complete (future clone-strategy addendum, walk `20260818-02`).
- [x] **Seed transport redesign: helper-container copy** - **done `20260904-04`..`20260904-06` (wiring + live-verified fixes + removal, handovers 20260904-04/05/06).** Design settled `20260904-01` (handover `20260904-01-design-start_resume_rsync_stall.md`, design doc `20260904-design-settled-helper_container_seed.md`, ADR entry 2026-09-04). Replace the 7-step `docker cp` seed with a one-shot seeder container (project mounted read-only at `/src`, session volume at `/dest`; copy `.git` natively, stream git-enumerated tar, mixed reset to HEAD). Retires: host tar build + member-prefix transform, stdin 0B read-back verification, `baseline.tar` unpack + mixed init, rsync overlay + symlink repair, in-worktree `.agent-sandbox-seed/` staging (new requirement R7: no staging in the worktree). Includes: compose seeder wiring (exit-code readiness, hard timeout, fail-fast on container start failure), `run_agent.sh` seed-path retirement, `snapshot.sh`/entrypoint cleanup, mount-path `snapshot_copy_worktree` enumeration fix (negation leak, ADR 2026-09-04), trace-test rewrites, fail-closed tripwire for repos already tracking harness state, architecture doc sweep (`execution_model.md`, `sandbox_lifecycle.md` — deferred from the design iteration).
---

##### M2.6.1 - Foundation: Autosave, Security, Preconditions (Complete)

- [x] Autosave/session-save reliability (EXIT-trap export with return-value capture, `.export-status`, lockfile polling); security model documented; pi session resume confirmed; repo precondition audit (12 findings).

##### M2.6.2 - Foundation: Volume Lifecycle, Container Persistence (Complete)

- [x] Named volume per session with conditional compose teardown; `compose stop` preserves stopped containers; `--reset-volume`; compose project-name leak fix; pre-start cleanup consolidated in `run_agent.sh`.

##### M2.6.3 - Document Consolidation (Complete)

- [x] Single-use spec files rolled into handovers; policy disambiguation complete; `devlog/` extracted as top-level directory.

##### M2.6.4 - Mount Model Design (Complete)

- [x] Two-axis model settled (delivery: copy/mount x backing: user-provided `.git`); security model reframed; capability-layer git mediation retired; worktree backing rejected - [ADR](../docs/adr/sandbox_delivery_model.md). Four pre-design investigations complete.

##### M2.6.5 - Copy Model: Volume-backed Sandbox (Complete)

**Objective:** Complete the volume-based persistence model. The agent works in a Docker volume backed by the snapshot pipeline. Changes exported via diff pipeline. Volume survives stop/start. Maximum isolation from the host.

- [x] Label-filtered volume prune (aged by `PRUNE_AGE_DAYS`); volume-per-session via `SESSION_ID`-scoped compose projects with locking and an interactive selector; draft rollback via a local savepoint tag on patch failure. Design: [`devlog/discussions/20260730-design-settled-copy_model.md`](./discussions/20260730-design-settled-copy_model.md).

##### M2.6.6 - Mount Model: Host-backed Sandbox (In progress)

**Objective:** Mount a host directory (`.sandbox` in `SANDBOX_DIR`) into the container instead of using a Docker volume. The agent works directly on the host filesystem - no copy-in, no diff pipeline, no autosave as primary persistence. Session resume is instant: the files are already there.

**Security posture:** The sandbox inherits the security posture of the host directory. The operator is responsible for ensuring secrets are not present in the mounted directory. This is a lower-isolation model than the copy-based default - the trade-off is convenience.

- [x] **Mount model design settled** - two-axis model; design questions Q2/Q4/Q7 and N1-N5 resolved (walk `20260818-02`; record `devlog/discussions/20260730-design-settled-mount_model.md`); `security.md` rewritten for the two-path model.
- [x] **Mount delivery enablement (wiring)** - capability entrypoint is delivery-aware (mount validates `.git` + init marker, skips snapshot gate/init, writes `SESSION_STATE` into the worktree `.git`); `start_agent.sh` materializes the worktree via the shared snapshot primitive minus `baseline.tar`; `SANDBOX_TYPE` per-overlay literals.
- [ ] **Mount delivery runnability** - close the no-mount/`baseline.tar`-transfer gap so the wired mount path runs end-to-end (runnability verification outstanding, handover `20260828-01`).

###### Not in scope - Worktree backing (Rejected)

Worktree backing is rejected. See [ADR - Worktree Backing Rejected](../docs/adr/sandbox_delivery_model.md) and the [full investigation record](discussions/20260730-study-settled-worktree_rejection.md).

#### M2.7 - Session Identity and Harness Versioning

**Status:** Complete. Hash-based identity model (SANDBOX_ID, SESSION_ID), container lifecycle (naming, labels, stop/prune), artefact paths, build pipeline simplification (repo-root context, COPY contract tests), two-sig model (container-sig label + preflight), generic pre-flight validation, dual-layer dry-run seam testing, DIFF_TYPE flag, --no-renames flag. See handover chain `20260609-01` through `20260611-04`.

#### Not in scope

Items indefinitely deferred or explicitly excluded from M2 scope.

- **Submodules not supported.** `snapshot_enumerate_files` detects gitlink entries and aborts with a clear message. Operators must deinitialise submodules before running the harness.
- **Bad diff applied to host repo corrupts future snapshots.** `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`. The risk is after the operator applies a bad diff - the host repo is then in a bad state and future snapshots reflect it. See Recovery in `docs/development/quickstart.md` for how to reset.
- **Multi-service project composition not supported.** Projects requiring additional services (databases, test containers) have no mechanism to inject them alongside the harness-managed sandbox and agent. See `execution_model.md` for the deferred discussion.

---

## Notes

- Future milestone detail: [`roadmap_future.md`](roadmap_future.md).
- Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../docs/architecture/security.md).
