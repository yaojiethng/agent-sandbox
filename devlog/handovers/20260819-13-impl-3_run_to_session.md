# Agent Handover

**Date:** 2026-08-19
**Milestone:** M2.6.6 — terminology, iteration 3 (run→session)
**Type:** Implementation
**Status:** Closed

## Objective

Rename the container-lifecycle identifier `RUN_ID` → `SESSION_ID` across the repository (Bucket A of the categorization working doc), including its derived spellings (`run_id`, `_run_id`, `agent-sandbox.run-id` label, `--run-id` stop flag, compose project/volume/registry names). Persistence-critical: rename the `SESSION_STATE` write key `run_id`→`session_id` and the docker label `agent-sandbox.run-id`→`agent-sandbox.session-id` atomically with the code rename so the resume path stays correct. Reserve/settle sub-decisions D-A and D-D. `SESSION_TS` (both container and draft context) stays as-is (D-E resolved KEEP, operator `20260819-10`). D-B/D-C (bundle CLI) deferred to phase 5.

## Context (verified)

- Baseline `8d29640` (2A), clean tree.
- Categorization working doc: `output/terminology-sweep/categorization.md` — Bucket A (`RUN_ID`→`SESSION_ID`, ~260 token occurrences across src/scripts/tests/docs/Makefile) + rule 5 sub-decisions.
- Reserved terms registered: `docs/concepts/terminology.md` (session = container lifecycle; notes `SESSION_ID` formerly `RUN_ID`, deprecated).
- `SNAPSHOT/SESSION` container tokens are Bucket C1: `SESSION_TS`, `SESSION_STATE`, `RESUME_SESSION`, `session-diffs`, `agent-sandbox.session-ts` label, `session_state.sh` — all KEEP.
- Historical records (ADR `20260722-*session_identity*`, handovers, changelog) — Bucket C3, never retro-renamed.

## Persistence-critical rename surface (verified)

| File | Token | Note |
|---|---|---|
| `src/build/docker-compose.yml` | `{{RUN_ID}}`, `agent-sandbox.run-id` label (×2) | label → `session-id` |
| `src/build/docker-compose.copy.yml` | `{{RUN_ID}}`, `run-id` label, volume `{{RUN_ID}}-sandbox-data` | label + volume → session |
| `src/build/compose.sh` | RUN_ID/run_id subst, project-name | → SESSION_ID |
| `scripts/start_agent.sh` | RUN_ID export (fresh: sha from SESSION_TS), resume read from `agent-sandbox.run-id` label, container names, echo | → SESSION_ID + label read |
| `scripts/run_agent.sh` | `$COMPOSE_DIR/$RUN_ID.yml` registry filename | → `$COMPOSE_DIR/$SESSION_ID.yml` |
| `scripts/stop.sh` | `--run-id=<id>` flag, RUN_ID var, label filter | D-A decision |
| `scripts/dry_run_capability.sh` | RUN_ID | → SESSION_ID |
| `src/capability/entrypoint.sh` | RUN_ID env, `SESSION_STATE` write key `run_id` | key → `session_id` (resume) |
| `src/capability/snapshot.sh` | `SESSION_STATE` write key `run_id` | key → `session_id` |
| `src/libs/diff_export.sh` | `_run_id` param, `RUN_ID=` echo | → session |
| `src/libs/draft_state.sh` | RUN_ID in folder name | → SESSION_ID |
| `src/libs/package_branch.sh` | RUN_ID auto-resolve `run_id` key | → session; key back-compat D-D |
| `src/libs/routing.sh` | verify | — |
| `scripts/workflows/draft.sh` | RUN_ID identity | → SESSION_ID |
| `scripts/templates/Makefile.template` | RUN_ID | → SESSION_ID |
| `tests/*` (~25) | RUN_ID/run_id | → session |
| `docs/*` (execution_model, sandbox_lifecycle, security, sandbox_identity, sandbox_host_correspondence, project_index, quickstart, prompt package-branch, provider quickstarts) | RUN_ID | → SESSION_ID; **historical ADR not edited** |

## Sub-decisions (resolved this session)

- **D-A** — `stop.sh --run-id` → `--session-id` (operator: rename, no back-compat). See Decisions #1.
- **D-D** — resume back-compat: operator chose **force-fresh, no back-compat**. See Decisions #2.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | **D-A: rename `--run-id` → `--session-id`, no back-compat** | it filters containers by the container-session label; operator-approved. No persisted value to migrate — operator passes it fresh each call. |
| 2 | **D-D: force fresh — NO back-compat read** | operator-approved. New code reads only `session_id`/`session-id`. Pre-rename volumes fail the label gate at `start_agent.sh` resume check (`[[ -z "$SESSION_TS" || -z "$SESSION_ID" ]]`) with the existing clean error: "volume has no session identity labels... older harness version... start fresh: make start". No dual-read anywhere. |
| 3 | Scope confirmed | full Bucket A rename; historical ADR/handovers untouched (C3); Bucket C1 tokens keep (SESSION_TS/STATE, session-diffs, RESUME_SESSION); draft-context SESSION_TS KEEP (D-E); bundle CLI tokens deferred to phase 5 (D-B/C) |

## Acceptance criteria (verified)

- [x] Operator confirms scope + D-A + D-D — confirmed `2026-08-19` (D-A rename; D-D force-fresh)
- [x] `RUN_ID`→`SESSION_ID` complete across live code/docs (Bucket A); suite green (476/0/0) — verified `bash scripts/run_tests.sh` → 476 passed / 0 failed / 0 skipped
- [x] Persistence keys/label renamed atomically — `agent-sandbox.run-id`→`session-id` label (compose.yml, copy.yml), `SESSION_STATE` key `run_id`→`session_id` (entrypoint.sh, snapshot.sh), `.compose/<run-id>.yml`→`<session-id>.yml`; resume path covered (D-D force-fresh: pre-rename volumes rejected at label gate)
- [x] Bucket C1 tokens untouched (`SESSION_TS`/`SESSION_STATE`/`session-diffs`/`RESUME_SESSION`); historical ADR `20260722-*session_identity*` + handovers untouched (C3) — verified zero diff on ADR
- [x] Roadmap phase-4 task marked DONE with D-A/D-D resolution; register `SESSION_ID` note consistent

## Completed this session

- [x] **Source/scripts rename** — `src/build/docker-compose.yml`, `docker-compose.copy.yml` (label + volume + env), `compose.sh` ({{SESSION_ID}} subst, project-name, dead {{RUN_ID}} subst removed), `scripts/start_agent.sh` (export/resume/container names/echo + label read `agent-sandbox.session-id`), `scripts/run_agent.sh` (registry filename), `scripts/stop.sh` (D-A `--session-id`), `scripts/dry_run_capability.sh`, `src/capability/entrypoint.sh` (SESSION_STATE key `session_id`, `_session_export`), `src/capability/snapshot.sh` (SESSION_STATE key), `src/libs/diff_export.sh` (`_session_id`), `src/libs/draft_state.sh` (folder-name parse SESSION_ID, `.draft-state` key `session_id`), `src/libs/package_branch.sh` (auto-resolve `session_id`), `src/libs/routing.sh` (export_path SESSION_ID), `scripts/workflows/draft.sh` (RUN_ID→SESSION_ID identity), `scripts/templates/Makefile.template` (SESSION_ID_FLAG)
- [x] **Tests updated** — 8 test files + `diagnose_autosave.sh` (RUN_ID/run_id/run-id → SESSION_ID/session_id/session-id; function names); suite green 476/0/0
- [x] **Docs updated** — `execution_model.md`, `sandbox_lifecycle.md`, `security.md`, `tool_interface.md`, `sandbox_identity.md`, `sandbox_host_correspondence_model.md`, `project_index.md`, `quickstart.md`, provider quickstarts (hermes/opencode), prompt `package-branch.md`; register `terminology.md` already correct (`SESSION_ID` formerly `RUN_ID`, deprecated)
- [x] **Roadmap updated** — phase-4 `[DONE - session 20260819-13]` with D-A/D-D resolution; lifecycle depends-on text `RUN_ID`→`SESSION_ID`
- [x] `bash -n` clean on all edited scripts; no new shellcheck warnings (SC2155/SC1090 pre-existing); suite green

## Findings

| # | Finding | Disposition |
|---|---|---|
| 1 | `export_path`/`routing.sh` had RUN_ID in param + path format comments, not just the variable — renamed across doc + body consistently | resolved |
| 2 | `compose.sh` still listed a dead `{{RUN_ID}}` substitution (no template uses it after the file-set split) — removed the sed line + doc note | resolved |
| 3 | Force-fresh resume (D-D) is clean because the volume-label gate in `start_agent.sh` (`[[ -z "$SESSION_TS" || -z "$SESSION_ID" ]]`) already rejects pre-rename volumes with a descriptive "older harness version — start fresh" error; the SESSION_STATE `session_id` key never receives a stale `run_id` because old volumes never resume | documented — no back-compat needed anywhere |
| 4 | Operator amendment (post-commit): roadmap M2+ prose still carried a few stale `RUN_ID`/`run-id` references (compass lifecycle bullet, compose-persistence bullet, prune task, M2.6.5 multi-volume, `.run-identity`-deprecation identity bundle, M2.7 status). Corrected to `SESSION_ID`/`session-id`; added a canonical changelog `[CORRECTION - 2026-08-19]` entry recording the rename (the M2.7 changelog entry + historical ADR keep `RUN_ID` per C3, now cross-referenced by the CORRECTION) | resolved — amendments applied, commit amended to `4c54159` |
| 5 | Operator amendment 2: expand the roadmap terminology-sweep entry (the deconflicting record) to name the two new reserved terms with links to their register definitions ([`session`](../concepts/terminology.md#session), [`iteration`](../concepts/terminology.md#iteration)), and briefly list the replaced terms (`run`/`RUN_ID` → `session`/`SESSION_ID`, the dropped `unit`, `new-session` skill → `new-iteration`) | resolved — roadmap line 149 expanded; commit amended to `4c54159` |

## What's Next

Phase 5 — bundles refactor (`--session`→`--bundle`, `--session-summary`→`--bundle-summary`, `SESSION_*`→`BUNDLE_*`), now on a `SESSION_ID` base.
