# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Impl
**Status:** Closed

## Objective
Implement **ID 03** of the F2 `start`/`resume` two-command design (design session `20260821-02`): complete the two remaining `make resume` surfaces after the `--session-id` direct-resume path landed in `20260821-03`.

1. **`--interactive` resume picker + confirm** — `make resume INTERACTIVE=1` opens an interactive picker over the `.compose/<session-id>.yml` session inventory, then resumes the chosen session. This is the "slow mode" per the cross-command convention (fast = supplied args, slow = explicit `--interactive`).
2. **`PROVIDER=<n>` inventory filter** — narrows the session inventory by provider before listing/picker, per D8/D11.

Both `--interactive` and `--provider` are currently routed-but-not-implemented in `scripts/resume_agent.sh` (they error with "not yet implemented" — ID 05). Both share the parser, so they land together in this iteration (ID 03 rationale).

## Context (verified — needed to start)
### Current resume_agent.sh dispatch (ID 07, implemented `20260821-03`)
Parsed flags then dispatch order:
1. `--list` → list `.compose/*.yml` filenames (fast, no resume)
2. `--interactive` → **errors** "not yet implemented" (line ~94)
3. `--provider=<n>` → **errors** "not yet implemented" (line ~100)
4. `--session-id=<id>` → resume path (identity recovery from `.compose/<id>.yml` record, then `session_env_common_init`/`session_env_names`, `preflight ... "false"` no-build, `exec run_agent.sh standard`)
5. bare → help hinting `--list`/`--interactive`

Flag vars: `RESUME_LIST`, `SESSION_ID_ARG`, `INTERACTIVE_FLAG`, `PROVIDER_FILTER` (plus `--name/--project/--sandbox/--env`).

### Registry record format (`.compose/<session-id>.yml`, D7 — the unified inventory)
- Agent service `image: <provider>-agent-<lower-project>` → provider recovered via grep+sed (ID 06, already in resume_agent.sh)
- Labels: `agent-sandbox.session-ts`, `agent-sandbox.host-head-sha`, `agent-sandbox.session-id`
- `SANDBOX_TYPE=copy|mount` in env
- Filename = `<session-id>.yml` (what `--list` emits, minus `.yml`)

### Reusable interactive primitive (to avoid reinventing)
`scripts/workflows/interactive.sh` provides:
- `interactive_pick LABEL ENTRIES_VAR [DEFAULT PAGE_SIZE AUTO_SELECT]` — entries as `value|display` strings named-variable array; prints `value` on stdout, display table + prompt on stderr; paginates (PAGE_SIZE); `q`/abort returns 1. Auto-selects if `AUTO_SELECT=true` and 1 entry.
- `interactive_confirm_or_abort` — confirm prompt (used by draft/apply).
- Pattern: `interactive_select_channel`/`interactive_select_bundle` wrap `interactive_pick` with labeled entries.

Note: interactive.sh currently lives under `scripts/workflows/` (sourced by draft/apply). Check its `set`/source requirements before sourcing from resume_agent.sh (resume_agent sits at `scripts/`; needs a `source` path decision — possibly `source "$REPO_ROOT/scripts/workflows/interactive.sh"`).

### Score map
- Suite baseline **465/465** (green after `20260821-04`).
- Tests: `tests/test_resume.sh` — 6 tests, one asserts `--interactive` returns "not yet implemented" (must be updated/removed once interactive is implemented). One asserts `--provider=pi` returns "not yet implemented" (update).

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `--interactive` with ≥1 record → picker (value|display), confirm, resumes chosen session | ✅ picker+confirm+resume wired (end-to-end verified via fixture) |
| 2 | `--interactive` with 0 records → clear "no sessions" error, non-zero | ✅ test |
| 3 | `--interactive` sole record → still shows picker + confirm (I-1, no auto-select) | ✅ |
| 4 | `PROVIDER=<n>` filters inventory; with `--interactive` picker shows only that provider | ✅ test |
| 5 | `PROVIDER=<n>` no matching records → clear error | ✅ test |
| 6 | bare/unknown still route to help; `--session-id` still silent direct resume | ✅ 6 prior shape tests retained |
| 7 | tests updated for new behavior; suite green | ✅ 468/468 (3 new tests) |
| 8 | docs + Makefile help reflect implemented picker/filter; roadmap L152 closed | ✅ |

## Findings

### [F] 2026-08-21 — Staleness criteria lost in the command-split; terminology conflated

**Type:** correctness/UX gap (operator-led finding)

**Finding 1 — the keyword `staleness` is used in two distinct places, now a term collision.**
1. **Volume / sandbox staleness** — a volume/session is stale when its `agent-sandbox.host-head-sha` Docker label differs from the current `git rev-parse HEAD`. Used by `make prune STALE=1` (`scripts/prune.sh`) and, pre-split, by the `start` resume auto-path (`volume_is_stale()`/`_auto_resume_or_new()`, removed in `20260821-04`).
2. **Image staleness** — `agent-sandbox.container-sig` label (SHA-256 of source populating `/opt/sandbox/` + `/opt/workflow/`) vs a re-computation; warning-only in `preflight()` (`scripts/build.sh`).

Both render/behave under the word `stale`, but they are different requirements (session/volume freshness vs image freshness).

**Finding 2 — the volume/sandbox staleness criterion is LOST post-command-split.** After `20260821-04`, `make resume` reads identity from `.compose/<session-id>.yml` and applies **no** staleness gate; the old volume-label criterion was deleted with `start`'s resume branch. Any documentation that still describes volume staleness (Makefile `STALE`, `prune.sh`, `sandbox_identity.md` label-consumption table, roadmap L141 STALE semantics) is **out of date** for the resume surface until the functionality is restored. `--list`/`--interactive` show no staleness; pruning still self-computes from volume labels (inconsistent with the registry-as-truth model, D7).

**Proposed restoration (recorded for a follow-up iteration — the interactive prune-command redesign, roadmap L141; not done here):**
- Port the volume/sandbox staleness criterion to use the `.compose/<session-id>.yml` record as the source of truth (D7) rather than volume labels.
- Reuse the consistent `--list` output shape for `prune` as well as `resume`.
- Add a **sandbox staleness** column to `--list` (`host-head-sha` vs current HEAD).
- An **image staleness** column is a **recommendation only** (operator, `20260821-05`): a proper design is pending a check against the current implementation. It would require `docker image inspect` per record to read the `container-sig` label and compare against a recompute (`preflight()`/`container_sig()` in `build.sh`); untestable in the no-docker container. Details may be wrong — confirm the criterion against the current impl before finalizing.

---

## Decisions
*Design settled in `20260821-02` (D1–D11: fast=args, slow=`--interactive`, `PROVIDER=` narrows inventory). This iteration's decisions:*
- **I-1 (operator)** — `--interactive` with a sole matching record still presents the picker + confirmation (no auto-select shortcut); explicit `--interactive` is deliberately slow. (Chooses against `interactive_pick AUTO_SELECT` despite the old default-auto behavior removed from start by D10.)
- **I-2 (operator)** — `PROVIDER=<n>` is an inventory-wide filter: `make resume LIST=1 PROVIDER=pi` filters the list too (not interactive-only).
- **I-3 (operator)** — once the enriched display (`SESSION_ID | session-ts | provider | branch`) is implemented for the picker, `--list` is also updated to use that display (replaces the raw-filename list).

## Completed
| File | Change | Status |
|---|---|---|
| `devlog/handovers/20260821-05-impl-resume_interactive_and_provider.md` | Created this impl handover (ID 03) | done |
| `scripts/resume_agent.sh` | Added shared inventory helpers (`record_provider`/`record_label`/`build_inventory`); `--list` enriched table (id|provider|ts|branch, newest first); `--interactive` picker+confirm (sources `interactive.sh`, no auto-select, I-1); `PROVIDER=<n>` filter for list+interactive; provider-alone guidance; downstream `--session-id` reuses helpers; help updated | done |
| `tests/test_resume.sh` | 3 new tests (enriched list, list provider-filter, list no-match, interactive abort, interactive no-records, provider-alone) replacing 2 not-implemented tests; fixture now builds pi + hermes records | done |
| `scripts/templates/Makefile.template` | resume target help + comment block: LIST/interactive no longer NOT-YET-IMPLEMENTED; PROVIDER=<n> filter documented | done |
| `docs/architecture/tool_interface.md` | `make resume` section: enriched list, interactive picker+confirm, PROVIDER filter | done |
| `docs/architecture/sandbox_lifecycle.md` | resume via registry: enriched list + interactive picker + PROVIDER filter | done |
| `docs/development/quickstart.md` | resume persistence: list/interactive/provider | done |
| `devlog/roadmap.md` | L152 marked done (resume session surfaces); L151 notes remaining = `make start` wizard | done |

## What's Next
- Present AC status + suite output for pre-close review (Gate 3); then set Status Closed and commit.
- Remaining for `start`/`resume` redesign (L151): the `make start` interactive config wizard (D11) — the current `--interactive` error on `start` is its attach point.
- **Deferred (F1/F2 finding):** restore volume/sandbox staleness on the registry-as-truth model — filed under the **interactive prune-command redesign (roadmap L141)**: port the criterion to `.compose/*.yml`, unify the `--list` shape with `prune`, add sandbox staleness column to `--list`. The **image-staleness column is a recommendation only** (operator: not settled design; requires `docker image inspect` per record, untestable in the no-docker container — confirm against `preflight()`/`container-sig` in `build.sh` before finalizing). See Findings + roadmap L141.