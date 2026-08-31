# Agent Handover

**Date:** 2026-08-28
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Implement the deferred dry-run execution-point change (bearer checks run at container start-up via a compose `command`/`entrypoint` override reusing the full-init sequence, instead of `docker compose exec`), and produce the exact end-to-end `make dry-run` testing procedure. The change is unverified (no docker in this env); the operator applies it on a docker machine and reports logs.

## Scope
Roadmap follow-on: "Dry-run execution-point: probes at container start-up (follow-on)" — see roadmap bullet added at close of handover `20260828-01`.

In scope:
- Container start-up execution point: compose `command`/`entrypoint` override in `docker-compose.dry-run.yml` so each bearer container runs its probe (after full init) instead of orchestration exec'ing it; reuse the normal init sequence (DRY), standard path untouched.
- The exact, step-by-step end-to-end `make dry-run` testing procedure (as a document) for the operator to run and return logs.

Deferred / not in scope: everything else (pre-existing items unchanged).

## Carried forward

| Item | From handover |
|---|---|
| Dry-run execution-point (probes at container start-up, compose override) — deferred as unverifiable without docker; escalated to a roadmap follow-on bullet | `20260828-01-impl-dry_run_feature_scope_trim` |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | Bearer probes run at container START-UP (compose `command:` override); orchestration no longer exec's them | Agent: trace tests (up present / exec absent). Operator: e2e E2E-1 | met (operator e2e: probes ran at start-up, no exec; full dry-run PASS) |
| AC2 | Extensible sandbox `command:` prelude: sandbox runs its probe after init/preflight then STAYS ALIVE (depends_on healthy + volumes-from + container_network hold) | Agent: entrypoint prelude + suite. Operator: e2e E2E-3 | met (operator e2e: container_network PASS both containers) |
| AC3 | `DRY_RUN_IDENTITY` baked into overlay env (not exec env); records still carry correct per-container identity | Agent: overlay + record contract (24 unit tests). Operator: e2e E2E-2 | met (operator e2e: identities matched, all layers PASS) |
| AC4 | Image-signature staleness hard gate retained on the start-up path | Agent: image-verify unit tests. Operator: e2e E2E-5 | met (agent unit tests + operator negative test: plain dry-run on edited sig-source shows container-sig stale WARNING + phase-3 FAIL/rebuild-required) |
| AC5 | Record-poll bounded/overridable (`DRY_RUN_RECORD_TIMEOUT`), suite deterministic (657/40/0) | Agent: full suite x2, lint 0 | met (agent) |
| AC6 | Exact end-to-end test procedure written | `docs/development/e2e-dry-run-container-startup-test.md` | met (agent; record format updated to textual layers) |

## Hot files
| File | Why in scope |
|---|---|
| [`src/build/compose.sh`](../../src/build/compose.sh) | `compose_dry_run` drops exec phases; start-up probes + bounded record-poll + Phase-3 verify |
| [`src/build/docker-compose.dry-run.yml`](../../src/build/docker-compose.dry-run.yml) | `command:` + DRY_RUN_IDENTITY start-up execution (replaces script-bind-only overlay) |
| [`src/capability/entrypoint.sh`](../../src/capability/entrypoint.sh) | optional start-up command prelude (after init, before stay-alive) |
| [`scripts/dry_run_capability.sh`](../../scripts/dry_run_capability.sh) / `dry_run_reasoning.sh` | unchanged (embedded via old overlay) |
| `tests/test_trace_dry_run.sh` | new shape: up present / no exec / bounded timeout |
| [`docs/development/e2e-dry-run-container-startup-test.md`](../../docs/development/e2e-dry-run-container-startup-test.md) | exact operator-run e2e procedure |

## Decisions
| Decision | Rationale | Scope |
|---|---|---|
| Extensible sandbox `command:` prelude (Option B) chosen over a dry-run special-case | command-shape validation: agent is already `command:`-extensible (serve precedent); sandbox lacked the hook; a run-and-exit start-up would break `depends_on: health` + `volumes_from` + L5 cross-checks, so the hook is a prelude that runs after init and then stays alive | this iteration |
| Probe execution moves to container start-up via a plain `command:` override in the dry-run overlay (same shape as the serve overlays); orchestration drops the exec phase and pulls records via poll | uniform invocation method across both layers and all command types; records remain source of truth | this iteration |
| Bug C resolved (operator) = option (a): KEEP the image-signature staleness hard gate; dry-run's contract is "validate the images as they exist", stale -> clear FAIL directing the user to `make build` / `REBUILD=1` (message not yet reworded) | preserves the correct-container guarantee; dry-run never rebuilds by construction, so it cannot mutate the image `make start` uses | this iteration |
| Bug A fix applied (operator-approved): bind-mount `${INPUT_DIR}` + `${OUTPUT_DIR}` on the SANDBOX service (it previously mounted only `${CHANGES_DIR}`), so the capability diagnostics record reaches the host | latent since the record contract (`20260828-01`); record-based Phase 3 exposed it | this iteration |
| Bug B solution NOT yet implemented -- operator asked for further explanation before committing (see Findings Bug B) | L6 stdin/TTY checks are exec/terminal-oriented; need a confirmed context-aware approach | this iteration |
| Bug B resolved (operator): REPLACE the non-functional stdin/TTY checks, don't keep them. L6 (agent_runtime) now asserts the probe runs as a bash script (not fed to the agent) + the agent binary is present/executable (readiness-to-take-input WITHOUT launching, which would start a real session). | checks that can never pass at headless start-up are dead weight; readiness = agent can accept input, which dry-run asserts without launching | this iteration |
| Standard invocation interface adopted (operator): provider agent containers standardize ENTRYPOINT = harness wrapper ONLY (no baked binary) and CMD/command: = the single extension point. All 3 providers rebased. | a baked-binary-ENTRYPOINT made compose `command:` args feed the provider binary as input (the "bash as chat input" bug); the standard fixes it systemically so start/serve/dry-run + future commands adapt to one dockerd-level baseline | this iteration |
| Readiness-layer labels renamed to textual STE100-style names (operator): docker_image / workspace_mounts / session_state / session_data / container_network / agent_runtime (record keys + sections + design record). | numeric L1..L6 labels force digging docs; contextual-knowledge-light textual labels are self-describing | this iteration + communications-convention principle |
| Bug E (stop template) handled like Bug D: recorded in Findings, escalated at iteration end (not fixed now; operator is already on it) | keep out of dry-run scope; avoid silently fixing an adjacent Makefile target | this iteration |

## Findings
- **Bug A (blocking, in-scope) -- capability record never reaches the host.** `src/build/docker-compose.yml` mounts `${OUTPUT_DIR}` + `${INPUT_DIR}` on the **agent** service only; the **sandbox** service bind-mounts only `${CHANGES_DIR}` yet sets `OUTPUT_DIR=/home/agentuser/workspace/output` in env. So `dry_run_capability.sh` writes `dryrun.capability.record` to the sandbox container's LOCAL volume, invisible to host orchestration -> host Phase 3 sees "timed out waiting for capability record / record missing" every time. Latent since the record contract landed (`20260828-01`); the record-based Phase 3 (my change) now exposes it. Fix: bind-mount output (+ input, which the capability probe asserts readable) on the sandbox service.
- **Bug B (in-scope) -- reasoning probe L6 stdin/TTY FAIL at start-up.** `dry_run_reasoning.sh` L6 runs `critical "stdin is not /dev/null" _stdin_not_devnull` + a `warn_check` stdin-is-a-TTY. These were authored for an exec/terminal context; at detached start-up (stdin=/dev/null, no TTY) they fail by design -> agent record `status=FAIL`, L6=FAIL -> Phase 3 fails. The start-up execution point is the new norm for dry-run, so the terminal/stdin checks should be context-aware (e.g. `DRY_RUN_STARTUP=1` from the overlay -> report stdin readiness as info, keep the headless liveness checks).
- **Bug C (UX/behavior, needs operator decision) -- REBUILD ownership + rebuild-side-effect worry.** Running `make dry-run` without `REBUILD=1` on stale images emits the container-sig WARNING then Phase-3 hard-FAILs (`dry_run_image_verify` stale/unknown). Operator asks: (1) should the user be the one to remember rebuilding? (2) does dry-run trigger rebuilds that mutate the image `make start` later uses?
- **Bug D (adjacent, pre-existing, NOT this change) -- `make start PROVIDER=pi RESUME=1` resets baseline instead of reusing the session volume.** RESUME semantics (volume/baseline reuse) not honoured. Separate; needs its own investigation.
- **Bug E (adjacent, pre-existing, Makefile template) -- `make stop` omits `--project`/`--sandbox` in `scripts/templates/Makefile.template`.** Operator patched their generated Makefile ad hoc; fix must propagate to the TEMPLATE. After the patch, `agent-sandbox stop` lists the same container IDs twice and `docker rm` reports "removal of container ... already in progress" -> second defect (duplicate stop/id emission).

- **Principle to harden -- contextual-knowledge-light naming (communications convention).** Numeric/opaque labels (`L1..L6`) force readers to dig docs for meaning. Prefer short, textual, STE100-style names (e.g. readiness layers now `docker_image / workspace_mounts / session_state / session_data / container_network / agent_runtime`). Escalate: fold this principle into the communications conventions (AGENTS.md / docs/development/conventions.md) at iteration end.
- **Finding (operator, iteration close) -- SERVE mode integration is a standalone roadmap item, not a dry-run concern.** SERVE is not in regular use and may be out of date; the serve overlays (hermes/opencode) were rebased to the standard invocation interface this iteration but NOT docker-tested (operator: not convenient); pi lacks feature integration to support server mode. Elevate: named roadmap item for SERVE mode integration (uses + verify + pi server-mode support); do NOT fold into dry-run follow-ups.
- **Verification status (operator e2e, `make dry-run PROVIDER=pi REBUILD=1`):** FULL PASS. Both per-container records written + phase-3 verified; every layer PASS on both containers (incl. `agent_runtime` -- confirming the bash-script invocation guard and dropped stdin/TTY checks); image signatures match source; `Phase 3 PASSED` / `ALL PHASES PASSED`. Bug A fix confirmed (capability record reaches host). `make start PROVIDER=pi` works. Negative staleness test confirmed: plain dry-run on an edited sig-source emits the container-sig stale WARNING + phase-3 FAIL/rebuild-required.
## Completed
| File | Change |
|---|---|
| [`src/build/compose.sh`](../../src/build/compose.sh) | `compose_dry_run`: drop exec Phase-1/2; start-up probes via overlay; bounded/overridable record-poll (`DRY_RUN_RECORD_TIMEOUT`); Phase-3 verify unchanged |
| [`src/build/docker-compose.dry-run.yml`](../../src/build/docker-compose.dry-run.yml) | `command:` override (sandbox prelude / agent one-shot) + `DRY_RUN_IDENTITY` baked env |
| [`src/capability/entrypoint.sh`](../../src/capability/entrypoint.sh) | optional start-up command prelude after init/preflight, before stay-alive (`$# > 0`) |
| [`src/build/docker-compose.yml`](../../src/build/docker-compose.yml) | Bug A fix: bind ${INPUT_DIR} + ${OUTPUT_DIR} on SANDBOX service so the capability record reaches the host |
| `tests/test_trace_dry_run.sh` | assert up-present / exec-absent / no-reset / refresh not changed; bounded timeout |
| `docs/development/e2e-dry-run-container-startup-test.md` | Phase A..E operator e2e procedure + acceptance gates |
| `src/reasoning/providers/{pi,hermes,opencode}/provider.dockerfile` | standard interface: ENTRYPOINT = wrapper only, add CMD agent binary |
| `src/reasoning/providers/{hermes,opencode}/docker-compose.serve.yml` | rebase serve command: to include the binary |
| `src/reasoning/entrypoint.sh` | doc: first command arg is agent binary or dry-run script; wrapper runs it verbatim |
| `docs/operations/provider_onboarding_guide.md` | document the standard invocation interface as the provider contract |
| readiness-layer rename | workflow_mounts keys renamed: probes, `dry_run_record.sh`, tests, design doc, e2e doc -> docker_image / workspace_mounts / session_state / session_data / container_network / agent_runtime; L6 agent_runtime now asserts probe-as-bash-script + agent binary ready (no stdin/TTY) |
| This handover | scope, decisions, findings, ACs |

## Deferred items
- **Bug D -- `make start PROVIDER=pi RESUME=1` resets baseline instead of reusing the session volume** (pre-existing, outside dry-run): escalate to a named roadmap item at iteration end.
- **Bug E -- `make stop` missing `--project`/`--sandbox` in `scripts/templates/Makefile.template` + duplicate container-ID emission -> `docker rm ... already in progress`** (adjacent, pre-existing): escalate at iteration end.
- **SERVE mode integration** -- elevated to its own roadmap bullet this iteration (see roadmap); serve untested post-interface-change.
- **Principle -- contextual-knowledge-light naming** -- fold into communications conventions (AGENTS.md / docs/development/conventions.md) at iteration end.

## What's Next
M2.6 - Session Persistence. Post-close bookkeeping: n/a (mid-milestone).
Primary deliverable verified end-to-end by the operator: `make dry-run PROVIDER=pi REBUILD=1` -> ALL PHASES PASSED (both records, all layers PASS both containers, image-sig gates PASS); `make start PROVIDER=pi` works; negative staleness test confirmed. Execution-point + standard-invocation-interface + readiness-label rename + Bug A fix all landed. Next iterations: M2.6 general; **dry-run probe-check unit-test harness** (LIBS_DIR-parameterize the probes so the host suite tests each layer's checks in isolation) -- proposed as the next iteration scope; SERVE-mode integration (roadmap bullet); Bug D (RESUME) + Bug E (stop template) escalation.
Watch-outs: dual-grep bridge; full-tree close-out greps.