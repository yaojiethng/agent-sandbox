# Agent Handover

**Session date:** 2026-06-11
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Complete Proposal 3 — add generic pre-flight validation to the shared entrypoint. Cover missing lib file checks and agent command presence validation.

## Scope

1. **Add missing lib file checks** to shared entrypoint — `diff.sh`, `diff_export.sh`, `package_branch.sh` are in `/opt/sandbox/lib/` but not checked. Add as WARN-level (consistent with existing pattern).
2. **Add agent command validation** — before `exec "$@"`, validate that the command (first argument) exists and is executable. If missing, print a FATAL error with the image name hint.
3. **Update roadmap** — mark the task complete.

**Out of scope:**
- Provider-specific bind mount checks (already in pi/preflight.sh)
- AGENT_HOME writable check (already done)
- Lib CRITICAL severity changes (session_state.sh is the only CRITICAL)

## Hot files

| File | Reason |
|---|---|
| `src/reasoning/entrypoint.sh` | Add missing lib checks + agent command validation |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | All 7 active lib files are in the preflight check list | grep for `diff.sh`, `diff_export.sh`, `package_branch.sh` in entrypoint.sh's preflight loop | |
| 2 | Agent command is validated before exec | grep for `FATAL.*not found\|executable.*missing` in the exec section | |
| 3 | `entrypoint.sh` passes `bash -n` | `bash -n src/reasoning/entrypoint.sh` exits 0 | |
| 4 | Tests still green | `bash tests/test_build_context.sh` exits 0 | |
| 5 | Roadmap marked complete | `grep "generic pre-flight" devlog/roadmap.md` shows `[x]` | |
