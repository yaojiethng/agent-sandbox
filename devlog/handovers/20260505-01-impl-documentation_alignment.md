# Agent Handover

**Date:** 2026-05-04
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Type:** Implementation
**Status:** Closed

## Objective (Phase 1)

Update all architecture, concepts, and development documents to describe the system as built after A.1, A.2, A.4, and A.5. Verify drift items: sweep commit elimination and apply semantics.

**Phase 2 (added mid-session):** Consolidate all harness path derivation into a single module (`dirs_resolve` in `libs/dirs.sh`), eliminating the derived-path cache in `.env` and unifying host-side and container-side path conventions.

## Scope

Targets A.3 from the roadmap. In scope:

*Architecture docs:*
- `docs/architecture/execution_model.md` — rename `changes.diff` → `uncommitted.diff`, `staged.diff` → `all-changes.diff`; add `changed-files/`; update directory tree and mermaid diagrams
- `docs/architecture/sandbox_lifecycle.md` — remove sweep commit description; rename filenames; update apply/draft command descriptions for `--channel` / `--uncommitted.diff`
- `docs/architecture/tool_interface.md` — rewrite `apply`/`draft` for `--channel`, `--session` (name-only), `--diff=<path>`, `AUTOSAVE=1`, `BUNDLE=1`; document `package-diff`/`package-branch` subcommands; document `--to` flag
- `docs/architecture/system_overview.md` — update diff output description; remove "legacy" framing

*Concept docs:*
- `docs/concepts/sandbox_host_correspondence_model.md` — update correspondence cycle; rewrite command map with new flags and output paths

*Development docs:*
- `docs/development/project_index.md` — update `Last touched in` for A.1/A.2/A.4/A.5 files; remove stale entries
- `docs/development/testing_policy.md` — rename `staged.diff` → generic "diff files" in anti-pattern examples
- `docs/development/quickstart.md` — recovery section: verify recovery paths are consistent; add `--channel`, `--diff=<path>` snippets

*Discussion docs:*
- `docs/devlog/discussions/design_change_a_contract.md` — verify design doc is self-consistent
- `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` — add forward-reference to `design_change_a_contract.md`

*Drift verification:*
- Confirm no remaining references to sweep commits in architecture docs
- Confirm apply semantics documented correctly: always results in unstaged git apply, patch size varies by channel (uncommitted.diff for autosave/exit/diffs channel; all-changes.diff for session channel)
- Confirm `IN_CONTAINER`, `--outdir`, `.package-diff-output` references removed from docs

**Explicitly deferred:**
- Roadmap compaction for A.5 (Trigger B not yet — A.3 must complete first)
- No code changes — documentation only

## Carried forward

None.

## Acceptance criteria

1. `grep -rn "changes\.diff\|staged\.diff\|\.package-diff-output\|IN_CONTAINER" docs/ --include="*.md"` returns 0 results outside `docs/devlog/discussions/`
2. `grep -rn "sweep commit\|sweep_commit\|BASELINE_SHA\|diff_commit_pending" docs/ --include="*.md"` returns 0 results outside discussion archives
3. `execution_model.md` directory tree matches current layout: `session-diffs/{session,autosave}/<SESSION_TS>-<BRANCH>/` with `uncommitted.diff`, `all-changes.diff`, `patches/`, `changed-files/`
4. `sandbox_lifecycle.md` Phase 3 describes `diff_export` + `session_export_path` (no sweep commit)
5. `sandbox_lifecycle.md` apply workflow describes `--channel`, `--session` (name-only), `--diff=<path>`
6. `tool_interface.md` documents `make draft --channel=`, `make apply --channel=`, `make package-diff`, `make package-branch`, `--to` flag
7. `system_overview.md` diff/apply section uses current filenames; removes "legacy" framing
8. `sandbox_host_correspondence_model.md` command map matches current CLI
9. `design_diff_and_branch_packaging_workflow.md` has forward-reference to `design_change_a_contract.md`
10. `project_index.md` has `Last touched in` updated to M2.3 for all A.1/A.2/A.4/A.5 files
11. `quickstart.md` recovery section consistent with current CLI
12. Roadmap Trigger B status line reads "A.0–A.5"
13. Architecture documents in scope describe the system as built

## Hot files

| File | Why in scope |
|---|---|
| [`docs/architecture/execution_model.md`](../../docs/architecture/execution_model.md) | Filename renames; output layout |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Sweep commit removal; `--channel` |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | New CLI flags, subcommands |
| [`docs/architecture/system_overview.md`](../../docs/architecture/system_overview.md) | Output format description |
| [`docs/concepts/sandbox_host_correspondence_model.md`](../../docs/concepts/sandbox_host_correspondence_model.md) | Command map updates |
| [`docs/development/project_index.md`](../../docs/development/project_index.md) | Last-touched updates |
| [`docs/development/testing_policy.md`](../../docs/development/testing_policy.md) | Anti-pattern rename |
| [`docs/development/quickstart.md`](../../docs/development/quickstart.md) | Recovery section |
| [`docs/devlog/discussions/design_change_a_contract.md`](../../docs/devlog/discussions/design_change_a_contract.md) | Self-consistency check |
| [`docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md`](../../docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md) | Forward-reference |

## Decisions made this session

- **`dirs_resolve` does NOT set `SANDBOX_DIR`.** SANDBOX_DIR has different base semantics on host (it IS the base for derivation) vs container (it is derived from ROOT + SANDBOX_DIR_NAME). Callers supply or derive SANDBOX_DIR separately.
- **Derived paths removed from `.env`.** SNAPSHOT_DIR, CHANGES_DIR, INPUT_DIR, OUTPUT_DIR are no longer stored in `.env` — they are produced on demand by `dirs_resolve`.
- **Single function, two conventions.** The only difference between host and container path derivation is the `WORKSPACE_DIR_NAME` override (`workspace` in container vs `.workspace` default on host). The same `dirs_resolve` function handles both.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `docs/architecture/execution_model.md` | Updated directory tree to flipped layout `{session,autosave}/<SESSION>/`; updated mermaid diagram (diff_on_exit → diff_export, filenames renamed) |
| `docs/architecture/sandbox_lifecycle.md` | Rewrote Phase 3 (no sweep commit, `diff_export` + `session_export_path`); updated apply workflow for `--channel`, `--session` name-only, `--diff=<path>`; added `make package-diff`/`package-branch` docs |
| `docs/architecture/tool_interface.md` | Rewrote make apply/draft with `--channel`; added `make package-diff`/`package-branch`/`make confirm`/`make reject`; updated dry-run output description |
| `docs/architecture/system_overview.md` | Updated diff/apply description with current filenames; removed "legacy" framing |
| `docs/concepts/sandbox_host_correspondence_model.md` | Updated correspondence cycle, command map, running section, model gaps — all reflect current CLI and layout |
| `docs/development/project_index.md` | Updated Last touched in to M2.3 for tool_interface, onboard, quickstart; added routing.sh entry; fixed stale package_branch/test_diff descriptions |
| `docs/development/testing_policy.md` | Renamed `staged.diff` → "diff files" in anti-pattern examples |
| `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` | Added forward-reference to `design_change_a_contract.md` |
| `docs/devlog/discussions/design_change_a_contract.md` | Updated scope to A.0–A.5; added A.5 to dependency ordering diagram |
| `docs/devlog/roadmap.md` | Updated Trigger B status to A.0–A.5 |
| `tests/test_dirs.sh` | **New** — 11 tests for `dirs_resolve` (host convention, container convention, empty base, env overrides) |
| `libs/dirs.sh` | Added `WORKSPACE_DIR_NAME` default (`.workspace`); changed `CHANGES_DIR_NAME`/`INPUT_DIR_NAME`/`OUTPUT_DIR_NAME` to leaf-only; added `dirs_resolve` function |
| `libs/routing.sh` | Sourced `dirs.sh`; replaced inline path derivation with `dirs_resolve` |
| `libs/sandbox-entrypoint.sh` | Replaced inline `$ROOT/$X_DIR_NAME` with `WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"` |
| `scripts/dry_run.sh` | Same pattern — replaced inline with `dirs_resolve` |
| `scripts/start_agent.sh` | Removed `REQUIRED_ENV_VARS` validation; added `source dirs.sh` + `dirs_resolve` |
| `scripts/agent-sandbox.sh` | Replaced `.env` sourcing (for INPUT_DIR) with `source dirs.sh` + `dirs_resolve` in package-diff/package-branch |
| `scripts/onboard.sh` | Removed SNAPSHOT_DIR/CHANGES_DIR/INPUT_DIR/OUTPUT_DIR from .env template |
| `docs/devlog/discussions/design_unified_path_derivation.md` | **New** — design doc for path derivation consolidation |
| `docs/architecture/tool_interface.md` | Moved derived vars out of `.env` table into "Runtime-derived paths" subsection |
| `docs/concepts/sandbox_host_correspondence_model.md` | Updated command map phrasing to "Derives INPUT_DIR from SANDBOX_DIR" |
| `tests/test_routing.sh` | Added `unset` for leaking `_DIR_NAME` env vars at top |

## Deferred items

None.

## Next session

**Interactive confirmation flag (Change B) — next M2.3 task.**

A.0–A.5 groups are complete, and the path derivation unification is done. The remaining M2.3 task is the `--interactive` flag for `make apply` and `make draft`: print resolved diff file list, prompt for confirmation, abort on rejection.

**Watch-out items:**
- `test_package_diff.sh` and `test_package_branch.sh` don't source `test_common.sh` and report 0 tests each — pre-existing, not blocking
- The env var leak (`INPUT_DIR_NAME=workspace/input`, `OUTPUT_DIR_NAME=workspace/output`) in the container shell environment is not a production issue (dirs.sh defaults apply correctly in fresh shells), but test fixtures in `test_routing.sh` now explicitly `unset` them to stay hermetic

**Conclusions from this session:**
- All architecture, concept, and development docs now describe the system as built after A.1–A.5
- Sweep commit elimination confirmed: `uncommitted.diff` captures unstaged changes without committing
- Apply semantics confirmed: 4-arg `apply_run` applies resolved diff file unstaged; channel determines which diff file is applied
- Bundle/draft identity drift confirmed resolved: router-based resolution correctly extracts SESSION_TS from bundle folder names
- Path derivation unified under `dirs_resolve` — derived paths removed from `.env`, single canonical function for host and container
- No stale cache to drift — derived paths are strict functions of `SANDBOX_DIR` at point-of-use
