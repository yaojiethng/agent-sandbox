# Agent Handover

**Date:** 2026-08-28
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation (feature)
**Status:** Closed


## Objective
Extend `make resume --list` (and `--interactive`): rename the stale columns to STE100-clear warning labels, add relative time display for STARTED and a new LAST_USED column (time since the session last stopped), backed by a minimal unified per-session log file. Scope finalized with operator at Gate-1.

## Scope
1. `resume --list` becomes an aligned table `SESSION_ID PROVIDER STARTED BRANCH LAST_USED`; `STARTED` + `LAST_USED` render as relative elapsed (`5 hours ago`); sorting stays on the RAW `session-ts` (newest-first).
2. Drop the `WORKSPACE`/`IMAGE` VALUE columns; show OPTIONAL warning labels `[SANDBOX_STALE]` / `[IMAGE_STALE]` only when that state is `stale` (exception-only; `fresh`/`unknown` = no marker, consistent with the existing picker honesty).
3. Unified per-session log `.compose/<session-id>.log` (KEY=VALUE lines; starts minimal with `last_stopped=` + `last_started=`; extensible for preflight/dry-run notes). Written: `last_started` on session start/resume; `last_stopped` on post-session teardown (covers natural exit + `make stop`). On start/resume, last_stopped is cleared so a RUNNING session shows `LAST_USED = ---`.
4. `--interactive` picker: rename markers `[STALE]`/`[IMG-STALE]` -> `[SANDBOX_STALE]`/`[IMAGE_STALE]`; surface last_used.
5. Shared relative-time helper (`N minutes/hours/days ago`).
6. `prune` keeps its own selection-list format; apply relative `ts` for consistency (shares `enumerate_records` only).
7. Docs: document the `.compose/<session-id>.log` as a lifecycle artifact alongside the `.yml` record.

Carried forward / NOT in scope: full preflight/dry-run logging into the unified log (future); SERVE; Bug E; naming-principle conventions fold.

## Carried forward

| Item | From handover |
|---|---|
| SERVE mode integration (roadmap) | `20260828-02` |
| Bug E -- `make stop` template + duplicate-ID | `20260828-02` |
| Contextual-knowledge-light naming principle | `20260828-02` |
| Resume volume-reuse verification (Bug D) -- CLOSED `20260828-04` | resolved |

## Acceptance criteria
| # | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | ` --list` renders aligned headers `SESSION_ID | PROVIDER | STARTED | BRANCH | LAST_USED`; STARTED + LAST_USED relative | MET | manual + `test_resume.sh` |
| AC2 | Sorting remains newest-first by raw session-ts | MET | `build_inventory` `sort -t'|' -k3 -r` on raw ts unchanged |
| AC3 | Stale shown as optional `[SANDBOX_STALE]`/`[IMAGE_STALE]` labels, not value columns | MET | `test_list_shows_{sandbox,image}_staleness`, `test_list_columns_are_independent` |
| AC4 | `.compose/<sid>.log` written: last_stopped on teardown; last_started + cleared last_stopped on start/resume; running -> LAST_USED `---` | MET | `test_resume_writes_session_log`, `test_session_log.sh` |
| AC5 | `--interactive` picker markers renamed + last_used surfaced | MET | `test_interactive_marks_image_stale` |
| AC6 | relative-time helper unit-tested; suite green; lint clean; `.log` documented as lifecycle artifact | MET | `test_session_log.sh`; suite 736/43; lint 100 files; docs updated |

## Hot files
TBD -- after repo reconnaissance.

## Decisions
| Decision | Rationale | Scope |
|---|---|---|
| Stale columns -> optional warning labels `[SANDBOX_STALE]`/`[IMAGE_STALE]`; value keywords (`stale/fresh/unknown`) unchanged | operator (exception-only pattern; snap-decision); do NOT change step values, only headers/labels | resume --list/--interactive |
| STARTED + LAST_USED show relative elapsed; sort on raw session-ts | display-decode, sort integrity | --list |
| Unified per-session `.compose/<session-id>.log` (KEY=VALUE), minimal (`last_stopped=`,`last_started=`), extensible | operator; single per-session source of truth, interoperable with dry-run record shape | lifecycle |
| `.log` documented as a lifecycle artifact alongside the `.yml` | operator | docs |
| `prune` keeps its own selection-list format; only relative `ts` for consistency | prune selects (not displays) staleness; shares enumerate_records only | scope carve-out |


## Findings
- **STE100 naming (this iteration):** the two always-visible `stale`/`image_stale` VALUE columns were replaced by exception-only `[SANDBOX_STALE]`/`[IMAGE_STALE]` warning labels with descriptive headers -- a session user gets a snap decision (fresh = silent, stale = flagged); value keywords (`stale/fresh/unknown`), the `session_stale`/`record_image_stale` functions, and terminology stay unchanged. Retaining the value keywords was the operator's choice (headers as the vehicle).
- **Deferred (this iteration, operator): PROVIDER image identifier.** Explored showing `pi (<image>)` then `pi (<container-sig:0:7>)` next to PROVIDER. The image NAME (`image:` in the record = the docker tag, e.g. `pi-agent-test-project`) was deemed not useful; the meaningful identifier, the `container-sig` (Docker label `agent-sandbox.container-sig`, a SHA-256 of baked `/opt/sandbox` + `/opt/workflow` sources), is NOT a `.yml` field -- it lives on the image and requires `docker image inspect` (which `[IMAGE_STALE]` already invokes via `image_is_stale`). Per operator direction, the sig display was ROLLED BACK (a temporary `image_baked_sig` helper + `image_is_stale` refactor were reverted) to keep `--list` from adding a per-row docker dependency; the current format is `pi [IMAGE_STALE]`, and refinements are deferred for investigation next session (best identifier to show: consider whether a meaningful image identifier could be made registry-available). Registered for next iteration.
- **`.yml` containment (answered, not changed):** each service in `.compose/<id>.yml` declares BOTH `image:` (the docker tag via `{{AGENT_IMAGE_NAME}}`, e.g. `pi-agent-test-project`) and `container_name:` (the container instance, e.g. `pi-test-project-<sid>`). Docker compose creates a container named `container_name` from the image tagged `image`; `record_image FILE agent` recovers the `image:` tag. `container-sig` is not in the record.
- **Unified per-session `.log`:** `.compose/<sid>.log` (KEY=VALUE) is now a lifecycle artifact alongside the `.yml`; minimal entries `last_started=`/`last_stopped=` (UTC `YYYYMMDD-HHMMSS`) feed the LAST_USED column. Format extensible for future preflight/dry-run outcome lines. NOTE: dry-run does NOT write the log (it exits before the start-time writes and is pre-session); full dry-run/preflight logging into the unified log is a future concern.
- **Exposed constraint:** a running vs never-started session is not distinguished in LAST_USED (`---` for both), because `--list` is registry-only (no docker call) and last_stopped is cleared on start/resume. Accepted per the operator's "in use" request (`---` = not stopped).

## Completed
- `scripts/resume_agent.sh`: `--list` -> aligned table `SESSION_ID | PROVIDER | STARTED | BRANCH | LAST_USED` (relative STARTED + LAST_USED); dropped the two value columns for exception-only `[SANDBOX_STALE]`/`[IMAGE_STALE]` warning labels; `--interactive` picker markers renamed + last_used surfaced; `build_inventory` reads `last_used` from each session's `.log`. Sort stays raw session-ts.
- `src/libs/session_inventory.sh`: added `session_log_path`/`session_log_read`/`session_log_set` (per-session `.compose/<sid>.log`, KEY=VALUE) + `ts_to_epoch`/`relative_time` (relative elapsed).
- `scripts/run_agent.sh`: writes `last_started=` + clears `last_stopped=` at session start/resume (standard + serve, NOT dry-run which exits earlier); writes `last_stopped=` on post-session teardown (covers natural exit + make stop); sources session_inventory for the helpers.
- `scripts/prune.sh`: Rule-1 list shows relative `ts` (shares `enumerate_records`).
- `tests/test_session_log.sh` (NEW, 16 tests): session_log set/read/upsert + ts_to_epoch/relative_time. Updated `tests/test_resume.sh` display/marker tests; added `test_resume_writes_session_log` to `test_trace_resume.sh`.
- Docs: `execution_model.md` documents `.compose/<sid>.log` as a lifecycle artifact alongside the `.yml`; `sandbox_lifecycle.md`, `tool_interface.md`, `quickstart.md` updated for the new table/markers/last-used.
- Verified: suite 736/43/0; lint 0 warnings/100 files.

## Deferred items
- SERVE mode integration (roadmap).
- Bug E -- `make stop` template + duplicate-ID (escalate at iteration end).
- Contextual-knowledge-light naming principle (conventions at iteration end).

## What's Next
M2.6 - Session Persistence. Post-close bookkeeping: n/a (mid-milestone).
This iteration delivered the `make resume --list` refactor: relative `STARTED`/`LAST_USED`, exception-only `[SANDBOX_STALE]`/`[IMAGE_STALE]` warnings co-located with their column (provider/image, branch/workspace), BRANCH as `<branch> (<short sha>)`, and the unified per-session `.log` (last_stopped/last_started) feeding LAST_USED.
Deferred/PENDING next session: the PROVIDER image identifier (image name deemed not useful; container-sig display rolled back to keep `--list` docker-free -- investigate a meaningful, ideally registry-available identifier). Standing: SERVE mode integration (roadmap), Bug E (`make stop` template + duplicate-ID), contextual-knowledge-light naming (conventions fold at iteration end).
Watch-outs: dual-grep bridge; full-tree close-out greps.