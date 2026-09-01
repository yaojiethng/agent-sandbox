# Agent Handover

**Date:** 2026-08-10
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Implementation (commit type: fix)
**Status:** Closed

## Objective
Fix the harness-side cause of `Error response from daemon: all predefined address
pools have been fully subnetted` — Docker network address-pool exhaustion from
leaked RUN_ID-scoped compose networks. Doc drift is a bug and part of this fix:
the documented container-state contract and teardown semantics are corrected to
match intent and prevent future drift.

## Root cause (established)
Each session creates a RUN_ID-scoped compose project; `docker compose up -d
sandbox` creates a unique `_default` bridge network. Teardown (`compose_stop`)
is implemented as `docker compose stop` — keeps containers + network — while the
`compose.sh` header and `execution_model.md` lifecycle diagram document
`compose down`. Networks leak per session and are not caught by `make prune`
(the compose-created network carries no label). Docker's default address pool is
exhausted.

## Scope (operator-confirmed)
**Fix (urgent):**
1. `src/build/compose.sh` — `compose_stop`: `docker compose stop` → `docker
   compose down` (restores documented contract; removes containers + network,
   keeps named volumes so resume still works).
2. `src/build/docker-compose.yml` — label the default network with the session
   labels (project-name, sandbox-dir, run-id) so label-based teardown and prune
   can find it.
3. `scripts/stop.sh` — **label-based teardown** (operator chose option ii over
   option i): `docker stop` + `docker rm` the containers (disposable per
   container contract) + find/remove the network by label. Avoids the
   compose-file blast radius (compose file is temp, not persisted).
4. `scripts/prune.sh` — verify network cleanup now matches via labels.

**Doc (part of the fix — doc drift is a bug):**
5. `docs/architecture/execution_model.md`:
   - Correct the stale anonymous-volume text (lines 127-129) — the current
     design uses a NAMED RUN_ID volume for sandbox/, not the anonymous
     `--volumes-from` design the doc describes.
   - Add a **Container State Contract** subsection (Session Lifecycle):
     container writable layer holds only regenerable config (copy-in) + caches;
     all user-authored state lives in the named volume + bind mounts. The
     container is disposable; resume comes from the volume. This is the
     as-expected record for future environment-setup features.
   - Note the docker verb-semantics mismatch (`start`/`stop`/`down` vs ours).

## Mid-session findings (to record)
| # | Finding | Disposition |
|---|---|---|
| 1 | `run_agent.sh` hand-rolls two teardown paths (`docker wait` + `compose_stop` in serve; `compose run --rm` + `compose_stop` in standard). Should be one unified teardown dispatch. | refactor in a future session |
| 2 | The generated compose file is temp (`mktemp`, deleted on EXIT trap) and not persisted. A future change should persist it (e.g. `.compose/<run-id>.yml` in SANDBOX_DIR) so compose-aware teardown/inspection is possible. Open question: is RUN_ID available at compose-generation time? **RESOLVED during session: RUN_ID is exported by `start_agent.sh` before `run_agent.sh` runs, and `compose_generate` substitutes `{{RUN_ID}}` — so it IS available at compose-generation time.** | not urgent; compose persistence deferred; label-based teardown is the urgent fix |
| 3 | Docker verb semantics: our `start` = full setup (`compose up` + `run agent`) and `stop` = teardown, which do not match docker's `start`/`stop`/`down` (pause vs end-session). A future decision on word-choice alignment. | deferred; documented as stopgap note in `execution_model.md` |
| 4 | `stop.sh` stores container/network IDs in plain strings and disables SC2086 (word-splitting) at each consumer. String-as-list is the smell; a real array (`mapfile` + `"${arr[@]}"`) removes the disables, the empty-check becomes `[[ ${#arr[@]} -eq 0 ]]`, and the intent is structural. | refactor in a future session (operator-directed) |

**Not in scope:** run_agent teardown refactor (finding 1); compose-file
persistence (finding 2); docker-verb renaming (finding 3); build-output UX fix
(separate session); provider default; prune-stale semantics; M2.6 mount work.

## Carried forward
| Item | From |
|---|---|
| Docker build-output single-line progress fix | next session (operator split) |
| run_agent unified teardown refactor | mid-session finding 1 |
| compose-file persistence (.compose/<run-id>.yml) | mid-session finding 2 |
| docker-verb semantics decision | mid-session finding 3 |
| `stop.sh` string-as-list → array refactor (removes SC2086 disables) | mid-session finding 4 |
