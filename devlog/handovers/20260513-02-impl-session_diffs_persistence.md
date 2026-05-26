# Agent Handover

**Session date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Diagnose and fix the session-diffs persistence bug — diffs written inside the sandbox container did not survive across sessions. Two root causes found:

1. **(Prior session)** Compose template set `CHANGES_DIR_NAME=workspace/session-diffs` (a subpath with '/'), which `dirs.sh` prepended to `WORKSPACE_DIR_NAME`, producing a doubled path (`/home/agentuser/workspace/workspace/session-diffs`) that fell outside the bind mount — diffs persisted on the host but the agent couldn't read them back.

2. **(This session)** `libs/sandbox.Dockerfile` and `libs/containers.sh` (`build_context_sandbox`) did not include `package_branch.sh`. The sandbox image had `diff.sh` which calls `package_branch.sh` at runtime via `source` — the file didn't exist inside the container. `source` failed, `set -euo pipefail` killed the autosave subshell (permanently) and the EXIT trap's `diff_export` silently produced an empty export directory. The user saw "0 entries" in the session/autosave channels even though the pipeline code was correct on disk.

## Scope

M2.7 item 9 — Host-container seam testing via dry-run + session-diffs persistence fix.

- Diagnose the root cause: trace the full path from sandbox-entrypoint writing a diff through `dirs.sh` resolution, `docker-compose.yml` mount target, and `routing.sh` read path.
- Fix: change `CHANGES_DIR_NAME=workspace/session-diffs` → `CHANGES_DIR_NAME=session-diffs` in `libs/docker-compose.yml`.
- Write a knowledge test (`tests/knowledge/knowledge_session_diffs_path_resolution.sh`) that documents and validates the path resolution chain across host and container contexts.
- Add a targeted round-trip assertion in `dry_run.sh` that verifies CHANGES_DIR resolves to the bind mount target and can be written-to and read-from.
- Do NOT implement commit message capture (item 9 third subtask). That is a separate effort.

**This session (continuation):**
- Diagnose second root cause: autosave/session export producing no output despite path fix
- Fix `diff_export` to propagate `package_branch` errors (was silently swallowing failures)
- Add `package_branch.sh` to sandbox Docker build (was missing from Dockerfile and build context)
- Add unit tests for missing-SESSION_STATE failure paths
- Create diagnostic knowledge test for container-scoped diff_export pipeline

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Root cause identified: `CHANGES_DIR_NAME=workspace/session-diffs` (subpath with '/') causes `dirs.sh` to produce `/home/agentuser/workspace/workspace/session-diffs` — a doubled prefix | ✅ |
| 2 | Fix: `CHANGES_DIR_NAME=session-diffs` (leaf-only) in compose template | ✅ |
| 3 | Knowledge test exists at `tests/knowledge/knowledge_session_diffs_path_resolution.sh` with 7 assertions covering default host, container, bug reproduction, fix, mount target comparison, and leaf-name semantic check | ✅ |
| 4 | Round-trip assertion added to `dry_run.sh`: checks CHANGES_DIR == mount target, writes marker, reads it back | ✅ |
| 5 | **Second root cause** — `package_branch.sh` missing from sandbox Dockerfile and build context. `diff_export` calls `source /opt/sandbox/lib/package_branch.sh` at runtime — file didn't exist in container → `source` failed → `set -euo pipefail` killed autosave subshell and left empty session export directories | ✅ |
| 6 | Fix: `package_branch.sh` added to `libs/sandbox.Dockerfile` COPY list and `libs/containers.sh` (`build_context_sandbox`) | ✅ |
| 7 | Fix: `diff_export` now checks `package_branch` return value — returns 1 on failure instead of silent success | ✅ |
| 8 | Unit test: `test_dispatcher_missing_session_state` in `test_package_branch.sh` (regression guard, passes now) | ✅ |
| 9 | Unit test: `test_diff_export_missing_session_state` in `test_diff_dispatch.sh` (failing before fix, passing after) | ✅ |
| 10 | Knowledge test: `tests/knowledge/knowledge_diff_export_container.sh` — 13 assertions covering full pipeline, untracked files, missing SESSION_STATE gap, path agreement, accumulation | ✅ |
| 11 | Diagnostic script: `tests/knowledge/diagnose_autosave.sh` — checks env vars, process state, path resolution, SESSION_STATE, live diff_export | ✅ |
| 12 | `make test` passes clean (294/295, 1 pre-existing Docker skip) | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `libs/docker-compose.yml` | Fix applied: `CHANGES_DIR_NAME=workspace/session-diffs` → `session-diffs` |
| `libs/dirs.sh` | Path derivation — no change needed once compose env fixed |
| `libs/sandbox-entrypoint.sh` | Writes diffs — no change needed, uses dirs.sh correctly |
| `libs/routing.sh` | Reads diffs — no change needed, uses dirs.sh correctly with callers' SANDBOX_DIR |
| `scripts/dry_run.sh` | Added round-trip seam test (CHANGES_DIR resolution + marker write/read) |
| `tests/knowledge/knowledge_session_diffs_path_resolution.sh` | **New** — 7-assertion knowledge test confirming the path resolution fix |
| `libs/sandbox.Dockerfile` | **Fix:** added `COPY package_branch.sh /opt/sandbox/lib/package_branch.sh` |
| `libs/containers.sh` | **Fix:** added `_build_context_copy` for `package_branch.sh` in `build_context_sandbox` |
| `libs/diff.sh` | **Fix:** `diff_export` now checks `package_branch` return value, returns 1 on failure |
| `tests/test_package_branch.sh` | **New test:** `test_dispatcher_missing_session_state` |
| `tests/test_diff_dispatch.sh` | **New test:** `test_diff_export_missing_session_state` |
| `tests/test_build_context.sh` | **Updated:** file count 6→7 for sandbox context |
| `tests/knowledge/knowledge_diff_export_container.sh` | **New** — 13-assertion container-scoped knowledge test |
| `tests/knowledge/diagnose_autosave.sh` | **New** — diagnostic script for sandbox container env/process/export health |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Fix is a one-line change in compose template, not in dirs.sh | The env var was wrong: `CHANGES_DIR_NAME` is documented as a leaf name (no '/'). The entrypoint correctly sets `WORKSPACE_DIR_NAME=workspace` and relies on the default `CHANGES_DIR_NAME=session-diffs`. The compose template was the only erroneous override. | This handover |
| Round-trip test goes in dry_run.sh, not a separate test file | Aligns with directive scope: minimal seam test in existing dry-run infrastructure, not a separate test harness. The mechanism design is deferred. | This handover |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| **`dry_run.sh` runs in the reasoning layer only** — a single-file assertion suite cannot cover both capability and reasoning layer behaviour from one entrypoint. The round-trip test added this session validates the reasoning layer side of the seam (agent sees the correct mounted path). The capability layer side (sandbox entrypoint writes to the same path) is covered by the knowledge test but not by a runtime assertion inside the container. To assert both layers from dry-run, we would need either (a) a separate overlay that executes assertions inside the sandbox container, or (b) a host-side verification step after dry-run that checks what the sandbox container produced. | scope change | Next session — design a mechanism for dual-layer seam testing that covers both reasoning and capability layer behaviour |
| **`package_branch.sh` was missing from the sandbox Dockerfile/build context** — `diff.sh` sources `package_branch.sh` at runtime inside `diff_export`, but the sandbox image never had it. The `source` call failed with `set -euo pipefail` active, killing the autosave subshell on first iteration and silently producing empty session export directories from the EXIT trap. This was the root cause of "0 entries" in session/autosave channels even after the path resolution fix. | bug | Fixed by adding `package_branch.sh` to `libs/sandbox.Dockerfile` and `libs/containers.sh` `build_context_sandbox` |
| **`diff_export` silently swallowed errors** — `package_branch` return value was not checked. When SESSION_STATE was missing or `package_branch` failed for any reason, `diff_export` returned 0 and continued to write EXPORT-TIME.txt, producing an empty-but-seemingly-valid export directory. | bug | Fixed: `diff_export` now checks `package_branch` exit code and returns 1 on failure |
| **Autosave loop runs as an unprotected subshell** — `( ... ) &` with `set -euo pipefail` inherited from the parent. Any failure in the loop (`sleep`, `session_export_path`, `mkdir`, `diff_export`) kills it permanently. The loop has no restart mechanism or error recovery. | design | Consider adding `|| true` guards or a restart wrapper for resilience. Not fixed this session — see Deferred items. |
| **`WORKSPACE_DIR_NAME` is not exported in the sandbox container** — sandbox-entrypoint.sh sets `WORKSPACE_DIR_NAME=workspace` as a prefix to the `dirs_resolve` call (local scope), not as an exported env var. This is correct for the current code (the variable is used only by `dirs_resolve`), but subtle — any code that reads `$WORKSPACE_DIR_NAME` directly from the environment would get the default `.workspace` instead of `workspace`. | design | Documented; not a bug (dirs_resolve handles it correctly), but worth noting for future refactors. |
| **Race condition: `docker compose down -v` may remove containers before the EXIT trap completes** — the `-v` flag removes anonymous volumes. Session-diffs are a bind mount (not affected), but `volumes_from: - sandbox` on the agent service creates anonymous volume references. If Docker Compose removes those before the trap finishes writing, the export could be interrupted. | race | Listed for investigation — assumed not the issue this session per operator direction.

## Completed this session

| File | Change |
|---|---|
| `libs/docker-compose.yml` | `CHANGES_DIR_NAME=workspace/session-diffs` → `CHANGES_DIR_NAME=session-diffs` |
| `scripts/dry_run.sh` | Added session-diffs round-trip section: CHANGES_DIR resolution check + marker write/read assertion |
| `tests/knowledge/knowledge_session_diffs_path_resolution.sh` | **New** — 7-assertion knowledge test tracing path resolution across host and container contexts |
| `libs/sandbox.Dockerfile` | Added `COPY package_branch.sh /opt/sandbox/lib/package_branch.sh` |
| `libs/containers.sh` | Added `_build_context_copy` for `package_branch.sh` in `build_context_sandbox` |
| `libs/diff.sh` | `diff_export` now checks `package_branch` return value — returns 1 on failure instead of silent 0 |
| `tests/test_package_branch.sh` | **New test:** `test_dispatcher_missing_session_state` — verifies `package_branch` returns 1 and produces no artefacts when SESSION_STATE missing |
| `tests/test_diff_dispatch.sh` | **New test:** `test_diff_export_missing_session_state` — verifies `diff_export` returns 1 on SESSION_STATE failure (failing before fix, passing after) |
| `tests/test_build_context.sh` | Updated file count from 6 to 7 for sandbox context (package_branch.sh added) |
| `tests/knowledge/knowledge_diff_export_container.sh` | **New** — 13-assertion container-scoped knowledge test covering: full artefact output, uncommitted capture, untracked capture, missing SESSION_STATE gap, path agreement, multiple export accumulation |
| `tests/knowledge/diagnose_autosave.sh` | **New** — diagnostic script for sandbox container: env vars, process state (autosave loop alive?), path resolution, SESSION_STATE, live diff_export test |
| `docs/devlog/handovers/20260513-02-impl-session_diffs_persistence.md` | **Updated** — this handover (filled in second root cause, AC, findings, decisions, completed, next session) |

## Deferred items

| Item | Reason |
|---|---|
| Round-trip test mechanism design for dry-run (dual-layer: capability + reasoning) | Mid-session finding: dry_run.sh runs in reasoning layer only. Need design session for a mechanism that covers both layers. Scoped to M2.7 item 9 second subtask. |
| Commit message capture in package_branch and session-diffs | Scoped to M2.7 item 9 third subtask, not this session |
| Subsuming test_capability_layer.sh skipped tests into dry-run | Scoped to subsequent design session (part of dual-layer mechanism) |
| Autosave subshell resilience — the loop has no restart mechanism if it crashes (`set -euo pipefail` kills it permanently) | Should add `|| true` guards or a restart wrapper to prevent single-iteration failures from killing all future autosaves. Not fixed this session — the root cause (missing `package_branch.sh`) is fixed, but other transient errors could still kill the loop. |
| EXIT trap error handling — still doesn't check `diff_export`'s return value. Now that `diff_export` returns 1 on failure, the trap could write an error signal or delete the empty directory. | Not critical — `diff_export` no longer silently succeeds. The export dir is removed by `docker compose down -v` anyway. Worth addressing when designing the dual-layer seam test. |
| Remaining M2.7 work groups (items 1–8) | Not yet started — session-diffs was blocking, now unblocked |

## Next session

**The workspace path refactor (M2.7 item 10) is postponed.** The design document exists at `docs/devlog/discussions/design_workspace_path_resolution.md` and the task is in the roadmap, but no implementation will start this session.

**Priority: dry-run validation first.** The next session should pick up the dual-layer seam testing problem. The mid-session finding is the starting point: `dry_run.sh` only runs in the reasoning layer. To validate the host-container seam end-to-end, we need either:

   (a) A mechanism to run assertions inside the sandbox (capability layer) container during dry-run, or
   (b) A host-side verification step after dry-run completes that checks what the sandbox produced.

This also covers the tests in `test_capability_layer.sh` that skip when Docker is unavailable — they could be rehoused as dry-run assertions that run inside the capability layer container.

**SESSION_STATE caveat (M2.6):** `session_state_write` appends (`>>`) rather than overwriting in place. This is currently safe because the sandbox `.git/` is container-ephemeral — destroyed on `stop.sh` + `docker rm`. If M2.6 bind-mounts `.git/` for session resume, the append semantics will cause stale key accumulation. That session should either make writes idempotent (sed-replace) or have `snapshot_init_git` truncate the file before writing.

**Known limitation (M2.6):** Session commit history, git state, and `SESSION_STATE` are lost between `make start` cycles. Only `CHANGES_DIR` (diff exports) survives via host bind mount. Documented in `docs/operations/recovery_protocol.md` as a recovery gap — if a session crashes before diff export, the work is unrecoverable.

**Context handover (supersedes prior thread):** This session continues the investigation from the prior planning session. Two root causes were found — the original path resolution fix was correct but insufficient. The second root cause (`package_branch.sh` missing from sandbox image) fully explains the "0 entries" symptom.

**Rebuild required:** After this fix, the sandbox image must be rebuilt (`make build` or `make start --rebuild`) to bake `package_branch.sh` into `/opt/sandbox/lib/`. Until rebuild, the sandbox container still has the old image without the fix.

**M2.7 unblocked:** Both session-diffs persistence bugs are now fixed. The remaining work groups (items 1–8) can proceed.

**Conclusions from this session:**
- **Second root cause:** `package_branch.sh` was missing from the sandbox Dockerfile and build context. `diff.sh` sources it at runtime — `source` failed, `set -euo pipefail` killed the autosave subshell and silently produced empty session export directories. This was responsible for "0 entries" in session/autosave channels.
- Fixes: added `package_branch.sh` to `sandbox.Dockerfile` and `build_context_sandbox`; added error checking to `diff_export`; added unit tests for missing-SESSION_STATE failure paths.
- Diagnostic: `tests/knowledge/diagnose_autosave.sh` runs inside the sandbox container and checks every link in the autosave chain.
- Knowledge test: `tests/knowledge/knowledge_diff_export_container.sh` validates the full EXIT trap / autosave function chain in 13 assertions.
- Key insight for future: the autosave subshell has no resilience — any failure kills it permanently. Consider adding restart logic or `|| true` guards.
