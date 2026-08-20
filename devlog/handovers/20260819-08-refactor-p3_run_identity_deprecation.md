# Agent Handover

**Session date:** 2026-08-19
**Milestone:** M2.6 — Session Persistence (prefactor track)
**Session type:** Refactor
**Status:** In progress

## Objective

**P3 — `.run-identity` deprecation / identity registry fold** (operator-confirmed scope P1 → P4 → P3; then STOP for P2/P5). Roadmap task: fold the host-side identity bundle (SESSION_TS/RUN_ID/HOST_HEAD_SHA/SANDBOX_ID) into the `.compose` per-run registry, refactor `start_agent.sh` identity sourcing (copy-resume keeps volume labels; bind-mount resume reads the registry), remove the `.run-identity` file, sweep docs. Container-side SESSION_STATE stays (export machinery, co-located provenance) — out of scope.

## Context (verified)

- Design decisions (walk `20260818-02`):
  - **N2** — per-run RUN_ID (never reused); SANDBOX_ID frozen once per sandbox (derivation kept, `SANDBOX_DIR:HOST_HEAD_SHA` = branch-point tag); resource identity lives in the registry (registry fold; completely deprecates `.run-identity`); SESSION_STATE retained as container-side provenance (see N4); mount-source per-run field/label.
  - Registry = the persisted per-run `.compose/<run-id>.yml` compose file (`COMPOSE_DIR`).
- Current `.run-identity` role (`scripts/start_agent.sh`): written at every start (fresh: recomputed; resume: read from volume labels), storing SESSION_TS/RUN_ID/HOST_HEAD_SHA/SANDBOX_ID. **Verified: it has NO readers** — grep shows only writers in `start_agent.sh` and a doc-reference comment in `entrypoint.sh`; docker/env transport is via compose env + volume labels, not the file. So the file is pure cache with no consumer — the fold is safe; the only real work is in `start_agent.sh`'s identity lifecycle and the mounted compose record.
- Compose registry today: `run_agent.sh` writes `$SANDBOX_DIR/.compose/<RUN_ID>.yml` (resume) or a hash-named file (no RUN_ID). See `compose.sh`/`run_agent.sh` for exactly where the merged file lands.
- Identity consumers (host-side): stop.sh (`--run-id` label filter), auto_resume/new picker, dry_run scripts, draft workflow. Container-side SESSION_STATE consumed by export machinery.

## Completed this session

- [x] Verified `.run-identity` had zero readers (only writers in `start_agent.sh` + a doc comment) — the fold is safe with no behavioral dependency.
- [x] `start_agent.sh`: removed `RUN_IDENTITY` var and both `.run-identity` write blocks (fresh `_new_session_identity`, resume `_resume_from_volume`); identity still exported fresh on new and read from volume labels on copy resume; updated the header comment to describe the registry as identity home.
- [x] `src/capability/entrypoint.sh`: updated the upgrade-path comment to drop the stale `.run-identity` reference.
- [x] Docs swept: `sandbox_identity.md` (identity table + new registry section replacing the `.run-identity` pullout), `sandbox_lifecycle.md` (resume flow diagram now volume-label based), `quickstart.md` (identity persisted via registry/labels).
- [x] Full suite green (476/0/0); `bash -n` clean on both edited scripts.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Remove `.run-identity` writes and the `RUN_IDENTITY` var; keep fresh-compute and label-read identity sourcing | the file had **no readers** anywhere (verified by grep) — pure vestigial cache; identity sources are fresh-compute (new) and volume labels (copy resume) |
| 2 | Registry = the persisted per-run `.compose/<run-id>.yml`; it already embeds identity (RUN_ID/HOST_HEAD_SHA/SESSION_TS in labels + env) | no code change needed to the registry itself — it is already self-describing; fold is satisfied by removing the cache file and documenting the registry as the identity home |
| 3 | Container-side SESSION_STATE retained, unchanged | explicitly out of scope (N2/N4) — export machinery + co-located provenance |

## Files in scope (proposed)

| File | Change |
|---|---|
| `scripts/start_agent.sh` | Identity lifecycle: remove `.run-identity` writes (fresh `_new_session_identity` and resume `_resume_from_volume`); compute/export identity fresh on new; read identity on copy-resume from volume labels (unchanged, no cache write); ensure the per-run compose record carries the identity so resume can recall it |
| `scripts/run_agent.sh` | The composed `.compose/<run-id>.yml` record is already written every run and embeds identity (RUN_ID/HOST_HEAD_SHA/SESSION_TS in labels + env) — verified, no change needed |
| `scripts/stop.sh`, `src/...` | No `.run-identity` dependency — label-based filtering only (verified) |
| `docs/concepts/sandbox_identity.md`, `docs/architecture/sandbox_lifecycle.md`, `docs/development/quickstart.md` | Sweep `.run-identity` mention → registry record (DONE) |
| `src/capability/entrypoint.sh` | Comment-only: remove stale `.run-identity` reference (DONE) |

## Out of scope

P2/P5 (terminology sweep, docs sweep) — operator-hold. Container-side SESSION_STATE fold — explicitly retained. Actual delivery gating — F1.

## Verification

- Fresh run: identity computed and exported; no `.run-identity` written; per-run compose record written
- Copy resume: identity read from volume labels (no cache write)
- No `.run-identity` readers/writers remain; file removed from runtime path
- Full suite green (476/0/0); no shellcheck regressions

## Acceptance criteria

- [x] `.run-identity` removed; identity lives in the registry (` .compose/<run-id>.yml`) + volume labels
- [x] start_agent identity sourcing refactored (copy-resume via labels; no cache) — fresh still computes/exports
- [x] Docs swept; entrypoint comment updated
- [x] Full suite green (476/0/0); committed as `refactor:`; handover closed

## Operational notes

Baseline: `841788b` (P4). Planning record `20260819-05`. Suite green 476/0/0 at P4.