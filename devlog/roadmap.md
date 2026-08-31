---
active-milestone: M2.6 - Session Persistence
active-milestone-status: in-progress
---

# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules - task granularity, cleanup on completion, section removal - are defined in [`docs/operations/roadmap_policy.md`](../operations/roadmap_policy.md).

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

Conceptual model: [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md)
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
- [x] **Build-output single-line progress TRUNCATED (revert to docker `auto`)** - finding (operator `20260821-01`): the single-line progress utility does not render well - operators see raw BuildKit `COPY ...`/`RUN ...` step lines repeated instead of clean progress. **Revert:** `build_image` now builds with docker"s default `auto` progress (dropped `--progress=plain` and the `_buildkit_run` TTY/non-TTY branch), collapsing to a single plain build call that still captures the exit status and emits the descriptive `build_image: ERROR build FAILED ...` on failure (fail-closed `set -e` behavior preserved). `src/libs/buildkit_progress.sh` **kept dormant** (unreferenced, not deleted) - restore only when the truncation/rendering is reliable; the prior sessions" history (`20260810-11`, `20260812-01`, `20260812-03`) documents the implementation for re-addition. Tests: removed the `progress=plain` assertion + the two `_buildkit_current_step` tests from `test_trace_build.sh`; kept `test_build_image_failure_surfaces_descriptive_error_under_e` (passing). Session `20260821-01`.
- [x] **Silent build failure on `REFRESH`/`REBUILD`** - `make start PROVIDER=pi REFRESH=1` aborted with a bare exit 1 and no output in the build path. Root cause: three `set -euo pipefail` landmines in `_buildkit_run` (`_buildkit_current_step` returned non-zero on the still-empty log -> poll-loop command substitution; bare `wait` on a failed child; and the non-zero `return` at the `build_image` call site), all aborting before any output/failure dump. Fixed with the repo-canonical `|| true` / `|| _rc=$?` capture idioms; `build_image` now handles TTY and non-TTY failure uniformly with a descriptive `build_image: ERROR build FAILED ...` message. Session `20260812-03`.
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
- [x] **Prune-command redesign (registry + shape)** - **Rule 2 CONFIRMED** (design walk `20260818-02`): at prune time, a session under the current sandbox with no matching `.compose/<session-id>.yml` is prunable - scope differs by delivery (copy -> volume + containers; bind-mount -> registry resources only; worktrees never touched, D8/D4). **Command SHAPE redesign DEFERRED until after the M2.6.5/M2.6.6 artifact shapes settle** (registry, worktree, locks) - requirements will be clearer then. **STALE=1 terminology REJECTED** (unclear: `=1` as boolean-true vs staleness filter; prune-all-stale vs keep-all-stale ambiguity; unknown command for "prune everything"; scope of "everything" incl. active containers undefined). Minimums for the redesign: interactive mode showing the cutoff + ask confirmation; descriptive option names; explicit scope semantics. **Staleness-criteria restoration sub-task (finding `20260821-05`):** the volume/sandbox staleness criterion (`host-head-sha` label vs current HEAD) was LOST when the resume branch was stripped from `start` (`20260821-04`); `make resume` now applies no staleness gate and docs describing volume staleness are out of date. Proposed (design pending a check against current impl): port the volume/sandbox staleness criterion to use `.compose/<session-id>.yml` as the source of truth (D7) rather than volume labels; reuse the `resume --list` output shape for `prune`; and extend `--list` to show sandbox staleness + image staleness columns. The image-staleness column is a recommendation only - it requires `docker image inspect` per record and is untestable in the no-docker container; confirm the criterion against `preflight()`/`container-sig` in `build.sh` before finalizing.
- [x] **`compose_sandbox_wait` teardown gap** - sandbox health-check timeout
  exits before unified teardown dispatch, leaving containers running.
  **Resolved** - the unified teardown dispatch (run_agent EXIT trap on
  `TEARDOWN_NEEDED`, set before `compose_sandbox_wait`) tears down on
  sandbox-wait failure; guarded by `test_standard_sandbox_unhealthy_still_tears_down`
  (docker-stub forces never-healthy, asserts `compose down` runs).
  Surfaced session `20260810-13`; resolved by the `20260810-14` teardown refactor,
  confirmed `20260812-12`.
- [x] **Terminology sweep - deconflict the term "session"; register `session` + `iteration` as reserved technical terms** - mapping REVERSED from the design walk (operator, session `20260819-09`). Two reserved technical terms are defined in the register: [`session`](../concepts/terminology.md#session) = one container lifecycle (start -> teardown; identified by `SESSION_ID`; may contain zero or more iterations); [`iteration`](../concepts/terminology.md#iteration) = one work cycle producing a handover + commit (the `new-iteration` prompt opens one). **Replaced terms:** `run`/`RUN_ID` -> `session`/`SESSION_ID` (phase 4); the short-lived `unit` term dropped (2A); `new-session` skill -> `new-iteration`. First-mention section-link convention applied; policy docs + `sandbox_identity.md` link to the register ([`docs/concepts/terminology.md`](../concepts/terminology.md)). Sequence (reordered session `20260819-10` - the field-schema migration runs FIRST so no schema heading carries "session"): (1) broad sweep + categorization in `output/terminology-sweep/` (working doc, not committed) [DONE - session `20260819-09`]; (2) **field-schema migration** - rename the handover field headings to schema-neutral names (strip "session"/"iteration" from headings: `## Session type`->`## Type`, `## Session date`->`## Date`, `## Next session`->`## What"s Next` [operator target], `## Mid-session findings`->`## Findings`, `## Completed this session`->`## Completed`, `## Decisions made this session`->`## Decisions`, `## Session directive`->`## Directive`), coordinate all consumers (whats-next/audit/recovery/wrapup prompts + skills, AGENTS.md, git_policy, project_index, tests/eval), with a formal historical transition (Bucket C3 - historical handovers not retro-renamed, read tools handle both) [DONE - session `20260819-11`; consumers updated, dual-grep bridge logged as GOTCHAS `[G] 2026-08-19` with a ~30-handover/~1-week removal point; bold preamble fields kept as `**Date:**`/`**Type:**` per operator]; (3) **session->iteration prose/entity sweep** - `new-session` skill->`new-iteration` + invocation surface, independent ops-workcycle prose "session"->"iteration" across policy docs/AGENTS/prompts/skills/concepts/dev docs (B4 new-devlog prose) [DONE - session `20260819-12`; "unit" term dropped, iteration start/end adopted, STE simplification applied; git_policy Branching Strategy + Merge Policy "session branch" terms left OOS (section up for removal - see handover findings); stale `claude-ai` provider folder deleted]; (4) **run->session** - container lifecycle `RUN_ID`->`SESSION_ID` (`run_id`, `agent-sandbox.run-id` label, `SESSION_STATE` write key `run_id`, `--run-id` stop flag, compose project/volume/registry names; persistence-critical - keys+label atomic, D-D back-compat pending) [DONE - session `20260819-13`; D-A stop flag `--run-id`->`--session-id` (no back-compat - operator, fresh-pass flag); D-D resume FORCE-FRESH (no back-compat read - the copy-resume volume-label gate at `start_agent.sh` rejects pre-rename volumes with the existing "older harness version... start fresh" error; SESSION_STATE keys `run_id`->`session_id` atomic; `.compose/<run-id>.yml`->`<session-id>.yml`; `export_path`/routing/diff/package_branch/draft all on `SESSION_ID`; historical ADR `20260722-*session_identity*` + handovers untouched (C3); suite 476/0/0]; (5) **bundles refactor** - draft/apply `--session=<name>`->`--bundle=<name>`, `--session-summary`->`--bundle-summary`, `SESSION_*` workflow vars->`BUNDLE_*`, `interactive_select_session`->`interactive_select_bundle`; runs after run->session so the shared files (draft/package_branch/routing/draft_state) are already on `SESSION_ID`. Historical records stay as-is (Bucket C3). **5A (bundle rename, behavior-neutral) DONE - session `20260819-14`:** bundle CLI/flags/vars/Makefile/tests/docs renamed across 19 files; `interactive_select_session`->`interactive_select_bundle` (+ `SESSION_NAME/ARG/SUMMARY`->`BUNDLE_*`); adjacent pre-existing shellcheck fixes folded (draft.sh SC2028 echo quoting, SC2034 -> `_dummy_init` recipient matching the existing `_dummy_*` convention); suite 476/0/0; SC1091 the only shellcheck category, no new findings. **5B (apply simplification) DONE - session `20260819-15`:** operator refined 5B beyond the original diff-channel removal - `make apply` now requires an exact `--diff=<path>` (no default, no channel/bundle/diff-type auto-resolution); `resolve_diff_for_apply` removed from routing, the dead `diffs` channel dropped from `resolve_channel_base_dir`, `interactive_select_diff_type` removed (its only caller was apply); apply `--interactive` previews the diff (git-oneline file list + total) then confirms via `interactive_confirm_or_abort`; draft channel resolution (session/autosave/bundles) and `interactive_select_channel`/`interactive_select_bundle` unchanged; docs (tool_interface, sandbox_lifecycle, sandbox_host_correspondence, sandbox_identity), Makefile (`apply DIFF=<path>` required, `--interactive` preview/confirm), provider quickstarts, project_index updated; new test `test_apply_requires_diff_flag`; suite 462/0/0. Resolves the M2.6 session-naming-collision item. Sub-decisions: D-A stop-flag target (resolved phase 4: `--session-id`); D-B/D-C bundle CLI targets (phase 5), D-D resume back-compat (resolved phase 4: force-fresh, no back-compat); D-E draft-context `SESSION_TS` KEPT as `SESSION_TS` [operator `20260819-10`].
- [x] **`start`/`resume` redesign (two-command split)** - **Design SETTLED (walk `20260818-02` + F2 session `20260821-02`, decisions D1-D11)**: `make start` unconditionally starts a NEW session (interactive form = provider/config wizard); `make resume` is the resume entrypoint - inventories the unified `.compose/<session-id>.yml` registry (both deliveries, secondary existence check), filters by args (`--session-id=<id>` direct silent resume; `PROVIDER=` narrows; `--interactive` = picker+confirm; bare `resume` prints help). Cross-command convention: fast = supplied args, slow = explicit `--interactive`. Freshness-on-new = container freshness (implicit rebuild downgraded by staleness detection). Supersedes the earlier "interactive-by-default merged wizard" sketch and the `--run` flag (terminology sweep: `--session-id`). Implementation carried by the follow-on F2 `impl` iterations. **Start-wizard sub-task DONE - `20260821-06`:** `make start INTERACTIVE=1` provider/config wizard (provider picker + build policy + confirm; refactor-safety for serve/dry-run via an explicit error). The full redesign is now delivered; the **serve/dry-run interface refactor is a separate deferred entry below (L153)**.
- [x] **Start/serve/dry-run interface + dry-run readiness/execution refactor** - serve became an on/off toggle on `start` (standalone verb removed, `20260823-16`); the dry-run path was reshaped into a readiness/ownership refactor (`20260828-01` feature-scope trim): the bearer containers (sandbox + agent) each run their own readiness self-checks and write per-container diagnostics records; orchestration validates the correct container from those records + a hard image-signature (staleness) gate; probes run at container start-up (no `docker compose exec`; sandbox runs its probe as a prelude then stays alive) via a standard invocation interface (providers' ENTRYPOINT = harness wrapper only, agent binary via `CMD`, `command:` = the single extension point across standard/serve/dry-run, which also fixed a baked-binary entrypoint feeding probe args to the agent as chat input); readiness labels are STE100 textual names (docker_image / workspace_mounts / session_state / session_data / container_network / agent_runtime). Verified e2e on a docker host: `make dry-run PROVIDER=pi REBUILD=1` -> ALL PHASES PASSED (both records, all layers PASS, image-sig gates PASS); staleness negative test confirmed (plain dry-run on an edited sig-source -> stale WARNING + phase-3 FAIL/rebuild-required); `make start PROVIDER=pi` works. Design: [`20260828-design-settled-dry_run_phase_split.md`](./discussions/20260828-design-settled-dry_run_phase_split.md). Handovers: `20260828-01`, `20260828-02`.
- [ ] **Dry-run probe-check unit-test harness** - build a host-side harness so each readiness-layer check in the dry-run probes is unit-tested in isolation (`LIBS_DIR`-parameterize `dry_run_capability.sh`/`dry_run_reasoning.sh` + a `test/stubs/libs` of session_state_read/diff_export/dirs_resolve; new `tests/test_dry_run_probe_*.sh`) instead of relying on a manual docker dry-run (the checks are otherwise invoked exactly once, only through dry-run). In progress (handover `20260828-03`).
- [ ] **SERVE mode integration (standalone item)** - SERVE is not in regular use and may be out of date; the serve overlays (hermes/opencode) were rebased to the standard invocation interface (prefixing the binary in `command:`) but NOT docker-tested (operator: not convenient); pi currently lacks feature integration to support server mode. Scope: verify/enable `make serve` per provider (uses + retest + rebase correctness), add pi server-mode feature support, reconcile with the standard `command:` interface. Elevation from `20260828-02` finding. A real-session smoke test (`make start`) confirms standard mode post-standardization, but serve remains unverified.
- [x] **`resume` session surfaces (was: session-id pass-through; blocked-on Finding 1 in `20260821-01-fix-start_agent_bugfixes.md`)** - implemented across `20260821-03`/`20260821-05`: `make resume --session-id=<id>` direct resume via `.compose/<session-id>.yml` registry lookup -> silent; `--list` enriched table (`SESSION_ID | provider | session-ts | branch`); `--interactive` picker+confirm; `PROVIDER=<n>` inventory filter (list/interactive); bare->help. `start` no longer carries resume args (`--resume`/`--session-id`; `SESSION_ID_FLAG` stays `stop`-only); `stop.sh` prints `make resume SESSION_ID=<id>`. Remaining for `start`/`resume` redesign: the `make start` interactive config wizard (D11).
- [ ] **`make resume` volume reuse - verify it attaches the existing volume (does NOT recreate/reset the baseline)** - refined from the reported Bug D (`make start RESUME=1` resetting the baseline). `make start RESUME=1` is INTENTIONALLY removed (the `start`/`resume` two-command split, `20260818-02`; `start` no longer carries `--resume`/`--session-id` - see resume-session-surfaces bullet). So re-invoking `RESUME=1` against current `start` is an outdated invocation, not a née start bug. The real residual to verify: `make resume` itself may be recreating the volume / resetting the baseline instead of reusing the persisted one. Scope: correct resume invocation -> confirm the existing session volume is attached (baseline/tree preserved); audit the resume path for any volume-recreate/reset; confirm per-copy-delivery (volume) and mount-delivery (worktree) both preserve state. Elevation from `20260828-02` finding.
- [x] **Run test scripts under `set -e`** - `tests/test_*.sh` and `tests/libs/test_common.sh` run under `set -uo pipefail` **without** `-e`, so the trace tests never execute scripts under the production `set -euo pipefail` runtime - which is how the silent `REFRESH`-build abort slipped through. **Resolved - session `20260812-12`:** `build.sh` relied on the caller setting `-e`; a standalone `bash build.sh` (as the trace tests invoke) inherited the harness"s no-`-e`, so the build path never ran under `-e`. `build.sh` now self-enables `set -euo pipefail` on standalone invocation (guarded by `BASH_SOURCE[0]==$0` so sourcing does not mutate callers) - the trace tests now exercise the build path under the production `-e` runtime, catching this abort class. Added `test_build_image_failure_surfaces_descriptive_error_under_e` (failing `docker build` under standalone `-e` surfaces the descriptive `build_image: ERROR build FAILED` message) + a `DOCKER_STUB_BUILD_RC` mock toggle. Escalated as a blind-spot finding from session `20260812-03`.
- [x] **Shellcheck findings cleanup in `build.sh`** - pre-existing `SC2046` (unquoted `$(_sandbox_sig_sources)`/`$(_agent_sig_sources)` in `container_sig`/`build_sandbox`) and `SC2034` (`sandbox_dir` unused in `preflight`). Unrelated to the `20260812-03` fix; cleanup task escalated from that session. **Resolved - session `20260812-04`:** sig-sources emit per-line `printf` and are consumed via `mapfile` + `"${arr[@]}"` (SC2046 gone); `preflight` dropped the dead `sandbox_dir` param (SC2034 gone). Full suite green (474, 0 failed).
- [x] **`container_sig` defensive `|| true` guard** - `find ... 2>/dev/null` under `pipefail`/`set -e` would abort if a configured source path were invalid. All current paths are valid, so this works today, but the piped `find` has no error guard. Add `|| true` or an explicit guard. Escalated from session `20260812-03`. **Resolved - session `20260812-04`:** `container_sig` now fail-closes on a missing source path (`container_sig: ERROR: source path not found: <path>` + `return 1`) - chose a loud diagnostic over a naive `|| true` (which would hash an empty set).
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
- [x] **`onboard --refresh` syncs derived `.env` paths; preserves operator config** - verified no `.env`-overwrite path exists across all three refresh invocation points (`make refresh` from SANDBOX_DIR, `agent-sandbox onboard --refresh`, `make refresh` from project_dir): fresh `onboard` is guarded against clobbering an existing sandbox, and refresh only updated `MAKEFILE_VERSION` in place. Extended refresh to also re-sync `PROJECT_DIR`/`SANDBOX_DIR` (derived paths) while preserving `INSTALL_DIR` and operator config (SERVE_PORT/AUTOSAVE/provider stubs) - INSTALL_DIR is operator config with no `--install-dir` input to sync it to. Escaped `&` in sed values. Regression test `test_refresh_syncs_paths_preserves_config`. Sessions `20260812-10`.
- [ ] **Campaign findings 2026-08-21 - production fixes (operator decision needed on behavior items)** - flagged by the test-run / test-campaign / loc-reduction campaigns, pinned by tests where possible, deliberately not fixed in-campaign. Reports on the output mount (`output/test-run-20260821/`, `output/test-campaign-20260821-165041-258/`, `output/loc-reduction-20260821-175035-166983/`); ingest recorded in handovers `20260823-01`-`20260823-04`. Items:
  - [x] **Empty `uncommitted.diff` hard-fails apply** - **Complete (handover `20260823-12`).** Operator decision: empty `uncommitted.diff` is SKIPPED with a warning; empty member diffs inside a bundle that carry associated commit messages still land via an empty commit (message preserved) with a warning. Implemented via shared `diff_is_empty` helper in [`src/libs/diff.sh`](../src/libs/diff.sh); count contract tests extended in [`tests/test_apply_count.sh`](../tests/test_apply_count.sh).
  - [x] **Conventions compliance sweep** - **Complete (handover `20260823-08`).** Dual-use guards (`main()` + `BASH_SOURCE[0] == "$0"`) added to `prune.sh`, `onboard.sh`, `start_agent.sh`; `validate_wsl_path` returns instead of exiting; `template_version` made deterministic on absent marker (rc-leak masked by callers until now). The three sed-extraction test seams deleted - tests source-and-call directly. Suite 628/38/0 x2.
  - [x] **Shell flag policy standardization** - **Complete (handover `20260823-10`).** New rule 1.17 in bash-coding-conventions: four-class regime (entry points `-euo` / dual-use flags-under-guard / libs never set options / observe-and-report no `-e`). 4 test files aligned to `-uo pipefail`; `toc.sh` gained entry-point flags; dry-run diagnostics and `build.sh` confirmed already compliant (documented rationale). Direct-exec prevention considered and rejected - it is the rule 1.13 dispatch design. Suite 629/38/0 x2.
  - [x] **Error-message vs control-flow coherence** - **Complete (handover `20260823-11`).** `_session_export` absorbs `wait_git_lockfile`'s return (the "proceeding anyway" message no longer kills the export it promises); `apply_run`/`apply_preview` count sites use the `|| true` + `${VAR:-0}` idiom instead of the double-emitting `|| echo 0`; rule 4.3 now names the copyable idiom and the hazard. Count contract pinned in new `tests/test_apply_count.sh`. Suite 631/39/0 x2.
  - [x] **container_sig defects** - **Complete (handover `20260823-09`).** Root cause went deeper than the recorded symptom: the `current_sig` memoization was provably inert since baseline (three nested command substitutions fork subshells; the cache write evaporates), so it was deleted rather than repaired - `current_sig` is now a pure per-call function. Empty file-set pinned to the `xargs -r` digest (no stdin read); empty sources array fails closed instead of hashing caller cwd. Suite 629/38/0 x2.
  - [x] **confirm.sh savepoint rollback latent bug** - rebase-conflict rollback runs `git reset --hard confirm-savepoint` on a path where the tag was never created; a stale tag from a prior run lands the reset on the wrong commit. **Complete (handover `20260828-06`).** The savepoint is now a same-process `SAVEPOINT_COMMIT` local variable (no git tag): a missing tag can no longer abort the rollback raw under `set -e`, and a stale tag from an interrupted prior run can no longer rewind the draft branch to the wrong commit (reproduced as silent data loss before the fix). The conflict help text is aligned to the auto-rollback (no dead "resolve and continue" text). Two regression tests + the drop-step rollback test drive a real failure under the missing-tag, stale-tag, and drop-step conditions. Suite 660/0/0, lint 0.
  - [x] **Naming/header contradictions (one-line doc fixes)** - **Complete (handover `20260823-14`).** image.sh return contract corrected; compose template generic `{{VAR}}` mention rephrased; template_version empty-means-unknown documented at header + call site; all four workflow headers describe dual-use reality.
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

- [x] Two-axis model settled (delivery: copy/mount x backing: user-provided `.git`). Security model reframed. Capability-layer git mediation retired. Raw project dir backing is a non-goal. Worktree backing rejected - see [ADR](../../docs/adr/20260730-adr-settled-worktree_rejection.md).
- [x] Four pre-design investigations complete: extensibility audit, mount wiring survey, apply/draft unification, security model reframe.

##### M2.6.5 - Copy Model: Volume-backed Sandbox (Complete)

**Objective:** Complete the volume-based persistence model. The agent works in a Docker volume backed by the snapshot pipeline. Changes exported via diff pipeline. Volume survives stop/start. Maximum isolation from the host.

- [x] **Volume prune** - `prune.sh` includes volumes (label-filtered by `agent-sandbox.sandbox-dir`, aged by `PRUNE_AGE_DAYS`). Docker prevents volume removal while any container references it - stopped container keeps volume until container ages out.
- [x] **Multi-volume concurrency** - Volume-per-session via `SESSION_ID`-scoped compose projects. Volume discovery by sandbox-dir label. Volume locking prevents concurrent attachment. Interactive volume selector when multiple volumes exist under the same sandbox directory. Design: [`devlog/discussions/20260730-design-settled-copy_model.md`](./discussions/20260730-design-settled-copy_model.md).
- [x] **Draft rollback on patch failure** - `make draft` applies a series of patches to a draft branch. If any patch fails partway through, the draft branch is left in a partially-applied state. Create a local tag savepoint before starting patch application; on failure, `git reset --hard <savepoint>` and delete the tag. Local tags don"t push by default - no remote pollution. On success, delete the tag.

##### M2.6.6 - Mount Model: Host-backed Sandbox (In progress)

**Objective:** Mount a host directory (`.sandbox` in `SANDBOX_DIR`) into the container instead of using a Docker volume. The agent works directly on the host filesystem - no copy-in, no diff pipeline, no autosave as primary persistence. Session resume is instant: the files are already there.

**Security posture:** The sandbox inherits the security posture of the host directory. The operator is responsible for ensuring secrets are not present in the mounted directory. This is a lower-isolation model than the copy-based default - the trade-off is convenience.

- [x] **Resolve open design questions** - ALL SETTLED (design walk `20260818-02`; live record: handover `20260818-02`, formal record: `20260730-design-settled-mount_model.md`). Q1/Q3/Q5/Q6 retired with evidence; Q2 (compose file sets at generation time), Q4 (`--volumes-from` retained), Q7 (wizard) settled; N1 (`.worktree/` + copy staging to per-run tmp), N2 (identity/resume, registry fold, `.run-identity` deprecation), N3 (flock per mount point), N4 (start contract, SESSION_STATE retained, port-back via package_branch/draft), N5 (containers strictly per-run, persistence via mounted sources) settled. Grouped: prune rule 2 confirmed (command-shape redesign deferred), terminology agent run + agent iteration (own sweep task), start redesign realized by the wizard
- [x] **Security model updated** - `security.md` rewritten for simplified two-path model (Copy M2.6.5, Mount M2.6.6). Worktree row removed. Mount mode: user-provided `.git`, harness does not mediate git operations. See handover `20260730-07`.
- [x] **Mount delivery enablement (wired, not confirmed runnable end-to-end)** - **consumes the compose file-set split (session `20260818-03`)**; the capability-layer entrypoint becomes delivery-aware (mount path validates `.git` + init marker, skips the snapshot gate/init, writes SESSION_STATE into the worktree `.git` as the init marker - walk N4; includes the entrypoint branch-inversion cleanup carried from `20260818-02`); `start_agent.sh` materializes the worktree via the shared snapshot primitive minus `baseline.tar` when absent and validates it before `up`; N1 worktree model (`.worktree/` default; `.snapshot` dropped from SANDBOX_DIR); `SANDBOX_TYPE`/`WORKTREE_DIR` pass through to compose; tests + docs; copy path unchanged. **Resolved - session `20260820-01`:** entrypoint delivery-aware (mount validates `.git`, writes SESSION_STATE init marker when absent, skips snapshot gate/init + `baseline.tar` preflight); `start_agent.sh` mount materialization (`snapshot_copy_worktree` minus baseline.tar + git baseline); `SANDBOX_TYPE` env as per-overlay literals (copy.yml=`copy`, mount.yml=`mount`); `execution_model.md` delivery-aware init/init-marker semantics; suite 462/0/0. Folded in this session: M2.6-close housekeeping (lines 149/241 checkboxes) + shellcheck backlog (package_branch SC2086/SC1003 + safe test fixes). **Status clarification (session `20260828`): this marks the mount code path WIRED - SANDBOX_TYPE selection, sub-delivery-aware entrypoint, worktree materialization all present - and is NOT a claim that mount delivery runs end-to-end. End-to-end runnability verification is outstanding (see the no-mount/`baseline.tar`-transfer gap, handover `20260828-01`).**
- [x] **`.run-identity` deprecation** - fold the identity bundle (SESSION_TS/SESSION_ID/HOST_HEAD_SHA/SANDBOX_ID) into the `.compose` registry (registry-fold decision, walk `20260818-02`); refactor start_agent identity sourcing (copy-resume keeps volume labels; bind-mount resume reads the registry); remove the file; sweep docs (`sandbox_identity.md`, `sandbox_lifecycle.md`, `quickstart.md`); consumers inventoried in the decision. NOTE: the fold covers HOST-side identity only - container-side SESSION_STATE stays (export machinery, co-located provenance). **Resolved - session `20260819-08`:** `.run-identity` had zero readers (pure vestigial cache); `start_agent.sh` dropped `RUN_IDENTITY` + both write blocks (identity sourced fresh on new, from volume labels on copy resume); `entrypoint.sh` comment updated; docs swept to registry/labels (`sandbox_identity.md`, `sandbox_lifecycle.md`, `quickstart.md`); registry `.compose/<session-id>.yml` already self-describing (no code change).
- [x] **Compose template - realizes the file-set decision** - mode-selectable compose file set at generation time: base + copy/mount overlays merged through `compose_generate` (existing `docker compose config` pipeline); no YAML conditionals (walk `20260818-02`); `volumes:` handled by generation-time substitution/override. Copy-only `SNAPSHOT_DIR` mount + env move into the copy overlay file set (not the base template), so mount-mode compose never inherits it and the future copy-side seeding cleanup is a single deletion. **Resolved - session `20260818-03`:** base template stripped of all copy-only wiring (verified zero references); `docker-compose.copy.yml` (named volume + snapshot mount/env) and `docker-compose.mount.yml` (worktree bind at `/home/agentuser/sandbox`) created; `SANDBOX_TYPE=copy|mount` selector (default copy, invalid rejected) + `WORKTREE_DIR` default (`${SANDBOX_DIR}/.worktree`) wired in `run_agent.sh`; `WORKTREE_DIR` substitution added to `compose_generate`; 9 new tests (suite 476/0/0: 471 baseline + 9 new - 4 trivial repo-presence checks removed); docs updated (`execution_model.md` Compose Generation, `tool_interface.md`). Mount delivery enablement (entrypoint redirect, validation) remains the next task.
- [x] **Queued code-review amendments from the start-wizard iteration** - findings from the `20260821-06` review, **folded into `20260821-07`** (behavior-neutral; suite 473/473 green). (1) `interactive.sh` self-locates its repo root (mirroring `draft.sh`/`apply.sh`); `start_agent.sh` + `resume_agent.sh` drop their duplicated `AGENT_SANDBOX_REPO` fallback and use `$REPO_ROOT`. (2) `test_wizard_accept_runs_to_completion` reuses `make_committed_repo`. (3) `_start_providers()` comment reworded. Done `20260821-07`.
- [x] **Registry-based prune (Rules 1+2) - consecutive follow-on to `20260821-07`** - **done `20260821-08`.** the registry-truth prune, deferred to a consecutive iteration (operator `2026-08-21`). Original model confirmed against design walk `20260818-02` / mount-model record: **Rule 1** - prune `.compose/*.yml` per prune args (the stale records); **Rule 2** - a run with no matching `.compose/<session-id>.yml` record is prunable, scope by delivery (copy: volume + containers; mount: registry resources only; worktrees never touched). `prune.sh`"s current `--stale` is the legacy volume-label path. Reuse the shared `session_stale` helper added in `20260821-07`; revisit the N3 mount-lock shape for the copy/mount scope semantics.
- [x] **Image-staleness detection - wire `STALE=image` (done `20260821-09`)** - the image-staleness criterion (image `agent-sandbox.container-sig` label vs recomputed `container_sig`) implemented: `container_sig`/`_sandbox_sig_sources`/`_agent_sig_sources` lifted into `src/libs/container_sig.sh` with a shared `image_is_stale` predicate consumed by build.sh (`_check_container_sig`) and prune (`STALE=image`; `STALE=all` = sandbox OR image). Stub-tested (DOCKER_STUB_IMAGE_SIG_LABELS per-image map). See `docs/concepts/terminology.md` `## staleness`. **Follow-up `20260821-10`:** `record_image_stale` lifted into the lib; `resume --list` shows both staleness columns (sandbox + image, capped at 10 rows/page with remainder footer); `resume --interactive` marks `[STALE]`/`[IMG-STALE]` and paginates at 10; `start`"s `_check_container_sig` preflight warning confirmed to share the same predicate (contract unchanged).

###### Not in scope - Worktree backing (Rejected)

Worktree backing is rejected. See [ADR - Worktree Backing Rejected](../../docs/adr/20260730-adr-settled-worktree_rejection.md) and the [full investigation record](../../devlog/discussions/20260730-study-settled-worktree_rejection.md).

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
- Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../architecture/security.md).
