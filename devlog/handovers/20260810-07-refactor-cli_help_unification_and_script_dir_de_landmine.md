# Agent Handover

**Session date:** 2026-08-10
**Milestone:** M2.6 — Session Persistence (general CLI refactor track; deferred from handover `20260810-04`)
**Session type:** Implementation (commit type: refactor)
**Status:** Closed

## Objective
Session 1 of a 3-session refactor split (per operator). This session handles
**Finding B only** — removing the `SCRIPT_DIR` assigned side-effect (and
potential clobber) from `src/libs/common.sh` at the root cause, giving `stop.sh`
and `prune.sh` a consistent self-resolution, and dropping the now-obsolete
comment in `start_agent.sh`.

**Context — the ambiguity the operator surfaced:** `SCRIPT_DIR` carries two
different semantic intents under one name:
- `stop.sh` / `prune.sh` get it *injected* by `common.sh` from `BASH_SOURCE[1]`
  (the script that sourced common.sh) — a caller-derived, shared-lib side effect.
- Every other top-level script (`start_agent.sh`, `run_agent.sh`, `onboard.sh`,
  `run_tests.sh`, `check_test_coverage.sh`) *self-derives* it from
  `BASH_SOURCE[0]`.

Separation of sessions (operator-designated):
1. **This session — Finding B:** remove the `common.sh` `SCRIPT_DIR` side effect;
   `stop.sh`/`prune.sh` self-resolve consistently; drop stale comment in
   `start_agent.sh`. (No rename.)
2. **Next session — rename:** repo-wide cleanup of the variable to a descriptive
   STE100 name, done only AFTER the injection mechanism is removed (renaming the
   ambiguity first would be pointless). Includes a `tests/` sweep.
3. **Later session — Finding A/C:** extract `route_help()` in the dispatcher,
   fix `--help` for all subcommands, and the corresponding `test_dispatch.sh`
   updates.

## Scope
**Confirmed with operator (Finding B only):**
1. `src/libs/common.sh` — remove the `SCRIPT_DIR` assigned side effect (the
   `_common_self`/`SCRIPT_DIR="$_common_self"` block) AND update the header
   docstring so it no longer claims to set `SCRIPT_DIR` — only `PROJECT_NAME`,
   `SANDBOX_DIR`, and the three flag functions. It becomes a pure flag-parsing
   library with no caller-state mutation.
2. `scripts/stop.sh` — self-resolve `SCRIPT_DIR` via the canonical
   `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` (it invokes
   `$SCRIPT_DIR/prune.sh`); update the now-inaccurate comment that says common.sh
   sets it.
3. `scripts/prune.sh` — same self-resolve for consistency/predictability despite
   not currently using `SCRIPT_DIR`; update the comment.
4. `scripts/start_agent.sh` — drop the now-obsolete comment (the "common.sh sets
   SCRIPT_DIR from BASH_SOURCE[1]... matching the value above" rationale);
   derivation itself is unchanged (already self-resolves).

**Why no `/tests/` change:** `common.sh`'s `SCRIPT_DIR` assignment is consumed
only in `test_common_lib.sh`, and only as an overwrite of `test_common.sh`'s
`SCRIPT_DIR` that is currently benign — removing it makes that test more
correct, not less.

**Not in scope (later sessions):** the variable rename (Session 2); `route_help`
dispatch unification (Session 3); provider default; prune-stale semantics; M2.6
mount work.

## Acceptance criteria
| # | Criterion | Status | Verifiable by |
|---|---|---|---|
| 1 | `common.sh` no longer sets `SCRIPT_DIR` (pure flag library); docstring reflects this | done | grep `SCRIPT_DIR` in `src/libs/common.sh` → only the docstring reference |
| 2 | `stop.sh` / `prune.sh` self-resolve `SCRIPT_DIR` via `BASH_SOURCE[0]` and still source `common.sh` for the flag functions | done | read files; suite green |
| 3 | `start_agent.sh` own `SCRIPT_DIR` (line 33) is no longer clobbered by `common.sh`; obsolete comment dropped | done | read file; suite green |
| 4 | `test_common_lib.sh` still passes (12 tests) — the clobber removal did not break the common.sh unit tests | done | run `tests/test_common_lib.sh` |
| 5 | Full suite green (28 files, no failures) | done | `bash scripts/run_tests.sh` |

## Carried forward
| Item | From |
|---|---|
| Root-cause fix for Mid-session Finding B | handover `20260810-04`, Deferred item 2 |
| (next session) descriptive STE100 rename of the script-dir variable | this session's split |
| (later session) root-cause fix for Finding A/C (`route_help`) | handover `20260810-04`, Deferred item 1 |

## Decisions made this session
| # | Decision | Notes |
|---|---|---|
| 1 | Remove the `SCRIPT_DIR` injection *mechanism* rather than rename it | Renaming an injected variable under another name would preserve the ambiguity; removing it makes the mechanism consistent first |
| 2 | Session split into 3 (Finding B → rename → Finding A/C) per operator | Each is an independent handover/commit; session 2 depends on session 1 only in that the rename must follow the injection removal |

## Mid-session findings
Recorded in the handover; operator routed **all 3** to `devlog/AGENT_FEEDBACK.md` at close (session 20260810-07 section).

| Class (proposed) | Finding | Notes |
|---|---|---|
| B — stack design, to operator | `SCRIPT_DIR` is ambiguous about WHICH scripts copy is meant (host repo vs snapshot vs sandbox), not just its derivation mechanism (self vs injected). My earlier Finding B under-diagnosed this; the operator surfaced the "which scripts dir?" scope. | Feeds Session 2's descriptive rename: the new name must disambiguate *which* scripts tree, per STE100. Recorded here so the rename session starts from the full problem |
| A — agent friction | A `cp ... 2>/dev/null \|\| true` command during verification created a stray `tests/tests_common_verify.sh` (not a real test), which I caught and removed. Cause: running an exploratory verify harness inside the repo rather than in `/tmp`. | Mitigation: run throwaway verification scripts in `/tmp`, never in the repo tree; the repo is git-tracked so stray files surface in `git status` (they did — saved here) |
| A — agent friction | The `edit` tool rejected a call for a missing required `path` argument (omitted on first edit of `common.sh`). Tool-usage error, self-corrected. | Mitigation: always pass `path` explicitly on edit calls |

## Completed this session
| File | Change |
|---|---|
| [src/libs/common.sh](../../src/libs/common.sh) | Removed the `SCRIPT_DIR` assigned side effect (`_common_self`/`SCRIPT_DIR="$_common_self"`); docstring now states it is a pure flag-parsing library that sets only `PROJECT_NAME`/`SANDBOX_DIR` and never touches caller path variables |
| [scripts/stop.sh](../../scripts/stop.sh) | Self-resolves `SCRIPT_DIR` via the canonical `BASH_SOURCE[0]` pattern before sourcing `common.sh`; comment updated (no longer claims common.sh sets it) |
| [scripts/prune.sh](../../scripts/prune.sh) | Same self-resolution + comment update; `_common_dir` now derived from `SCRIPT_DIR` |
| [scripts/start_agent.sh](../../scripts/start_agent.sh) | Dropped the now-obsolete comment about common.sh setting SCRIPT_DIR; derivation unchanged (already self-resolves) |
| [devlog/roadmap.md](../../devlog/roadmap.md) | Added the M2.6 General CLI/infra refactor track (3 sub-tasks: Finding B, rename, Finding A/C) |
| [devlog/handovers/20260810-07...](../../devlog/handovers/20260810-07-refactor-cli_help_unification_and_script_dir_de_landmine.md) | This handover |
