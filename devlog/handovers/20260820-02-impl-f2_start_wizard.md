# Agent Handover

**Date:** 2026-08-20
**Milestone:** M2.6.6 — Mount Model: Host-backed Sandbox
**Type:** Implementation
**Status:** In progress

## Objective

**F2 — `start` command redesign (resumable/stale UX wizard)** per the settled
design (walk `20260818-02`, decision D6), carrying the **dry-run change-source
gap (F-dryrun)**. Prerequisites are complete: P3 `.run-identity` deprecation
(`20260819-08`), P2 terminology sweep (`20260819-10..13`), F1 mount delivery
(`20260820-01`). Make `make start` interactive-by-default with run inventory
across both deliveries, resume-or-new, freshness, and `--run=<id>` resume.

## Context (verified)

- **F2 roadmap task** (`devlog/roadmap.md` line 150, unchecked): "interactive-by-default
  wizard — agent-run inventory first (copy via labels; bind-mount via registry),
  resume-N or new; freshness-on-new (implicit rebuild, auto-downgraded); config
  prefilled from the newest run; prints the full non-interactive command;
  `--run=<id>` resumes (absence = new); no subcommand split. Decision rows
  D6/A-Resolved/N2a/N4; implementation carried by the M2.6.6 delivery tasks."
- **Decision D6** (walk `20260818-02`): interactive-by-default; run inventory
  (copy via labels, mount via registry); resume-N or new; config prefilled from
  newest run's record; prints full non-interactive command at end; `--run=<id>`
  resumes (absence = new); no new/resume subcommand split. Fresh runs get the
  freshest container: implicit `--rebuild` auto-downgraded to `--refresh`/no-op
  by staleness detection (image digest + config check).
- **Registry** (decision R7): each run's effective config (delivery, provider,
  mode, identity) recorded in the persisted `.compose/<run-id>.yml` = the
  registry/record of the run and source of session memory. Copy resume reads
  volume labels; mount resume reads the registry.
- **Current `start_agent.sh`** is volume-centric (copy-only), pre-Terminology
  names: `SESSION_ID`/`SESSION_TS`, `_auto_resume_or_new`, `_resume_from_volume`,
  `--refresh`/`--rebuild`/`--resume` flags, an interactive volume picker, and
  `RESUME_SESSION`. It does NOT yet: read mount-run registry identity, expose
  `--run=<id>`, or print the non-interactive command.
- **Current `run_agent.sh`** receives identity via exported env from start_agent
  (no `--run=` flag); selects the delivery overlay by `SANDBOX_TYPE`.
- **F-dryrun gap**: `dry_run_capability.sh` (and `dry_run_reasoning.sh`)
  hard-depend on the copy snapshot — `critical "SNAPSHOT_DIR readable (snapshot
  mount)" test -d "$SNAPSHOT_DIR"` — which does not exist in mount mode. Dry-run
  must be delivery-aware: validate the actual change source (copy: snapshot /
  `baseline.tar`; mount: worktree `.git` + init marker).
- **Terminology status**: programmed sweep done (`20260819-10..13`) renamed
  `--session→--run`, `SESSION_TS→RUN_TS`, `SESSION_STATE→RUN_STATE`,
  `RESUME_SESSION→RESUME_RUN`. Live code uses the new names; the `start_agent.sh`
  wizard surfaces are the remaining consumer.

## Files likely in scope (proposed — pending scope confirmation)

| File | Change |
|---|---|
| `scripts/start_agent.sh` | Wizard CLI: `--run=<id>`; interactive resume-or-new; run inventory (copy labels + mount registry); config prefill; prints non-interactive command; freshness/implicit-rebuild handling |
| `scripts/run_agent.sh` | Pass-through for wizard-selected identity/delivery; `--run` consumed indirectly via exported env; delivery-aware dry-run wiring |
| `scripts/dry_run_capability.sh` | Delivery-aware change-source (mount: worktree `.git`+marker instead of snapshot) |
| `scripts/dry_run_reasoning.sh` | Symmetric delivery-aware checks |
| `src/capability/entrypoint.sh` | (if needed) dry-run delivery branch alignment |
| `docs/architecture/execution_model.md`, `tool_interface.md`, `quickstart.md` | Wizard semantics, `--run=`, freshness, dry-run delivery-awareness |
| `tests/*` | Wizard behavior tests (inventory, `--run`, prefill, staleness, dry-run mount branch); suite stays green |
| `devlog/roadmap.md` | Mark F2 resolved at close |

## Out of scope (deferred)

- F3 (mount worktree with git history), F5 (prune redesign) — later items.
- Copy-side host-volume seeding + vestigial cleanups — deferred (M2.6.5 follow-up).
- Full repository-wide terminology prose sweep of *historical* docs — completed;
  only live wizard surfaces are touched here.

## Verification

- `make start` interactive: inventory lists prior runs (copy + mount), resume-N
  or new; `--run=<id>` resumes a specific run; fresh runs print the full
  non-interactive command; freshness auto-downgrades an implied rebuild.
- Dry-run under both deliveries is delivery-aware (no copy-only snapshot
  dependency in mount mode).
- Full suite green; `bash -n` clean; no new shellcheck categories beyond SC1091.

## Decisions

None yet — scope pending operator confirmation.

## Acceptance criteria

- [ ] Operator confirms the F2 scope split (which slice this iteration covers).
- [ ] Wizard behavior and `--run` per the settled design (as scoped).
- [ ] Dry-run delivery-aware (mount no longer depends on `SNAPSHOT_DIR`).
- [ ] Copy default flow unchanged; suite green.
