# Agent Handover

**Session date:** 2026-05-04
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Add `--channel` flag and router functions to `agent-sandbox.sh`, rewrite `apply_run`/`draft_run` to the file-path/SOURCE_DIR contract, update Makefile flag mappings, unify `diff_on_exit`/`diff_on_autosave` into a single `diff_export` helper, and add router unit tests.

## Scope

Targets A.2 from the roadmap (`docs/devlog/roadmap.md`  A.2), expanded with three design refinements confirmed during Gate 1:

- **C1** — Extract routing layer into `libs/routing.sh` (not inline in agent-sandbox.sh)
- **C2** — Entrypoint path construction reuses routing logic via `session_export_path`; `diff_on_exit`/`diff_on_autosave` removed
- **C3** — Flip export layout to `session-diffs/{session,autosave}/<SESSION>/` for easier latest-session discovery
- **Output unification** — Both `package_branch.sh` and `package_diff.sh` use shared `output_export_path` from `routing.sh`; host-side fallback reads `.env` for `INPUT_DIR`
- **Layout flip** — `session-diffs/session/<SESSION>` and `session-diffs/autosave/<SESSION>`

**In scope (grouped):**

*Routing module:*
- `libs/routing.sh` (NEW) — `session_export_path`, `output_export_path`, `resolve_source_for_draft`, `resolve_diff_for_apply`
- `scripts/agent-sandbox.sh` — `--channel` flag parsing, source `routing.sh`, router dispatch, absolute-path rejection for `--session`
- `libs/session.sh` — remove `resolve_session_dir`

*Entrypoint cleanup:*
- `libs/diff.sh` — remove `diff_on_exit`/`diff_on_autosave`; update function header
- `libs/sandbox-entrypoint.sh` — source `routing.sh`; use `session_export_path` + direct `package_branch` call in EXIT trap and autosave loop

*Workflow contract updates:*
- `libs/diff_workflow.sh` — rewrite `apply_run` to 4 args: `PROJECT_DIR DIFF_FILE BRANCH FORCE`
- `libs/draft_workflow.sh` — rewrite `draft_run` to SOURCE_DIR + SESSION_NAME contract; apply `patches/*.diff` then `uncommitted.diff` if present
- `libs/_templates/Makefile.template` — AUTOSAVE → `--channel=autosave`, BUNDLE → `--channel=bundles`

*Script-mode consolidation:*
- `libs/package_branch.sh` — source `routing.sh`; use `output_export_path` instead of inline path construction
- `libs/package_diff.sh` — source `routing.sh`; use `output_export_path`; read `.env` for `INPUT_DIR` on host fallback

*Stale cleanup:*
- `libs/dirs.sh` — update stale output-format comment
- `scripts/onboard.sh` — update stale `staged.diff`/`changes.diff` comments

*Container packaging:*
- `libs/sandbox.Dockerfile` — add `COPY routing.sh /opt/sandbox/lib/routing.sh`
- `providers/*/provider.Dockerfile` — add `COPY routing.sh /opt/sandbox/lib/routing.sh` (×4)

*Tests:*
- `tests/test_routing.sh` (NEW) — pure unit tests for all 4 routing functions
- `tests/test_diff_dispatch.sh` — rewrite for entrypoint path construction + direct package_branch
- `tests/test_diff_workflow.sh` — rewrite for 4-arg `apply_run`
- `tests/test_draft_workflow.sh` — update for new `draft_run`; add `test_draft_applies_uncommitted_diff`
- `tests/libs/session_fixtures.sh` — rename `changes.diff` → `uncommitted.diff`; add `all-changes.diff`
- `tests/test_session.sh` — update/remove `resolve_session_dir` tests

**Explicitly deferred:**
- A.3 (documentation alignment) — depends on A.2 completing first
- Path resolution unification (SNAPSHOT_DIR/CHANGES_DIR/INPUT_DIR/OUTPUT_DIR common interface) — recorded as mid-session finding for future session

## Carried forward

None.

## Acceptance criteria

1. `scripts/run_tests.sh` exits 0
2. `make draft` (no flags) resolves `--channel=session`, finds the latest session export under `session-diffs/session/`, applies `patches/*.diff` then `uncommitted.diff` if present
3. `make draft BUNDLE=1` resolves `--channel=bundles`, finds latest bundle export under `$OUTPUT_DIR/bundles/`
4. `make apply` (no flags) resolves `--channel=diffs`, finds latest `uncommitted.diff` under `$OUTPUT_DIR/diffs/`
5. `make apply AUTOSAVE=1` resolves `--channel=autosave`, finds latest `uncommitted.diff` under `session-diffs/autosave/<session>/`
6. `--diff=<path>` bypasses all channel resolution; `--session=<name>` rejects absolute paths with clear error
7. `draft_run` applies `patches/*.diff` sequentially then `uncommitted.diff` if present
8. `apply_run` applies any file path passed to it (no hardcoded filename, no internal resolution)
9. Router unit tests exist for `resolve_source_for_draft` and `resolve_diff_for_apply` covering: default channel, explicit channel, name-only session, absolute-path rejection, missing session
10. `session_export_path` and `output_export_path` unit tests exist covering both subfolder variants
11. `session_export_path` constructs correct paths: `$CHANGES_DIR/session/<TS>-<BRANCH>` and `$CHANGES_DIR/autosave/<TS>-<BRANCH>`
12. `diff_on_exit` and `diff_on_autosave` removed from `libs/diff.sh`; no remaining callers
13. `resolve_session_dir` removed from `session.sh`; tests updated
14. `package_branch.sh` and `package_diff.sh` script-mode still functional when invoked directly (BASH_SOURCE guard preserved)
15. `routing.sh` is COPY-ed into all 5 Dockerfiles
16. Stale `staged.diff`/`changes.diff` references removed from `onboard.sh`, `sandbox-entrypoint.sh`, `dirs.sh`
17. Architecture documents in scope describe the system as built

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | `--channel` flag; routers; absolute-path rejection |
| [`libs/diff.sh`](../../libs/diff.sh) | Remove `diff_on_exit`/`diff_on_autosave`; add `diff_export` |
| [`libs/diff_workflow.sh`](../../libs/diff_workflow.sh) | `apply_run` 4-arg file-path contract |
| [`libs/draft_workflow.sh`](../../libs/draft_workflow.sh) | `draft_run` SOURCE_DIR + SESSION_NAME contract |
| [`libs/_templates/Makefile.template`](../../libs/_templates/Makefile.template) | AUTOSAVE/BUNDLE flag mappings |
| [`libs/sandbox-entrypoint.sh`](../../libs/sandbox-entrypoint.sh) | Path construction for `diff_export`; stale comment cleanup |
| [`libs/session.sh`](../../libs/session.sh) | Deprecate/move `resolve_session_dir` |
| [`libs/dirs.sh`](../../libs/dirs.sh) | Update stale output format comment |
| [`scripts/onboard.sh`](../../scripts/onboard.sh) | Update stale `staged.diff`/`changes.diff` comments |
| [`tests/test_diff_workflow.sh`](../../tests/test_diff_workflow.sh) | New apply_run tests |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | New draft_run tests |
| [`tests/libs/session_fixtures.sh`](../../tests/libs/session_fixtures.sh) | Fixture renames |
| [`tests/test_session.sh`](../../tests/test_session.sh) | Update/remove `resolve_session_dir` tests |
| [`tests/test_diff_dispatch.sh`](../../tests/test_diff_dispatch.sh) | Rewrite for entrypoint path construction |

## Decisions made this session

None.

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| SNAPSHOT_DIR/CHANGES_DIR/INPUT_DIR/OUTPUT_DIR are currently resolved differently inside the container (from dirs.sh + ROOT) vs on the host (from `.env`). Could be unified behind a single interface that only varies the base path, eliminating the duplicate resolution logic. Identified during A.2 routing design but out of scope. | scope change | A.5 — host path resolution unification |
| Detecting `$HOME/workspace/output` for IN_CONTAINER logic is fragile — assumes fixed container layout. Fix alongside finding #1. One host repo can have many SANDBOX_DIRs (one-to-many), so auto-deriving SANDBOX_DIR from REPO_ROOT is incorrect. Approach undecided — could be a Makefile target, an explicit git alias with `--sandbox-dir=<path>`, or something else. | design gap | A.5 — host path resolution (approach TBD) |
| A.2 scope expansion (host path resolution) is valuable but would bloat this session. Better to schedule as A.5 after A.2, before A.3. A.2 stays focused on routing module + workflow contracts. | steering | A.2 scope confirmed as-is; A.5 added to roadmap

## Completed this session

| File | Change |
|---|---|
| `libs/routing.sh` | NEW — `session_export_path`, `output_export_path`, `resolve_source_for_draft`, `resolve_diff_for_apply` |
| `libs/diff.sh` | Removed `diff_on_exit`/`diff_on_autosave`; added `diff_export`; source `routing.sh` |
| `libs/sandbox-entrypoint.sh` | Source `routing.sh`; inline path construction via `session_export_path` + `diff_export` |
| `scripts/agent-sandbox.sh` | Source `routing.sh`; `--channel` flag; router dispatch; absolute-path rejection for `--session` |
| `libs/diff_workflow.sh` | Rewrote `apply_run` to 4-arg file-path contract; fixed SCRIPT_DIR collision |
| `libs/draft_workflow.sh` | Rewrote `draft_run` to SOURCE_DIR + SESSION_NAME contract; applies `patches/*.diff` then `uncommitted.diff` |
| `libs/session.sh` | Removed `resolve_session_dir` |
| `libs/_templates/Makefile.template` | Added `AUTOSAVE`/`BUNDLE` flag mappings; `--channel` in draft/apply targets |
| `libs/package_branch.sh` | Source `routing.sh`; use `output_export_path` |
| `libs/package_diff.sh` | Source `routing.sh`; use `output_export_path` |
| `libs/dirs.sh` | Updated stale comment (`staged.diff` → `uncommitted.diff, all-changes.diff, patches/, changed-files/`) |
| `scripts/onboard.sh` | Updated stale comment (`staged.diff` → `session checkpoints`) |
| `libs/sandbox.Dockerfile` | Added `COPY routing.sh /opt/sandbox/lib/routing.sh` |
| `providers/*/provider.Dockerfile` | Added `COPY routing.sh /opt/sandbox/lib/routing.sh` (×4) |
| `tests/test_routing.sh` | NEW — 23 tests for all 4 routing functions |
| `tests/test_diff_dispatch.sh` | Rewritten for entrypoint path construction + `diff_export` |
| `tests/test_diff_workflow.sh` | Rewritten for 4-arg `apply_run` |
| `tests/test_draft_workflow.sh` | Updated for new `draft_run`; added `test_draft_applies_uncommitted_diff` |
| `tests/libs/session_fixtures.sh` | Updated to create `uncommitted.diff` and `all-changes.diff`; patches at top level (not session/ subdir) |
| `tests/test_session.sh` | Removed `resolve_session_dir` tests |

## Deferred items

None.

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| A.5 — Host path resolution unification | Out of scope for A.2. IN_CONTAINER detection is fragile; host-side wrapper approach TBD (Makefile, git alias, or scripts/ shim). | A.5, before A.3 |
| A.3 — Documentation alignment | Blocked on A.2 completing. Architecture docs describe old layout. | A.3, after A.2

## Next session

**A.3 — Documentation alignment.**

**Session type:** Implementation (or Housekeeping).

**Trigger B pending:** Not yet. A.2, A.3, and A.5 must all complete before Trigger B can fire.

**Blocking design questions for A.5:**
- Host wrapper approach undecided (Makefile target, git alias with `--sandbox-dir=<path>`, or scripts/ shim)
- How to register the host-side entry point during `agent-sandbox onboard`

**Context:** A.1, A.2, A.4 are complete. A.3 is the next implementation task. A.5 was identified mid-session in A.2 — approach TBD.

**Watch-out items for A.3:**
1. Layout changed to `session-diffs/{session,autosave}/<SESSION_TS>-<BRANCH>/` — update all folder path descriptions in architecture docs
2. Routers live in `libs/routing.sh`, not inline in `agent-sandbox.sh` — update tool_interface.md accordingly
3. `diff_on_exit`/`diff_on_autosave` replaced by `diff_export` + `session_export_path` — update sandbox_lifecycle.md
4. `changes.diff` → `uncommitted.diff`, `staged.diff` → `all-changes.diff` throughout docs
5. Stale `make apply SESSION=<path>` comments in Makefile.template already cleaned — verify nothing reverted

**Context handover:** This session (A.2) supersedes the prior implementation thread (A.1). The prior implementation handover is `20260503-09-impl-unified_output_format.md` — routers and output format design are linked.

**Conclusions from this session:**
- `libs/routing.sh` is the single authority on path layout conventions (both session-diffs/ and output/ paths)
- Entrypoint path construction uses `session_export_path` + `diff_export` — no inline path building
- CLI routing uses `resolve_source_for_draft` and `resolve_diff_for_apply` — workflow functions are pure path consumers
- Layout flip to `session-diffs/{session,autosave}/<SESSION>/` confirmed and implemented
- Host path resolution (A.5) deferred — approach undecided
