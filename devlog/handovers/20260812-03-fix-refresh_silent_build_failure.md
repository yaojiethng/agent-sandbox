# Agent Handover

**Session date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Session type:** Fix
**Status:** Closed

## Objective

`make start PROVIDER=pi REFRESH=1` (and `--rebuild`) fails with a bare `make: *** [Makefile:94: start] Error 1` and **no output at all** after "Refreshing sandbox and provider: pi...". Starting without `REFRESH` works. Trace the error to its root cause and explain why the message is so undescriptive, then fix within this session. Operator added in-scope: adopt the Google Shell Style Guide as the definitive style guide (with shellcheck noted), and resolve findings #9 (TTY/non-TTY failure-line asymmetry) and #10 (`_build_rc` fail-closed sentinel) in `_buildkit_run`/`build_image`.

## Root cause (established, reproduced deterministically under a pty)

The build path runs under `set -euo pipefail`. It is taken only when `REFRESH`/`REBUILD` is set (which is why plain `make start` works). `build_sandbox` → `build_image` → on a TTY → `_buildkit_run` (`src/libs/buildkit_progress.sh`, added by `20260812-01`). Three compounding `set -e` landmines abort the script with an empty exit code:

1. **`_buildkit_run` poll loop** — `_step="$(_buildkit_current_step "$_prog_log")"`. At build start the captured BuildKit log is still empty; `_buildkit_current_step` is `grep | tail | sed`, `grep` finds nothing → returns 1 → `pipefail` makes the pipeline return 1 → the plain command-substitution assignment's status is 1 → `set -e` aborts on the first poll (docker hasn't emitted its first `#N [stage]` header yet). No output, bare exit 1.
2. **`wait "$_prog_pid"`** — `wait` on a failed background build returns its (non-zero) status; a bare `wait` under `set -e` aborts *before* `_buildkit_run`'s failure handler can dump the captured output. Even a genuine docker failure died silently.
3. **`_buildkit_run`'s `return $_rc` at the call site** (`build_image`) — a sourced function returning non-zero, called as a top-level command, aborts under `set -e` before the caller can read `$?`.

Compounding these, `build_image`'s failure path was a bare `exit 1` (no message), and its **non-TTY branch** had the same class of defect (a bare `"${build_cmd[@]}"` under `set -e` would abort silently on a docker failure, surfacing only docker's raw stderr). The asymmetry meant the two branches handled the identical "docker build failed" condition differently.

This is the exact class documented in `docs/development/bash-coding-conventions.md` rule 4.3 ("`grep` returns exit 1 on zero matches... Always append `|| true`") and mirrored in open `devlog/AGENT_FEEDBACK.md` bash entries. The `20260812-01` code violated it; the prior test did not catch it because it only exercised a populated log, and the harness runs `set -uo pipefail` without `-e`.

## Fix approach

Minimal, pattern-consistent (uses the `|| true` / `|| _rc=$?` idiom already canonized in the repo's bash conventions rule 4.3 and AGENT_FEEDBACK). Also makes the two `build_image` modes handle failure uniformly instead of split-brained.

## Completed this session

| # | Item | Notes |
|---|---|---|
| 1 | `src/libs/buildkit_progress.sh` — `_buildkit_current_step` | split `local step` + `... \|\| true`; returns "" and exit 0 on an empty log (no `grep` no-match abort in the poll loop). |
| 2 | `src/libs/buildkit_progress.sh` — `_buildkit_run` | `wait "$_prog_pid" \|\| _rc=$?` captures the child's exact status without a `set -e` abort; kept the full failure dump. |
| 3 | `src/libs/buildkit_progress.sh` — doc example | replaced the stale `if [[ $? -ne 0 ]]` example (which taught the buggy pattern) with the `\|\| _rc=$?` capture idiom and the reason. |
| 4 | `scripts/build.sh` — `build_image` | unified failure handling across TTY/non-TTY via `local _build_rc=1` sentinel + `&& _build_rc=0 \|\| _build_rc=$?` capture (fail-closed; success clears to 0, failure records the real code, a missing build path reports failure); one shared descriptive message + `exit 1`; non-TTY success line gated so neither mode double-reports completion. |
| 5 | `src/libs/buildkit_progress.sh` — `_buildkit_run` failure terminal line | removed the separate `FAILED (Ns)` terminal line; on failure the renderer now dumps the captured build output and returns the status, leaving the single conclusive failure report to the caller (`build_image`). |
| 6 | `tests/test_trace_build.sh` | new `test_buildkit_current_step_empty_log_returns_zero` (empty log → empty step + exit 0). |
| 7 | `docs/development/bash-coding-conventions.md` | declared Google Shell Style Guide as the authoritative style guide (this doc wins on project-specific conventions, incl. the `\|\| true`/`\|\| rc=$?` idioms; Google guide is silent there) and noted shellcheck is installed/run and what it does/does not catch. |

## Verification

- Reproduced the original silent failure (pty, empty log, `set -euo pipefail`): before → exit 1 with zero output; after → full progress line, completes exit 0.
- End-to-end TTY success and failure, plus non-TTY failure, all under `set -euo pipefail`: TTY fail exits 1 with progress → FAILED → BuildKit dump → `build_image: ERROR build FAILED for <image> (exit N).`; TTY/non-TTY success exit 0 with one completion line.
- `src/libs/buildkit_progress.sh` shellcheck-clean; no new shellcheck findings in `scripts/build.sh` (only pre-existing `SC2046`/`SC2034`/`SC1091` on untouched lines).
- Full suite green: **471 tests, 465 passed, 0 failed, 6 skipped** (the +1 is the new empty-log test).

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Use `\|\| true` / `\| _rc=$?` capture (repo-canonical) rather than a bare `set +e` region or `|| :` | matches `bash-coding-conventions.md` rule 4.3 and the open AGENT_FEEDBACK mitigation; `\|\| _rc=$?` preserves the child's exact exit code (e.g. 42), not just "non-zero". |
| 2 | Unify `build_image` TTY/non-TTY failure handling | the two modes were handling the identical "docker failed" condition differently (one descriptive, one a silent `set -e` abort); unify failure, keep each mode's existing success rendering to avoid regression. |
| 3 | Keep `_buildkit_run` contract "return child's exit status" | correct per GOTCHA [H]: a returned library function may return non-zero; the caller guarding with `\|\|` is the documented pattern. Do not silently swallow status. |

## Mid-session findings

| # | Finding | Disposition |
|---|---|---|
| 1 | `set -e` + `pipefail` + a `grep`-no-match pipeline in a command-substitution assignment aborts the whole script, not just the assignment | fixed; the canonical `|| true` / `|| _rc=$?` idioms now applied |
| 2 | `wait` on a failed child aborts under `set -e` before failure handling runs | fixed with `wait ... || _rc=$?` |
| 3 | A sourced function returning non-zero, called at top level, aborts under `set -e` before the caller reads `$?` | the caller (`build_image`) now captures status via `\|\| _rc=$?` |
| 4 | **Googler's shell style guide is silent on `\|\| true`** (it is not blessed or forbidden); it is standard POSIX/bash for "this command legitimately fails sometimes, don't blow up" and matches this repo's conventions | n/a (answered operator question) |
| 5 | non-TTY `build_image` branch had the same silent-abort class | fixed in scope (see Completed #4) |
| 6 | Test harness (`tests/test_*.sh` + `test_common.sh`) runs under `set -uo pipefail` **without** `-e`, so trace tests never exercise scripts under the production `set -euo pipefail` runtime — this is how the silent-abort bug slipped through | deferred; escalated to roadmap as "test harness must run under `set -e`" |
| 7 | Pre-existing shellcheck findings in `build.sh` on untouched lines (`SC2046` unquoted `$(_sandbox_sig_sources)`/`$(_agent_sig_sources)`; `SC2034 sandbox_dir` unused in `preflight`) | deferred; escalated to roadmap as a cleanup task |
| 8 | `container_sig` has no guard for a `find` error: `find ... 2>/dev/null` under `pipefail`/`set -e` would abort if a configured source path were invalid (works today — all paths valid, but unguarded) | deferred; escalated to roadmap as a defensive `\|\| true` task |
| 9 | TTY failure emits two failure-ish lines (`... FAILED (Ns)` + `build_image: ERROR build FAILED ...`) vs non-TTY's single line — message-cosmetic asymmetry | fixed in scope: `_buildkit_run` no longer prints its own `FAILED` terminal line; both modes now emit exactly one conclusive `build_image: ERROR build FAILED ... (exit N).` line, with mode-appropriate diagnostics (TTY dump / non-TTY raw stderr) |
| 10 | `build_image._build_rc` initialized to `0` then conditionally overwritten would mask a failure if `_buildkit_run` were ever removed or short-circuited | fixed in scope: `_build_rc` is now a fail-closed sentinel (`1`) with `&& _build_rc=0 \|\| _build_rc=$?` capture |
| 11 | Google Shell Style Guide is authoritative but silent on the `set -e`/`pipefail` failure-tolerant idioms; shellcheck is installed/run and does not flag that class | doc change: `bash-coding-conventions.md` intro now declares the style guide + shellcheck (see Completed #7) |
| 12 | Two subsequent items (#9, #10) were brought into this session's scope by the operator after the initial fix | resolved in this session |

## Deferred (escalated to roadmap tasks)

- **Escalated this session** (see roadmap M2.6 General CLI/infra track):
  - test harness must run scripts under `set -e` (finding #6)
  - shellcheck findings cleanup in `build.sh` (`SC2046`/`SC2034`, finding #7)
  - `container_sig` defensive `|| true` guard (finding #8)
- Roadmap M2.6 track pre-existing open items (`.compose/*.yml` pruning, `compose_sandbox_wait` teardown gap, session-naming collision, `STALE=1` prune mode) — unrelated to this fix, already tracked.

## Not in scope

Any other M2.6 infra-track items; M2.6.6 mount model; the roadmap "Finding — handover close-order" policy item.

## Carried forward

None — bugfix complete and verified this session.
