# Agent Handover

**Date:** 2026-08-19
**Milestone:** M2.6.6 — terminology, phase 5B (apply simplification)
**Type:** Implementation
**Status:** Closed

## Objective

Iteration 5B of the phase-5 terminology refactor. **Scope per operator instruction (expanded beyond the original diffs-channel removal):** render `make apply` a purely explicit-path operation — **remove the apply default entirely; always require `--diff=<full path to an exact filename>`; no channel resolution at all.** This replaces the previously proposed 5B (remove dead `diffs` channel + flip apply default to `session`). `draft` keeps its channel resolution unchanged.

## Context (verified)

- Baseline `4490ad8` (5A bundle rename), working tree clean.
- ADR `20260801` frames `apply` as "direct recovery sync, no branch overhead, **accepts arbitrary diff paths**" — the operator's simplification aligns `apply` with that stated purpose: a single-diff tool that takes an explicit file path.
- `draft.sh` keeps full channel resolution (`session`/`autosave`/`bundles`) — it applies a patch **series** from a bundle; `apply` applies a single diff file.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | **Keep interactive in apply, reframed** — `--interactive` shows the diff changes (git-oneline style: file headers + total) then asks y/N via `interactive_confirm_or_abort`. No channel/bundle/diff-type picker. | operator; apply is a single-diff tool, distinct from draft's channel picker |
| 2 | **Missing `--diff`** — print `Error: --diff=<path> is required` + usage, exit 1; help updated. | operator; explicit path is mandatory |
| 3 | **Dropped apply flags** (`--channel`/`--bundle`/`--diff-type`) — removed from `apply`, kept for `draft`. | operator; apply has no channel resolution |
| 4 | **Split out the picker** — apply does NOT share `interactive_select_channel`/`interactive_select_bundle`/`interactive_select_diff_type`. Those become draft-only; apply gets its own preview+confirm. | operator 4; no shared picker needed |
| 5 | **`interactive_select_diff_type` REMOVED** (not kept draft-only) — its only production caller was `apply.sh`; draft never calls it; `--diff-type` dropped from apply → dead. | operator question ("do we still need this?") — verified apply-only |
| 6 | **`diffs` dead-channel removal folded in** — `resolve_diff_for_apply` removed (only apply used it); `diffs` dropped from `resolve_channel_base_dir`; `test_resolve_channel_base_dir_diffs`/apply-resolution tests removed. `export_path` "diffs" subdir test kept (generic path constructor, independent of channel validity). | completes the ADR `20260801` partially-applied removal alongside the apply change |

## Completed this session

- [x] **`apply.sh`**: `--diff=<path>` now **required** (`Error: --diff=<path> is required` + usage + exit 1); removed `--channel`/`--bundle`/`--diff-type` parsing + usage; non-interactive applies directly; `--interactive` invokes new `apply_preview` (prints each `diff --git` file + total count to stderr) then `interactive_confirm_or_abort`.
- [x] **`src/libs/routing.sh`**: removed `resolve_diff_for_apply` (dead); removed `diffs` entry from `resolve_channel_base_dir` (draft channels session/autosave/bundles intact); removed header reference.
- [x] **`scripts/workflows/interactive.sh`**: removed the `apply` case from `interactive_select_channel` (draft-only); **removed `interactive_select_diff_type`** (apply-only, now dead); kept `interactive_confirm_or_abort`/`interactive_select_channel`/`interactive_select_bundle`.
- [x] **Makefile.template**: `apply` target now `DIFF=<path>` (required) + `BRANCH` + `INTERACTIVE` + `FORCE`; removed `APPLY_CHANNEL` + `--channel`/`--bundle`/`--diff-type` forwarding; help + workflow comment blocks updated (apply = explicit-path; `FROM`/channel = draft only).
- [x] **`scripts/agent-sandbox.sh`**: apply usage line → `--diff=<path>` required.
- [x] **Docs**: `tool_interface.md` (apply = `--diff=<path>` required, interactive preview), `sandbox_lifecycle.md` (apply requires `--diff`, no resolution), `sandbox_host_correspondence_model.md` (×3: apply DIFF required + model-gaps + command table), `sandbox_identity.md` (removed stale `output/diffs` package-diff row), providers hermes/opencode quickstarts (apply requires `--diff=<path>`), `project_index.md` (dropped `interactive_select_diff_type` from interactive.sh facility row).
- [x] **Tests**: `test_routing.sh` (removed `resolve_diff_for_apply` tests + `test_resolve_channel_base_dir_diffs` + header ref; kept generic `export_path` diffs test), `test_interactive_session_select.sh` (removed apply-channel test + `interactive_select_diff_type` tests + run calls), `test_diff_workflow.sh` (added `test_apply_requires_diff_flag` verifying main errors without `--diff`).
- [x] **Verified**: `bash -n` clean on edited scripts; suite green **462 passed / 0 failed / 0 skipped**; interactive apply end-to-end confirmed (preview shows `f.txt`, total 1, confirm applies, `line2` lands); no stale `resolve_diff_for_apply`/`interactive_select_diff_type`/`diffs`-channel references in live code; draft channel resolution unchanged.

## Findings

| # | Finding | Disposition |
|---|---|---|
| 1 | `interactive_select_diff_type`'s only production caller was `apply.sh` — draft never used it. With `--diff-type` dropped from apply it became fully dead. | removed (decision 5) |
| 2 | `test_export_path_diffs_with_label` (routing tests) exercises the generic `export_path` constructor with "diffs" as a subdir string — independent of channel validity. | kept (documented in decision 6) |
| 3 | Removed ~14 tests (resolve_diff_for_apply, interactive_select_diff_type, apply-channel); added 1 (`test_apply_requires_diff_flag`) → net suite 476→462. | expected — dead-code tests removed |
| 4 | `output/diffs` / `package-diff` stale references remain only in the historical ADR `20260801` (C3) — not edited. | keep (historical) |

## Acceptance criteria (verified)

- [x] Operator confirms the apply simplification decisions — confirmed `2026-08-19` (decisions 1–5)
- [x] `make apply` requires `--diff=<path>`; no channel/bundle/diff-type auto-resolution; `draft` channel resolution unchanged — verified `apply.sh`/Makefile/interactive
- [x] `resolve_diff_for_apply` removed; `diffs` channel removed from `resolve_channel_base_dir`; draft channels (session/autosave/bundles) intact — verified routing.sh
- [x] Docs/Makefile/prompt reflect apply-as-explicit-path; suite green; no new shellcheck warnings — `make` absent, ran `bash scripts/run_tests.sh` → 462/0/0

## What's Next

Phase 5 (terminology sweep) is now fully complete (5A + 5B). Next program work per the earlier prefactor inventory: the deferred `.run-identity`/identity-registry fold is already done (P3); remaining planned items include the `start`-command/wizard (F2), mount delivery enablement (F1), prune-command redesign (F5), and the M2.6-close housekeeping (changelog extraction for M2.6.x + stale close-order label cleanup if still not applied).

## Operational notes

- `make` not installed in this environment; suite run via `bash scripts/run_tests.sh` (same as `make test`).
- Open gotchas in force: library functions `return` not `exit`; policy-text changes need per-section approval (this session's doc changes are architecture/dev docs, not policy).
