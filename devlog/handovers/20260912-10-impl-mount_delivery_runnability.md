# Handover 20260912-10 - impl: mount delivery runnability (end-to-end verification)

**Date opened:** 2026-09-12
**Type:** impl
**Milestone:** M2.6 - Session Persistence (M2.6.6 Mount Model)
**Branch:** feat/M2_6_mount_model_redesign
**Status:** Closed

## Task

Roadmap l.158 (sole open M2.6.6 task-list item): verify the wired mount delivery path runs end-to-end -- start, work in, resume, and diff export on `SANDBOX_TYPE=mount`.

## Origin

Operator direction pick at the close of handover `20260912-09`.

## Current state (verified at open)

- Mount wiring is done (`20260818-03` compose file set, `20260820-01` F1 enablement): `docker-compose.mount.yml` bind-mounts the worktree; capability entrypoint validates `.git` + init marker, skips snapshot gate/init, writes `SESSION_STATE` into the worktree `.git`; `start_agent.sh` materializes the worktree via `snapshot_copy_worktree` minus `baseline.tar`; `SANDBOX_TYPE=mount` per-overlay literals.
- Wired but never run. The task is verification-first: run the real path, record what breaks, fix at the smallest correct layer.
- **Docker is NOT available in this container** (`docker: command not found`; no podman). The suite's docker stub exists (`tests/stubs/docker`) but stubs cannot verify runnability. End-to-end runs require the operator side.

## Scope (operator-confirmed, revised at Gate 2)

Three passes, one iteration:

- **Pass A -- offline static readiness sweep:** enumerate every `SANDBOX_TYPE=mount` conditional branch (entrypoint, start_agent, run_agent, compose set, session_env, prune, preflight); check each against the start contract from walk `20260818-02`; check `make` wiring (Makefile template passes no SANDBOX_TYPE/WORKTREE_DIR today -- start/dry-run/resume all default to copy). Deliverable: readiness report (untracked file, not committed).
- **Pass B -- implement the gaps:** make-target wiring (SANDBOX_TYPE/WORKTREE_DIR passthrough on start/dry-run/resume/stop), suite extensions for untested mount branches, offline-detectable defect fixes. Committed.
- **Pass C -- segmented live runbook:** runbook split into segments (start, work, stop, resume, diff export); presented one at a time; operator executes on the docker host and returns logs; failures documented and fixed in real time.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Every `SANDBOX_TYPE=mount` conditional branch enumerated with its contract source and current test coverage (readiness report) | offline read | pass -- 8-site inventory, contract cross-check, make-wiring analysis, coverage map, risk register (produced as an untracked ephemeral report; removed after the review pass -- the durable results live in this handover's Pass C log and Findings) |
| AC2 | Pass A gaps implemented: make wiring + suite extensions + defect fixes | suite + offline read | pass -- delivery contract reworked (start/run_agent/resume/session_env/template), `env_field` shared, +27 tests (779 vs 752 at open); live defects found and fixed: resume-as-copy, stale deployed Makefile (template v4) |
| AC3 | Segmented runbook exists; each segment executed by the operator with logs returned | chat record | pass -- 4 segments, all PASS (dry-run mount; start+attach+export; mount start under new contract; resume from record) |
| AC4 | Full suite passes | suite | pass -- 779 passed / 0 failed / 44 files |

## Completed

| File | Change |
|---|---|
| Pass A readiness report (ephemeral, removed) | 8-site branch inventory, start-contract cross-check, make-wiring analysis, coverage map, risk register |
| `src/capability/entrypoint.sh` | lib-dir test seam: `SANDBOX_LIB_DIR` override for the container lib dir (preflight + 5 source sites); default unchanged |
| `tests/stubs/libs/snapshot.sh` | no-op stub: entrypoint lists it CRITICAL and sources it unconditionally; consumers here never invoke it |
| `tests/test_capability_entrypoint_mount.sh` (new) | B5 behavioral: fail-closed without `.git`, first-run init marker + identity + path fields, attach preserves identity. Runs the real entrypoint via a sed-patched copy (ROOT rewritten; the hardcoded container root must not be created on the host) |
| `tests/test_start_agent.sh` | B4 behavioral: mount start materializes worktree (default `WORKTREE_DIR`, baseline commit, tracked content); second start attaches without re-materializing |
| `tests/test_trace_resume.sh` | B7: mount resume -- zero volume-destroying teardown/removal, sandbox re-attached, mount overlay merged at compose time (trace-observed; stub `compose config` returns the first input unchanged, so composed-file content cannot distinguish delivery) |
| `tests/test_trace_dry_run.sh` | G2 hygiene: mount dry-run stacks the overlay (trace-observed) + static probe-write gate -- probes may write only to channel dirs; the sole in-mount write is entrypoint-owned `.git/SESSION_STATE` |
| suite | 779 passed / 0 failed / 44 files (+27 tests) |

## Decisions

| Decision | Rationale |
|---|---|
| Verification-first, two-pass (static here, live on operator side) | docker absent in this container; runnability cannot be proven here, but wiring defects can be shaken out statically first |

## Pass C log (live run, operator-executed)

| Segment | Command | Result | Evidence |
|---|---|---|---|
| 1: dry-run (mount) | `make dry-run PROVIDER=pi SANDBOX_TYPE=mount` (+refresh) | PASS | Record verification green (9 capability + 8 reasoning layers, digest roundtrip); worktree materialized + baseline commit; resume pass reused the worktree |
| 2: start + attach + clean exit | `make start PROVIDER=pi SANDBOX_TYPE=mount`; agent touches a file; exit | PASS (start/export) + BUG found+fixed | Start attach clean (no re-materialization); file written in container propagated to host worktree; session export dir exists, `.export-status` SUCCESS. `make resume SESSION_ID=7bcb87` FAILED (delivery: copy) -- fixed by the delivery-contract rework; live re-run of resume pending (segment 3) |
| 3a: stale deployed Makefile | `make start PROVIDER=pi SANDBOX_TYPE=mount` ran COPY mode | ROOT CAUSE: deployed sandbox Makefile predates `DELIVERY_FLAG` -- the make var was silently ignored, default copy applied | Template version bumped 3 -> 4; upgrade path: `agent-sandbox onboard --refresh --name=<n> --sandbox=<dir>` re-renders the Makefile. A stray copy-mode session left on the operator's host by this defect is operator-owned housekeeping -- inert, prune-reachable. |
| 3b: mount start (new contract) | `make start PROVIDER=pi SANDBOX_TYPE=mount` after onboard --refresh | PASS (operator) | `--delivery=mount` in the echoed command; attach path; no seeder/volume |
| 4: resume from record | `make resume SESSION_ID=7bcb87` (no SANDBOX_TYPE on the command line) | PASS (operator) | `delivery: mount` recovered from the record; mount overlay merged; agent reattached with prior file state |

All four segments green. Pass C closed.

Q&A (operator, segment 1 evidence): worktree `.git` holds a single squashed baseline commit. Confirmed by-design for M2.6.6: N4 of the settled mount model prescribes snapshot-primitive materialization minus baseline.tar (clone strategies deferred); the diff pipeline is init_sha-bounded so history depth is unused; full-history worktree is roadmap l.118, explicitly outside M2.6.6. Copy delivery diverges intentionally: its seeder carries the full `.git`.

## Findings

- Pass A: wiring is coherent end-to-end on paper; every mount branch exists and the host->bind->container path chain checks out.
- LIVE-RUN BUG (segment 2 follow-up, fixed): `make resume SESSION_ID=<mount session>` defaulted to copy delivery -- resume read ambient `SANDBOX_TYPE` instead of the record; the mount session died against an unseeded volume. Operator steering generalized it: delivery is a command input, never environment state. `--delivery` parsed once at ingestion (start_agent, default copy), required (no default) in run_agent, recovered from the record in resume_agent (missing field = hard error), zero env reads/exports in the chain. Rule added: `bash-coding-conventions.md` 1.13.
- AUDIT CANDIDATE (future codebase audit): sweep the remaining env-dependent config for the same defect class -- candidates spotted: `RESET_VOLUME` (exported in run_agent, read via env), `WORKTREE_DIR` (env-read in session_env/run_agent), `INTERACTIVE_MAX_ENTRIES` (env-overridable in bash_env.sh), `SERVE_PORT`/`AGENT_CMD`/`AUTOSAVE_INTERVAL` (env with inline defaults). Assess each: command input vs persisted config vs safe default.
- `make start SANDBOX_TYPE=mount` works mechanically today (GNU make exports command-line vars into recipe env); the gap is documentation + tests, not plumbing.
- A mount resume test already existed (`test_resume_mount_keeps_worktree`) -- the readiness report's coverage map missed it (grep output truncation); B7's new value is the overlay-merge + composed-file observability assertions.
- The docker stub's `compose config` returns the first input file unchanged, so generated records in stub tests never show delivery overlays -- delivery must be asserted from the compose invocation trace, not the record file.
- Pass C runbook order (operator-directed): low impact first -- dry-run (mount), start+inspect (materialization), then escalating to agent file writes/commits, stop, resume, diff export.
- G2 decision recorded: dry-run never touches tracked repo content; sole in-mount write is `.git/SESSION_STATE` (git metadata, idempotent, entrypoint-owned). Encoded as a static probe-hygiene gate in `test_trace_dry_run.sh`.

## Review-pass outcome

Three rounds (fresh subagent per round, thermo-nuclear standard, both standing instruction classes seeded): round 1 BLOCK (B1: execution_model.md self-contradictory paragraph; plus 4 same-class doc-drift findings and 5 design notes -- all fixed: usage surfaces, DELIVERY_TYPE alias, stale test comment, lib-dir single assignment); round 2 BLOCK (B1: run_agent usage lines omitted --delivery; B2: handover suite-count inconsistency; plus false-comment and lib-dir notes -- all fixed); round 3 APPROVE. Non-blocking items folded: duplicate section banner and inaccurate loop-transients comment in entrypoint.sh. Deferred: shared delivery_validate (judged not load-bearing twice), warning-path coverage for ambient-SANDBOX_TYPE-ignored in resume (audit-candidate list). Suite re-verified 779/0/0 after each round.

## Deferred items

- Pass B execution (operator side, needs docker).

## Operator approvals on record

- Direction pick: "Mount delivery runnability next" (handover `20260912-09` close).
- Gate 2 scope confirmation: three-pass split (A sweep + untracked report, B implement gaps incl. unwired make commands, C segmented live runbook with realtime error tracking). Operator notes: make commands not yet wired with `SANDBOX_TYPE=mount`, including dry-run.
- Mid-iteration steering (operator): eliminate ambient-env delivery entirely -- functional contract, default parsed once at ingestion, resume reads the record; add the pattern to bash conventions; register an audit finding. Implemented.
- Live runbook order: low impact first (dry-run) escalating to file writes/commits. Followed.
