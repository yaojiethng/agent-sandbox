# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Closed

## Objective

Replace the `trap 'rm -rf "$staging_dir"' RETURN` cleanup in `compose_generate` with an explicit cleanup per return path, so temp removal does not depend on shell-functrace semantics. This is robustness leftover 1 of 3, run under the operator's advance close authorization (Mode B).

## Decided approach

The RETURN trap is latent but fragile: under bats' `functrace` the trap fires across subprocess boundaries and can delete the staging dir mid-function. The keep-current runner never enables functrace, so the failure is latent, not active. Replace the trap with explicit `rm -rf "$staging_dir"` on every path that can exit at or after staging-dir creation:

- the `input file not found` early-return path;
- the normal completion path, after the `docker compose config` merge.

Preserve the function's return code: capture the merge pipeline's `$?` into `rc`, clean, `return "$rc"`. The early returns before staging creation (no input files; docker missing; digest missing) need no cleanup.

## Acceptance criteria

The RETURN trap is gone; every staging-dir return path cleans up explicitly; the return-code contract is unchanged; the full suite, order gate, selftest, and lint stay green; the roadmap row flips to `[x]`.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Explicit cleanup per path, not an EXIT trap | an EXIT trap fires at shell exit (too late) and, with a `local` staging_dir, would run `rm -rf` on an empty var | roadmap row |

## Completed

- [x] Replaced the RETURN trap with explicit per-path cleanup in `compose_generate`
- [x] Preserved the return-code contract (input-file-not-found returns 1; merge failure returns the pipeline rc)
- [x] Verified: 712/712 suite green (10s P8), order gate 58/58 clean, selftest 16/16, lint Clean

## Next steps

Run iteration 2 (`20260922-11`): the entrypoint-signal race hardening in `test_git_hook.sh` and `test_capability_entrypoint_mount.sh`, porting the branch-B `exec` + settle-grace fix.
