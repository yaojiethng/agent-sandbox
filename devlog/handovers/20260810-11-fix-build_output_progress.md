# Agent Handover

**Date:** 2026-08-10
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Implementation (commit type: fix)
**Status:** Closed

## Objective
Fix the verbose `docker build` output: `build_image` in `scripts/build.sh` uses
`--progress=plain` (lines 86, 93), which forces a full per-step log even on
interactive TTYs. Switch to `--progress=auto` so builds on a TTY show a single
self-overwriting progress line, with plain output retained as the fallback for
non-TTY contexts (pipes, CI, captured logs).

Split out of session `20260810-10` (operator-directed: network fix first,
build-output fix second).

## Root cause (established)
`build_image` passes `--progress=plain` to `docker build` unconditionally.
BuildKit's `plain` mode disables TTY progress rendering and prints every step's
log lines verbatim — noisy on interactive builds where `auto` (the default)
would render a compact self-overwriting progress line. `auto` is BuildKit's
default: TTY-aware progress when stdout is a terminal, plain fallback otherwise.

## Scope (operator-confirmed)
**Fix:**
1. `scripts/build.sh` — `build_image`: replace `--progress=plain` with
   `--progress=auto` in both branches (with-sig at line 86, without-sig at
   line 93).

**Tests:**
2. `tests/test_trace_build.sh` — add a regression assertion that the build
   invocation does not use `--progress=plain` (the docker stub records the
   full flag string via `log "build $*"`). Existing assertions only check that
   `docker build` is issued; the flag change is invisible to them.

**Docs:**
3. Verify no documentation references `--progress=plain` (grep shows none in
   `docs/`); no doc change expected.

## Mid-session findings (to record)
| # | Finding | Disposition |
|---|---|---|
| 1 | `build_image` expands the optional cache flag as an unquoted string (`docker build $no_cache --progress=auto`), same string-as-optional-flag pattern as the stop.sh SC2086 finding. Intentional (empty → no flag) but shellcheck-flagged; an array (`cache_args=()`, append `--no-cache` conditionally) removes it. | deferred; can land with the stop.sh array refactor |

## Decisions
| # | Decision | Rationale |
|---|---|---|
| 1 | Fix only `--progress`; leave `$no_cache` unquoted expansion for a future session | Scope confirmed without the `$no_cache` change; same class as stop.sh SC2086 finding, best landed together |

## Completed this session
| # | Item | Notes |
|---|---|---|
| 1 | `scripts/build.sh` — `--progress=plain` → `--progress=auto` in both `build_image` branches | TTY-aware single-line progress, plain fallback for non-TTY |
| 2 | `tests/test_trace_build.sh` — regression test `test_build_uses_concise_progress` asserting `progress=plain` absent from trace | Verified: fails when `plain` is restored, passes with `auto`; docker stub logs the full flag string |
| 3 | Full suite green | 459 tests, 453 passed, 0 failed, 6 skipped |

## Not in scope
run_agent unified teardown refactor; compose-file persistence; docker-verb
semantics decision; `stop.sh` string-as-list → array refactor (SC2086);
provider default; M2.6 mount work. All tracked in roadmap M2.6 general track
and the `20260810-10` carried-forward table.

## Carried forward
| Item | From |
|---|---|
| `build_image` `$no_cache` unquoted expansion → array (with the stop.sh SC2086 array refactor) | mid-session finding 1 |

---

## Session open — status
- [ ] Handover created (this file)
- [ ] Scope confirmed by operator
- [ ] Fix implemented
- [ ] Tests updated + full suite green
- [ ] Handover updated (findings, decisions, completed)
- [ ] Roadmap checkboxes updated
- [ ] Operator released pre-close gate
- [ ] Status → Closed; committed
