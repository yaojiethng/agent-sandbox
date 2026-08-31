# Dry-run Readiness Model & Responsibility Split

**Date:** 2026-08-28
**Milestone:** M2.6 - Session Persistence
**Type:** design
**Status:** settled

## Context

`make dry-run` is the procedure that verifies the harness containers start to a ready state. Today it conflates two distinct responsibilities and mixes concerns:

1. **Orchestration** concerns (image staleness warnings, build policy, version choice, session bookkeeping) are emitted from inside the dry-run flow, although they are decisions the harness makes, not properties the container reflects.
2. **Container-readiness** concerns are partly double-asserted: the container preflight (entrypoint, runs on every `up -d`) already guarantees baked-file presence, mount presence, and SESSION_STATE presence, yet the dry-run probes re-assert those same checks.

The flow also carries a stale assertion (`brief.md`), which is a retired input channel, and pays full session-start cost (full repo init) whose value as a readiness probe has never been separated from its cost.

The model below is the durable reference for the set of checks that determine container/agent readiness and the responsibility split between the components that assert them.

## Decision

### Two-actor model

Dry-run is composed of two actors with a strict responsibility split:

- **Bearer — the dry-run containers** (capability/sandbox + reasoning/agent), each of which:
  - runs its own full e2e self-check set (the readiness inventory below);
  - records one **diagnostics record** per container to a host-visible mount;
  - returns.
- **Orchestration — the `dry-run.sh` procedure** (invoked via `make dry-run`), which:
  - handles build, startup, teardown, cleanup;
  - consumes the two records and asserts that the **correct container** was started (version/signature in-container == expected, identity, mount wiring, record completeness), referring to the recorded diagnostics/metrics.

Both the container checks and the orchestration checks are part of the full dry-run procedure.

### Readiness layers

Readiness is judged against six ordered layers, delivery- and lifecycle-agnostic, each named with a short textual label (STE100-style -- precise, no numeric indirection):

| Layer | Assertion (this layer = ready) |
|---|---|
| docker_image | image correctly constructed: baked libs/entrypoint/docs present, entrypoint is the entrypoint |
| workspace_mounts | compose-time wiring correct: delivery mounts (copy: volume + snapshot ro; mount: worktree bind) and workspace channels (INPUT ro / OUTPUT rw / CHANGES rw) at the right targets |
| session_state | entrypoint-derived state present + valid: SESSION_STATE keys, git baseline, init_sha valid, version-in-container == expected |
| session_data | functional capability runs: diff_export, export_path, package_branch, autosave, git lockfile |
| container_network | containers see each other: volumes-from, marker round-trip capability->reasoning, shared-workspace readback |
| agent_runtime | process runtime: entrypoint up + stay-alive, agent binary ready to take input, ro/rw semantics, liveness |

### Responsibility split (who asserts each layer)

| Owner | Scope | Layers owned |
|---|---|---|
| Container preflight (CP, entrypoint, every `up -d`) | minimal invariants for ANY start | docker_image baked-libs; workspace_mounts mount presence; session_state presence; working-tree-clean / AGENTS.md (standard-start concerns) |
| Bearer dry-run (ED, the two containers in dry-run) | the readiness DEPTH for a verified start | session_state validity (init_sha valid commit); session_data (diff_export runs); container_network cross-component; agent_runtime process; workspace_mounts ro/rw semantics ED-only |
| Orchestration (dry-run.sh) | correct-container verification via records | workspace_mounts wiring (from records); session_state version-in-container == expected; container_network write-back; record completeness |

The trim's subject is duplicated assertion between CP and ED, and orchestration-convenience warnings leaking into the bearer. Each readiness assertion is owned exactly once.

### Record contract (one per container)

Each bearer container writes one diagnostics record (capability record + reasoning record) to a host-visible path during startup. Orchestration merges and validates them:

- container identity / version (image signature) used for the correct-container check;
- completeness marker per layer with pass/fail;
- a terminal status the orchestration can wait on (container exit encodes done).

### Execution mechanism (trade-off)

The checks could run either as interactive `docker compose exec ... bash /dry_run_*.sh` (the current shape) or as the container's own start-up execution that writes records and returns. We chose the latter:

- **Determinism.** exec is *pull*: it depends on the container being up/healthy when exec fires, returns live stdout, and the orchestration parses stdout to judge success - the flakiest capture available (the existing overwrappers `|| true` + `grep -vE` already encode that fragility). Record-writing start-up is *push*: the container does its checks, writes a structured record, and encodes completion in its exit; orchestration does `docker wait` + reads a file. Exit codes and a written record are deterministic artifacts; there is no exec channel and no stdout parsing.
- **Selection point.** The execution point is selected in the dry-run compose overlay (`command:`/`entrypoint:` override), not the Dockerfile, so the canonical image entrypoint is untouched and standard mode is unaffected. The number-gating requirement (keep full repo init) means the dry-run execution point must reuse the normal init sequence via the existing lib functions (DRY) rather than copy orchestration - specialize, don't consolidate.

One hard constraint shapes the mechanism: the cross-component phase (container_network) needs the sandbox up while the agent reads its marker (volumes-from), so the sandbox runs its checks, writes its record, and *stays alive* through the agent's phase; the agent runs, writes, and exits.

### Scope of the trim

- Full repo init RETAINED (dry-run bearer asserts against a fully-initialised repo). The snapshot cost-trim (dropping the full rsync) is explicitly off the table this iteration.
- Trim = deduplicate CP/ED owners per layer, drop the stale `brief.md` assertion, order each probe image -> workspace -> state -> data -> network -> runtime, move orchestration-convenience warnings (image staleness) out of the bearer.
- The per-check dedup matrix (which check moves/drops/reorders) is this iteration's working state in handover `20260828-01`.

## Consequences

**Changes:**
- The dry-run probes become record-writing startup execution (selected via the dry-run compose overlay), replacing `docker compose exec` + scattered host-phase-3 checks.
- Orchestration validates records + correct-container (version/sig in-container == expected) instead of pulling stdout.
- Standard (non-dry-run) startup is unchanged; the container preflight stays the minimal-every-start owner.
- The stale `brief.md` assertion is removed; its knowledge-test and a `provider_lifecycle.md` doc line get corrected.
- The mount-delivery "enablement" roadmap record is qualified to "wired, not confirmed runnable end-to-end".

**Enables:** a uniform readiness + responsibility model that other orchestration commands can adopt (same completeness standard), so future commands don't re-derive their own check inventories.

**Forecloses / deferred:**
- The snapshot cost-trim (full rsync removal) for dry-run.
- Promotion to a formal ADR. **This is a documentation record, not an ADR**, deliberately: opening/closing an ADR now would churn until all orchestration commands meet the same completeness standard. Promote to `docs/architecture/` + ADR when the model stabilises across commands.