# Agent Handover

**Session date:** 2026-04-21
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Fix apply workflow breakage identified during manual testing: new-file application failures
in `make apply`, whitespace warnings from `package-diff.sh`, and file mode mismatch
warnings. Update stale documentation in `sandbox_lifecycle.md` and `system_overview.md`.
Rename `make apply` from a no-command fallback to a named command.

## Scope

Script fixes to `scripts/apply_workspace.sh` and `libs/package-diff.sh`. Documentation
updates to `docs/architecture/sandbox_lifecycle.md` and `docs/architecture/system_overview.md`.
Roadmap update to reflect `make apply` naming change and `apply_workspace.sh` fixes.

## Carried forward

None.

## Acceptance criteria

- [x] `make apply` succeeds for diffs containing new files (no "does not exist in index" error)
- [x] `make apply` applies file mode changes without warnings
- [x] `package-diff.sh` produces diffs with no trailing whitespace and exactly one trailing newline
- [x] `apply_workspace.sh` `apply` command is a named command, not a no-arg fallback
- [x] All callers of `apply_workspace.sh` pass `apply` as explicit command arg (`agent-sandbox.sh`, test files)
- [x] `sandbox_lifecycle.md` reflects current state: no `checkpoint-latest.ref`, correct legacy apply description
- [x] `system_overview.md` reflects two-layer model: no M1.x component descriptions

## Hot files

| File | Why in scope | Status |
|---|---|---|
| `scripts/apply_workspace.sh` | New-file pre-staging; `--index` flag; `apply` named command | ✓ Complete |
| `libs/package-diff.sh` | Whitespace normalisation in diff output | ✓ Complete |
| `docs/architecture/sandbox_lifecycle.md` | `checkpoint-latest.ref` reference; legacy apply description | ✓ Complete |
| `docs/architecture/system_overview.md` | M1.x component descriptions; `doc-status.md` reference | ✓ Complete |
| `docs/development/roadmap.md` | Change 3 description updated; `apply` naming | ✓ Complete |
| `scripts/agent-sandbox.sh` | `apply` dispatch: add `apply` command arg | ✓ Complete |
| `tests/test_apply_workspace.sh` | 9 no-command calls → `apply`; header comment updated | ✓ Complete |
| `tests/test_apply.sh` | "apply (legacy)" comment → "apply command" | ✓ Complete |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Pre-stage new files via `touch` + `git add` before `git apply --3way` | New files have no index entry; `--3way` cannot merge against nothing. `touch` + `git add` gives git an empty blob to merge against — error never surfaces | `apply_workspace.sh`, roadmap Change 3 note |
| Use `--index` on `git apply` | Propagates mode changes (100644↔100755) to the index, eliminating file mode mismatch warnings | `apply_workspace.sh` |
| `make apply` is a named command, not a no-arg fallback | No-arg dispatch is confusing and inconsistent with all other commands; `apply` as an explicit command matches the pattern | `apply_workspace.sh`, roadmap |
| Whitespace normalisation in `package-diff.sh` via sed pipe | `git diff` does not strip trailing whitespace from output; sed post-processing is the correct fix at the packaging side so generated diffs are clean | `package-diff.sh` |
| Standard: strip trailing whitespace per line, one trailing newline before EOF | Consistent with Linux text file conventions; matches what editors and `git apply` expect | `package-diff.sh` |

## Completed this session

| File | Change summary |
|---|---|
| `scripts/apply_workspace.sh` | New-file pre-staging (touch + git add) before git apply; `--index` on both apply paths; `apply` is now a named command (was no-arg fallback); section comment and header updated; `apply` added to valid commands list |
| `libs/package-diff.sh` | Diff generation piped through sed to strip trailing whitespace per line and ensure single trailing newline |
| `docs/architecture/sandbox_lifecycle.md` | Checkpoint tag paragraph: removed `checkpoint-latest.ref` write, replaced with `checkpoint.sh` lookup note; legacy apply description: `staged.diff` → `changes.diff`, added `.workspace/output/` source reference |
| `docs/architecture/system_overview.md` | `doc-status.md` → `project_index.md`; Major Components section rewritten for two-layer model: `.bootstrap/` and single-container descriptions replaced with two-layer containers, `.snapshot/`, sandbox as Docker volume, `.workspace/` subdirectory ownership, draft/confirm/apply workflow, SANDBOX_DIR per-project config |
| `docs/development/roadmap.md` | Change 3 table entry renamed to `draft/confirm/reject/apply`; Change 3 bullet updated: "legacy fallback" → "named command", added new-file pre-staging and `--index` notes |
| `scripts/agent-sandbox.sh` | `apply` dispatch: added `apply` as positional command arg before flags |
| `tests/test_apply_workspace.sh` | 9 no-command invocations updated to pass `apply`; header comment updated: "draft/confirm/reject/apply", `--index --3way` noted, "(legacy)" removed |
| `tests/test_apply.sh` | Comment updated: "apply (legacy)" → "apply command" |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Next task:** Implement Change 6 (baseline advancement).

**Files to upload:**
- This handover
- `roadmap.md` (updated)
- `scripts/apply_workspace.sh` (updated — starting point for Change 6 `SYNC=1` and `sync` command stubs)
- `scripts/agent-sandbox.sh` (updated)
- `scripts/checkpoint.sh` (sourced by advancement script)
- Prior impl handover `20260421-01-impl-m2_3_container_naming_labels_checkpoint.md` for Change 5 context
- `docs/discussions/design_apply_workflow_and_baseline_advancement.md` for Change 6 design reference
