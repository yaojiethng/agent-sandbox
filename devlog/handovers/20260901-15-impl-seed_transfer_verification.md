# Handover 20260901-15 — impl seed-transfer verification (post-docker-cp fail-closed check)

**Milestone:** M2.6 - Session Persistence
**Type:** impl
**Status:** Closed
**Date:** 2026-09-01

## Objective

Operator field report from the first real `make start` on the seed pipeline:
`docker cp` printed `Successfully copied 0B to sandbox-agent-sandbox-a47671:/home/agentuser/sandbox`.
The 0B figure is normal for stdin-mode `docker cp` (the byte counter covers the local-file copy
path; stdin extraction reports 0B regardless of payload). But the seed step currently has no
post-transfer verification, so a silently-empty seed would surface only as a container that
never initializes. This iteration adds a fail-closed verification to `seed_sandbox_volume` and
records the resume-testing state.

## Acceptance Criteria

- AC1: After `docker cp`, `seed_sandbox_volume` reads the sentinel `baseline.tar` back out of the
  volume (docker cp works on stopped containers) and fails the start if it is missing or empty.
- AC2: Trace test exercises the verification through the stub (success path; failure path via
  stub RC override if cheap, else documented).
- AC3: Suite green, lint Clean.
- AC4: Resume-testing state recorded: what is verified, what awaits operator docker runs.

## Completed

| Task | Evidence |
|---|---|
| Post-transfer verification in `seed_sandbox_volume` (AC1) | reads sentinel `baseline.tar` back out of the volume after `docker cp`; fail-closed with a one-line cause; success line now reads `Sandbox volume seeded (baseline.tar verified in volume).` |
| Docker stub implements both `docker cp` forms (AC2) | stdin-extract logged; read-back form writes a non-empty placeholder so trace tests observe a landed seed. `test_start_agent.sh` 32/0, `test_trace_dry_run.sh` 4/0 |
| Suite + lint (AC3) | 758/758/0; `check_lint.sh` Clean (0 warnings) |
| Resume-testing state recorded (AC4) | section below |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Verify by reading the sentinel file back out of the same container, not by launching a check container | no volume-name resolution needed, no extra containers, works on the stopped container |
| D2 | Verification is fail-closed (start aborts) | a bad seed always produces a container that cannot initialize; failing at seed time gives the operator a one-line cause instead of a health-wait stall |

## Findings

**F1 -- `docker cp` stdin mode always reports `0B`.** The operator's `Successfully copied 0B to
sandbox-agent-sandbox-a47671:/home/agentuser/sandbox` is expected output: the byte counter covers
the local-file copy path; stdin extraction reports 0B regardless of payload. Recorded here as the
authoritative explanation so the message is not re-investigated.

**F2 -- stub `local` at top level.** The first stub `cp` implementation used `local` outside a
function (rc=1, silent under the trace tests' `|| true`). Caught by the start_agent trace suite.

**F3 -- dry-run sandbox_init diagnostics (operator request).** The capability probe now emits a
`sandbox_init` layer: `project initialized at <path> (<N> files, <M> bytes)` on the console, plus
`sandbox_init.path` / `sandbox_init.files` / `sandbox_init.bytes` keys in the per-container
record (`.workspace/output/dryrun.capability.record`). Metrics are read-only (git-content only:
`.git` excluded) and never fail on their own -- a missing sandbox is a critical failure surfaced
by the session_state checks.

**F4 -- a found-empty seed list is the pipeline's dangerous failure mode** (carried from
20260901-14 F2). The post-transfer verification covers the transfer leg; an enumeration-side
fail-closed guard (non-empty worktree when the repo has files) remains a cheap future hardening.

## Resume-testing state (operator runs docker; agent continues statically)

- Verified by construction + stub tests: fresh start seeds the volume and init consumes it
  (trace tests through the stub); resume skips seeding entirely; resume of pre-change volumes
  works with the new entrypoint (needs the one-time `make start REBUILD=1` for image/compose
  agreement — handover 20260901-14 F8).
- Awaiting operator docker verification: real `make start` healthy status after seed;
  `make stop` / `make resume` round-trip on a seeded volume; diff export from a seeded session.
- The `0B` message is expected output, not an error (this handover is the record).

## Deferred

- Harness-version-identity impl (would make the old-image/new-compose skew fail fast instead of
  relying on the one-time rebuild) — existing roadmap item, unchanged.
