# Agent Handover

**Session date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Diagnose and fix the session-diffs persistence bug — diffs written inside the sandbox container did not survive across sessions because the compose template set `CHANGES_DIR_NAME=workspace/session-diffs` (a subpath with '/'), which `dirs.sh` prepended to `WORKSPACE_DIR_NAME`, producing a doubled path (`/home/agentuser/workspace/workspace/session-diffs`) that fell outside the bind mount. This blocked all apply-workflow and packaging tools.

## Scope

M2.7 item 9 — Host-container seam testing via dry-run (first two subtasks only).

- Diagnose the root cause: trace the full path from sandbox-entrypoint writing a diff through `dirs.sh` resolution, `docker-compose.yml` mount target, and `routing.sh` read path.
- Fix: change `CHANGES_DIR_NAME=workspace/session-diffs` → `CHANGES_DIR_NAME=session-diffs` in `libs/docker-compose.yml`.
- Write a knowledge test (`tests/knowledge/knowledge_session_diffs_path_resolution.sh`) that documents and validates the path resolution chain across host and container contexts.
- Add a targeted round-trip assertion in `dry_run.sh` that verifies CHANGES_DIR resolves to the bind mount target and can be written-to and read-from.
- Do NOT implement commit message capture (item 9 third subtask). That is a separate effort.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Root cause identified: `CHANGES_DIR_NAME=workspace/session-diffs` (subpath with '/') causes `dirs.sh` to produce `/home/agentuser/workspace/workspace/session-diffs` — a doubled prefix | ✅ |
| 2 | Fix: `CHANGES_DIR_NAME=session-diffs` (leaf-only) in compose template | ✅ |
| 3 | Knowledge test exists at `tests/knowledge/knowledge_session_diffs_path_resolution.sh` with 7 assertions covering default host, container, bug reproduction, fix, mount target comparison, and leaf-name semantic check | ✅ |
| 4 | Round-trip assertion added to `dry_run.sh`: checks CHANGES_DIR == mount target, writes marker, reads it back | ✅ |
| 5 | `make test` passes clean | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `libs/docker-compose.yml` | Fix applied: `CHANGES_DIR_NAME=workspace/session-diffs` → `session-diffs` |
| `libs/dirs.sh` | Path derivation — no change needed once compose env fixed |
| `libs/sandbox-entrypoint.sh` | Writes diffs — no change needed, uses dirs.sh correctly |
| `libs/routing.sh` | Reads diffs — no change needed, uses dirs.sh correctly with callers' SANDBOX_DIR |
| `scripts/dry_run.sh` | Added round-trip seam test (CHANGES_DIR resolution + marker write/read) |
| `tests/knowledge/knowledge_session_diffs_path_resolution.sh` | **New** — 7-assertion knowledge test confirming the bug and fix |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Fix is a one-line change in compose template, not in dirs.sh | The env var was wrong: `CHANGES_DIR_NAME` is documented as a leaf name (no '/'). The entrypoint correctly sets `WORKSPACE_DIR_NAME=workspace` and relies on the default `CHANGES_DIR_NAME=session-diffs`. The compose template was the only erroneous override. | This handover |
| Round-trip test goes in dry_run.sh, not a separate test file | Aligns with directive scope: minimal seam test in existing dry-run infrastructure, not a separate test harness. The mechanism design is deferred. | This handover |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| **`dry_run.sh` runs in the reasoning layer only** — a single-file assertion suite cannot cover both capability and reasoning layer behaviour from one entrypoint. The round-trip test added this session validates the reasoning layer side of the seam (agent sees the correct mounted path). The capability layer side (sandbox entrypoint writes to the same path) is covered by the knowledge test but not by a runtime assertion inside the container. To assert both layers from dry-run, we would need either (a) a separate overlay that executes assertions inside the sandbox container, or (b) a host-side verification step after dry-run that checks what the sandbox container produced. | scope change | Next session — design a mechanism for dual-layer seam testing that covers both reasoning and capability layer behaviour |

## Completed this session

| File | Change |
|---|---|
| `libs/docker-compose.yml` | `CHANGES_DIR_NAME=workspace/session-diffs` → `CHANGES_DIR_NAME=session-diffs` |
| `scripts/dry_run.sh` | Added session-diffs round-trip section: CHANGES_DIR resolution check + marker write/read assertion |
| `tests/knowledge/knowledge_session_diffs_path_resolution.sh` | **New** — 7-assertion knowledge test tracing path resolution across host and container contexts |
| `docs/devlog/handovers/20260513-02-impl-session_diffs_persistence.md` | **Updated** — this handover (filled in AC, findings, decisions, completed, next session) |

## Deferred items

| Item | Reason |
|---|---|
| Round-trip test mechanism design for dry-run (dual-layer: capability + reasoning) | Mid-session finding: dry_run.sh runs in reasoning layer only. Need design session for a mechanism that covers both layers. Scoped to M2.7 item 9 second subtask. |
| Commit message capture in package_branch and session-diffs | Scoped to M2.7 item 9 third subtask, not this session |
| Subsuming test_capability_layer.sh skipped tests into dry-run | Scoped to subsequent design session (part of dual-layer mechanism) |
| Remaining M2.7 work groups (items 1–8) | Not yet started — session-diffs was blocking, now unblocked |

## Next session

**The workspace path refactor (M2.7 item 10) is postponed.** The design document exists at `docs/devlog/discussions/design_workspace_path_resolution.md` and the task is in the roadmap, but no implementation will start this session.

**Priority: dry-run validation first.** The next session should pick up the dual-layer seam testing problem. The mid-session finding is the starting point: `dry_run.sh` only runs in the reasoning layer. To validate the host-container seam end-to-end, we need either:

   (a) A mechanism to run assertions inside the sandbox (capability layer) container during dry-run, or
   (b) A host-side verification step after dry-run completes that checks what the sandbox produced.

This also covers the tests in `test_capability_layer.sh` that skip when Docker is unavailable — they could be rehoused as dry-run assertions that run inside the capability layer container.

**SESSION_STATE caveat (M2.6):** `session_state_write` appends (`>>`) rather than overwriting in place. This is currently safe because the sandbox `.git/` is container-ephemeral — destroyed on `stop.sh` + `docker rm`. If M2.6 bind-mounts `.git/` for session resume, the append semantics will cause stale key accumulation. That session should either make writes idempotent (sed-replace) or have `snapshot_init_git` truncate the file before writing.

**Known limitation (M2.6):** Session commit history, git state, and `SESSION_STATE` are lost between `make start` cycles. Only `CHANGES_DIR` (diff exports) survives via host bind mount. Documented in `docs/operations/recovery_protocol.md` as a recovery gap — if a session crashes before diff export, the work is unrecoverable.

**Context handover (supersedes prior thread):** This session supersedes the investigation/design direction from the prior planning session. The bug was diagnosed via knowledge test and fixed directly — no design pass needed for the fix itself. See [`20260513-01-plan-m2_7_activation.md`](20260513-01-plan-m2_7_activation.md) for the original planning context.

**M2.7 unblocked:** The session-diffs persistence fix removes the blocking dependency. The remaining work groups (items 1–8) can proceed in parallel with the dual-layer design session.

**Conclusions from this session:**
- Root cause: `CHANGES_DIR_NAME=workspace/session-diffs` in compose template (subpath with '/') causes `dirs.sh` to produce a doubled path (`/home/agentuser/workspace/workspace/session-diffs`). Diffs were written outside the bind mount and never reached the host.
- Fix: one-line change to leaf-only `CHANGES_DIR_NAME=session-diffs`.
- Knowledge test (7 assertions) documents the full resolution chain and can be re-run to detect future regressions.
- Round-trip assertion in dry_run.sh checks CHANGES_DIR resolution and marker write/read.
- Key architectural insight: `dry_run.sh` is a single-file, single-container (reasoning layer) check. True seam testing requires dual-layer coverage.
