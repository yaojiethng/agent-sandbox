# Agent Handover

**Date:** 2026-08-19
**Milestone:** M2.6.6 — Mount Model: Host-backed Sandbox
**Type:** Workflow (task inventory + prefactor-first sequencing)
**Status:** Closed

## Objective

Compile the complete outstanding-task inventory for the M2.6.6 program, sorted by dependency, with prefactor (refactor/cleanup) work clearly separated from feature work. Operator intends: **prefactors first, before any more feature changes.**

## Context (verified)

- HEAD `63f763f` (compose file-set split, session `20260818-03`); baseline `e026891` carries the design-walk work (session `20260818-02`).
- Roadmap M2.6.6: design `[x]`, security `[x]`, compose template `[x]`; open: mount delivery enablement, `.run-identity` deprecation, mount worktree with git history.
- Roadmap M2.6 general track open: prune redesign (rule 2 confirmed; command shape deferred until artifact shapes settle), terminology sweep (own task), start redesign (design settled; impl not started).
- Roadmap future: copy-model seeding (unblocked — file-set mechanism exists), environment-change persistence (parked), harness-sig + STE sweep (backlog).
- Carried notes (design handover `20260818-02`): dry-run change-source gap (F-dryrun, with wizard); entrypoint branch inversion cleanup (M2.6.6 delivery scope); docs sweep to settled names; changelog extraction + stale close-order label (M2.6 close).
- Stale record confirmed: roadmap.md line 197 close-order finding still labelled "(current)" though resolved by session `20260809-05`.
- Untracked in tree: `devlog/handovers/20260818-04-impl-mount_delivery_enablement.md` — proposed-but-unconfirmed delivery scope, now superseded by the prefactor-first direction.

## Task inventory (dependency-sorted)

### Prefactors / refactors / housekeeping — no feature work

| # | Task | Depends on | Notes |
|---|---|---|---|
| P1 | **Housekeeping batch** (chore) — changelog extraction (M2.4, M2.6.x); stale close-order label roadmap L197; GOTCHAS close-order entry state (operator action); roadmap "Mount delivery enablement" task text refresh (`.snapshot/` → worktree) | none | independent, zero-risk |
| P2 | **Terminology sweep** (refactor, large) — agent run / agent iteration; SESSION_TS→RUN_TS, SESSION_STATE→RUN_STATE, session-diffs→run-diffs, RESUME_SESSION→RESUME_RUN, `--session`→`--run=<id>`, session-ts labels, registry/volume-label fields, wizard text, new devlog prose; session keyword reserved | none (design settled Q9) | historical handovers stay as-is |
| P3 | **`.run-identity` deprecation / identity registry fold** (refactor) — host-side identity into `.compose` registry; copy-resume via volume labels, mount-resume via registry; remove file; docs sweep | registry exists (20260810-14) | prerequisite for F2 wizard; uses new RUN_* names — coordinates with P2 |
| P4 | **Entrypoint branch inversion cleanup** (refactor, extractable) — `if ! -d .git` → init; else → resume bookkeeping | none | design note files it under delivery scope; extacting shrinks F1 |
| P5 | **Docs sweep to settled names** (docs) — identity lifecycle, execution_model (security unchanged, invariant-7) | P2 | |

### Features (after prefactors)

| # | Task | Depends on | Notes |
|---|---|---|---|
| F1 | **Mount delivery enablement** (impl) — entrypoint delivery branching, worktree materialization, SANDBOX_TYPE env wiring, tests, docs | compose file-set (DONE); ideal P4 | handover `20260818-04` proposed, unconfirmed |
| F2 | **Start redesign / wizard** (impl) — interactive-by-default, run inventory, resume-N, freshness, `--run=<id>`; carries **dry-run change-source gap (F-dryrun)** | P3, P2 | design settled `20260818-02` |
| F3 | **Mount worktree with git history** (impl) — future clone strategy | F1 lands | sequenced after base delivery |
| F4 | **Host-side volume seeding** (impl, copy follow-up) — subtasks: drop always-mounted SNAPSHOT_DIR; re-scope `baseline.tar` preflight gate; re-examine snapshot_dir env | file-set (DONE → unblocked now) | copy-only, orthogonal to mount work |
| F5 | **Prune-command redesign** (impl/refactor) — interactive cutoff+confirm, descriptive options, explicit scope | artifact shapes settle (registry, worktree, locks → after F1/F2) | rule 2 confirmed |
| F6 | **Environment-change persistence** (impl) — persisted install-cache volume candidate | — | parked |

### Backlog (not M2.6) — harness-sig, STE-clean sweep, W1 vault, M3+

## Open questions for operator

1. **Disposition of untracked `20260818-04` handover** — proposed scope superseded by prefactor-first. Recommend: delete at close (content lives in the roadmap task + design record); alternative: retain as the future F1 handover.
2. **Which prefactor opens next** — recommendation: P1 housekeeping as a quick chore session, then P2 terminology sweep (largest, unblocks docs and feature naming).
3. **P2/P3 ordering** — P3's registry fold writes the new names, so P2's identity surface shrinks if P3 lands first; either consistent. (Included in P2/P3 above as separate sessions; operator may merge.)

## Completed this session

- P1 housekeeping (chore `1bccde0`): changelog M2.4/M2.6 entries; close-order finding resolved annotation; Mount-delivery task text refresh; GOTCHAS close-order entry mitigated.
- P4 entrypoint branch inversion (refactor `841788b`): fresh-init now the primary branch, resume the else.
- P3 `.run-identity` deprecation (refactor `0f18786`): identity folded into the .compose registry + volume labels; file removed; docs/entrypoint swept.
- P2 (terminology sweep) and P5 (docs sweep) **paused** — operator instructed to stop and wait before starting them.

## Decisions

None yet — awaiting operator direction on scope.

## Acceptance criteria

- [x] Dependency-sorted inventory delivered and operator-visible
- [x] Prefactor-first order agreed (P1 → P4 → P3 executed; P2/P5 paused)
- [x] Disposition of the `20260818-04` untracked handover settled (deleted per operator)
- [x] Roadmap write-back recorded at close (handover task list mirrors roadmap rows)

## Operational notes

Git: `63f763f` + untracked `20260818-04` handover. Nothing else modified this session.