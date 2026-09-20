---
active-milestone: M2.6 - Session Persistence
active-milestone-status: complete
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
| **M2 - Reasoning/Capability Layer Separation** | **Complete** |
| &nbsp;&nbsp;[M2.1 - General Capability Layer Prototype](changelog.md#m21--general-capability-layer-prototype) | Complete |
| &nbsp;&nbsp;[M2.2 - Reasoning Layer Modularisation](changelog.md#m22--reasoning-layer-modularisation) | Complete |
| &nbsp;&nbsp;[M2.3 - Apply Workflow: Capability Layer Diff Pipeline](changelog.md#m23--apply-workflow-capability-layer-diff-pipeline) | Complete |
| &nbsp;&nbsp;[M2.4 - Session and Config Persistence](changelog.md#m24--session-and-config-persistence) | Complete |
| &nbsp;&nbsp;[M2.6 - Session Persistence](#m26---session-persistence) | Complete |
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

**Path B - Mount Model** (M2.6.6): Host-backed sandbox. A host directory (`.sandbox` in `SANDBOX_DIR`) is bind-mounted into the container. Agent works directly on the host filesystem. Full history by default; `--flatten` delivers a fresh baseline instead. Higher convenience, lower isolation.

**Depends on:** M2.4 (bind mount infrastructure), M2.7 (session identity, SESSION_ID, container lifecycle).

##### M2.6 - General cross-cutting track

Completed work, at contract level (history in handovers/changelog):

- [x] **Session lifecycle invariant** - a single teardown dispatch (`session_teardown`/`session_destroy`) covers standard, serve, and failure paths, including a sandbox health-check timeout; `docker compose down` preserves named volumes, so session data survives stop/start and `resume` re-attaches the same `SESSION_ID`-stable volume; compose networks are labelled and removed with the session; shutdown prints the copy-paste resume command.
- [x] **Session identity + registry contract** - single canonical `SESSION_ID = sha256(canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS)[:6]` ([`session_identifier.md`](../docs/adr/session_identifier.md)); `.compose/<session-id>.yml` is the registry of truth for resume and prune (a run with no matching record is prunable; worktrees never touched); docker labels (sandbox-dir, session-id) bake the canonical path independent of `--sandbox` spelling; compose is generated from a base plus a delivery overlay per mode (`SANDBOX_TYPE=copy|mount`) and the merged file persists under `.compose/` for inspection.
- [x] **CLI surface** - `agent-sandbox start|dry-run|stop|resume|prune` with unified `--help` before arg validation; `make start` always starts a NEW session (interactive config wizard; `SERVE=1` toggles serve mode); `make resume` inventories the registry (`--session-id=<id>` silent; `--list`; `--interactive`; `PROVIDER=` filter); `onboard --refresh` re-syncs derived paths in place and never clobbers an existing sandbox.
- [x] **Copy delivery + diff export contract** - the sandbox volume is seeded host-side before container start via a git-enumerated tar (baseline `git archive` + tracked/untracked members; `.snapshot/`/`SNAPSHOT_DIR` retired); diff export is git-verbatim with `--no-renames` by default; empty diffs skip with a warning; empty directories are not carried (git cannot represent them - accepted). The seed half was superseded by the helper-container seeder (see M2.6.5). Model: [`copy_delivery.md`](../docs/concepts/copy_delivery.md).
- [x] **Build + dry-run interface** - standard invocation: provider ENTRYPOINT is the harness wrapper, agent binary via `CMD`, and `command:` is the single extension point across standard/serve/dry-run; image build fails closed with a descriptive error; dry-run always rebuilds current source and gates on the digest roundtrip (image-identity) check with per-container diagnostics record verification in both passes (fresh + resume); source staleness is a warning-only preflight check (freshness detection retired, ADR harness_versioning.md); readiness probes are unit-tested in isolation. Design: [`20260828-design-settled-dry_run_phase_split.md`](./discussions/20260828-design-settled-dry_run_phase_split.md); semantics overhauled in handover `20260912-05`.
- [x] **Test harness + conventions** - tests run under the production `set -euo pipefail` runtime with an assert-helper quartet; advisory gates: `make test-smoke`, `make lib-liveness`; `make lint` is blocking; a test belongs under `make test` when the seam is maintained code - knowledge tests only for unmodifiable seams; entry points are dual-use guarded with a four-class shell-flag policy; `container_sig` fails closed on missing source paths.
- [x] **Vocabulary** - [`session`](../docs/concepts/terminology.md#session) (one container lifecycle, identified by `SESSION_ID`) and [`iteration`](../docs/concepts/terminology.md#iteration) (one work cycle - handover + commit) are reserved technical terms; `RUN_ID`/`unit` retired; bundle flags/vars renamed `BUNDLE_*`; all consumers swept.
- [x] **Documentation records** - ADRs are living, component-scoped rationale records (dated entries, append-and-demote, failure-locus rejections, optional requirements preamble); six per-principle ADRs live in `docs/adr/`; concept docs are standalone behavioral-contract explainers (interface level; defect history and internal command sequences live in the ADR); drafting follows skeleton-first, records-state steering with STE100 quick rules.
- [x] **Harness version identity (image + worktree + host)** - docker digest records for both images, plain worktree HEAD, symlink host install; freshness signal retired; digest roundtrip gate in dry-run; ADR `harness_versioning.md`. Handover `20260904-07`.
- [x] **Seed transport redesign: helper-container copy** - one-shot seeder container replaces the legacy docker-cp/tar seed (native `.git` copy, git-enumerated tar stream, mixed reset to HEAD); legacy pipeline removed. ADR entry 2026-09-04; handovers `20260904-04..06`.
- [x] **Seeder stash-clear** - the seeder clears the host stash stack on the volume copy after the `.git` copy; empty-stash tripwire in the self-verification; ADR entry 2026-09-11. Handover `20260911-08`.
- [x] **Delete the remaining sed-extraction probe** - `tests/test_onboard.sh` sources `onboard.sh` and calls `template_version` in-process; the last sed-extraction probe is gone. Handover `20260911-04`.
- [x] **Testing-policy cleanup** - mechanical liveness checks (`scripts/check_test_liveness.sh`, `make test-liveness`): every `test_*()` registered, every target resolves; registration rule added to `testing_policy.md`. Handover `20260904-08`.
- [x] **Architecture-doc staleness sweep** - 13 verified findings fixed across `docs/architecture/` (behavior text predating landed redesigns); method comparison recorded in `workflow/coding-agent/audits/`. Handover `20260911-05`.
- [x] **Pi models-store freshness reset at container start** - pi preflight zeroes `checkedAt` on every `models-store.json` entry at container start, forcing conditional etag revalidation at the first refresh while the build-time catalog stays the offline fallback. Handover `20260912-01`.
- [x] **Test-harness and CLI-parsing consolidation (operator-scoped simplification pass, `20260918-12`)** - suite-wide test scaffolding deduplicated into shared helpers (trace assertions in `test_common.sh`, git/session fixtures, `make_draft_fixture` collapsing 18 repeated prologues, `draft_branch` lookup, `captured_has`); dispatch tests and 90+ verbose leaf-assert blocks data-driven into one-line `assert_*` helpers (git-test count 854, 0 failed). Dry-run probes share one harness lib (`src/libs/dry_run_harness.sh`). `draft.sh` source resolution unified into `_resolve_draft_source`; `resume_agent.sh` inventory/display split into `src/libs/resume_list.sh` (460 -> 262 lines). New `src/libs/cli.sh` centralizes per-command flag parsing: `parse_args` (value/boolean/literal specs, `--help`, exact unknown-word override, tolerant mode) replaces the `for ARG` loops in 12 leaf scripts (workflows apply/confirm/draft/reject, build, onboard, start, resume, run_agent, stop, prune, package-branch); the dispatcher's PASSTHROUGH collect-loop is the deliberate exception. ADR [`command_flag_parsing.md`](../docs/adr/command_flag_parsing.md). Net LOC -721 across scripts/src/tests; `scripts` surface alone -425 (7%). Follow-up same session: the architecture-layer freeze table relocated from `project_index.md` to `system_overview.md` at module scope (per-layer status column), `project_index.md` then removed entirely (registry judged convenience, not correctness; docs tree itself is the file list), and the `documentation_policy.md` freeze references repointed; wholesale freeze-policy removal left open for evaluation (AGENT_FEEDBACK 2026-09-18).
- **Decision - handover close = the commit:** `iteration_policy.md` Step 8 ("The close is the commit"); enforced by GOTCHAS entry.

- [x] **Roadmap write-back gate** - the pre-close summary gained named sections (AC status, Roadmap write-back, Propagation replay) and a single canonical roadmap-timing rule; `roadmap_policy.md` reorganized to invoke -> invariants -> procedure. Handover `20260912-04`.
- [x] **Autonomous review pass prompt** - `workflow/coding-agent/prompts/review-pass-run.md` orchestrates fresh-subagent review rounds with a WIP-diff scope, a VERDICT contract, standing drift instructions, and a round cap. Handover `20260912-06`.
- [x] **Roadmap write-back completeness gate** - `iteration_policy.md` Step 7 also corrects completed rows the change supersedes; the stale dry-run row was fixed and AGENT_FEEDBACK 20260818-03 closed. Handover `20260912-07`.
- [x] **Testing-conventions rules** - the test-quality campaign rules landed in `testing_policy.md`: anti-pattern 7 (Test-the-Copy), the mandatory test-structure template with a runner liveness scan, and the pin-citation rule. Handover `20260912-08`.
- [x] **Test-runner selftest FATAL** - the liveness scan misread registration-shaped words in the selftest's own quoted payload; the scan is now anchored to the registration contract and the suite returns to rc=0. Handover `20260912-15`.
- [x] **Interface-contract compatibility** - one authoritative `INTERFACE_CONTRACT_VERSION`, declared in `src/libs/interface_contract.sh`, stamped into tier-3 images and the session record, and compared at start/resume and at the agent entrypoint; the container-sig fallback is retired. ADR [`interface_contract_compatibility.md`](../docs/adr/interface_contract_compatibility.md); handovers `20260919-03..08`.
- [x] **Dry-run semantics overhaul** - dry-run rebuilds current source, splits `--fast`/`--rebuild`, runs a two-pass resume testbed, and keeps the digest roundtrip gate; dry-run sessions are labelled and filtered from the listing. Handover `20260912-05`.
- [x] **Mount worktree with full git history** - full history is the default for copy and mount, with `--flatten` as the opt-out; the diff pipeline remains the only port-back channel. Handover `20260912-14`.
- [x] **Centralized env-precedence resolver** - single-source resolution for `PROJECT_NAME`/`PROJECT_DIR`/`SANDBOX_DIR` (CLI flag > `AGENT_SANDBOX_*` env > per-sandbox `.env`), with thin CLI wiring. ADR [`env_resolution.md`](../docs/adr/env_resolution.md); handover `20260917-06`.
- [x] **Markdown lint gate** - `markdownlint-cli2` config (`.markdownlint-cli2.mjs`) with a policy-aligned rule subset plus the custom `doc-ascii` rule; one `make lint` runs [`scripts/lint.sh`](../scripts/lint.sh), which sequences the ShellCheck gate ([`scripts/check_shell.sh`](../scripts/check_shell.sh)) and the Markdown gate ([`scripts/check_markdown.sh`](../scripts/check_markdown.sh)); the linter installs in every provider base (shared node layer and `hermes/base.dockerfile`); a copy-delivery `pre-commit` hook lints staged Markdown and blocks the commit (mount excluded, ADR [`git_hooks.md`](../docs/adr/git_hooks.md)); documented in `documentation_policy.md` and referenced from the project `AGENTS.md`. The repo holds zero findings. Handover `20260919-18`.
- [x] **Review-findings sweep** (thermo-nuclear pass over `b1aac61..0037dba`, two models): both lint gates now fail closed (a missing tool, an empty file set, a tool that could not run, and a zero-file lint run are findings, not passes); the save decision is three-valued with one helper owning the dispatch, so an unreadable repository can no longer report "nothing to save"; the autosave checkpoint is staged outside the reader-enumerated channel and swapped in, and a failed or interrupted cycle keeps the previous checkpoint; one `SESSION_STATE` parser and one `.export-status` reader replace six hand-rolled copies; the container contract check and the library preflight are sourceable functions rather than inlined entrypoint bodies; the exit-code verdict rule is codified in `bash-coding-conventions.md` 3.2. Ten review rounds over two tranches, both models approving the final state. Handover `20260919-19`.

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
- [x] Seed transport, final mechanism: a one-shot helper-container seeds the volume -- the project `.git` is copied natively, the worktree crosses as a git-enumerated tar, then a mixed reset to HEAD restores the index. The seeder clears the host stash stack and prunes unreachable objects (`git fsck --unreachable` probe; conditional reflog expire + `gc --prune=now`; fsck-empty tripwire), so the sandbox baseline carries no host archaeology. Design: [`20260904-design-settled-helper_container_seed.md`](./discussions/20260904-design-settled-helper_container_seed.md); ADR entries 2026-09-04 and 2026-09-11.

##### M2.6.6 - Mount Model: Host-backed Sandbox (Complete)

**Objective:** Mount a host directory (`.sandbox` in `SANDBOX_DIR`) into the container instead of using a Docker volume. The agent works directly on the host filesystem - no copy-in, no diff pipeline, no autosave as primary persistence. Session resume is instant: the files are already there.

**Security posture:** The sandbox inherits the security posture of the host directory. The operator is responsible for ensuring secrets are not present in the mounted directory. This is a lower-isolation model than the copy-based default - the trade-off is convenience.

**Acceptance criteria:**

- A `SANDBOX_TYPE=mount` session starts against the host worktree; the agent works in the mounted directory with no volume seed step.
- `git status` in the container is porcelain-identical to the host worktree state.
- A stopped session resumes against the same worktree; prior state is present without re-seed.
- Diff export produces a draft from the mount-session work.

- [x] **Mount model design settled** - two-axis model; design questions Q2/Q4/Q7 and N1-N5 resolved (walk `20260818-02`; record `devlog/discussions/20260730-design-settled-mount_model.md`); `security.md` rewritten for the two-path model.
- [x] **Mount delivery enablement (wiring)** - capability entrypoint is delivery-aware (mount validates `.git` + init marker, skips snapshot gate/init, writes `SESSION_STATE` into the worktree `.git`); `start_agent.sh` materializes the worktree via the shared snapshot primitive minus `baseline.tar`; `SANDBOX_TYPE` per-overlay literals.
- [x] **Seed object-store prune (study `20260911-study-seed_object_store_cleanliness.md`)** - **done `20260911-11`.** The seeder probes the volume object store with `git fsck --unreachable`; when dirty it expires reflogs and runs `gc --prune=now`, then asserts fsck-empty (fail closed). Removes host archaeology (stash objects, reflog-anchored session junk) from the sandbox baseline; parity unaffected; ~0.6 s on this repo, conditional on dirt. Clone/bundle transports remain rejected (index references staged blobs absent from any HEAD-bounded transport). History truncation deferred as a separate decision. ADR 2026-09-11 entry updated; handover `20260911-11`.
- [x] **Mount delivery runnability (raised `20260828-01`) - done `20260912-10`.** Mount path verified live end-to-end: dry-run (mount, both probe passes), start+attach (worktree reuse, no re-materialization), container file write propagating to the host worktree, session export SUCCESS, resume from record. Two defects found and fixed live: resume defaulted to copy (delivery recovered from record now), and the delivery contract was reworked per operator steering -- `--delivery` parsed once at ingestion (default copy), required (no default) in run_agent, record-recovered in resume, zero env reads/exports; template v4 ships `DELIVERY_FLAG`. Makefile.template version bumped 3->4 (onboard --refresh). Suite 779/0/0; handover `20260912-10`.
- [x] **Env-dependence audit (raised `20260912-10` Finding) - done `20260912-11`.** Six-variable sweep (RESET_VOLUME, WORKTREE_DIR, INTERACTIVE_MAX_ENTRIES, SERVE_PORT, AGENT_CMD, AUTOSAVE_INTERVAL) against the bash-conventions 1.13 defect class: no ambient mode/config reads; all sites classify as command input, persisted config, or safe default with verified load ordering. Two fixes: run_agent SERVE_PORT fallback warning gated to serve mode (was noise in non-serve modes), default 46553 documented in the tool_interface env table. Review pass APPROVE (1 round). Suite 780/0/0; handover `20260912-11`.

###### Not in scope - Worktree backing (Rejected)

Worktree backing is rejected. See [ADR - Worktree Backing Rejected](../docs/adr/sandbox_delivery_model.md) and the [full investigation record](discussions/20260730-study-settled-worktree_rejection.md).

#### M2.7 - Session Identity and Harness Versioning

**Status:** Complete. Hash-based identity model (SANDBOX_ID, SESSION_ID), container lifecycle (naming, labels, stop/prune), artefact paths, build pipeline simplification (repo-root context, COPY contract tests), two-sig model (container-sig label + preflight), generic pre-flight validation, dual-layer dry-run seam testing, DIFF_TYPE flag, --no-renames flag. See handover chain `20260609-01` through `20260611-04`.

#### Not in scope

Items indefinitely deferred or explicitly excluded from M2 scope.

- **SERVE mode integration.** Indefinitely deferred (operator `20260912-12`): not in regular use; the serve overlays (hermes/opencode) were rebased to the standard invocation interface but not docker-tested; pi lacks server-mode feature integration. Revisit only if serve gains regular use. Elevation from `20260828-02` finding.
- **Submodules not supported.** `snapshot_enumerate_files` detects gitlink entries and aborts with a clear message. Operators must deinitialise submodules before running the harness.
- **Bad diff applied to host repo corrupts future snapshots.** `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`. The risk is after the operator applies a bad diff - the host repo is then in a bad state and future snapshots reflect it. See Recovery in `docs/development/quickstart.md` for how to reset.
- **Multi-service project composition not supported.** Projects requiring additional services (databases, test containers) have no mechanism to inject them alongside the harness-managed sandbox and agent. See `execution_model.md` for the deferred discussion.
- **Env-resolution thinness for direct leaf invocation (indefinitely deferred).** The `agent-sandbox` CLI resolves identity at the dispatcher seam for `build`/`stop`/`prune`/workflows/`start`/`dry-run`; direct leaf invocation (`bash scripts/build.sh --name=...`) still requires identity flags (`start_agent.sh`'s own `--name/--project` gate), while `resume` is the one command that is thin at the leaf (via `session_env_common_init`). CLI-only thinness is the intended boundary (operational use goes through the CLI). Extending resolution to the remaining direct leaf calls is possible future work, not scheduled. See `docs/adr/env_resolution.md`.
- **Nushell rewrite (indefinitely deferred).** A rewrite of the host-side tooling in a cross-platform structured-data language (nushell) would remove the GNU/BSD host difference at the cost of rewriting ~100 scripts, 46 test files, and 817 tests mid-milestone. The bounded alternative is the `scripts/install.sh` requirement gate and portable call sites. Revisit only if the host-support burden grows beyond the gate's capacity. See `docs/development/host_requirements.md`.

---

## Notes

- Future milestone detail: [`roadmap_future.md`](roadmap_future.md).
- Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../docs/architecture/security.md).
