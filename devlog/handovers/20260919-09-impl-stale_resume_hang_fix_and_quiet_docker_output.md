# 20260919-09-impl-stale_resume_hang_fix_and_quiet_docker_output

- **Handover:** 20260919-09
- **Type:** Implementation
- **Milestone:** M2.6 / M2.6.7 (Interface Contract Compatibility)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Fixes the stale-session resume hang and quiets docker build and compose console
output at source. Backfilled after the fact from the pi session record; no
handover was opened when the work landed.

## Stale-resume hang

Compose v5 asks interactively to recreate a volume whose config no longer
matches the regenerated compose file. This happens on a stale-session resume
where the named volume predates the current compose config. The prompt blocks on
stdin, hanging `up -d sandbox` (and the EXIT trap's `compose down`) on the
unattended resume path.

Root cause: compose `survey/v2.(*Confirm).Prompt` called a blocking
`syscall.read` of stdin. Answering would destroy the stale session's volume, so
the harness must never auto-answer. Fix: guard the sandbox `up`, serve `up`, and
dry-run `up` with `< /dev/null` so compose runs non-interactive and keeps the
existing volume. A `docker compose` version probe confirmed daemon and volume
state before the fix landed.

## Quiet docker output

Investigation (operator-run probes on the host) established:

- `--progress tty` and `--progress auto` both use the fancy renderer when a TTY
  is present; the observed vertical dump is the cached-step staircase, not a
  plain-renderer downgrade. No progress mode compresses it; only `--quiet`
  removes it.
- Build output is not piped by the harness; `build.sh` runs `docker build`
  directly.
- `docker compose --progress quiet` silences the resource table at source for
  `up -d`.

Resolution: `docker build` runs with `--quiet`; compose `up` (standard, serve,
dry-run) passes `--progress quiet`. A shared `compose_output_filter()` was
factored, then deleted as dead code once quiet-at-source landed. `< /dev/null`
is retained independently of progress rendering for the interactive-prompt
safety. Documented in a new ADR (`docs/adr/docker_output_presentation.md`).

## Files in scope

- `scripts/run_agent.sh` -- `< /dev/null` on standard and serve `up`; drop the
  compose filter pipe.
- `src/build/compose.sh` -- `< /dev/null` on dry-run `up`; `--progress quiet`;
  shared `compose_output_filter()` added then removed.
- `scripts/build.sh` -- `docker build --quiet`; header comment updates.
- `docs/adr/docker_output_presentation.md` -- new ADR, first durable record of
  docker console-output presentation.
- `tests/stubs/docker` -- `--progress` added to the compose-arg flag list.
- `tests/test_start_agent.sh` -- dry-run fixture supplies `OUTPUT_DIR` and
  `DRY_RUN_RECORD_TIMEOUT`.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | Resume on a stale session no longer blocks on compose's interactive recreate prompt; it attaches the existing volume |
| AC2 | Docker build and compose console output is quiet at source (no progress staircase, no resource table) |
| AC3 | Failed builds still surface their error text |
| AC4 | A session volume is never destroyed by an unanswered prompt |
| AC5 | Suite green across the three code commits |

---
[CORRECTION -- 2026-09-20: The `--progress quiet` flag added here to the dry-run `up` in `src/build/compose.sh` was not recognised by the compose-arg parser in `tests/stubs/docker`, so `compose up -d` was misparsed, the stub never wrote the per-container diagnostics records, and every dry-run test polled the full 180s `DRY_RUN_RECORD_TIMEOUT` default twice per run before failing. The suite was not green and did not terminate; AC5's claim did not hold. Fixed by teaching the stub parser that `--progress` takes a value, and by supplying `OUTPUT_DIR` and `DRY_RUN_RECORD_TIMEOUT` from the `test_start_agent.sh` dry-run fixture. The two test files are recorded under Files in scope above. The stub-parser gap is routed to GOTCHAS.md; the stale AC5 claim is corrected in place.]
---

## Operator gate

Live resume of the previously-stale session (`692eb5`) is operator-run on the
host. The `< /dev/null` mechanism was validated during the investigation.
