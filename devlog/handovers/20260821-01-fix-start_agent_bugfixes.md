# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Fix
**Status:** Closed

## Objective
Fix the agent-sandbox **`start` / `make start` bugfixes** (operator-steered restructure of the F2 session): pull all bugfixes ahead into this iteration, independently of the F2 `start`-command redesign. The F2 interactive-start redesign is split out into **two future iterations** — (1) a design session for the interactive control flow (incl. rework of existing control flow if required), then (2) an implementation iteration wiring the interactive control flow to the new mount mode. This iteration delivers only the fixes. The buildkit-progress revert (finding 2) is already done in this session.

## Bugfix scope (this iteration, type `fix`)
| # | Bug | Fix direction |
|---|---|---|
| 1 | `make start RESUME=1` does not resume (Make variable, not the agent-sandbox `--resume` flag) | Make-layer hookup: `RESUME=1` must pass `agent-sandbox start --resume` properly, consistent with the agent-sandbox flag; diagnose install-time Makefile vs template + `--resume` path before fixing |
| 2 | `make start INTERACTIVE=1` does not bring up the interactive picker | the template Makefile `start` target never references `INTERACTIVE` (draft/apply-only) → wire it into `start` |
| 3 | `make start` does not flag unused args | no general unused-arg guard in the Makefile `start` target (only special-case `CHANNEL`/`STALE_ONLY`); Make silently ignores unknown `VARIABLE=` overrides |
| 4 | `make stop` does not print a resume command (finding 1 — pulled in per operator, then **deferred**) | teardown should print the command to resume *that specific session*. **Blocked:** the session-id → `start` pass-through is not wired today (`RESUME=1`/`--resume` only open the picker; `start_agent.sh` has no `--session-id` flag; `SESSION_ID_FLAG` is `stop`-only). **Deferred to the F2 `start`-redesign iteration** — its pass-through is the blocked-on driver (roadmap L152), which will enable the accurate resume message. |
| 5 | Build buildkit-progress output regression (finding 2) | **DONE** — reverted to docker `auto`, `src/libs/buildkit_progress.sh` kept dormant |

## Not in this iteration
- F2 interactive `start` redesign (wizard, run inventory, config prefill, prints non-interactive command) — **future design session**, then implementation.
- F-dryrun delivery-awareness (mount no longer depends on `SNAPSHOT_DIR`) — **future implementation iteration** (hooks the interactive control flow to mount mode).
- Prune-command redesign (F5), F3 (mount worktree with full git history) — later.

## Context (verified)
- **`agent-sandbox start --resume`** exists (`start_agent.sh` L119 → `RESUME=true`; always shows the interactive volume picker; shares `_show_volume_picker` with the auto path).
- **Template Makefile** `start` target *does* define `RESUME_FLAG = $(if $(RESUME),--resume,)` and includes `$(RESUME_FLAG)` in `start` (L151/162/173). **The operator reports `make start RESUME=1` does not resume** — so the failure needs diagnosis against the installed Makefile / the actual `--resume` path (diagnose before fixing). The `start` target does **not** reference `INTERACTIVE` (draft/apply-only) — Bug 2.
- **Registry/delivery**: identity lives in `.compose/<session-id>.yml` (registry) + volume labels (copy resume). `.run-identity` deprecated (P3, `20260819-08`).

## Hot files
| File | Why in scope |
|---|---|
| `scripts/start_agent.sh` | `--resume` path; resume identity sourcing; teardown/resume command print |
| `scripts/templates/Makefile.template` | `start` target variable wiring: `RESUME`, `INTERACTIVE`, unused-arg guard; `stop` resume-command print |
| `scripts/agent-sandbox.sh` / `stop.sh` | teardown path for printing the resume command (finding 1) |
| `scripts/build.sh` | finding-2 revert (done) |
| `tests/test_trace_build.sh` | finding-2 test removals (done) |

## Out of scope (deferred)
- F2 interactive-start design + implementation (future two iterations).
- F-dryrun, F3, F5 (prune redesign).

## Acceptance criteria
- [x] `make start RESUME=1` resumes a session via `--resume` (Bug 1) — **closed**; wiring correct at HEAD (repro); operator will manual-test after container closes
- [x] `make start INTERACTIVE=1` reaches the interactive picker (Bug 2) — **done**: `INTERACTIVE=1`→`--interactive` wired into the `start` target; `--interactive` is a distinct knob (interactive picker, not a resume alias); currently **not yet implemented** — errors with a clear message pending F2.
- [x] Bug 3 — **converted to a finding** (not a fix; see Decisions 7 + Findings).
- [ ] `make stop` prints the resume command for the stopped session (finding 1) — **blocked on the session-id→`start` pass-through link-up** (roadmap L152; resuming a *specific* session by id is not wired yet). **Deferred** — this iteration does not deliver it; it lands in the F2 `start`-redesign iteration.
- [x] Build output is clean `auto` (finding 2, done); suite green — **459/459 pass.**

## Decisions
| # | Decision | Rationale |
|---|---|---|
| 1 | Finding 2 (buildkit-progress revert) — keep `src/libs/buildkit_progress.sh` dormant, not deleted; done this iteration | operator; full revert would discard the utility's documented history; dormant file keeps re-addition easy |
| 2 | Finding 1 (stop prints resume command) initially pulled into this fix iteration — **then deferred** (see Findings): blocked on the session-id→`start` pass-through (roadmap L152), lands in the F2 `start`-redesign iteration | operator initially coupled it to the resume surface (Bug 1); deferral per the pass-through not being wired (start_agent.sh has no `--session-id`) |
| 4 | F2 wizard split into two future iterations (design → impl+mount hookup); this iteration is type `fix` and excludes F2 design/impl | operator restructure |
| 5 | Handover renamed `20260821-01-impl-f2_start_wizard.md` → `20260821-01-fix-start_agent_bugfixes.md`, Type `Fix` | operator confirmed; type must match dominant activity at close |
| 6 | `INTERACTIVE` = the **interactive picker** (a distinct layer); `RESUME` = a **resume branch of the interactive picker** — they are NOT synonyms. Bug 2 implemented as: wire the `INTERACTIVE=1`→`--interactive` surface, but **`--interactive` errors as not-yet-implemented** (the real picker is F2) rather than aliasing to the resume picker | operator clarification; my initial alias was wrong |
| 7 | Bug 3 (unused-arg guard) **converted to a finding**, not a fix — plain Make cannot enumerate unknown `VAR=` overrides; the realistic fix is that the Makefile may not be the best command surface (explore a replacement — deferred investigation) | operator; a general guard is not feasible in Make |

## Findings
| Finding | Type | Impact |
|---|---|---|
| 1 | `make start RESUME=1` does not resume — Make variable `RESUME=1` passes `agent-sandbox start --resume`. **Repro (2026-08-21, via dispatcher + docker stub):** wiring is correct at HEAD — template Makefile `RESUME_FLAG`→`--resume`; dispatcher injects `standard` mode; `start_agent.sh --resume` shows the picker and resumes the prior session via `compose up -d` (no reset-volume/fresh build). Root cause: operator's **older installed Makefile** (predates `RESUME_FLAG` in `start`). **CLOSED — no code change; operator refreshed Makefile, will manual-test after container closes** | bug | closed (this iteration) |
| `make start INTERACTIVE=1` does not bring up the interactive picker — the template Makefile `start` target never references `INTERACTIVE` (draft/apply-only), silently dropped; script's `Unknown flag` guard never fires | bug | **DONE** this iteration — wired `INTERACTIVE`→`--interactive` into `start`; `--interactive` recognized in `start_agent.sh` as a distinct knob and errors `not yet implemented` until F2 (78–86, L420) |
| `make start` does not flag unused args — no general unused-arg guard in the template Makefile `start` target (only special-case `CHANNEL`/`STALE_ONLY`); Make silently ignores unknown `VARIABLE=` overrides | bug | **converted to finding** (Decisions 7): a general guard is not feasible in plain Make; realistic fix = replace the Makefile command surface (deferred investigation) |
| Test-infra gap: `test/stubs/docker` `volume inspect` ignores `--format` (returns raw JSON, polluting identity) and serves `run-id` not `session-id`; `volume ls` returns nothing by default; the dispatcher's `@@AGENT_SANDBOX_REPO@@` placeholder isn't exercised by tests | gap (found during Bug 1 repro) | follow-up — resume picker + dispatcher mode-injection are currently untested |
| `make stop` teardown should print the resume command needed to resume that session (model: `pi --session <id>`; `make draft` accept/reject guide) | feature (steering) | **DEFERRED to F2 `start`-redesign** — pulled in this iteration, then blocked: impossible without the session-id→`start` resume pass-through (roadmap L152), which is not wired (start_agent.sh has no `--session-id`; SESSION_ID derived not passed; SESSION_ID_FLAG is `stop`-only). Lands at roadmap L152. Triaged to: roadmap L152 (F2). |
| Build buildkit-progress output regression (`src/libs/buildkit_progress.sh`/`_buildkit_run`/`--progress=plain`) — not rendering well | bug (steering) | DONE this iteration — reverted to `auto`, lib kept dormant |
| Findings header rename (mid-session findings → Findings) — already applied (`20260819-11`); residual is the intentional transient GOTCHAS dual-grep bridge | steering | invalid — no-op, removed per operator |

## Completed
| File | Change |
|---|---|
| `devlog/handovers/20260821-01-fix-start_agent_bugfixes.md` | Recreated this handover (lost in baseline reset); merged the absorbed prior handover `20260820-02` into it; deleted `20260820-02`; renamed to `fix` type + bugfix scope |
| `devlog/roadmap.md` | F3 relocated out of M2.6.6 into a general M2.6 item (compaction prep); finding-2 truncation task added under M2.6 |
| `scripts/build.sh` | Finding-2 revert: removed `source buildkit_progress.sh`; `build_image` uses docker `auto` (dropped `--progress=plain` + `_buildkit_run` branch); preserved fail-closed descriptive error |
| `tests/test_trace_build.sh` | Removed `buildkit_progress.sh` source, `progress=plain` assertion, and the two `_buildkit_current_step` tests + registrations; kept the `set -e` descriptive-error test |
| `src/libs/buildkit_progress.sh` | Unchanged — kept dormant (unreferenced, not deleted) |
| `scripts/start_agent.sh` | Bug 2: added `--interactive` flag (parse + init); `--interactive` errors `not yet implemented` (distinct from `--resume`, which still forces the picker); usage/help updated |
| `scripts/templates/Makefile.template` | Bug 2: added `INTERACTIVE_FLAG` + wired `$(INTERACTIVE_FLAG)` into `start`; extended `INTERACTIVE` comment block + help line (`not yet implemented`). Verified: 82/82 relevant tests pass; smoke-tested `--interactive` (err) + `--resume` (picker) via dispatcher |

## What's Next
This iteration (type `fix`): Bugs 1, 2, and finding 2 are **done**; Bug 3 was **converted to a finding** (operator — a general guard is not feasible in plain Make; Makefile may be replaced as the command surface). **Finding 1 is DEFERRED** — `make stop` printing the resume command is blocked on the session-id→`start` resume pass-through (roadmap L152, not wired), so it lands in the F2 `start`-redesign iteration, not close at this iteration. **Remaining here: pre-close verification + delivery commit (fix).** After this iteration: F2 design session (interactive start wizard — `--interactive` is already a wired-but-not-implemented knob ready for it), then F2 implementation + mount hookup. Follow-up recorded: test-stub gaps (resume picker + dispatcher mode-injection untested).
