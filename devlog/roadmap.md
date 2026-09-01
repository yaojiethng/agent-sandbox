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

##### M2.6 - General CLI/infra refactor track (cross-cutting, deferred from handover `20260810-04`)

Technical debt from the `c975d37` help-fix session - the interim `wants_help`
workaround and the `SCRIPT_DIR` shared-lib side effect. Split into three sessions
(operator-directed):

- [x] **Finding B - remove `SCRIPT_DIR` side effect from `common.sh`** - make
  `common.sh` a pure flag-parsing library; `stop.sh`/`prune.sh` self-resolve
  `SCRIPT_DIR` consistently; drop the obsolete comment in `start_agent.sh`. (This
  session.)
- [x] **Descriptive STE100 rename of the script-dir variable** - repo-wide
  cleanup, done only after the injection mechanism is removed. Includes a
  `tests/` sweep.
- [x] **Finding A/C - unify `--help` across all subcommands** - extract
  `route_help()` in the dispatcher; fix `--help` for every subcommand before arg
  validation; delete `wants_help`; update `test_dispatch.sh`.
- [x] **Docker network leak fix** - `compose_stop` -> `docker compose down`
  (keep named volumes), label the compose default network, label-based teardown
  in `stop.sh`. Session `20260810-10`. Carried findings: run_agent unified
  teardown refactor; compose-file persistence (`.compose/<session-id>.yml`);
  docker-verb semantics decision.
- [x] **Build-output single-line progress fix** - `build_image` uses array
  dispatch (`build_cmd[]`) with a single self-updating progress line on TTY
  via `_buildkit_run` (`src/libs/buildkit_progress.sh`), showing the real
  current BuildKit step (parsed from `--progress=plain` output). Sessions
  `20260810-11` (initial `--progress=auto` - incomplete - `auto` on TTY is
  still multi-line) and `20260812-01` (array collapse + BuildKit step parsing).
- [x] **Build-output progress + silent build-failure fixes** - desktop-usable build progress: first a single-line BuildKit-progress utility (`buildkit_progress.sh`), then reverted to docker `auto` when the single-line rendering proved unreliable (`buildkit_progress.sh` kept dormant, restore only when reliable). `build_image` fails closed with a descriptive `build_image: ERROR build FAILED ...` under both TTY and non-TTY via `|| true` / `|| _rc=$?`. Sessions `20260810-11`, `20260812-01`, `20260812-03`, `20260821-01`.
- [x] **String-as-list -> array refactor (removes SC2086 disables)**  -- 
  `stop.sh` `CONTAINER_IDS`/`NETWORK_IDS` -> `mapfile` arrays;
  `build_image` `$no_cache` -> `cache_args` array. Test-enablement rolled in:
  docker stub emits IDs via `DOCKER_STUB_PS_IDS`/`DOCKER_STUB_NETWORK_IDS`;
  stale `test_stop_uses_docker_ps` replaced by three behavior tests.
  Session `20260810-12`.
- [x] **Run_agent unified teardown dispatch** - mode branch runs the session
  only; single teardown dispatch after it; `compose_stop`/`compose_destroy`
  renamed to `session_teardown`/`session_destroy`; standard mode now tears
  down even on agent failure and propagates the agent"s rc (exit semantics
  documented); serve exits 0. Stale `security.md` `compose stop` claim
  corrected. Session `20260810-13`. Carried: session-naming collision
  (replaces the docker-verb semantics decision - the bad `compose_stop` name
  is gone; what remains is the harness "session" vs ops "session" overlap);
  compose-file persistence; `compose_sandbox_wait` failure-skip teardown gap.
- [x] **Compose-file persistence** - the merged compose file is written to
  `$SANDBOX_DIR/.compose/<session-id>.yml` and persists after the session
  (inspection/compose-aware tooling handle; devcontainer Shape-3 blocker
  removed). SESSION_ID available at generation time (start_agent.sh exports it).
  Docs reversed the tmpfile model (execution_model.md Compose Generation,
  tool_interface.md, docker-compose.yml header); `.compose/` gitignored.
  Session `20260810-14`. **Deferred: pruning of stale `.compose/*.yml`**
  (accumulation is KB-scale; candidate: `stop.sh --prune` host-artifact
  extension; routine implementation - no ADR needed). **Staleness-criteria
  restoration sub-task: see the prune-command redesign below (L141).**
- [x] **Prune-command redesign (registry + shape)** - **Rule 2 CONFIRMED** (design walk `20260818-02`): at prune time, a session under the current sandbox with no matching `.compose/<session-id>.yml` is prunable - scope differs by delivery (copy -> volume + containers; bind-mount -> registry resources only; worktrees never touched, D8/D4). **Command SHAPE redesign DEFERRED** until the M2.6.5/M2.6.6 artifact shapes settle; `STALE=1` terminology REJECTED. **Staleness-criteria restoration sub-task (finding `20260821-05`):** port the volume/sandbox staleness criterion to `.compose/<session-id>.yml` as source of truth (D7) vs the legacy volume labels; reuse `resume --list` shape for prune; the image-staleness column is docker-dependent and untestable in-container (superseded by the harness-version-identity reconciliation - see the image-staleness entry).
- [x] **`compose_sandbox_wait` teardown gap** - sandbox health-check timeout
  exits before unified teardown dispatch, leaving containers running.
  **Resolved** - the unified teardown dispatch (run_agent EXIT trap on
  `TEARDOWN_NEEDED`, set before `compose_sandbox_wait`) tears down on
  sandbox-wait failure; guarded by `test_standard_sandbox_unhealthy_still_tears_down`
  (docker-stub forces never-healthy, asserts `compose down` runs).
  Surfaced session `20260810-13`; resolved by the `20260810-14` teardown refactor,
  confirmed `20260812-12`.
- [x] **Terminology sweep - deconflict the term "session"; register `session` + `iteration` as reserved technical terms** - mapping REVERSED from the design walk (operator, session `20260819-09`). Two reserved technical terms in the register ([`docs/concepts/terminology.md`](../docs/concepts/terminology.md)): [`session`](../docs/concepts/terminology.md#session) = one container lifecycle (start -> teardown; identified by `SESSION_ID`); [`iteration`](../docs/concepts/terminology.md#iteration) = one work cycle producing a handover + commit. **Replaced terms:** `run`/`RUN_ID` -> `session`/`SESSION_ID` (container lifecycle, phase 4); `new-session` skill -> `new-iteration`; `unit` dropped; bundle CLI/flags/vars (`SESSION_*` -> `BUNDLE_*`, phase 5A/5B). All consumers swept (policy docs, prompts, skills, concepts, `project_index`, Makefile, tests). Historical handovers not retro-renamed (Bucket C3); dual-grep bridge logged as GOTCHAS `[G] 2026-08-19`. Sessions `20260819-09` through `20260819-15`. Suite 476/0/0 (phase 4), 462/0/0 (phase 5).
- [x] **`start`/`resume` redesign (two-command split)** - **Design SETTLED** (walk `20260818-02` + F2 `20260821-02`, D1-D11): `make start` unconditionally starts a NEW session (interactive form = provider/config wizard, done `20260821-06`); `make resume` inventories the `.compose/<session-id>.yml` registry and resumes (`--session-id=<id>` silent; `PROVIDER=` narrows; `--interactive` picker+confirm; bare -> help). Supersedes the earlier merged-wizard sketch and the `--run` flag. The serve/dry-run interface is a separate deferred entry below.
- [x] **Start/serve/dry-run interface + dry-run readiness/execution refactor** - serve became an on/off toggle on `start` (standalone verb removed, `20260823-16`); dry-run reshaped into a readiness/ownership refactor (`20260828-01`): bearer containers each run readiness self-checks and write per-container diagnostics records; a hard image-signature (staleness) gate validates the correct container; standard invocation interface (providers' ENTRYPOINT = harness wrapper, agent binary via `CMD`, `command:` = the single extension point across standard/serve/dry-run). Verified e2e: `make dry-run PROVIDER=pi REBUILD=1` -> ALL PHASES PASSED; negative staleness test confirmed. Design: [`20260828-design-settled-dry_run_phase_split.md`](./discussions/20260828-design-settled-dry_run_phase_split.md). Handovers `20260828-01`, `20260828-02`.
- [x] **Dry-run probe-check unit-test harness** - **done `20260828-03`.** Probes parameterized (`LIBS_DIR`/`ROOT`/`SANDBOX_DIR`, `EXPECTED_MOUNT_TARGET` defaults preserving container behavior); `test/stubs/libs/` provide minimal `session_state_read`/`diff_export`/`dirs_resolve`/`routing` stubs injected via `BASH_ENV`; `tests/test_dry_run_probe.sh` runs each readiness layer in isolation (47 tests, incl. a FAIL per red branch). Also hardened + consolidated `init_sha` validity: shared `init_sha_is_valid` (`git cat-file -e` object check) wired into the probe gate + all three knowledge diagnostics (fixing their stale `session.sh` sourcing).
- [ ] **SERVE mode integration (standalone item)** - SERVE is not in regular use and may be out of date; the serve overlays (hermes/opencode) were rebased to the standard invocation interface (prefixing the binary in `command:`) but NOT docker-tested (operator: not convenient); pi currently lacks feature integration to support server mode. Scope: verify/enable `make serve` per provider (uses + retest + rebase correctness), add pi server-mode feature support, reconcile with the standard `command:` interface. Elevation from `20260828-02` finding. A real-session smoke test (`make start`) confirms standard mode post-standardization, but serve remains unverified.
- [x] **`make start` shutdown output surfaces the resume command** - the post-session teardown in `run_agent.sh` now prints `Resume this session later: make resume SESSION_ID=<id>` (mirroring `make stop`), so closing `make start` gives a fully formed copy-paste resume command for the container just shut down. Covered by a regression test; `execution_model.md` session-exit note updated. Session `20260831-04`.
- [x] **Fix docker resource label reliability for prune Rule 2** - **done `20260831-08`.** `sandbox_dir_canon` moved to `src/libs/common.sh` (single canonical home, sourced by all four entrypoints) and applied once in start/resume (before compose/label baking) and stop/prune (before label filters), so the `agent-sandbox.sandbox-dir` label and every discovery filter share the canonical absolute path regardless of `--sandbox` spelling. Regression test asserts prune canonicalizes before its `ps -aq` filter; diagnostic aligns. `sandbox_identity.md` label-lifecycle table corrected (copy volumes carry session-id/ts). No name-pattern matching, no `docker system prune` shift. Suite 746/0/0. Coupled-after `20260831-07`. Raised `20260831-05`.
- [x] **`resume` session surfaces (was: session-id pass-through; blocked-on Finding 1 in `20260821-01-fix-start_agent_bugfixes.md`)** - implemented across `20260821-03`/`20260821-05`: `make resume --session-id=<id>` direct resume via `.compose/<session-id>.yml` registry lookup -> silent; `--list` enriched table (`SESSION_ID | provider | session-ts | branch`); `--interactive` picker+confirm; `PROVIDER=<n>` inventory filter (list/interactive); bare->help. `start` no longer carries resume args (`--resume`/`--session-id`; `SESSION_ID_FLAG` stays `stop`-only); `stop.sh` prints `make resume SESSION_ID=<id>`. Remaining for `start`/`resume` redesign: the `make start` interactive config wizard (D11).
- [ ] **Harness version identity (image + worktree + host) - DESIGN SETTLED `20260901-02`; impl NEXT** - the `make resume LIST=1` slowness (`record_image_stale` -> 2xN docker inspects), the `[IMAGE_STALE]` marker / preflight warnings, the `container-sig`/`harness-sig`/`image-sig` proliferation, silent host-CLI drift, and the deferred digest-tracking are ONE root problem: no serializable, increasing version on any of the three surfaces (container image content, git worktree checkout, host installed CLI). Story `20260831-*-image_and_harness_version_identity` frames it (Resolved); design stub settled + ADR `harness_versioning.md` recorded (**Status: settled** = decision recorded; **task stays open until impl lands**). Mechanism: image-surface = docker digest (record as `agent-sandbox.agent-image-digest`/`sandbox-image-digest`); worktree = plain `$REPO_ROOT` HEAD (absorbed into interface-contract thread, no record field); host = symlink install (self-locating dispatcher, no separate version; semver deferred to packaging); freshness signal retired; dry-run = always-current-source + digest roundtrip gate; `container-sig` reframed as interim leaky contract check (scoped for deletion). **Next: impl iteration** - record labels, symlink install, dry-run digest roundtrip, retire list-time staleness + `record_image_stale`, temporary container-sig transition double-check then removal; closes the ADR.
- [ ] **Interface-contract compatibility (deferred design thread, raised `20260901-02`)** - the real need behind the retired freshness signal: the host checkout driving a session and the wiring baked into the image must speak the same SHAPE (bind-mount folder shape, `SANDBOX_DIR` format, onboard command shape, host/container command semantics - the change-class-1/2/3 High band). Two contract points host-vs-container framing misses: (1) intra-session container<->container drift (agent vs sandbox images buildable independently via `--targets=agent|sandbox`); (2) session-record schema as a resume-breaking contract (`.compose/<session-id>.yml` + in-worktree `SESSION_STATE` written by host, read by both host-resume/list and container-entrypoint). Planned mechanism: an explicit interface/contract version declared+compared by each co-resident copy (bumped only when the cross-boundary contract changes; immune to doc edits); `container-sig` is the interim implementation.
- [ ] **Dry-run semantics overhaul (raised `20260901-02`)** - dry-run is the operator's e2e/diagnostic for CURRENT source: it must always build/run current source, so a stale container even after a fresh build is an ERROR, not a warning. `[IMAGE_STALE]` was a stopgap for un-refactored dry-run. Gate = structural phase-3 record verification + a digest roundtrip (running image repo-digest == just-built-from-current-source digest). `--fast`/headless (cached/skip build) is deferred into this refactor's scope, not the version-identity design. Also test `resume` semantics (dry-run controls its container fully, so it is a good resume testbed).
- [x] **ADR-policy revision (done `20260901-03`)** - redesigned ADRs from the immutable-snapshot ledger into a living, component-scoped record of *rationale*. `docs/operations/adr_policy.md` reworked: purpose (the why behind standing principles), unit of record (a standing principle, not a design), spawn criterion (consequence reaches beyond the introducing change), liveness/evolution (dated entries, current-on-top, append-and-demote with condensation + why-rejected), per-entry statuses (file has none), archive (`docs/adr/archive/`). `documentation_policy.md`: added `adr/` to Folder Structure, slimmed Concepts-docs section to the model-vs-rationale boundary (defers production guidance to `adr_policy.md`), added record-invariant-shifts-now rule, header reconciliation for ADRs, removed `discussions/` row (governed by its own policy). Existing ADRs moved to `docs/adr/archive/` awaiting review. **Next: follow-up task** (below) - recreate ADRs under the new living format + sweep concept docs to distill ADR rationale + re-point links.
- [x] **ADR recreation + concept-doc sweep (follow-up to `20260901-03`, done `20260901-04`)** - recreated all six archived ADRs as living per-principle files in `docs/adr/`: `session_identifier.md` (consolidates the 20260722 two-stage + 20260831 canonical derivation chain as historical→current entries; marker-schema decisions remain in force), `harness_versioning.md` (from `20260901` version-identity mechanism), `sandbox_delivery_model.md` (from the worktree rejection, incl. the removed `20260721` worktree-mount-model as historical entry), `policy_declarative_framing.md`, `diff_packaging.md`, plus new `drift_state_coherence.md` (coherence by minimisation-not-detection; container-sig reframed as interim contract check). `docs/adr/archive/` retained as-is. Concept sweep: `sandbox_identity.md` and `terminology.md` carry further-reading links to the drift/versioning ADRs (stale image-staleness framing flagged as current-until-impl); `two_layer_model.md` header/link fixes; rationale distilled, the *what* kept. Re-pointed every `docs/adr/` reference across docs, skills, roadmap, and closed handovers/discussions to the new stable names; rewrote the non-conforming `skills/domain-model/ADR-FORMAT.md` to the living format. Registered all six ADRs in `project_index.md`.
- [x] **`make resume` volume reuse - verified (Bug D, done `20260828-04`)** - resume **preserves** the session volume; no production bug found. Trace of copy + mount deliveries shows teardown is `compose down` (never `down -v`/`volume rm`/`--reset-volume`), sandbox re-attached via `compose up -d sandbox`, and the namespace/volume name is SESSION_ID-stable (record SESSION_ID reused, so the `SESSION_ID-sandbox-data` volume is re-attached). The original "RESUME reset" was the **deprecated** `make start RESUME=1` (fresh start by design; old volume preserved). 11 regression tests lock in the no-destroy + namespace-stability invariants (`tests/test_trace_resume.sh`, both deliveries); suite 719/42. A latent test-runner stdin bug surfaced by the new tests was also fixed (tests run with stdin from `/dev/null`).
- [x] **Run test scripts under `set -e`** - tests run under `set -uo pipefail` without `-e`, so trace tests never exercised the production `set -euo pipefail` runtime (how the silent `REFRESH`-build abort slipped through). **Resolved `20260812-12`:** `build.sh` self-enables `set -euo pipefail` on standalone invocation (guarded by `BASH_SOURCE[0]==$0` so sourcing doesn't mutate callers); added `test_build_image_failure_surfaces_descriptive_error_under_e` + `DOCKER_STUB_BUILD_RC`.
- [x] **Shellcheck findings cleanup in `build.sh`** - pre-existing `SC2046` (unquoted `$(_sandbox_sig_sources)`/`$(_agent_sig_sources)` in `container_sig`/`build_sandbox`) and `SC2034` (`sandbox_dir` unused in `preflight`). Unrelated to the `20260812-03` fix; cleanup task escalated from that session. **Resolved - session `20260812-04`:** sig-sources emit per-line `printf` and are consumed via `mapfile` + `"${arr[@]}"` (SC2046 gone); `preflight` dropped the dead `sandbox_dir` param (SC2034 gone). Full suite green (474, 0 failed).
- [x] **`container_sig` defensive `|| true` guard** - piped `find` could abort under `pipefail`/`set -e` if a source path were invalid. **Resolved `20260812-04`:** `container_sig` fails closed on a missing source path (`container_sig: ERROR: source path not found: <path>` + `return 1`) - loud diagnostic over a naive `|| true` (which would hash an empty set).
- [x] **`diff_export --no-renames` by default** - `diff_export()` now
  passes `--no-renames` to `package_branch` by default, producing delete+create
  diffs instead of rename operations. Fixes pre-existing bug where
  `package_branch` passed `INIT_SHA` as the NO_RENAMES argument, silently
  disabling the flag. 15-case knowledge test. Session `20260812-02`.
- [x] **Whitespace round-trip hardening (git-verbatim diffs)** - the exporter"s
  `sed` strip of trailing whitespace on `+`/`-` lines was removed at all 3
  sites (`package_branch.sh`, `diff.sh` x2); exports are now git-verbatim
  (only `strip_index_lines` blob-hash metadata is stripped). This fixes the
  0009 draft-apply failure (a removed-line trailing-space byte broke `git apply`
  pre-image matching) and prevents silent content corruption on added/CRLF
  lines. git apply never refuses trailing whitespace under the default `warn`
  policy. Covered by 3 new unit tests in `test_diff_helpers.sh` (removed-line
  preservation, verbatim round-trip, 8-class funny-whitespace/CRLF matrix);
  stale `knowledge_trailing_whitespace_context_mismatch.sh` deleted. Sessions
  `20260812-07`.
- [x] **Knowledge-test convention established (external seams vs unit tests)**  -- 
  `testing_policy.md` Test Placement rule: a test belongs under `make test` when
  the seam is our maintained code with an API; a knowledge test is only for
  unmodifiable seams (external binary/lib/network, legacy mid-refactor);
  `tests/integration/` holds still-not-runnable flows. Reclassified the wrongly-
  classified knowledge tests: internal `dirs.sh` path resolution -> `test_dirs.sh`
  (unit); internal diff_export rename pipeline -> `test_diff_rename.sh` (unit);
  `knowledge_diff_rename.sh` trimmed to git-external probing only; broken
  `knowledge_diff_export_container.sh`/`knowledge_session_diffs_path_resolution.sh`
  deleted (referenced a nonexistent `libs/` path). **`make test` invariant:**
  failed 0, skipped 0 enforced by runner; the 6 provider-structure skips in
  `test_run_agent.sh` made deterministic (option B - internal-consistency
  invariants). Sessions `20260812-08`.
- [x] **Remove dead onboard `AGENTS.md` stub + correct stale agent-capability claims**  -- 
  `onboard.sh` wrote an empty host `$SANDBOX_DIR/AGENTS.md` stub that was never mounted
  into the agent container and shadowed by the committed repo-root `AGENTS.md` pi actually
  loads; it was a premature implementation of M3"s individual task-briefs feature, and its
  name misleadingly implied it was live. Removed the stub (onboard.sh block + summary
  instructions + header/refresh refs), the `_preflight_warn` that checked for it,
  quickstart/onboarding-guide "fill in AGENTS.md" sections, and the asserting tests. Also
  corrected the pi provider `AGENTS.md` claim that subagents "cannot persist/make git
  commits - read-only reviewer" (false - they share the workspace and can commit).
  Sessions `20260812-09`.
- [x] **`onboard --refresh` syncs derived `.env` paths; preserves operator config** - verified no `.env`-overwrite path across all three refresh invocations; fresh `onboard` is guarded against clobbering an existing sandbox; refresh re-syncs `PROJECT_DIR`/`SANDBOX_DIR` in place while preserving `INSTALL_DIR` and operator config; escaped `&` in sed values. Regression test `test_refresh_syncs_paths_preserves_config`. Sessions `20260812-10`.
- [x] **Campaign findings 2026-08-21 - production fixes (campaigns complete)** - the test-run / test-campaign / loc-reduction campaign fixes are delivered (ingest in handovers `20260823-01`-`20260823-04`; reports on the output mount). Empty `uncommitted.diff` now skips with a warning (empty bundle-member diffs land as empty commits, `20260823-12`); a conventions-compliance sweep added dual-use guards to prune/onboard/start_agent (`20260823-08`); shell-flag policy standardized to a four-class regime - entry points `-euo`/dual-use guards/libs no options/observe-and-report (`20260823-10`); error-message vs control-flow coherence fixed (`.export-status` + `apply` count idioms, `20260823-11`); `container_sig` defects fixed (`current_sig` pure per-call, empty-set fail-closed, `20260823-09`); `confirm.sh` savepoint rollback uses a same-process `SAVEPOINT_COMMIT` local (no git tag, `20260828-06`); naming/header one-line doc contradictions corrected (`20260823-14`).
- [x] **Test-harness hardening recommendations (campaigns 2026-08-21)** - **Complete (handover `20260823-07`).** Assert-helper quartet (`assert_eq`/`assert_ne`/`assert_rc`/`assert_contains`) in `test_common.sh`; runner counting contract locked by `tests/test_runner_selftest.sh` via a new `RUN_TESTS_DIR` override; non-gating gates: `make lint` / `scripts/check_lint.sh` (ShellCheck `-S warning`, baseline 31 warnings, flip-to-blocking-at-zero criterion in header), `make test-smoke` / `scripts/check_test_smoke.sh` (`bash -n` rot detection for excluded tests), `make lib-liveness` / `scripts/check_lib_liveness.sh` (orphaned-lib check, negative-tested against the buildkit_progress failure mode). Dead-flag policy recorded as `bash-coding-conventions.md` rule 3.3. Deferred: fixing the 31 findings to enable the blocking gate; mechanical migration of older suites to the helpers.
- [ ] **Mount worktree with full git history (future clone strategy, M2.6 general - not active delivery)** - materialize the mount worktree WITH full git history (common ancestor with PROJECT_DIR -> git-based port-back becomes possible alongside the diff pipeline). General M2.6 sequencing note, not part of the M2.6.6 delivery task set (relocated out of M2.6.6 so that sub-milestone can compact); design and implement once the base mount delivery is complete (future clone-strategy addendum, walk `20260818-02`).

---

**Finding - handover close-order contradiction - RESOLVED (session `20260809-05` P2):** `iteration_policy.md` Steps 8-9 say commit then mark the handover Closed; `handover_policy.md` requires a Closed handover with no uncommitted changes. The two statements contradict. Preferred resolution: close = the commit itself - mark Closed, then the final commit includes the closed handover (no substantive action after close). Resolve alongside the Bucket-1 policy changes (P2, close-flow edit) in the session that implements the agent-feedback/gotchas workflow. Surfaced from session `20260809-03`; initially mis-routed to M3, corrected here. **Resolution applied:** `iteration_policy.md` Step 8 now reads "The close is the commit" (mark Closed, then the final commit includes it); enforced by GOTCHAS entry "Set handover Status Closed before the final commit".

---

##### M2.6.1 - Foundation: Autosave, Security, Preconditions (Complete)

- [x] Autosave and session-save reliability - Fixed EXIT trap `diff_export` return value capture, added `.export-status` + error logs, lockfile polling. Dry-run checks added.
- [x] Security model documented. 4 story docs closed with Resolution sections.
- [x] Pi session resume confirmed.
- [x] Repo precondition audit - 12 findings (5 HIGH, 2 MED, 4 LOW, 1 NONE).

##### M2.6.2 - Foundation: Volume Lifecycle, Container Persistence (Complete)

- [x] Named volume with conditional compose teardown, `.run-identity`-based resume path, volume-aware entrypoint gating.
- [x] Volume teardown fix - post-agent no longer destroys volume on `--refresh`. `compose_teardown` split into `compose_stop` (`stop`) and `compose_destroy` (`down -v`). `--refresh` flag in run_agent.sh renamed to `--reset-volume`.
- [x] Compose project name leak fix - volume `name:` lines injected by `compose config` now stripped, preventing new volumes per run.
- [x] Container persistence - `compose_stop` uses `docker compose stop` (preserves stopped containers), `stop.sh` drops `docker rm`. Pre-start cleanup consolidated in `run_agent.sh`.

##### M2.6.3 - Document Consolidation (Complete)

- [x] Single-use spec files rolled into handovers. Policy disambiguation complete. `devlog/` extracted as top-level directory.

##### M2.6.4 - Mount Model Design (Complete)

- [x] Two-axis model settled (delivery: copy/mount x backing: user-provided `.git`). Security model reframed. Capability-layer git mediation retired. Raw project dir backing is a non-goal. Worktree backing rejected - see [ADR](../docs/adr/sandbox_delivery_model.md).
- [x] Four pre-design investigations complete: extensibility audit, mount wiring survey, apply/draft unification, security model reframe.

##### M2.6.5 - Copy Model: Volume-backed Sandbox (Complete)

**Objective:** Complete the volume-based persistence model. The agent works in a Docker volume backed by the snapshot pipeline. Changes exported via diff pipeline. Volume survives stop/start. Maximum isolation from the host.

- [x] **Volume prune** - `prune.sh` includes volumes (label-filtered by `agent-sandbox.sandbox-dir`, aged by `PRUNE_AGE_DAYS`). Docker prevents volume removal while any container references it - stopped container keeps volume until container ages out.
- [x] **Multi-volume concurrency** - Volume-per-session via `SESSION_ID`-scoped compose projects. Volume discovery by sandbox-dir label. Volume locking prevents concurrent attachment. Interactive volume selector when multiple volumes exist under the same sandbox directory. Design: [`devlog/discussions/20260730-design-settled-copy_model.md`](./discussions/20260730-design-settled-copy_model.md).
- [x] **Draft rollback on patch failure** - `make draft` applies a series of patches to a draft branch. If any patch fails partway through, the draft branch is left in a partially-applied state. Create a local tag savepoint before starting patch application; on failure, `git reset --hard <savepoint>` and delete the tag. Local tags don"t push by default - no remote pollution. On success, delete the tag.

##### M2.6.6 - Mount Model: Host-backed Sandbox (In progress)

**Objective:** Mount a host directory (`.sandbox` in `SANDBOX_DIR`) into the container instead of using a Docker volume. The agent works directly on the host filesystem - no copy-in, no diff pipeline, no autosave as primary persistence. Session resume is instant: the files are already there.

**Security posture:** The sandbox inherits the security posture of the host directory. The operator is responsible for ensuring secrets are not present in the mounted directory. This is a lower-isolation model than the copy-based default - the trade-off is convenience.

- [x] **Resolve open design questions** - ALL SETTLED (walk `20260818-02`; record `20260730-design-settled-mount_model.md`). Q1/Q3/Q5/Q6 retired; Q2 (file sets at generation), Q4 (`--volumes-from`), Q7 (wizard) settled; N1 (`.worktree/` + copy staging), N2 (identity/resume, registry fold), N3 (flock per mount), N4 (start contract, SESSION_STATE), N5 (containers per-run) settled. Prune rule 2 confirmed; terminology/resume/wizard realized by their own tasks.
- [x] **Security model updated** - `security.md` rewritten for simplified two-path model (Copy M2.6.5, Mount M2.6.6). Worktree row removed. Mount mode: user-provided `.git`, harness does not mediate git operations. See handover `20260730-07`.
- [x] **Mount delivery enablement (wired, not confirmed runnable end-to-end)** - capability entrypoint becomes delivery-aware (mount validates `.git` + init marker, skips snapshot gate/init, writes SESSION_STATE into the worktree `.git`, walk N4); `start_agent.sh` materializes the worktree via the shared snapshot primitive minus `baseline.tar`; N1 worktree model (`.worktree/` default; `.snapshot` dropped); `SANDBOX_TYPE` as per-overlay literals (copy.yml=`copy`, mount.yml=`mount`); tests + docs. **Resolved `20260820-01`**; suite 462/0/0. **Status clarification (`20260828`): WIRED, not end-to-end runnable** - runnability verification outstanding (no-mount/`baseline.tar`-transfer gap, handover `20260828-01`).
- [x] **`.run-identity` deprecation** - fold the identity bundle into the `.compose` registry (registry-fold, walk `20260818-02`); **Resolved `20260819-08`:** `.run-identity` had zero readers (vestigial cache); `start_agent.sh` dropped `RUN_IDENTITY` + both write blocks; `entrypoint.sh` comment updated; docs swept to registry/labels. Registry `.compose/<session-id>.yml` already self-describing.
- [x] **Single canonical session identity (identity prefactor) - done `20260831-07`** - replaced the two-stage `SANDBOX_ID`/`SESSION_ID` hash with a single canonical `SESSION_ID = sha256(canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS)[:6]` (design `20260831`, ADR `20260831-*single_canonical_session_identity`; partially supersedes ADR `20260722-*session_identity`). `sandbox_id` was a dead intermediate (sole consumer `session_id_derive`; resume derived then discarded). Canonicalizes `SANDBOX_DIR` (all path spellings of one folder converge); unresolvable path fails loudly; `HOST_HEAD_SHA` stays folded (state coupling + same-second collision avoidance); forward-only migration (resume reads id from record, never recomputes). Dropped `sandbox_id_derive` + both derivation sites; new `sandbox_dir_canon` + single `session_id_derive`; tests (`checkpoint` 8/8, `start_agent` 32/32), docs swept; suite 745/0/0. **Prune label-reliability fix remains a coupled-after follow-up (separate iteration).**
- [x] **Compose template - realizes the file-set decision** - mode-selectable compose file set at generation time (base + copy/mount overlays merged via `compose_generate`; no YAML conditionals); copy-only `SNAPSHOT_DIR` mount + env moved into the copy overlay so mount-mode never inherits it. **Resolved `20260818-03`:** base stripped of copy-only wiring; `docker-compose.copy.yml` + `docker-compose.mount.yml` created; `SANDBOX_TYPE=copy|mount` selector + `WORKTREE_DIR` wired; 9 new tests; suite 476/0/0; docs updated.
- [x] **Queued code-review amendments from the start-wizard iteration** - findings from the `20260821-06` review, **folded into `20260821-07`** (behavior-neutral; suite 473/473 green). (1) `interactive.sh` self-locates its repo root (mirroring `draft.sh`/`apply.sh`); `start_agent.sh` + `resume_agent.sh` drop their duplicated `AGENT_SANDBOX_REPO` fallback and use `$REPO_ROOT`. (2) `test_wizard_accept_runs_to_completion` reuses `make_committed_repo`. (3) `_start_providers()` comment reworded. Done `20260821-07`.
- [x] **Registry-based prune (Rules 1+2) - done `20260821-08`** - registry-truth prune confirmed against `20260818-02`/mount-model record: Rule 1 prunes stale `.compose/*.yml`; Rule 2 prunes a run with no matching record (copy: volume + containers; mount: registry resources only; worktrees never touched). `prune.sh`'s current `--stale` is the legacy volume-label path.
- [x] **Image-staleness detection - wire `STALE=image` (done `20260821-09`)** - the image-staleness criterion (image `agent-sandbox.container-sig` label vs recomputed `container_sig`) implemented: `container_sig`/`_sandbox_sig_sources`/`_agent_sig_sources` lifted into `src/libs/container_sig.sh` with a shared `image_is_stale` predicate consumed by build.sh (`_check_container_sig`) and prune (`STALE=image`; `STALE=all` = sandbox OR image). Stub-tested (DOCKER_STUB_IMAGE_SIG_LABELS per-image map). See `docs/concepts/terminology.md` `## staleness`. **Follow-up `20260821-10`:** `record_image_stale` lifted into the lib; `resume --list` shows both staleness columns (sandbox + image, capped at 10 rows/page with remainder footer); `resume --interactive` marks `[STALE]`/`[IMG-STALE]` and paginates at 10; `start`"s `_check_container_sig` preflight warning confirmed to share the same predicate (contract unchanged). **[SUPERSEDED in 20260831 - image & harness version identity:](./discussions/20260831-story-active-image_and_harness_version_identity.md) the image-staleness machinery is reframed as a symptom of the absent version identity, to be reconciled by the design next session (see the harness-version-identity task).**

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
