# Agent Handover

**Date:** 2026-08-10
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Implementation (commit type: refactor)
**Status:** Closed

## Objective
Refactor `scripts/run_agent.sh` so the two hand-rolled teardown paths become a
single unified teardown dispatch. Carried finding 1 from session `20260810-10`
(docker network pool exhaustion): *"run_agent.sh hand-rolls two teardown paths
(`docker wait` + `compose_stop` in serve; `compose run --rm` + `compose_stop`
in standard). Should be one unified teardown dispatch."*

## Current state (established)
`scripts/run_agent.sh` lines 223-248:

- **serve branch:** `compose up -d` → `docker wait "$AGENT_CONTAINER_NAME"`
  (blocks until `make stop`/`docker stop` triggers exit) → `echo "+ tearing
  down..."` + `compose_stop`.
- **standard branch:** `compose up -d sandbox` → `compose_sandbox_wait` →
  `compose run --rm agent` (blocks until agent exits) → `echo "+ tearing
  down..."` + `compose_stop`.

Both modes converge on the same post-session teardown (`compose_stop` → `down`,
keep named volumes) but duplicate the `echo` + call in each branch. The pre-run
`compose_stop` (stop any previous project, skipped on `--reset-volume`) is a
separate concern and stays as-is.

## Scope (operator-confirmed)
**Refactor (behavior-preserving) + one folded correction (issue 1):**
1. `scripts/run_agent.sh` — restructure so the mode branch only runs the
   session (serve: `up -d` + `docker wait`; standard: `up -d sandbox` +
   `compose_sandbox_wait` + `compose run --rm agent`), and a single unified
   teardown dispatch follows the mode branch: `echo "+ tearing down..."` +
   `session_teardown`. Pre-run `session_teardown` (stop-previous-project,
   skipped on `--reset-volume`) unchanged — it is the resume-path safety
   net, not dead code (verified: RUN_ID is reused from volume labels on
   resume, so the pre-run cleanup targets the same project).
2. **Rename** `compose_stop`/`compose_destroy` → `session_teardown`/
   `session_destroy` (intent-based naming resolves the docker-verb mismatch;
   `compose_stop` currently runs `docker compose down`, not `stop`).
   Propagation: `src/build/compose.sh` (defs + header + `_compose_down`
   selector), `scripts/run_agent.sh` (3 sites), `tests/test_trace_start.sh`
   (comments), `docs/architecture/execution_model.md` (verb table).
3. **Exit semantics (folded correction — issue 1 resolution):** unified
   dispatch captures the run's exit status so teardown always runs, then
   exits with it: standard propagates the agent's rc; serve exits 0 (its
   session ends via `make stop` → `docker stop` → SIGTERM/SIGKILL, whose
   container code is 137/143 — not a session result; the existing
   `docker wait ... || true` swallows it). Verified: nothing consumes
   run_agent's rc anywhere (all-`exec` chain, no chaining), so the contract
   is operator-facing only; documented in execution_model.md as the
   defined semantics.
4. `docs/architecture/security.md` line 84 — stale `docker compose stop
   (not down)` claim (doc drift from the network fix).

**Tests:**
5. `tests/test_trace_start.sh` — strengthen serve teardown to also assert
   `compose down` is issued (currently only asserts `down -v` absent); add
   trace-last-command lock (final compose dispatch is `down`) for standard +
   serve; add rc-propagation lock: stub `run` returns
   `DOCKER_STUB_RUN_RC` → standard exits with that rc AND teardown ran
   (locks issue-1 fix + exit semantics). Update rename comments.
6. `test/stubs/docker` — `compose run` honors `DOCKER_STUB_RUN_RC` (env-gated,
   zero impact on existing tests).

## Mid-session findings (to record)
| # | Finding | Disposition |
|---|---|---|
| 1 | **Standard-mode agent-failure skips teardown:** `docker compose run --rm` propagates the agent's exit code; under `set -euo pipefail` a non-zero agent exit aborts `run_agent.sh` before teardown, leaking containers + network. Serve mode always tears down (`docker wait ... \|\| true`). | **fixed this session** (operator-approved): EXIT-trap teardown — `_session_cleanup` runs `session_teardown` on every exit after `TEARDOWN_NEEDED` is set; standard captures rc (`\|\| agent_rc=$?`) and exits with it |
| 1a | **Thermo-nuclear review P1 (adopted):** the explicit dispatch only ran on the happy path — `compose up` failure (serve + standard, pipefail propagates), and `compose_sandbox_wait`'s bare `exit 1` (unhealthy/timeout) all aborted *before* it. Trap-based teardown fixes all three. Verified: subagent's "Ctrl-C bonus" claim was overstated — bash defers its own traps while a foreground child runs, so both designs handle Ctrl-C identically (child receives SIGINT and returns). | fixed: `_session_cleanup` EXIT trap; three new failure-simulation tests (stub `DOCKER_STUB_UP_RC` + `DOCKER_STUB_SANDBOX_HEALTH`); each verified to fail when the trap is disabled |
| 2 | Serve teardown was never positively tested — `test_serve_post_agent_no_v` asserts only `down -v` count 0, not that `compose down` runs at all. | fixed in this session (scope item 5) |
| 3 | Pre-run teardown (stop previous project) and post-session teardown are two different concerns sharing the same primitive. Keeping them separate preserves the `--reset-volume` skip semantics. | stays as-is; documented in the code comment |
| 4 | `compose_stop` is misnamed: it runs `docker compose down` (removes containers+network), not `docker compose stop`. The network fix changed the implementation but kept the name — the source of this session's Q2 confusion. | fixed: renamed `session_teardown` (this session) |
| 5 | Serve's `make stop` path yields a container exit of 137/143 (SIGTERM/SIGKILL, per the entrypoint's documented SIGTERM limitation — no TERM trap in the reasoning entrypoint), not a meaningful agent result. Uniform agent-rc propagation would make every normal serve stop report failure. | serve exits 0 (docker wait rc swallowed); documented in execution_model.md |
| 6 | run_agent's exit code is consumed nowhere (all-`exec` chain, no chaining) and documented nowhere — the semantics have drifted. | standardized + documented this session (decisions 4/5) |
| 7 | `compose_sandbox_wait` failure exits 1 before teardown — sandbox-not-healthy path skips the unified dispatch (pre-existing; container may be left running on timeout). | flagged; carried forward |
| 8 | **Naming collision:** the `session_teardown`/`session_destroy` rename trades the docker-verb mismatch (`compose_stop` ran `down`) for a better-but-collided name: "session" is reserved in the ops domain (commit + handover, per handover_policy) yet the harness already uses it for the agent run (`RESUME_SESSION`, `SESSION_TS`, `agent-sandbox.session-ts` volume labels, `session-diffs`, execution_model.md "Session Lifecycle" + "session teardown"). The rename was kept (operator decision) — the two domains are separated by context — but the collision is logged as a future naming decision. **This replaces the original carried docker-verb semantics decision** (finding 3 from `20260810-10`): the old bad name is gone, so the "align with docker verbs or rename" question is moot; what remains is the session-naming collision. | flagged; replaces carried docker-verb finding |
| 9 | **Stub lost its executable bit mid-session** — the mode divergence (index 100644; working tree 755 via snapshot pipeline) surfaced only in-container because the container git runs `core.fileMode=true` while the host repo ran `core.fileMode=false` [see correction below] — a host/container asymmetry, not a repo defect. A `git stash`/`git checkout` cycle normalized the working-tree file to the index mode → all 16 stub-invoking tests failed with "Permission denied". Fixed: `chmod +x` + `git update-index --chmod=+x` (index now 100755). The `git checkout tests/test_trace_start.sh` (to remove a debug patch) also reverted that file's session edits — the git-restore trap from session 12 struck again, despite the AGENT_FEEDBACK entry. | fixed; re-applied test edits; recorded in AGENT_FEEDBACK |

## Decisions
| # | Decision | Rationale |
|---|---|---|
| 1 | Unify by restructuring: mode branch runs the session only; single teardown dispatch after it | Both branches already converge on identical teardown; one site = one place to change. The mode branch must still block until session end (serve: `docker wait`; standard: `compose run`) so the provider-entrypoint copy-out EXIT trap has fired before teardown |
| 2 | Pre-run `session_teardown` left untouched | Different semantic (stop-previous-project, skipped on reset); it is the resume-path cleanup — RUN_ID is reused from volume labels on resume, so it targets the same project |
| 3 | Rename to `session_teardown`/`session_destroy` | Intent-based naming; `compose_stop` runs `down` (not `stop`) — the name caused exactly the confusion raised in this session's Q2. Kept despite the session-naming collision (finding 8): the collision is pre-existing harness-wide (RESUME_SESSION etc.), the functions are unambiguous in their harness context, and a full sweep would break persisted volume labels |
| 4 | Exit semantics: standard → agent rc (captured, teardown runs first); serve → 0 | Uniform principle "clean session end = 0, standard agent failure = its rc". Serve's `make stop` path yields SIGKILL 137/143 — not a session result, so not forwarded. Nothing consumes the rc (verified); contract documented for the operator |
| 5 | All non-error exits are 0 by design; error codes surface only when meaningful (standard agent failure) | Operator-endorsed simplification: the rc is operator-facing only today; document the defined semantics, don't invent consumers |

## Completed this session
| # | Item | Notes |
|---|---|---|
| 1 | `scripts/run_agent.sh` — EXIT-trap teardown (`_session_cleanup`, `TEARDOWN_NEEDED` guard) + rc capture/exit | Mode branch runs session only; teardown guaranteed on every post-start exit (agent completion/failure, up failure, sandbox-wait failure); standard propagates agent rc, serve exits 0; pre-run cleanup kept (resume-path safety net); SC2317 directive for trap-invoked function |
| 2 | `src/build/compose.sh` — rename `compose_stop`→`session_teardown`, `compose_destroy`→`session_destroy` (+ header, `_compose_down` selector) | Zero stale references repo-wide |
| 3 | `docs/architecture/execution_model.md` — verb-table rename + **Session exit semantics** section (updated for trap-based teardown) | Documents the standardized contract |
| 4 | `docs/architecture/security.md` — stale `compose stop (not down)` claim fixed | Doc drift from the network fix |
| 5 | `tests/test_trace_start.sh` — serve teardown positive assert, trace-last-is-down lock (parameterized), rc-propagation lock, **3 failure-simulation tests** (up-fail serve/standard, sandbox-unhealthy); rename comments; `unset` stub vars in fixture | 15 tests; each verified to fail on its regression (NEG: trap disabled → 6 failures) |
| 6 | `test/stubs/docker` — `DOCKER_STUB_RUN_RC`, `DOCKER_STUB_UP_RC`, `DOCKER_STUB_SANDBOX_HEALTH`; merged up/run case | Env-gated; zero impact on existing tests |
| 7 | Stub executable-bit recovery — `chmod +x` + `git update-index --chmod=+x` (index 100644→100755) | Lost during a stash/checkout cycle [see correction below]; 16 tests were failing with "Permission denied"; recorded in AGENT_FEEDBACK |
| 8 | Verification | 468 tests, 462 passed, 0 failed, 6 skipped; shellcheck: no new findings vs HEAD (SC2317 directive used) |

## Not in scope
compose-file persistence (`.compose/<run-id>.yml`); session-naming collision
resolution (finding 8 — logged as the successor to the docker-verb decision);
M2.6 mount work (paths A/B).

## Carried forward
| Item | From |
|---|---|
| compose-file persistence (`.compose/<run-id>.yml` in SANDBOX_DIR) | session `20260810-10` finding 2 |
| **Session-naming collision** — harness "session" (agent run: RESUME_SESSION, Session Lifecycle, session labels) vs ops "session" (commit + handover). Decide whether to rename the harness vocabulary (breaking: volume labels, SESSION_STATE) or accept the two-domain overlap. Replaces the docker-verb semantics decision (finding 3 from `20260810-10`) — the bad `compose_stop` name is gone, so the verb-alignment question is moot | this session finding 8 (traded for the docker-verb finding) |
| `compose_sandbox_wait` failure exits 1 before teardown — sandbox-not-healthy path skips the unified dispatch (pre-existing; container may be left running on timeout) | this session (flagged during implementation) |

---

## Session open — status
- [x] Handover created (this file)
- [x] Scope confirmed by operator
- [x] Refactor implemented
- [x] Tests updated + full suite green
- [x] Handover updated (findings, decisions, completed)
- [x] Roadmap checkboxes updated
- [ ] Operator released pre-close gate
- [ ] Status → Closed; committed

---

[CORRECTION -- 2026-09-01]: the mode divergence in finding 9 and completed
item 7 was originally attributed to the repo running `core.filemode=false`.
The diagnosis is corrected per handover `20260901-01-fix-file_mode_anomaly.md`:
the divergence (index 100644; working tree 755) surfaced only in the container
because the container git runs `core.fileMode=true` (set from
`filesystem_tracks_exec_bits`) while the host repo ran `core.fileMode=false`
— a host/container `core.fileMode` mismatch, not a repo-level defect. Resolved
on the host by bringing `core.fileMode` to parity (`true`) and normalising
host tree exec bits. The underlying lesson — a `git stash`/`git checkout`
cycle normalises working-tree modes and can revert uncommitted edits; re-assert
a lost exec bit with `chmod +x` + `git update-index --chmod=+x` — is unchanged.
