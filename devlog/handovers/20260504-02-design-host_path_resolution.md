# Agent Handover

**Session date:** 2026-05-04
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Resolve open design questions for A.5 (host path resolution for `package_diff.sh` and `package_branch.sh`), using the grill-me protocol to walk the design tree and arrive at a confirmed approach.

Implement host path resolution unification

## Scope

A.5 — Host path resolution unification. Design confirmed via grill-me protocol.

**Confirmed approach:**
- Host entry point: `agent-sandbox package-diff` / `agent-sandbox package-branch` subcommands
- Makefile targets: `make package-diff` / `make package-branch` calling `agent-sandbox`
- Git alias stripped from `onboard.sh`
- `--to=<dir>` flag replaces `--outdir` in both lib scripts (required; means base parent dir, script adds subdir)
- `--all` / `--baseline=<sha>` flags added to both lib scripts
- `IN_CONTAINER` detection removed from `package_diff.sh`; `.package-diff-output` fallback removed
- `write_all_changes_diff` gets optional 3rd arg `SINCE_SHA`
- `package_branch` library function gets optional `init_sha_override`
- Prompt templates updated to use `--to=$HOME/workspace/output`
- Docstring for `agent-sandbox.sh` updated to reflect host-side tool

**Not in scope:** A.3 (documentation alignment) — deferred.

## Carried forward

None.

## Acceptance criteria

1. `scripts/run_tests.sh` exits 0
2. `agent-sandbox package-diff --sandbox=<path>` invokes `package_diff.sh` and produces output under `INPUT_DIR/diffs/<ts>-<label>/`
3. `agent-sandbox package-branch --sandbox=<path>` invokes `package_branch.sh` and produces output under `INPUT_DIR/bundles/<ts>-<label>/`
4. `make package-diff` (from project Makefile) delegates to `agent-sandbox package-diff` with correct `--sandbox`
5. `make package-branch` delegates to `agent-sandbox package-branch`
6. `bash .../package_diff.sh --to=<dir> --session-summary=<s>` produces `uncommitted.diff` + `changed-files/` under `<dir>/diffs/<ts>-<s>/`
7. `bash .../package_diff.sh --to=<dir> --all` produces `all-changes.diff` (reads SESSION_STATE)
8. `bash .../package_diff.sh --to=<dir> --baseline=<sha>` produces `all-changes.diff` against explicit SHA
9. `bash .../package_branch.sh --to=<dir>` produces `patches/*.diff`, `uncommitted.diff`, `all-changes.diff`, `changed-files/`
10. `bash .../package_branch.sh --to=<dir> --baseline=<sha>` packages commits since explicit SHA
11. Missing `--to` in either script produces a clear error
12. `IN_CONTAINER` variable and `.package-diff-output` fallback removed from `package_diff.sh`
13. `--outdir` flag removed from both scripts; `--to` flag present in both
14. Git alias for `package-diff` no longer registered by `onboard.sh`
15. `agent-sandbox.sh` docstring updated to reflect host-side-only tool
16. `write_all_changes_diff` accepts optional 3rd argument `SINCE_SHA`
17. Prompt templates (`package-diff.md`, `package-branch.md`) updated with `--to=$HOME/workspace/output`
18. Architecture documents in scope describe the system as built

## Hot files

| File | Why in scope |
|---|---|
| [`libs/package_diff.sh`](../../libs/package_diff.sh) | Currently has IN_CONTAINER detection + `.package-diff-output` fallback — target for A.5 |
| [`libs/package_branch.sh`](../../libs/package_branch.sh) | Script-mode path construction — may need host-side entry point |
| [`libs/routing.sh`](../../libs/routing.sh) | `output_export_path` already exists — A.5 host wrapper calls it |
| [`scripts/onboard.sh`](../../scripts/onboard.sh) | Currently registers git alias for package-diff — A.5 may update this |
| [`libs/_templates/Makefile.template`](../../libs/_templates/Makefile.template) | May gain a host-package-diff target |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Host-side entry point consideration |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `agent-sandbox package-diff` and `package-branch` subcommands | Reuses existing CLI infrastructure; `--sandbox` flag already parsed; no new script needed | Handover |
| Makefile targets call `agent-sandbox` | Consistent with all other Makefile targets | Handover |
| Git alias stripped | Replaced by `agent-sandbox` CLI + Makefile; removes fragile path dependency | Handover |
| `--to=<dir>` replaces `--outdir` | `--outdir` conventionally means final path; `--to` is shorter and doesn't mislead | Handover |
| `--to` is required (no default) | Avoids implicit container path detection (was IN_CONTAINER); explicit everywhere | Handover |
| `--all` / `--baseline=<sha>` mutual exclusive optional flags | Extends `package_diff` to package more than just `git diff HEAD` | Handover |
| `write_all_changes_diff` accepts optional `SINCE_SHA` | Enables `--baseline` without modifying SESSION_STATE | Handover |
| `package_branch`/`package_commits` get optional `init_sha_override` | Enables `--baseline` for branch packaging | Handover |
| Exec delegation (not source) | Clean process boundary; lib scripts handle own arg parsing | Handover |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `libs/diff.sh` | `write_all_changes_diff` gets optional 3rd arg `SINCE_SHA` |
| `libs/package_diff.sh` | `--outdir` → `--to`; added `--all`/`--baseline`; removed `IN_CONTAINER` detection; removed `.package-diff-output` fallback; `REPO_ROOT` moved behind source guard |
| `libs/package_branch.sh` | `--outdir` → `--to`; added `--baseline`; `package_commits` and `package_branch` get optional `init_sha_override`; updated docs |
| `scripts/agent-sandbox.sh` | Added `package-diff` and `package-branch` subcommands; updated docstring to host-side-only |
| `libs/_templates/Makefile.template` | Added `package-diff` and `package-branch` targets; added `SESSION_SUMMARY`, `BASELINE`, `ALL` vars |
| `scripts/onboard.sh` | Removed git alias registration for `package-diff`; updated refresh summary |
| `agent/prompts/package-diff.md` | Updated with `--to=$HOME/workspace/output`, `--all`, `--baseline`; host-side reference |
| `agent/prompts/package-branch.md` | Updated with `--to=$HOME/workspace/output`, `--baseline`; host-side reference |

## Deferred items

None.

## Next session

**A.3 — Documentation alignment.**

**Trigger B pending:** Not yet. A.2, A.3, and A.5 must all complete before Trigger B can fire.

**Context handover:** This session completed A.5 design and implementation. Resume A.3 by reading `20260504-01-impl-cli_contract_channel_flag_routing.md` Next session and watch-out items.

**Conclusions from this session:**
- Host entry point: `agent-sandbox package-diff` / `package-branch` subcommands
- Makefile targets delegate to `agent-sandbox`
- `--to=<dir>` replaces `--outdir`; required everywhere
- `--all` / `--baseline=<sha>` optional flags added
- `IN_CONTAINER` detection removed; `.package-diff-output` removed
- Git alias removed from `onboard.sh`
- `write_all_changes_diff` and `package_branch` get optional baseline override
- Design confirmed via grill-me protocol; implementation completed in same session
