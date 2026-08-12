---
active-milestone: M2.6 — Session Persistence
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
| &nbsp;&nbsp;[M2.6 — Session Persistence](#m26--session-persistence) | In progress |
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

#### M2.6 — Session Persistence

**Objective:** Make the agent's working state survive container stop/start cycles. Two implementation paths offer different security/convenience trade-offs — both are valid and may coexist per session.

**Foundation** (M2.6.1–M2.6.2): The shared infrastructure both paths depend on — session identity, volume lifecycle, container persistence, compose primitives.

**Path A — Copy Model** (M2.6.5): Volume-backed sandbox. Snapshot pipeline copies host state into a Docker volume at session start. Agent works in the volume. Volume persists across stop/start. Highest isolation.

**Path B — Mount Model** (M2.6.6): Host-backed sandbox. A host directory (`.sandbox` in `SANDBOX_DIR`) is bind-mounted into the container. Agent works directly on the host filesystem. No copy overhead, no diff pipeline. Higher convenience, lower isolation.

**Depends on:** M2.4 (bind mount infrastructure), M2.7 (session identity, RUN_ID, container lifecycle).

##### M2.6 — General CLI/infra refactor track (cross-cutting, deferred from handover `20260810-04`)

Technical debt from the `c975d37` help-fix session — the interim `wants_help`
workaround and the `SCRIPT_DIR` shared-lib side effect. Split into three sessions
(operator-directed):

- [x] **Finding B — remove `SCRIPT_DIR` side effect from `common.sh`** — make
  `common.sh` a pure flag-parsing library; `stop.sh`/`prune.sh` self-resolve
  `SCRIPT_DIR` consistently; drop the obsolete comment in `start_agent.sh`. (This
  session.)
- [x] **Descriptive STE100 rename of the script-dir variable** — repo-wide
  cleanup, done only after the injection mechanism is removed. Includes a
  `tests/` sweep.
- [x] **Finding A/C — unify `--help` across all subcommands** — extract
  `route_help()` in the dispatcher; fix `--help` for every subcommand before arg
  validation; delete `wants_help`; update `test_dispatch.sh`.
- [x] **Docker network leak fix** — `compose_stop` → `docker compose down`
  (keep named volumes), label the compose default network, label-based teardown
  in `stop.sh`. Session `20260810-10`. Carried findings: run_agent unified
  teardown refactor; compose-file persistence (`.compose/<run-id>.yml`);
  docker-verb semantics decision.
- [x] **Build-output single-line progress fix** — `build_image` uses array
  dispatch (`build_cmd[]`) with a single self-updating progress line on TTY
  via `_buildkit_run` (`src/libs/buildkit_progress.sh`), showing the real
  current BuildKit step (parsed from `--progress=plain` output). Sessions
  `20260810-11` (initial `--progress=auto` — incomplete — `auto` on TTY is
  still multi-line) and `20260812-01` (array collapse + BuildKit step parsing).
- [x] **Silent build failure on `REFRESH`/`REBUILD`** — `make start PROVIDER=pi REFRESH=1` aborted with a bare exit 1 and no output in the build path. Root cause: three `set -euo pipefail` landmines in `_buildkit_run` (`_buildkit_current_step` returned non-zero on the still-empty log → poll-loop command substitution; bare `wait` on a failed child; and the non-zero `return` at the `build_image` call site), all aborting before any output/failure dump. Fixed with the repo-canonical `|| true` / `|| _rc=$?` capture idioms; `build_image` now handles TTY and non-TTY failure uniformly with a descriptive `build_image: ERROR build FAILED ...` message. Session `20260812-03`.
- [x] **String-as-list → array refactor (removes SC2086 disables)** —
  `stop.sh` `CONTAINER_IDS`/`NETWORK_IDS` → `mapfile` arrays;
  `build_image` `$no_cache` → `cache_args` array. Test-enablement rolled in:
  docker stub emits IDs via `DOCKER_STUB_PS_IDS`/`DOCKER_STUB_NETWORK_IDS`;
  stale `test_stop_uses_docker_ps` replaced by three behavior tests.
  Session `20260810-12`.
- [x] **Run_agent unified teardown dispatch** — mode branch runs the session
  only; single teardown dispatch after it; `compose_stop`/`compose_destroy`
  renamed to `session_teardown`/`session_destroy`; standard mode now tears
  down even on agent failure and propagates the agent's rc (exit semantics
  documented); serve exits 0. Stale `security.md` `compose stop` claim
  corrected. Session `20260810-13`. Carried: session-naming collision
  (replaces the docker-verb semantics decision — the bad `compose_stop` name
  is gone; what remains is the harness "session" vs ops "session" overlap);
  compose-file persistence; `compose_sandbox_wait` failure-skip teardown gap.
- [x] **Compose-file persistence** — the merged compose file is written to
  `$SANDBOX_DIR/.compose/<run-id>.yml` and persists after the session
  (inspection/compose-aware tooling handle; devcontainer Shape-3 blocker
  removed). RUN_ID available at generation time (start_agent.sh exports it).
  Docs reversed the tmpfile model (execution_model.md §Compose Generation,
  tool_interface.md, docker-compose.yml header); `.compose/` gitignored.
  Session `20260810-14`. **Deferred: pruning of stale `.compose/*.yml`**
  (accumulation is KB-scale; candidate: `stop.sh --prune` host-artifact
  extension; routine implementation — no ADR needed).
- [ ] **Pruning of stale `.compose/*.yml`** — `stop.sh --prune` should remove
  stale compose files alongside containers and volumes. KB-scale accumulation;
  deferred from session `20260810-14`.
- [x] **`compose_sandbox_wait` teardown gap** — sandbox health-check timeout
  exits before unified teardown dispatch, leaving containers running.
  **Resolved** — the unified teardown dispatch (run_agent EXIT trap on
  `TEARDOWN_NEEDED`, set before `compose_sandbox_wait`) tears down on
  sandbox-wait failure; guarded by `test_standard_sandbox_unhealthy_still_tears_down`
  (docker-stub forces never-healthy, asserts `compose down` runs).
  Surfaced session `20260810-13`; resolved by the `20260810-14` teardown refactor,
  confirmed `20260812-12`.
- [ ] **Session-naming collision** — harness "session" (agent run:
  RESUME_SESSION, volume labels) vs ops "session" (commit + handover).
  Naming decision deferred from session `20260810-13`.
- [ ] **Prune stale containers regardless of start time** — `prune.sh`
  age-gates containers; a STALE=1 mode would skip the age check (sha-based
  staleness). Semantic change entangled with M2.6.6. Deferred from session
  `20260810-04`.
- [x] **Run test scripts under `set -e`** — `tests/test_*.sh` and `tests/libs/test_common.sh` run under `set -uo pipefail` **without** `-e`, so the trace tests never execute scripts under the production `set -euo pipefail` runtime — which is how the silent `REFRESH`-build abort slipped through. **Resolved — session `20260812-12`:** `build.sh` relied on the caller setting `-e`; a standalone `bash build.sh` (as the trace tests invoke) inherited the harness's no-`-e`, so the build path never ran under `-e`. `build.sh` now self-enables `set -euo pipefail` on standalone invocation (guarded by `BASH_SOURCE[0]==$0` so sourcing does not mutate callers) — the trace tests now exercise the build path under the production `-e` runtime, catching this abort class. Added `test_build_image_failure_surfaces_descriptive_error_under_e` (failing `docker build` under standalone `-e` surfaces the descriptive `build_image: ERROR build FAILED` message) + a `DOCKER_STUB_BUILD_RC` mock toggle. Escalated as a blind-spot finding from session `20260812-03`.
- [x] **Shellcheck findings cleanup in `build.sh`** — pre-existing `SC2046` (unquoted `$(_sandbox_sig_sources)`/`$(_agent_sig_sources)` in `container_sig`/`build_sandbox`) and `SC2034` (`sandbox_dir` unused in `preflight`). Unrelated to the `20260812-03` fix; cleanup task escalated from that session. **Resolved — session `20260812-04`:** sig-sources emit per-line `printf` and are consumed via `mapfile` + `"${arr[@]}"` (SC2046 gone); `preflight` dropped the dead `sandbox_dir` param (SC2034 gone). Full suite green (474, 0 failed).
- [x] **`container_sig` defensive `|| true` guard** — `find ... 2>/dev/null` under `pipefail`/`set -e` would abort if a configured source path were invalid. All current paths are valid, so this works today, but the piped `find` has no error guard. Add `|| true` or an explicit guard. Escalated from session `20260812-03`. **Resolved — session `20260812-04`:** `container_sig` now fail-closes on a missing source path (`container_sig: ERROR: source path not found: <path>` + `return 1`) — chose a loud diagnostic over a naive `|| true` (which would hash an empty set).
- [x] **`diff_export --no-renames` by default** — `diff_export()` now
  passes `--no-renames` to `package_branch` by default, producing delete+create
  diffs instead of rename operations. Fixes pre-existing bug where
  `package_branch` passed `INIT_SHA` as the NO_RENAMES argument, silently
  disabling the flag. 15-case knowledge test. Session `20260812-02`.
- [x] **Whitespace round-trip hardening (git-verbatim diffs)** — the exporter's
  `sed` strip of trailing whitespace on `+`/`-` lines was removed at all 3
  sites (`package_branch.sh`, `diff.sh` ×2); exports are now git-verbatim
  (only `strip_index_lines` blob-hash metadata is stripped). This fixes the
  0009 draft-apply failure (a removed-line trailing-space byte broke `git apply`
  pre-image matching) and prevents silent content corruption on added/CRLF
  lines. git apply never refuses trailing whitespace under the default `warn`
  policy. Covered by 3 new unit tests in `test_diff_helpers.sh` (removed-line
  preservation, verbatim round-trip, 8-class funny-whitespace/CRLF matrix);
  stale `knowledge_trailing_whitespace_context_mismatch.sh` deleted. Sessions
  `20260812-07`.
- [x] **Knowledge-test convention established (external seams vs unit tests)** —
  `testing_policy.md` Test Placement rule: a test belongs under `make test` when
  the seam is our maintained code with an API; a knowledge test is only for
  unmodifiable seams (external binary/lib/network, legacy mid-refactor);
  `tests/integration/` holds still-not-runnable flows. Reclassified the wrongly-
  classified knowledge tests: internal `dirs.sh` path resolution → `test_dirs.sh`
  (unit); internal diff_export rename pipeline → `test_diff_rename.sh` (unit);
  `knowledge_diff_rename.sh` trimmed to git-external probing only; broken
  `knowledge_diff_export_container.sh`/`knowledge_session_diffs_path_resolution.sh`
  deleted (referenced a nonexistent `libs/` path). **`make test` invariant:**
  failed 0, skipped 0 enforced by runner; the 6 provider-structure skips in
  `test_run_agent.sh` made deterministic (option B — internal-consistency
  invariants). Sessions `20260812-08`.
- [x] **Remove dead onboard `AGENTS.md` stub + correct stale agent-capability claims** —
  `onboard.sh` wrote an empty host `$SANDBOX_DIR/AGENTS.md` stub that was never mounted
  into the agent container and shadowed by the committed repo-root `AGENTS.md` pi actually
  loads; it was a premature implementation of M3's individual task-briefs feature, and its
  name misleadingly implied it was live. Removed the stub (onboard.sh block + summary
  instructions + header/refresh refs), the `_preflight_warn` that checked for it,
  quickstart/onboarding-guide "fill in AGENTS.md" sections, and the asserting tests. Also
  corrected the pi provider `AGENTS.md` claim that subagents "cannot persist/make git
  commits — read-only reviewer" (false — they share the workspace and can commit).
  Sessions `20260812-09`.
- [x] **`onboard --refresh` syncs derived `.env` paths; preserves operator config** — verified no `.env`-overwrite path exists across all three refresh invocation points (`make refresh` from SANDBOX_DIR, `agent-sandbox onboard --refresh`, `make refresh` from project_dir): fresh `onboard` is guarded against clobbering an existing sandbox, and refresh only updated `MAKEFILE_VERSION` in place. Extended refresh to also re-sync `PROJECT_DIR`/`SANDBOX_DIR` (derived paths) while preserving `INSTALL_DIR` and operator config (SERVE_PORT/AUTOSAVE/provider stubs) — INSTALL_DIR is operator config with no `--install-dir` input to sync it to. Escaped `&` in sed values. Regression test `test_refresh_syncs_paths_preserves_config`. Sessions `20260812-10`.

---

**Finding — handover close-order contradiction (current, routes to next session's policy work):** `iteration_policy.md` Steps 8–9 say commit then mark the handover Closed; `handover_policy.md` requires a Closed handover with no uncommitted changes. The two statements contradict. Preferred resolution: close = the commit itself — mark Closed, then the final commit includes the closed handover (no substantive action after close). Resolve alongside the Bucket-1 policy changes (P2, close-flow edit) in the session that implements the agent-feedback/gotchas workflow. Surfaced from session `20260809-03`; initially mis-routed to M3, corrected here.

---

##### M2.6.1 — Foundation: Autosave, Security, Preconditions (Complete)

- [x] Autosave and session-save reliability — Fixed EXIT trap `diff_export` return value capture, added `.export-status` + error logs, lockfile polling. Dry-run checks added.
- [x] Security model documented. 4 story docs closed with Resolution sections.
- [x] Pi session resume confirmed.
- [x] Repo precondition audit — 12 findings (5 HIGH, 2 MED, 4 LOW, 1 NONE).

##### M2.6.2 — Foundation: Volume Lifecycle, Container Persistence (Complete)

- [x] Named volume with conditional compose teardown, `.run-identity`-based resume path, volume-aware entrypoint gating.
- [x] Volume teardown fix — post-agent no longer destroys volume on `--refresh`. `compose_teardown` split into `compose_stop` (`stop`) and `compose_destroy` (`down -v`). `--refresh` flag in run_agent.sh renamed to `--reset-volume`.
- [x] Compose project name leak fix — volume `name:` lines injected by `compose config` now stripped, preventing new volumes per run.
- [x] Container persistence — `compose_stop` uses `docker compose stop` (preserves stopped containers), `stop.sh` drops `docker rm`. Pre-start cleanup consolidated in `run_agent.sh`.

##### M2.6.3 — Document Consolidation (Complete)

- [x] Single-use spec files rolled into handovers. Policy disambiguation complete. `devlog/` extracted as top-level directory.

##### M2.6.4 — Mount Model Design (Complete)

- [x] Two-axis model settled (delivery: copy/mount × backing: user-provided `.git`). Security model reframed. Capability-layer git mediation retired. Raw project dir backing is a non-goal. Worktree backing rejected — see [ADR](../../docs/adr/20260730-adr-settled-worktree_rejection.md).
- [x] Four pre-design investigations complete: extensibility audit, mount wiring survey, apply/draft unification, security model reframe.

##### M2.6.5 — Copy Model: Volume-backed Sandbox (Complete)

**Objective:** Complete the volume-based persistence model. The agent works in a Docker volume backed by the snapshot pipeline. Changes exported via diff pipeline. Volume survives stop/start. Maximum isolation from the host.

- [x] **Volume prune** — `prune.sh` includes volumes (label-filtered by `agent-sandbox.sandbox-dir`, aged by `PRUNE_AGE_DAYS`). Docker prevents volume removal while any container references it — stopped container keeps volume until container ages out.
- [x] **Multi-volume concurrency** — Volume-per-session via `RUN_ID`-scoped compose projects. Volume discovery by sandbox-dir label. Volume locking prevents concurrent attachment. Interactive volume selector when multiple volumes exist under the same sandbox directory. Design: [`devlog/discussions/20260730-design-settled-copy_model.md`](./discussions/20260730-design-settled-copy_model.md).
- [x] **Draft rollback on patch failure** — `make draft` applies a series of patches to a draft branch. If any patch fails partway through, the draft branch is left in a partially-applied state. Create a local tag savepoint before starting patch application; on failure, `git reset --hard <savepoint>` and delete the tag. Local tags don't push by default — no remote pollution. On success, delete the tag.

##### M2.6.6 — Mount Model: Host-backed Sandbox (Not started)

**Objective:** Mount a host directory (`.sandbox` in `SANDBOX_DIR`) into the container instead of using a Docker volume. The agent works directly on the host filesystem — no copy-in, no diff pipeline, no autosave as primary persistence. Session resume is instant: the files are already there.

**Security posture:** The sandbox inherits the security posture of the host directory. The operator is responsible for ensuring secrets are not present in the mounted directory. This is a lower-isolation model than the copy-based default — the trade-off is convenience.

- [ ] **Resolve open design questions** — See [`devlog/discussions/20260730-design-settled-mount_model.md`](./discussions/20260730-design-settled-mount_model.md) for the current design record. Seven questions remain unresolved: compose overlay vs conditional mount, Pi direct bind mounts under mount modes, `--volumes-from` under mount modes, role of `make apply`, snapshot pipeline under mount, migration path, WORKTREE_DIR baked vs runtime.
- [x] **Security model updated** — `security.md` rewritten for simplified two-path model (Copy M2.6.5, Mount M2.6.6). Worktree row removed. Mount mode: user-provided `.git`, harness does not mediate git operations. See handover `20260730-07`.
- [ ] **Mount delivery enablement** — `.snapshot/` mounted RW into the capability layer; agent works in `.snapshot/`; entrypoint redirect
- [ ] **Compose template** — conditional mount entries per mode

###### Not in scope — Worktree backing (Rejected)

Worktree backing is rejected. See [ADR — Worktree Backing Rejected](../../docs/adr/20260730-adr-settled-worktree_rejection.md) and the [full investigation record](../../devlog/discussions/20260730-study-settled-worktree_rejection.md).

#### M2.7 — Session Identity and Harness Versioning

**Status:** Complete. Hash-based identity model (SANDBOX_ID, RUN_ID), container lifecycle (naming, labels, stop/prune), artefact paths, build pipeline simplification (repo-root context, COPY contract tests), two-sig model (container-sig label + preflight), generic pre-flight validation, dual-layer dry-run seam testing, DIFF_TYPE flag, --no-renames flag. See handover chain `20260609-01` through `20260611-04`.

#### Not in scope

Items indefinitely deferred or explicitly excluded from M2 scope.

- **Submodules not supported.** `snapshot_enumerate_files` detects gitlink entries and aborts with a clear message. Operators must deinitialise submodules before running the harness.
- **Bad diff applied to host repo corrupts future snapshots.** `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`. The risk is after the operator applies a bad diff — the host repo is then in a bad state and future snapshots reflect it. See Recovery in `docs/development/quickstart.md` for how to reset.
- **Multi-service project composition not supported.** Projects requiring additional services (databases, test containers) have no mechanism to inject them alongside the harness-managed sandbox and agent. See `execution_model.md` for the deferred discussion.

---

## Notes

- Future milestone detail: [`roadmap_future.md`](roadmap_future.md).
- Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../architecture/security.md).
