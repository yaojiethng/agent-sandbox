# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Deliver the **registry-based prune (Rules 1+2) + full prune command-shape redesign** (roadmap L249 + L141). Replace `prune.sh`'s legacy volume-label `--stale` and age-based `docker system prune` with a registry-truth `.compose` model (D7), realize Rule 1 (prune stale `.yml` records per args) and Rule 2 (prune resources whose session has no matching `.compose` record), and redesign the command surface per L141 minimums (descriptive option names, interactive mode with cutoff + confirmation, explicit scope semantics; **`STALE=1` terminology rejected**).

**Scope note:** this is a **design + implementation** iteration — the exact command shape must be settled (Gate 2) before coding. The N3 mount-lock shape is assessed but likely stays a separate item.

## Confirmed design (from roadmap L141 + design walk `20260818-02`, mount-model record #7)

**Original prune rules:**
- **Rule 1** — prune `.compose/*.yml` per prune args (the stale records).
- **Rule 2** — a run with no matching `.compose/<session-id>.yml` record is prunable; **scope differs by delivery** (copy: volume + containers; mount: registry resources only; worktrees never touched).

**L141 command-shape minimums:** interactive mode showing the cutoff + ask confirmation; descriptive option names; explicit scope semantics. `STALE=1` rejected (boolean-vs-filter ambiguity; unknown "everything" scope).

## Current implementation to replace (`scripts/prune.sh`)
- `--name=<project> --sandbox=<path> [--stale]`.
- Non-stale mode: `docker system prune --force --all --volumes` filtered by `agent-sandbox.project-name` + `agent-sandbox.sandbox-dir` labels, `until=3d`.
- `--stale` mode: `docker volume ls` filtered by sandbox-dir label, inspect `host-head-sha` vs current HEAD → rm stale volumes.
- Invoked via `make prune` (targets at Makefile.template L230) and `make stop PRUNE=1 STALE=1`.
- Makefile vars: `STALE ?=`, `STALE_FLAG`, `PRUNE_FLAG` (L77/98/99); help lines L120/134; comment block L43-46, L226-227.

## Registry / resource naming (for Rule 2 discovery)
- **Registry records:** `$SANDBOX_DIR/.compose/<session-id>.yml`; label `agent-sandbox.host-head-sha` (staleness source); `.compose/` is gitignored.
- **Container names:** `sandbox-<project>-<session-id>`, `<provider>-<project>-<session-id>` (session_env.sh L118-119).
- **Container labels** (docker-compose `x-session-labels`, L41-47 + base anchor L35-38): `agent-sandbox.project-name`, `agent-sandbox.sandbox-dir`, `agent-sandbox.host-head-sha`, `agent-sandbox.host-branch`, `agent-sandbox.session-ts`, `agent-sandbox.session-id`. So Rule 2 resource discovery = `docker ps -aq --filter label=agent-sandbox.sandbox-dir=...` then read each resource's `session-id` label; no `.compose/<id>.yml` → orphan.
- **Staleness helper** (reusable, added `20260821-07`): `session_stale(file, [current_sha])` → `fresh/stale/unknown`. Lives in `resume_agent.sh`. For prune reuse, consider lifting it (or a copy) into a shared lib consumed by both.

## Settled scope (operator answers, `2026-08-21`)

The Gate 2 open questions are **resolved**; remaining is the filter set (proposed below).

**D8-1 — Interactive follows the other commands' convention.** `make prune INTERACTIVE=1` is a wrapper/wizard: collect the choices, **construct a fully-formed non-interactive `make prune ...` command**, print the equivalent command, confirm, then dispatch/act. Mirrors `resume`/`draft`/`apply` interactive convention.

**D8-2 — Rule 1 removes records only.** Rule 1 deletes stale `.compose/*.yml` records. It does not touch resources. Rule 2 (separate pass) cleans up the now-orphaned resources.

**D8-3 — Rule 2 implements both copy and mount scopes this iteration.** Delivery is read from the `.compose` record's sandbox-service `SANDBOX_TYPE=copy|mount` (verified: set in the delivery-overlay env, copy.yml L39 / mount.yml L19) — so it is recorded. Copy → volume+containers; mount → registry resources only (containers/networks; worktrees never touched — automatic, we never touch worktrees).

**D8-4 — Command shape is `make prune [INTERACTIVE=0|1] [DRY_RUN=0|1]` + filters.** No `RECORDS=stale`; `STALE=1` boolean remains rejected. **`SCOPE` is dropped** (operator `2026-08-21`): prune is never intentionally incomplete — you always run the full prune (Rule 1 records + Rule 2 resources); simulation is `DRY_RUN=1`, not a scope split.

**D8-5 — A staleness-kind filter distinguishes sandbox-stale from image-stale (operator `2026-08-21`).** Two distinct staleness dimensions for the "remove all stale" filter — recorded in `docs/concepts/terminology.md` (`## staleness`, added this iteration):
- **sandbox-stale** — repo out of date: session's `host-head-sha` ≠ current project HEAD (registry-truth, `session_stale`).
- **image-stale** — image out of date: the image's `agent-sandbox.container-sig` label ≠ recomputed source sig, so even resuming yields an incomplete/outdated feature set.

**D8-6 — Image-staleness detection is NOT yet implemented; the `STALE=image` flag is wired but raises "not yet implemented" (operator correction `2026-08-21`).** The image-staleness *criterion* is deferred to a future iteration (it needs `docker image inspect` + `container_sig` recompute; no-live-docker untestable). This iteration implements the flag + the error (mirroring the old `start --interactive` not-yet-implemented pattern), to be wired when image-staleness lands. Sandbox-staleness (`STALE=sandbox`/`all`) is fully implemented.

## Confirmed filter set (Gate 2 approved)

- `INTERACTIVE=0|1` — interactive wrapper (construct + print + confirm + act).
- `DRY_RUN=0|1` — print what would be pruned without acting (the simulation path; `SCOPE` dropped).
- `STALE=<sandbox|image|all>` — narrow Rule 1's stale-record selection to a staleness kind. `sandbox` = fully implemented; `image` = **flag wired, raises "not yet implemented"** (deferred, see roadmap); `all`/unset = all implemented kinds (sandbox).
- `PROVIDER=<n>` — narrow Rule 1 to records whose provider matches (reuse `record_provider`).
- `AGE_DAYS=<n>` — Rule 1 age cutoff on `session-ts` (default `PRUNE_AGE_DAYS=3`). A record must be sandbox-stale **and** older than the cutoff to be selected (G2-2: `AGE_DAYS` is a narrowing guard, not an independent criterion — on `AGE_DAYS=0` even the newest stale record is pruned).
- Rule 1 default selection = stale records of the implemented kind (sandbox), narrowed by `STALE`/`PROVIDER`/`AGE_DAYS`. Rule 2 = orphaned resources (labeled `sandbox-dir`, whose `session-id` has no record). Prune is always a complete pass (Rule 1 + Rule 2 together).

## Decisions (this iteration)

- **Shared inventory lib** — `record_provider`, `record_label`, `session_stale` lifted from `resume_agent.sh` into `src/libs/session_inventory.sh`, consumed by both resume and prune (no duplication).
- **Prune requires `--project`** — dispatcher `prune` and `stop` now use `require_base_args` (name+project+sandbox) and pass `--project`; `stop --prune` forwards it. `require_name_sandbox` removed (dead).
- **G2-3 (age semantics)** resolved at implementation: `AGE_DAYS` narrows the stale selection (sandbox-stale AND older than cutoff).
- **No formal design record** — the settled scope + this handover suffice; the requirement is fully self-contained.

## Findings

- **F-B1: pipefail + no-match `grep` in the record helpers aborts callers.** Original `record_label`/`record_provider` pipelines returned the `grep` exit (1) on no-match; under `set -o pipefail` that made `delivery="$(record_label ...)"` abort on the first absent label. Fixed by `|| true` on the pipeline in `session_inventory.sh` (and `env_field` in prune). Latent in resume too for any absent label — now robust.
- **F-B2: compose env extraction** — the sandbox-service `SANDBOX_TYPE` line is `- SANDBOX_TYPE=copy` (dash+space), so `.*-SANDBOX_TYPE=` never matched; fixed to `s/.*[[:space:]]-*[[:space:]]*VAR=.../\1/`. Delivery correctly recovered as `copy`/`mount` for Rule 2 scope.
- **F-B3: `require_name_sandbox` became dead** in the dispatcher once stop/prune moved to `require_base_args`; removed.
- **F-R1 (code review, CRITICAL): the "complete pass" was incomplete.** The plan was captured *before* any action, and Rule 2's orphan test was `! -f <record>`; a session whose record Rule 1 removes still had that record on disk at scan time, so its resources were never captured as orphans and were left behind. **Fixed** — see **R-R1** (honest-sequential) below.
- **R-R1 (review round 2, operator): execution is now strictly sequential with the registry as the single source of truth at each step.** Rule 1 removes the records first (collecting `SIDS_PRUNED`, the removal result); Rule 2 then does a **fresh scan** of the updated registry — a resource is an orphan iff it has no `.compose` record on disk. Removing a record makes its session orphaned, which the fresh Rule-2 scan catches in the same pass. No in-memory set couples the two rules. **Preview** (--dry-run/--interactive) cannot delete-then-rescan, so it uses a render-only `TREATED_REMOVED_SIDS` prediction (Rule-1-selected SIDs treated as already removed); the real action always re-scans. Rule-1 execution iterates `SIDS_PRUNED` directly.
- **R-R2 (code review, structural):** prune.sh's three near-identical container/network/volume scan blocks adapted into a single `collect_orphans KIND ID...` helper (+ `_session_id_of` kind dispatcher); a shared `_sid_is_orphaned` predicate.
- **R-R3 (code review, structural):** the plan is read into `mapfile` arrays (`RULE1_RECS` / `ORPHANS`) consumed directly for display + execution — no `mktemp` files / `trap` plumbing.
- **R-R4 (review round 2, operator — test quality):** execute as re-generating the registry (above) so the test asserts a **property** (the SIDs Rule 1 removes are caught by Rule 2's fresh step) rather than a negative. Added `test_complete_pass_removes_stale_session_resources` and `test_complete_pass_end_to_end` (stale copy+mount records removed, fresh keeper kept, removed-SID's container caught). Rule 2 **branch coverage** for all three resource kinds via `test_rule2_removes_network_and_volume_orphans`; fixed a `--interactive --dry-run` contradiction test (two silent modes — verify the command print via the abort gate instead). Removed the thin `interactive_confirm_via` wrapper and a vestigial `lines` array; dropped a `delivery`-gating false lead (delivery is disclosure-only; mount registers no volume so removal is label-driven).

## Completed (pre-close record)

| File | Change |
|---|---|
| `src/libs/session_inventory.sh` | NEW shared lib: `record_provider`, `record_label`, `session_stale` (lifted from resume; pipefail-safe) |
| `scripts/prune.sh` | REWRITE: registry-based Rules 1+2; `--stale=...`/`--provider`/`--age-days`/`--interactive`/`--dry-run`; complete-pass + plan display + equivalent-command print; `STALE=image` not-yet-implemented error; always removes records + orphaned resources |
| `scripts/resume_agent.sh` | Source shared `session_inventory.sh`; removed local helper copies |
| `scripts/stop.sh` | Accept + forward `--project` to prune; require it for `--prune`; drop dead `PRUNE_AGE_DAYS` |
| `scripts/agent-sandbox.sh` | `prune`/`stop` → `require_base_args` + pass `--project`; header usage lines; removed dead `require_name_sandbox` |
| `scripts/templates/Makefile.template` | `prune` target → registry-based flags + `--project`; `STALE=<kind>`/`AGE_DAYS`/`DRY_RUN` vars + help; dropped `STALE=1` docs |
| `test/stubs/docker` | `inspect` returns `DOCKER_STUB_SESSION_ID_LABEL` for `session-id` formats; `volume ls` returns `DOCKER_STUB_VOLUME_NAMES` |
| `tests/test_trace_stop.sh` | Updated prune-trace tests to registry model; added Rule 1 stale-removal, Rule 2 orphan-container, `--stale=image` guard, dry-run tests |
| `tests/test_prune.sh` | NEW: provider filter, age filter (`AGE_DAYS=0` broadens), fresh-kept, dry-run plan, interactive abort/command, **complete-pass regression (F-R1)**, unknown-kind + missing-project guards |
| `tests/test_dispatch.sh` | `stop` now asserts `--project` forwarding; added `prune` dispatch test |
| `docs/concepts/terminology.md` | New `## staleness` term (sandbox vs image dimensions) |
| `docs/architecture/tool_interface.md` | New `make prune` section (Rules 1+2, filters, interactive/dry-run) |
| `docs/architecture/sandbox_lifecycle.md` | Session-prune paragraph documenting the registry model |
| `docs/development/quickstart.md` | Prune line in session-persistence bullets |
| `devlog/roadmap.md` | L249 registry-based prune; NEW deferred image-staleness-detection entry (`STALE=image` wiring) |

## What's Next
- Pre-close review (Gate 3): present AC status + full-suite output. Suite now **489/489** and **deterministic across 3 consecutive runs** (property-based + branch-coverage prune tests; no negative/absence regressions).
- Set Status `Closed` and commit after release.

## Deferred / not in scope
- **Image-staleness detection** — `STALE=image` wired but "not yet implemented" (D8-6); future iteration wires the criterion (roadmap entry added). Image-staleness *column* in `resume --list` also stays out.
- N3 mount-point lock implementation (separate; Rule 2 does not need it — it operates on registered docker resources).