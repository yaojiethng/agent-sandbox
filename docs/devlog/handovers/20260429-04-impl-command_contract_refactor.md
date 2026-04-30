# Agent Handover

**Session date:** 2026-04-29
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Design
**Status:** Closed

## Objective
Finalize the Session A command contract refactor design. Scope was significantly revised and partitioned into three implementation chunks: A.1 (data model), A.2 (CLI contract), A.3 (documentation/recovery), followed by Session B (interactive).

## Scope

**This session produced a detailed spec for A.1 and a high-level contract for A.2 and A.3.** A.2 and A.3 are queued after A.1; their detailed specs will be produced in their respective design sessions.

**A.1 — Data model: output format unification (detailed spec):**
- `snapshot_init_git`: write `session_ts` + `init_sha` to `SESSION_STATE`; drop `INIT_SHA` file
- `sandbox-entrypoint.sh`: drop `BASELINE_SHA` variable
- `libs/diff.sh`: remove `diff_commit_pending`; add `write_uncommitted_diff` and `write_all_changes_diff`
- `libs/diff.sh`: `diff_on_exit` / `diff_on_autosave` call `package_branch` dispatcher; no sweep
- `libs/package_branch.sh`: dispatcher rewrite — orchestrates `package_commits` + `write_uncommitted_diff` + `write_all_changes_diff`
- `libs/package_diff.sh`: rename `changes.diff` → `uncommitted.diff`; extract reusable helpers
- `libs/diff.sh`: `diff_generate` / `diff_format_patch` param rename (`BASELINE_SHA` → `since_sha`)
- Add `session_state_write` to `libs/session.sh`
- `changed-files/` as separate accessibility operation (not part of unified format)
- Test impact assessment for A.1

**A.2 — CLI contract: `--channel` flag and routing (high-level contract, detailed spec deferred):**
- `agent-sandbox.sh`: add `--channel` flag; remove `--session` absolute-path support
- `resolve_session_dir`: remove absolute-path branch; consolidate channel routing
- `draft_run`: take `SOURCE_DIR` directly; apply `patches/*.diff` + optional `uncommitted.diff`
- `apply_run`: take file path directly; always apply `uncommitted.diff`
- `Makefile.template`: add `AUTOSAVE=1` → `--channel=autosave`, `BUNDLE=1` → `--channel=bundles`
- Test impact assessment for A.2

**A.3 — Documentation and recovery (high-level contract, detailed spec deferred):**
- `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md`: update Contract Amendments with final design
- `docs/development/quickstart.md`: add emergency recovery helper snippets
- Final test pass

**Session B — Interactive mode (blocked on A.1+A.2+A.3):**
- `interactive_select_sessions` utility
- `--interactive` wiring in `agent-sandbox.sh`
- Table rendering, default selection, abort handling

**Explicitly deferred:**
- Implementation of A.1, A.2, A.3 — reserved for subsequent implementation sessions
- Session B implementation — blocked on A.1+A.2+A.3
- M2.3 Trigger B — waits for Session B
- `package_diff` cross-write into `session-diffs/` — channel-boundary decision; no concrete use case

## Carried forward

| Item | From handover |
|---|---|
| Interactive confirmation flag (`--interactive` for `make apply` and `make draft`) | 20260429-03-design-command_shape_and_contract.md |

## Acceptance criteria

1. `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` contains a complete "Contract Amendments" section covering all three chunks (A.1, A.2, A.3) and Session B, with dependency relationships marked.
2. The design document lists every file that will change in each chunk, with the nature of change per file.
3. All open questions from prior design sessions are either resolved in the document or explicitly marked as deferred with a destination.
4. `docs/devlog/roadmap.md` accurately reflects the A.1 / A.2 / A.3 / B split, with dependency chains explicit.
5. `docs/development/quickstart.md` contains emergency recovery helper specifications (detailed content may be deferred to A.3).

## Hot files

| File | Why in scope |
|---|---|
| [`docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md`](docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md) | Design document — Contract Amendments section updated |
| [`docs/devlog/roadmap.md`](docs/devlog/roadmap.md) | Task list — partitioned into A.1, A.2, A.3, B |
| [`docs/development/quickstart.md`](docs/development/quickstart.md) | Recovery helpers — specifications added |
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | CLI entry point — A.2 will modify |
| [`libs/diff_workflow.sh`](libs/diff_workflow.sh) | `apply_run` — A.2 will modify signature |
| [`libs/draft_workflow.sh`](libs/draft_workflow.sh) | `draft_run` — A.2 will modify signature |
| [`libs/session.sh`](libs/session.sh) | `resolve_session_dir`; new `session_state_write` — A.1 + A.2 |
| [`libs/diff.sh`](libs/diff.sh) | `diff_on_exit` / `diff_on_autosave`; new helpers — A.1 |
| [`libs/package_diff.sh`](libs/package_diff.sh) | Rename; extract helpers — A.1 |
| [`libs/package_branch.sh`](libs/package_branch.sh) | Dispatcher rewrite — A.1 |
| [`libs/snapshot.sh`](libs/snapshot.sh) | `snapshot_init_git` — A.1 |
| [`libs/sandbox-entrypoint.sh`](libs/sandbox-entrypoint.sh) | Drop `BASELINE_SHA` — A.1 |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | New flags — A.2 |
| [`tests/test_diff.sh`](tests/test_diff.sh) | A.1 test updates |
| [`tests/test_diff_workflow.sh`](tests/test_diff_workflow.sh) | A.2 test updates |
| [`tests/test_draft_workflow.sh`](tests/test_draft_workflow.sh) | A.2 test updates |
| [`tests/test_session.sh`](tests/test_session.sh) | A.2 test updates |
| [`tests/test_snapshot_container.sh`](tests/test_snapshot_container.sh) | A.1 test updates |
| [`tests/test_package_branch.sh`](tests/test_package_branch.sh) | A.1 test updates |
| [`tests/test_package_diff.sh`](tests/test_package_diff.sh) | A.1 test updates |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Partitioned Session A into A.1, A.2, A.3 | Each chunk is reviewable independently; A.2 depends on A.1 output format | handover; roadmap; design doc |
| `apply` always applies `uncommitted.diff` (all channels) | Simpler semantics; channel selects source directory only | design doc — A.2 |
| No sweep commit in `diff_on_exit` | `uncommitted.diff` captures uncommitted changes directly | design doc — A.1 |
| `diff_generate` / `diff_format_patch` keep generic `since_sha` param | Functions remain reusable; callers pass `INIT_SHA` | design doc — A.1 |
| `diff_commit_pending` removed entirely | No longer needed without sweep; no dangling references | design doc — A.1 |
| `BASELINE_SHA` variable dropped from `sandbox-entrypoint.sh` | Same value as `INIT_SHA`; consolidated | design doc — A.1 |
| `SESSION_STATE` written at container init; `INIT_SHA` file dropped | Single source of truth for `session_ts` and `init_sha` | design doc — A.1 |
| `changed-files/` is separate operation, not part of unified format | Decouples file-copying from diff output contract | design doc — A.1 |
| `write_uncommitted_diff` / `write_all_changes_diff` live in `libs/diff.sh` | Co-located with other diff generation helpers | design doc — A.1 |
| Single `--channel` flag replaces `--source`/`--mode` | Simpler CLI surface; matches Makefile flag intent | design doc — A.2 |
| `package_branch` dispatcher orchestrates 3 operations | All packaging callers get unified output automatically | design doc — A.1 |

## Mid-session findings

| Finding | Impact |
|---|---|
| No `SESSION_STATE` write logic exists in codebase | Must add `session_state_write` to `snapshot_init_git` or `sandbox-entrypoint.sh` |
| `INIT_SHA` file is written by `snapshot_init_git` but `SESSION_STATE` is only read | Consolidation requires both write and read migration |
| `diff_commit_pending` only called by `diff_on_exit`; only tested in `test_diff.sh` | Safe to remove entirely |

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/handovers/20260429-04-impl-command_contract_refactor.md` | Created — active handover, partitioned into A.1/A.2/A.3 |
| `docs/devlog/roadmap.md` | Replaced Session A task list with A.1, A.2, A.3, B chunks |
| `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` | Replaced Contract Amendments section with A.1/A.2/A.3/B design |

## Deferred items

| Item | Reason | Next destination |
|---|---|---|
| A.1 implementation | Design complete; reserved for implementation session | Next implementation session |
| A.2 detailed spec | High-level contract agreed; detailed spec after A.1 completes | Session following A.1 close |
| A.3 detailed spec | High-level contract agreed; detailed spec after A.2 completes | Session following A.2 close |
| Session B: `--interactive` implementation | Blocked on A.1+A.2+A.3 | Implementation session after A.3 closes |
| `package_diff` cross-write into `session-diffs/` | Channel-boundary decision; no concrete use case yet | Future design session |

## Next session

**M2.3 — Session A.1 implementation: Data model — output format unification**

**Session type:** Implementation

**Objective:** Execute the A.1 design: unify packaging output format, consolidate SESSION_STATE, remove sweep commit, and update tests.

**Key files to read at session start:**
- `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` — A.1 section
- `docs/devlog/roadmap.md` — A.1 task list
- `libs/snapshot.sh` — `snapshot_init_git` (add SESSION_STATE write)
- `libs/sandbox-entrypoint.sh` — drop BASELINE_SHA
- `libs/diff.sh` — diff_on_exit, diff_on_autosave, new helpers
- `libs/package_branch.sh` — dispatcher rewrite
- `libs/package_diff.sh` — rename, extract helpers
- `libs/session.sh` — add session_state_write
- `tests/test_diff.sh`, `tests/test_snapshot_container.sh`, `tests/test_package_branch.sh`, `tests/test_package_diff.sh` — update assertions

**Trigger B status:** Not yet fired. M2.3 has A.1, A.2, A.3, and B pending.

**Context handover:** Resume from the amended design document (`docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` — A.1 section), not from any prior handover's Next session.
