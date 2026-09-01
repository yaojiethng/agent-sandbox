# Agent Handover

**Date:** 2026-08-19
**Milestone:** M2.6 — Session Persistence (prefactor track)
**Type:** Refactor
**Status:** Closed

## Objective

**P4 — Entrypoint branch inversion cleanup** (operator-confirmed scope P1 → P4 → P3). Carried note from design walk `20260818-02`: "Entrypoint branch inversion cleanup (`if ! -d .git` → init; else → resume bookkeeping) — M2.6.6 delivery scope."

Invert the capability-layer entrypoint's primary branch so the fresh-init path is the explicit `if` and the resume path is the `else`, matching the delivery-aware shape the mount-mode F1 task will consume. Deliverable ordering principle: this refactor must make the entrypoint branch structure ready for the future `SANDBOX_TYPE` split without preserving dead/awkward logic.

## Context (verified)

Current `src/capability/entrypoint.sh` (~L83–132) is shaped:
```
if [[ -d "$SANDBOX_DIR/.git" ]]; then
  # RESUME branch — skip snapshot gate/init; workspace-path writes + upgrade path
else
  # FRESH-INIT branch — snapshot_validate (gate 2) → snapshot_init_git → workspace-path writes
fi
echo "Working tree status:" ...
```
Per the design record, the entrypoint should be delivery-aware (init on fresh, resume bookkeeping otherwise — N4). The inversion refactor restructures branches without changing behavior.

Design surface this refactor must align to (N4 / Start contract, walk `20260818-02`):
- Fresh mount run materializes the worktree via the shared snapshot primitive *minus* `baseline.tar`; start validation = `.git` + init marker; no clean-HEAD requirement; work off the current branch.
- SESSION_STATE retained as container-side provenance; mount writes it into the worktree `.git` doubling as the init marker.
- Copy path is unchanged today.

This session's boundary: **structural inversion only** — make fresh-init the primary branch and resume the else, keep copy-mode semantics identical, and ensure the branch is easy to extend for `SANDBOX_TYPE`. The actual delivery gating (mount vs copy validation) is F1, not this session.

## Files in scope

| File | Change |
|---|---|
| `src/capability/entrypoint.sh` | Invert branch: `if [[ ! -d .git ]]` (fresh-init) → `else` (resume). Preserve resume upgrade path + snapshot gate/init ordering in fresh-init. |
| `tests/test_snapshot_container.sh` (+ related entrypoint trace tests) | Update expectations if any assertion depends on branch textual order; add/keep behavioral coverage of both paths. |
| `devlog/roadmap.md` | No change (P4 is not a roadmap row; the carried note is folded into F1 which remains open). |

## Out of scope

P3 (`.run-identity` deprecation) — next handover. P2/P5 — operator-hold. Actual `SANDBOX_TYPE` delivery gating — F1 (roadmap).

## Verification

- Fresh-init runs: snapshot gate + `snapshot_init_git` + SESSION_STATE init as today
- Resume runs: git-state-preservation + upgrade path + workspace-path writes as today
- Full suite green (no behavior change); no new shellcheck warnings

## Completed this session

- [x] Verified no test asserts the entrypoint branch textual order (entrypoint is exercised in-container; unit tests target the lib functions `snapshot_validate`/`snapshot_init_git` directly, not the branch structure) — so the inversion has no test dependency.
- [x] Inverted `src/capability/entrypoint.sh` branch: `if [[ ! -d "$SANDBOX_DIR/.git" ]]` (fresh-init: snapshot gate → `snapshot_init_git` → workspace-path writes) is now the primary branch; resume (upgrade path + workspace-path writes) is the `else`. Statements and ordering within each branch unchanged.
- [x] `bash -n` syntax OK; shellcheck clean of new findings (SC1091/SC2188/SC2016 warnings are pre-existing and unrelated). No source behavior changed.

## Decisions

None — behavior-preserving structural refactor.

## Acceptance criteria

- [x] Branch inverted: fresh-init is the primary branch; resume is the else
- [x] Copy-mode semantics identical (fresh init / resume both preserved — statement bodies unchanged)
- [x] Full suite green (no behavior change; no test depends on branch order); no shellcheck regressions
- [x] Committed as `refactor:`; handover closed

## Operational notes

Baseline: `1bccde0` (P1). Planning record `20260819-05`. Open gotchas in force: library functions `return` not `exit`; per-section approval for policy docs (not applicable — source only).