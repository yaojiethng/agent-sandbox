# Agent Handover

**Session date:** 2026-05-03
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Design (bootstrap)
**Status:** Closed

## Objective

Produce the Change A design record, roadmap entries (A.0–A.4), and consolidated handover — replacing the lost-timeline handovers 20260429-03 (design: command shape and contract), 20260429-04 (impl: contract refactor), 20260429-05 (impl: A.1 data model), 20260429-06 (impl: A.2 CLI contract), 20260429-07 (impl: A.3 docs/recovery), and 20260429-09 (impl: changed-files). Handover 20260429-08 (B: interactive design) is out of scope and preserved separately.

All deliverables (D-1 through D-4) are complete.

## Scope

This session maps the settled design decisions from the lost timeline onto the current post-pre-clean tree. It produces durable artifacts (design doc, roadmap entries, thin recovery pointer) that subsequent A.0–A.4 implementation sessions execute as ordinary M2.3 work — no recovery context, no staged.diff, no lost-handover references.

### What the session discovered

**The A.1, A.2, and A.4 implementations from the lost timeline did NOT land in the live tree.** The current tree is in the pre-refactor state with the old contract:

- `diff_on_exit` / `diff_on_autosave` use the old code path (sweep commit, `BASELINE_SHA` param, inline operations)
- `diff_commit_pending` still exists
- `changes.diff` and `staged.diff` filenames everywhere
- `package_branch.sh` is not a dispatcher — no `write_uncommitted_diff` / `write_all_changes_diff` / `write_changed_files`
- `agent-sandbox.sh` has no `--channel` flag, no router functions
- `apply_run` and `draft_run` use the old multi-arg signatures with inline path resolution
- `write_changed_files` does not exist — inline copy logic remains in `package_diff.sh`
- All stale doc references (`changes.diff`, `staged.diff`, `BASELINE_SHA`, `diff_commit_pending`) still present

The SESSION_STATE migration (pre-clean Group 1) is the only implementation that landed — `session_state_read`/`session_state_write` exist, `snapshot_init_git` writes to SESSION_STATE, and all test fixtures are migrated.

**Implication:** A.1–A.4 require full implementation from scratch, not verification or patch-up. The roadmap entries reflect this.

## Deliverables

### D-1 — Design doc

**File:** `docs/devlog/discussions/design_change_a_contract.md`

A single coherent design record describing Change A's contract as it will be implemented. Covers: unified output format ( 2), pipeline functions ( 3), CLI contract ( 4), session identity ( 5), `diff_on_exit` repair strategy ( 6), and dependency ordering ( 7). No recovery framing, no "Contract Amendments" fragments.

### D-2 — Roadmap entries

**File:** `docs/devlog/roadmap.md` ( A.0–A.4, inserted between pre-clean Group 3 completion and M2.5)

Five entries (A.0–A.4), each self-contained and executable without recovery context. Each includes objective, scope, hot files list, acceptance criteria, and dependency declaration. Entries are:

- **A.0** — Sourceability refactor: add `main` guard to `scripts/agent-sandbox.sh`
- **A.1** — Data model: unified output format, dispatcher rewrite, `diff_on_exit` repair (covers NDQ-1 and NDQ-2)
- **A.2** — CLI contract: `--channel` flag, routers, new `apply_run`/`draft_run` signatures, Makefile mappings (covers NDQ-3 and NDQ-5)
- **A.4** — `changed-files/` extraction: `write_changed_files` shared helper (covers NDQ-4)
- **A.3** — Documentation alignment: architecture docs unified contract update (covers NDQ-6)

### D-3 — This handover

Consolidated record. Replaces lost-timeline handovers 03–07 and 09.

### D-4 — Updated `recovery-change-a.md`

**File:** `recovery-change-a.md` (created as thin pointer file)

## Narrow design question resolutions

### NDQ-1 — `diff_on_exit` repair shape

**Resolution:** Folds into A.1. The current `diff_on_exit` uses the old code path (sweep commit via `diff_commit_pending`, `BASELINE_SHA` param, `diff_generate` for `staged.diff`). A.1 rewrites it as a thin dispatcher calling `package_branch` — this IS the fix. The empty-output bug is resolved by construction.

**Test gap closure specified in A.1 AC:** A.1 must include an end-to-end test validating `diff_on_exit` produces non-empty output for a session with changes.

### NDQ-2 — Helper unification status

**Resolution:** Did NOT land. Three separate `git diff` invocations exist: `diff_write_changes_diff` in `diff.sh`, `diff_generate` in `diff.sh`, inline diff in `package_diff.sh`. A.1 introduces `write_uncommitted_diff` and `write_all_changes_diff` as shared helpers.

**Helper signature (confirmed in design doc):**
- `write_uncommitted_diff(SANDBOX_DIR, OUTPUT_FILE)` — `git diff HEAD` with untracked staging
- `write_all_changes_diff(SANDBOX_DIR, OUTPUT_FILE)` — `git diff INIT_SHA` with untracked staging

### NDQ-3 — A.0 actual scope

**Resolution:** Scope #1 (sourceability refactor) confirmed — `agent-sandbox.sh` has no `main` guard. Scope #2 (router unit tests) cannot execute because routers don't exist in the live tree. Router introduction is part of A.2 (CLI contract); router tests move to A.2. A.0's scope is reduced to sourceability only.

### NDQ-4 — A.4 (`changed-files/` extraction) status

**Resolution:** A.4 has full scope. `write_changed_files` does not exist in `libs/diff.sh`. Inline changed-files logic remains in `package_diff.sh` only. A.4 is retained in the sequence.

### NDQ-5 — A.2 (CLI contract) status

**Resolution:** Full scope pending. Nothing from the settled A.2 contract has landed. The roadmap entry lists all pending items: `--channel` flag, routers, new function signatures, Makefile flag mappings, absolute-path rejection, stale comment cleanup.

### NDQ-6 — A.3 (documentation alignment) status

**Resolution:** Pre-clean Group 2 covered SESSION_STATE-specific doc updates only (5 files). The unified contract documentation (filename renames, `--channel` flag, router architecture, `SOURCE_DIR` contract) was not covered. Residue requires updating all architecture docs — listed explicitly in A.3's scope.

## Mid-session findings

### Finding 1 — Key input files not present

The following files referenced in the brief were not found in `~/workspace/input/`:
- `20260430-01-study-m2_3_audit.md`
- `20260430-02-study-recovery_investigations.md`
- `recovery-investigations-recovered-state.md`

These were audit and investigation records from the recovery workflow. Their absence did not block the session because:
1. The pre-clean handovers (`20260503-05`, `20260503-06`) and the live tree state provided sufficient information about what pre-clean accomplished
2. The lost-timeline handovers (`20260429-03` through `-09`) provided the design intent
3. `staged.diff` provided the landed state confirmation

No recovery investigation records were needed because the live tree state was conclusively determinable from the handovers and code inspection.

### Finding 2 — Pre-clean scope gaps not absorbable

A.3's scope is significantly larger than what the brief assumed ("the residue from pre-clean"). Pre-clean Group 2 explicitly limited its documentation updates to 5 files related to SESSION_STATE migration. The architecture docs still contain pervasive stale references to `changes.diff`, `staged.diff`, and `BASELINE_SHA`. This is accurately reflected in the A.3 roadmap entry.

### Finding 3 — `session.sh` `resolve_session_dir` removal deferred

The settled design calls for removing `resolve_session_dir` from `session.sh` in favour of the two channel-specific routers. This removal is explicitly listed in A.2's scope (`libs/session.sh` — move or deprecate). The function currently has callers in both `draft_run` (indirectly, via `resolve_session_dir` calls) and `apply_run` (direct path resolution). A.2 must verify all callers are migrated before removal.

### Finding 4 — Section B material surfaced

The handover `20260429-08-design-b_interactive.md` was found in the input directory. It contains the interactive confirmation flag design (Change B). This is out of scope for this session and preserved in `recovery-change-b.md` (deferred). Noted here for visibility.

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/discussions/design_change_a_contract.md` | Created — D-1: Change A contract design document |
| `docs/devlog/roadmap.md` | Added A.0–A.4 entries after pre-clean Group 3 and before M2.5 |
| `docs/devlog/handovers/20260503-07-design-recovery_change_a.md` | Created — D-3: this handover |
| `recovery-change-a.md` | Created — D-4: thin pointer file |

## Deferred items

| Item | Reason | Next destination |
|---|---|---|
| Change B (interactive mode) design | Not yet opened; preserved in `recovery-design-step-b.md` | Future design session per recovery flow |
| A.0–A.4 implementation | Scope defined; ready for impl sessions | A.0 → A.1 → A.2/A.4 parallel → A.3 |
| M2.3 Trigger B | Blocked on A.0–A.4 completion | After A.3 closes |
| `staged.diff` archaeology for Section B | Not needed for A; B's design may reference it | Recovery step B |
| Router unit tests | Routers introduced in A.2; tests scoped there | A.2 |
| `diff_on_exit` end-to-end test gap | Specified in A.1 AC | A.1 |

## Next session

---
[AMENDMENT — 2026-05-06]: Section headers `## Deliverables` and `## Narrow design question resolutions` are non-standard. No canonical 1:1 replacement exists — they carry design-session-specific content. Left unchanged. See 20260506-01-workflow-handover_audit_and_corrections.md.

**A.0 — Sourceability refactor for `agent-sandbox.sh`**

**Session type:** Implementation

**Objective:** Add a `main` guard to `scripts/agent-sandbox.sh` so the file can be sourced without executing dispatch logic.

**Hot files:**
- `scripts/agent-sandbox.sh` — add `main` guard

**Context handover:** This is an ordinary M2.3 implementation session. Read `docs/devlog/roadmap.md`  A.0 and `docs/devlog/discussions/design_change_a_contract.md`. No recovery context, no `staged.diff`, no lost-handover access. The file currently has no `main` guard — the sole task is adding one.

**After A.0:** A.1 (data model). A.1 is the largest entry; it rewrites the packaging pipeline end-to-end.
