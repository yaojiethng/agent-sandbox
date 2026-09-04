# Handover 20260904-05 — fix seeder compose run tty stall

**Milestone:** M2.6 - Session Persistence
**Type:** fix
**Status:** Closed
**Date:** 2026-09-04

## Objective

Fix the live-verification stall of the helper seeder (handover 20260904-04, operator step 2): `docker compose run --rm seeder` hung after the seeder container had already run and been removed by `--rm`.

## Diagnosis

Output fingerprint: `Created` → `failed to resize tty, using default size` → stall; `docker ps -a` empty. `docker compose run` allocates a TTY and attaches stdin by default; the seeder ran and exited (`--rm` removed the container, hence the empty `ps -a`), but compose kept waiting on the never-closing stdin attach stream of the non-interactive caller. The seed itself most likely completed and self-verified before the hang.

## Fix

Run the seeder non-interactively: `docker compose run --rm -T seeder </dev/null` — no TTY allocation, stdin closed, exit code still propagates. `SEED_TIMEOUT` remains the backstop.

## Second live finding (same iteration)

After the tty fix, the seeder failed fast and fail-closed exactly as designed: `cp: cannot create directory '/dest/.git': Permission denied`, seeder exit 1, start aborted, volume discarded. Root cause: fresh empty named volumes are initialized (content + ownership) from the image's directory at the **mount target path**. The seeder mounted the volume at `/dest`, which does not exist in the image, so the volume root initialized root-owned and the unprivileged seeder could not write. The legacy path never hit this because its extraction ran as root. Fix: mount the session volume at the sandbox service's own target path (`/home/agentuser/sandbox`), restoring the image-based ownership initialization; recorded in the ADR decision block and the seeder's DEST comment.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| AC1 | Seeder compose invocation is non-interactive (`-T`, stdin closed) | done |
| AC2 | Suite green, lint Clean | done |
| AC3 | Operator live re-run: start completes without stall, no `.agent-sandbox-seed/` in the worktree | done (dry-run ALL PHASES PASSED; worktree clean, uniform agentuser ownership) |
| AC4 | Session volume mounted at the sandbox service's target path; volume root writable by the seeder | done (code + docs; live confirmation rides AC3) |
