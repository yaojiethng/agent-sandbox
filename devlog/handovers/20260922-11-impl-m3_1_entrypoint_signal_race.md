# Agent Handover

**Date:** 2026-09-22
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Closed

## Objective

Harden the entrypoint-signal tests against the SIGTERM-before-trap race, in `tests/test_git_hook.sh` and `tests/test_capability_entrypoint_mount.sh`. This is robustness leftover 2 of 3, run under the operator's advance close authorization (Mode B).

## Decided approach

Both `invoke_*` helpers background a subshell that runs `bash entrypoint.sh`; `$pid` is the subshell, not the entrypoint. The readiness marker (`ALL CHECKS PASSED`, `Git hook installed`) prints at lines 230/177 of `entrypoint.sh`, before the `trap 'exit 0' TERM` registers at line 319. A SIGTERM sent after the marker can still land on the un-trapped script and `wait` returns 143.

Port the branch-B fix in its keep-current form:

- `exec bash entrypoint.sh` inside the background subshell, so `$pid` is the trap-bearing process (the signal reaches the entrypoint, not a wrapper).
- a short settle sleep after the readiness loop, so the exec'd process reaches trap registration before the SIGTERM.

`entrypoint.sh`'s TERM trap (`exit 0`) keeps `EP_RC == 0` on the clean signal path, so `assert_rc 0` in `test_git_hook.sh` is preserved.

## Acceptance criteria

Both helpers use `exec` + settle; the suite stays deterministic and green (712/712); order gate 58/58; selftest 16/16; lint Clean; roadmap row flips to `[x]`. The signal path is exercised repeatedly enough to trust the race is gone.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `exec` + settle, no FD-close | the keep-current runner gives the file a regular-file stdout (no pipe), so the bats-era `exec 3>&- 4>&-` is a no-op here; `exec` + settle directly close the marker-before-trap window | roadmap row |

## Completed

- [x] `exec bash` in both invoke helpers so `$pid` is the trap-bearing entrypoint process
- [x] Settle `0.2s` before the SIGTERM to close the marker-before-trap window
- [x] Verified: 5x rerun of both files stable; 712/712 suite green (10s P8); order gate 58/58; selftest 16/16; lint Clean

## Next steps

Run iteration 3 (`20260922-12`): the rc-driven failure reason in `scripts/run_tests.sh`.
