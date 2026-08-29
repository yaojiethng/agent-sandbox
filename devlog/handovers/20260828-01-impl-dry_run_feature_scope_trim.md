# Agent Handover

**Date:** 2026-08-28
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Trim the dry-run path so each readiness assertion is owned exactly once: the two dry-run containers (bearer) each run their own full L1..L6 self-checks and write a per-container diagnostics record; orchestration validates the correct container was started from those records. Includes the task rename "diet" -> "feature scope trim" and the mount-delivery "wired, not ready-to-run" claim correction. Full repo init RETAINED -- the snapshot cost-trim is out of scope this iteration.

## Scope
Authoritative design: [`devlog/discussions/20260828-design-settled-dry_run_phase_split.md`](../../devlog/discussions/20260828-design-settled-dry_run_phase_split.md) -- readiness layers L1..L6, responsibility split (bearer / container preflight / orchestration), per-container record contract. This handover carries the iteration-scoped working deltas.

In scope:
- Check-ownership dedup per layer + L1..L6 ordering in each probe (matrix below)
- Per-container diagnostics record (capability + reasoning) written at startup on a host-visible mount; orchestration consumes + validates correct-container (version/signature in-container == expected)
- Drop stale `brief.md` from the reasoning probe; fix `tests/knowledge/diagnose_preflight.sh:162` + `docs/architecture/provider_lifecycle.md:41` residue
- Move the orchestration-convenience container-sig staleness WARNING out of the bearer path
- Mount-delivery claim correction (applied: roadmap M2.6.6 changed to "wired, not confirmed runnable end-to-end")
- Tests (docker-stub for pre-start; in-env probe run for post-start) + docs (`execution_model.md`, `tool_interface.md`)

Not in scope / deferred: snapshot cost-trim (full rsync removal -- operator: full init retained); `.compose/*.yml` stale pruning; test-harness hardening follow-ons (shellcheck-to-blocking, helper migration); `confirm.sh` savepoint-rollback latent bug (operator behavior decision); dry-run interactive wizard.

## Working change matrix (check-ownership deltas -- tracking doc)

Layer order L1..L6. Bearer container: cap (sandbox) / rea (agent). CP = container preflight (every `up -d`). ED = dry-run probe. HS = host preflight.

| Layer | Check | Owner today | Duplicate of | Trim action |
|---|---|---|---|---|
| L1 Image | baked libs/entrypoint present | ED-cap + CP (diff/routing WARN) | CP libs check | dedup: drop from ED-cap; CP owns L1 every start |
| L2 Link-up | CHANGES_DIR writable | ED-cap + CP | CP | dedup: drop from ED-cap |
| L2 Link-up | SNAPSHOT_DIR readable / baseline.tar present | ED-cap + CP (copy) | CP | dedup: drop from ED-cap (CP owns mount presence) |
| L2 Link-up | INPUT_DIR readable, OUTPUT_DIR writable (ro/rw) | ED-cap/rea only | none | keep (ED-only semantics) |
| L3 State | init_sha/session_ts presence | ED-cap + CP | CP | dedup: drop presence; keep validity |
| L3 State | init_sha is a valid commit | ED-cap only | none | keep (validity depth) |
| L3 State | SESSION_STATE via shared .git (rea) | ED-rea only | none | keep |
| L3 State | version-in-container == expected sig | (new) | - | add: correct-container (orchestration), from recorded metric |
| L4 Data plane | diff_export runs, .export-status, autosave, export_path, lockfile | ED-cap only | none | keep (dry-run-only depth) |
| L5 Cross-component | marker round-trip cap->rea, session-diffs round-trip, SANDBOX_DIR visible | ED-cap/rea only | none | keep |
| L6 Runtime | stdin not /dev/null, TTY char-device, liveness write | ED-rea only | none | keep |
| stale | brief.md present | ED-rea (warn) | - | drop; fix knowledge-test + doc residue |
| HS | container-sig staleness WARNING | HS | - | move: orchestration-only; orchestrator ensures up-to-date |
| CP-only | AGENTS.md@AGENT_HOME, working tree clean | CP | - | keep (standard-start concerns) |

Plus: reorder each probe script so checks appear in L1..L6 layer order. Mechanism: probes run as the containers' start-up execution (compose `command`/`entrypoint` override in the dry-run overlay), each writing one record to the output mount; orchestration merges/validates -- replacing `docker compose exec` + scattered host-phase-3 checks.

## Carried forward

| Item | From handover |
|---|---|
| Dry-run feature scope trim - cut pre/post-flight to e2e-probe semantics; options (a) full trim / (b) partial trim, decide with timing measurements; DRY constraint: extract compose-file-set assembly into a lib first | `20260823-16-impl-remove_serve_toggle_on_start` |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `make dry-run` produces TWO per-container diagnostics records (capability + reasoning) on a host-visible path; orchestration validates the correct container from them (replaces stdout capture) | Agent: in-env record-writing probe run + 24 unit tests. Operator: e2e `make dry-run` | accepted |
| AC2 | No L1..L6 readiness assertion owned by both the container preflight AND a dry-run probe (each owned once) | Agent: code/ownership trace | accepted |
| AC3 | `brief.md` removed from `scripts/dry_run_reasoning.sh`, paired negative grep empty; `diagnose_preflight.sh` + `provider_lifecycle.md` corrected | Agent: grep empty + suite green | accepted |
| AC4 | Staleness no longer surfaced as a bearer-path warning; correct-container asserts the TRUE image-signature (option c): `dry_run_image_verify` hard-gates fresh/stale/unknown | Agent: unit tests (stale/fresh/unknown/skip). Operator: e2e `make dry-run` | accepted |
| AC5 | Full repo init retained: dry-run bearer asserts against a fully-initialised repo (init_sha valid) | Agent: suite + in-env probe | accepted |
| AC6 | Each dry-run probe lists its checks in L1..L6 layer order | Agent: read of probe files | accepted |

## Hot files
| File | Why in scope |
|---|---|
| [`scripts/dry_run_capability.sh`](../../scripts/dry_run_capability.sh) | bearer capability checks: dedup, L1..L6 order, record write |
| [`scripts/dry_run_reasoning.sh`](../../scripts/dry_run_reasoning.sh) | bearer reasoning checks: drop brief.md, dedup, L1..L6 order, record write |
| [`src/build/docker-compose.dry-run.yml`](../../src/build/docker-compose.dry-run.yml) | execution-point override (command/entrypoint) + diagnostics-record mount |
| [`src/build/compose.sh`](../../src/build/compose.sh) | `compose_dry_run` orchestration: consume records, correct-container validation |
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | dry-run dispatch / orchestration wiring |
| [`src/capability/entrypoint.sh`](../../src/capability/entrypoint.sh) | CP ownership reference (dedup source); stay-alive for cross-container phase |
| `tests/` (test_dry_run, test_dispatch, test_trace_dry_run, knowledge probes) | pre-start stub + in-env probe-run coverage |
| [`docs/architecture/execution_model.md`](../../docs/architecture/execution_model.md), [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | dry-run flow + surface docs |
| [`devlog/discussions/20260828-design-settled-dry_run_phase_split.md`](../../devlog/discussions/20260828-design-settled-dry_run_phase_split.md) | authoritative design record (layers + responsibility split + record contract) |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Task renamed "diet" -> "feature scope trim" (operator phrasing); options (a) full trim / (b) partial trim | "diet" reads oddly as a task name; "feature scope trim" describes the action (trimming dry-run's feature scope) | `devlog/roadmap.md` L154 bullet + this handover |
| Historical handover `20260823-16` keeps "diet" wording | Bucket C3 precedent - historical records are not retro-renamed | this handover |
| Iteration type = `impl`; delivery commit prefix = `refactor` (operator) | git_policy maps `refactor` -> `impl`; dry-run trim via refactor is minor-loop Step-6 code restructuring | git_policy.md Active Types; handover header |
| Dry-run uses TWO containers; checks run in their corresponding containers (not orchestration-exec) | preserves L5 cross-component assertion (bearer self-completeness across the two containers) | operator reframe, session `20260828` |
| 6-layer readiness taxonomy confirmed (L1 Image / L2 Link-up / L3 State / L4 Data plane / L5 Cross-component / L6 Runtime) | operator-confirmed decomposition | this handover |
| Separation of concerns: bearer (dry-run container) asserts self-completeness + records diagnostics/metrics; orchestrator (dry-run.sh) asserts correct-container by consuming the record | operator reframe | this handover |
| Stale-warning is orchestration convenience (excluded from bearer); version-in-container == expected is a correct-container (orchestration) check, retained | operator reframe + Q5 | this handover |
| Execution mechanism: probes run as the containers' start-up execution (compose `command`/`entrypoint` override in the dry-run overlay), each writing one diagnostics record to the output mount; orchestration docker-waits + reads + validates. Chosen over interactive `docker compose exec`+stdout for determinism (exit + written record over exec RC + stdout parsing). Trade-off recorded in the design doc, rejected trails omitted. | operator: keep trade-offs in design doc, drop tried-and-rejected | design doc + this handover |
| ADR foreclosure: this design is a documentation record, not (yet) an ADR -- promote to architecture + ADR only when all orchestration commands meet the same completeness standard (avoids ADR open/close churn) | operator | design doc Consequences |
| AC4 option (c) chosen (operator, session close): TRUE image-signature correct-container check -- `dry_run_image_verify` hard-gates the running image's container-sig against the recomputed source sig (fresh PASS / stale FAIL / unknown FAIL), replacing the warning on the dry-run bearer path | operator selection; strongest correct-container assertion | `src/libs/dry_run_record.sh` + design doc |

## Findings

| Finding | Type | Impact |
|---|---|---|
| **Q1 answer (operator): no-mount snapshot transfer has NOT landed.** `baseline.tar` is still transferred via the read-only SNAPSHOT_DIR bind mount (`docker-compose.copy.yml`: `source: ${SNAPSHOT_DIR}` -> `/home/agentuser/.snapshot`, `read_only: true`); `snapshot_init_git` reads it directly from the mount; the sandbox image is baked from repo-root context (COPYs libs/dockerfile only), never the project snapshot. Historical handover `20260503-01` removed a surplus copy-into-sandbox-worktree (a tracked-binary bug), NOT the mount. Dry-run uses the same mount-based pipeline as standard, so it is consistent with the current mechanism; there is no separate no-mount path to be out of sync with. | steering / factual | this iteration |
| **Method correction (operator): end-state assertions first, intermediate steps second.** Do not reason from intermediate steps (baseline.tar, snapshot_validate, snapshot_init_git). First define what dry-run asserts = "container properly set up and ready for use", refined by the set: `init_sha is a valid commit`, `diff_export runs`, `brief.md exists`. Only after that set is agreed, resolve the intermediate pipeline against what's already implemented, adding defensive checks only if needed. | steering | this iteration (redesign method) |
| **Verification method (operator): docker-stub for pre-start, in-env probe run for post-start.** Pre-start scripts (start_agent.sh/run_agent.sh/compose generation/flags) tested against the docker stub. Post-start probes (dry_run_capability.sh/dry_run_reasoning.sh) are run inside the container and can be executed against synthetic test state in THIS env (no docker needed). Operator runs end-to-end after unit tests. This resolves the earlier no-docker blocker; wall-clock timing is the operator's post-delivery verification, not a prerequisite. | steering / blocker-resolved | this iteration |
| **Refinement 1 (operator): `brief.md` is retired as an input file.** It was never populated (an unpopulated template); the input channel (`~/workspace/input/`, `INPUT_DIR`) remains wired and occasionally used for operator-supplied files, but `brief.md` is not used for agent orientation. The removal pass was partially done, leaving residue. Confirmed present in code: `scripts/dry_run_reasoning.sh:187` (`warn_check "brief.md present in INPUT_DIR" test -f "$INPUT_DIR/brief.md"` -- a stale assertion in the dry-run probe itself), `tests/knowledge/diagnose_preflight.sh:162`, `docs/architecture/provider_lifecycle.md:41` (claims start_agent.sh stages brief.md, which it no longer does). So `brief.md exists` must NOT be in the readiness assertion set; the residue is a scope decision (drop probe check, fix test + doc). | steering | this iteration (assertion set) |
| **Refinement 2 (operator): do not claim mount-delivery is ready to run.** The roadmap flags M2.6.6 "Mount delivery enablement - Resolved (session 20260820-01)", but end-to-end "ready to run" is not the case (Q1: no-mount/baseline.tar transfer still incomplete; run_agent.sh comment says mount "gains full behavior in M2.6.6 delivery enablement"). Avoid over-claiming mount readiness anywhere we touch. | steering | this iteration / next iteration (claim audit) |
| **Refinement 3 + Q (operator): readiness framing correct, but is a separate prefactor needed to separate mount-delivery defensive checks from dry-run and preflight, or is the refactor itself the trim?** Answer developed in chat: NO separate prefactor. The modularity -- declaring which readiness checks each lifecycle layer (host preflight / container preflight / dry-run probe / mount-delivery branch) owns, with no double-checking -- IS the mechanism of the trim; there is no prerequisite restructuring to land first. One genuinely separate dimension remains: the snapshot FLOW/pipeline cost reduction (mode-aware snapshot in start_agent.sh, dropping full rsync/baseline for dry-run) is a flow change distinct from check modularity. | design decision | this iteration (method) |
| **Refinement 4 + Q (operator): assertion set incomplete; want full enumeration of the internal mount/round-trip/TTY/liveness checks, and for each, whether it's checked in dry-run AND in start's preflight (which lifecycle layer).** Full matrix produced in chat and kept in the handover analysis; see the Lifecycle Check Matrix below. | steering | this iteration (assertion set) |
| **Implementation finding: the compose `command`/`entrypoint`-override execution-point is DEFERRED (unverifiable without docker).** The recorded mechanism decision says probes run at start-up via a compose override. With full repo init retained, that override must re-run the normal sandbox entrypoint init (snapshot_init_git + SESSION_STATE + preflight) before the probe -- invasive, and the container-start path cannot be validated in this no-docker env. Implemented instead: the probes write a per-container record to the output mount and orchestration reads/validates the records (the determinism the design targeted), keeping the existing probe invocation which yields full init via the normal `up -d` entrypoint. AC1 reframed to the record contract; the literal exec->startup swap is a follow-up. | blocker / scope change | this iteration (execution point) |

## Completed

| File | Change |
|---|---|
| [`scripts/dry_run_capability.sh`](../../scripts/dry_run_capability.sh) | dedup (drop CP-owned baked/mount/presence), L1..L6 order, per-container record write |
| [`scripts/dry_run_reasoning.sh`](../../scripts/dry_run_reasoning.sh) | remove stale `brief.md` check, L1..L6 order, per-container record write |
| [`src/build/compose.sh`](../../src/build/compose.sh) | `compose_dry_run` consumes records + correct-container image-signature gate (Phase 3) |
| [`src/libs/dry_run_record.sh`](../../src/libs/dry_run_record.sh) | new: record read/verify + `dry_run_image_verify` (option c) |
| [`tests/test_dry_run_record.sh`](../../tests/test_dry_run_record.sh) | new: 24 unit tests (record contract + image gate) |
| [`tests/knowledge/diagnose_preflight.sh`](../../tests/knowledge/diagnose_preflight.sh) | drop stale `brief.md` warn check |
| [`docs/architecture/provider_lifecycle.md`](../../docs/architecture/provider_lifecycle.md) | correct `workspace/input/` brief.md claim |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | `make dry-run` + Dry-Run Guarantees -> readiness/record model |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | feature-scope-trim bullet closed + follow-on; mount-delivery "wired, not ready-to-run" correction |
| [`devlog/discussions/20260828-design-settled-dry_run_phase_split.md`](../../devlog/discussions/20260828-design-settled-dry_run_phase_split.md) | new: readiness model + bearer/orchestration split (settled) |
| This handover | scope, decisions, findings, ACs, deferrals |

## Deferred items
- **Dry-run execution-point (probes at container start-up, compose `command`/`entrypoint` override)** - deferred: needs a start-up wrapper re-running full init (DRY), container-start path unverifiable without docker. Escalated to a `devlog/roadmap.md` follow-on bullet (sole in-scope deferral).
- (Pre-existing separate items, not from this session - roadmap-named, not re-listed: snapshot cost-trim, `.compose/*.yml` stale pruning, `confirm.sh` savepoint bug, test-harness hardening follow-ons.)

## What's Next
M2.6 - Session Persistence. Post-close bookkeeping: n/a (mid-milestone).
Next iteration: the dry-run execution-point follow-on (roadmap bullet) -- run the bearer checks at container start-up via a compose override reusing full init; verifiable only on a docker machine (the operator's end-to-end run).
Watch-outs (gotchas, session-open): dual-grep bridge for old-heading handovers; full-tree close-out greps; table-row append edits keep the anchor row.
Operator e2e pending: `make dry-run` on a real machine (AC1/AC4/AC5 end-to-end).
