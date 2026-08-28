# Agent Handover

**Session date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Add critical-invariant pre-flight checks to `libs/sandbox-entrypoint.sh` that run on every container start — before the `wait` loop — asserting that mounts, SESSION_STATE, and workspace channels are functional.

## Scope

M2.7 item 11b — Pre-flight script.

- Inline a pre-flight check block in `sandbox-entrypoint.sh`, after `snapshot_init_git` completes and before the diff pipeline.
- CRITICAL checks: SESSION_STATE keys (init_sha, session_ts), SNAPSHOT_DIR readable, CHANGES_DIR writable, INPUT_DIR readable, OUTPUT_DIR writable.
- WARN checks: brief.md present in INPUT_DIR, working tree clean.
- CRITICAL failures exit non-zero (container healthcheck fails). WARN failures log but do not exit.
- Do NOT touch the dry-run capability or reasoning scripts.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Pre-flight block exists in `sandbox-entrypoint.sh` after baseline init, before diff pipeline | ✅ |
| 2 | 5 CRITICAL checks (SESSION_STATE keys ×2, SNAPSHOT_DIR, CHANGES_DIR, INPUT_DIR, OUTPUT_DIR) | ✅ |
| 3 | 2 WARN checks (brief.md, working tree clean) | ✅ |
| 4 | CRITICAL failures exit 1 (non-zero) | ✅ |
| 5 | `bash -n` passes | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `libs/sandbox-entrypoint.sh` | Pre-flight checks injected inline |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Inline pre-flight in entrypoint rather than separate file | Tightly coupled — same env vars, same gate logic. Separate file would duplicate source/include boilerplate. | Design doc Pre-flight vs dry-run |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `libs/sandbox-entrypoint.sh` | Added pre-flight block (5 CRITICAL + 2 WARN checks) after baseline init, before diff pipeline |
| `docs/devlog/roadmap.md` | Marked 11b as ✅ |
| `docs/devlog/handovers/20260513-04-impl-preflight_checks.md` | **New** — this handover |

## Deferred items

None.

## Next session

**11c. dry_run_capability.sh.** Create the capability layer investigation script and add its bind mount to the dry-run compose overlay.

---
[CORRECTION — 2026-05-21]: Five issues corrected across the pre-flight check implementation and related files.

1. **Wrong container:** CRITICAL checks for INPUT_DIR and OUTPUT_DIR in
   sandbox-entrypoint.sh asserted mounts that only exist in the agent container.
   Removed; brief.md WARN check kept (non-fatal).

2. **Silent failures:** `"$@" 2>/dev/null` suppressed underlying error messages.
   Fixed to capture stderr and append to FAIL/WARN output.

3. **set -e regression:** `_err=$(cmd 2>&1 >/dev/null)` propagated non-zero exit through command substitution, killing the shell under `set -e`. Fixed by using
   `if _err=$(cmd 2>&1 >/dev/null); then` so errexit is suppressed by the `if` clause.

4. **local outside function in dry_run.sh:** `local _marker=...` at top-level scope.
   Bash rejects `local` outside a function. Removed `local`.

5. **Compound env vars in docker-compose.yml:** Agent service set
   `INPUT_DIR_NAME=workspace/input` and `OUTPUT_DIR_NAME=workspace/output` (old
   compound format). Combined with `dirs_resolve` prefixing this produced
   double-workspace paths. Fixed to leaf names (`input`, `output`).

Files changed:
  libs/sandbox-entrypoint.sh — removed 2 CRITICAL INPUT_DIR/OUTPUT_DIR checks;
    fixed _preflight_crit/_preflight_warn stderr capture and set -e regression
  libs/dirs.sh — updated container docstring example with agent-container-only note
  libs/docker-compose.yml — fixed agent env vars to leaf names
  scripts/dry_run.sh — fixed local outside function
  scripts/start_agent.sh — added dry-run mode guard (stop-previous-session skipped)
  tests/knowledge/diagnose_preflight.sh — new diagnostic test
  docs/devlog/changelog.md — added CORRECTION entry
  docs/devlog/handovers/20260513-06-impl-dry_run_rewrite.md — see that handover's
    CORRECTION block for the dry_run.sh context
