# Agent Handover

**Date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Fix
**Status:** Closed

## Objective
Debug and fix the leftover multi-line build progress issue. Session `20260810-11`
changed `--progress=plain` → `--progress=auto` under the assumption that `auto`
produces "a single self-overwriting progress line." The operator reports this
did not resolve the issue — multi-line build progress persists, with "vertical
bloat being in blue, mainly."

## Root cause (established)

Session `20260810-11` changed `--progress=plain` → `--progress=auto` under the
assumption that `auto` produces "a single self-overwriting progress line." This
assumption was incorrect: Docker BuildKit's `auto` mode on a TTY delegates to
`tty` mode, which renders a **multi-line** self-overwriting display — each
concurrent build step gets its own line with blue-colored status indicators
(arrows, step labels). This is the "blue vertical bloat" the operator sees.

The three-tier `build_agent` pipeline calls `build_image` three times, producing
3× multi-line progress blocks. `--progress=quiet` was considered but rejected
because it hides all progress — the operator needs a live-updating line to
detect stalls.

## Fix approach (operator-confirmed, revised mid-session)

**v1 (rejected):** TTY detection + background build + blind spinner.
Rejected by operator: a spinner that animates regardless of underlying activity
creates a false sense of progress — if the build stalls, the spinner keeps
spinning and the operator can't tell.

**v2 (implemented):** TTY detection + background build + BuildKit step parsing.
- `_run_with_progress` runs `docker build --progress=plain` in the background,
  captures output to a temp file, and polls the log for the most recent
  BuildKit step header (`#N [stage] STEP args...`).
- The single progress line shows **real BuildKit progress**: the current step's
  description and elapsed time. If the step text freezes while the timer keeps
  ticking → the operator immediately knows which step is stalled.
- On failure, the full captured output is dumped.
- On non-TTY (CI, pipes), `docker build --progress=plain` streams normally.

**Architecture:**
```
build_image (scripts/build.sh)
  ├─ if TTY → _run_with_progress (src/libs/spinner.sh)
  │    ├─ _buildkit_current_step   parse step from log
  │    ├─ docker build ... &       background, output → temp file
  │    └─ polling loop             show current step + elapsed time
  └─ if non-TTY → docker build --progress=plain  (streams directly)
```

## Mid-session findings (to record)
| # | Finding | Disposition |
|---|---|---|
| 1 | `--progress=auto` on TTY is not single-line — it's the multi-line `tty` mode with blue step lines | fixed in this session |
| 2 | Thermo-nuclear review (4 findings): sig/no-sig duplication ×4, filename `spinner.sh` misleading, `_run_with_progress` name hides BuildKit coupling, no TTY test coverage | all fixed; collapsed to array dispatch, renamed file+function, added unit test |

## Decisions
| # | Decision | Rationale |
|---|---|---|
| 1 | Extract progress logic to `src/libs/buildkit_progress.sh` as `_buildkit_run` | keeps `build_image` thin; reusable; STE-clear names |
| 2 | Show real BuildKit step text, not a blind spinner | operator needs to distinguish "working" from "stalled"; step text freezing while timer ticks = genuine stall |
| 3 | Use background+pid+tempfile, not pipes | pipes run in subshells — exit codes are unreliable; `wait $pid` gives clean exit code |
| 4 | Collapse sig/no-sig branching to array dispatch (`build_cmd[]`) | 4 branches → 1 command built conditionally; also resolves the deferred `$no_cache` array item from `20260810-11` |

## Completed this session
| # | Item | Notes |
|---|---|---|
| 1 | `src/libs/buildkit_progress.sh` — new utility: `_buildkit_run` + `_buildkit_current_step` | parses BuildKit plain output step headers; shows real current step on a single self-updating line |
| 2 | `scripts/build.sh` — `build_image` collapsed to array dispatch | 4 docker build branches → 1 command array + 2 mode dispatches; ~30 lines → ~15 lines |
| 3 | `tests/test_trace_build.sh` — `test_buildkit_current_step_parses_last_step` added | unit test verifies step extraction from fixture BuildKit output |
| 4 | `tests/test_trace_build.sh` — `test_build_uses_plain_progress` updated | asserts `--progress=plain` present |
| 5 | Full suite green | 470 tests, 464 passed, 0 failed, 6 skipped |
| 6 | Deferred `$no_cache` → array item from `20260810-11` resolved | `cache_args` array eliminated; `--no-cache` injected directly into `build_cmd[]` |

## Not in scope
All other M2.6 infra track items; M2.6.6 mount model.

## Carried forward
_None — the deferred `$no_cache` item from `20260810-11` was resolved by the array-dispatch collapse in this session._

---

## Session open — status
- [x] Handover created (this file)
- [x] Scope confirmed by operator
- [x] Fix implemented
- [x] Tests updated + full suite green
- [x] Handover updated (findings, decisions, completed)
- [ ] Roadmap checkboxes updated
- [x] Operator released pre-close gate
- [x] Status → Closed; committed
