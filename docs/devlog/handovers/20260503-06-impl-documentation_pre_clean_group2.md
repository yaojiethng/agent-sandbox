# Handover: 20260501-05-impl-documentation_pre_clean_group2

**Session:** 20260501-05
**Type:** Implementation (`impl`)
**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline — Pre-clean remediation
**Status:** Closed
**Branch:** master (commit 7a73bae)

---

## Session objective

Execute **Group 2** of the M2.3 pre-clean remediation — documentation updates and stale file cleanup that bring the documentation tree in line with the current codebase (post-SESSION_STATE migration). Group 2 is documentation-only; no code or test files are modified.

---

## Required reading

- Prior handover: `20260501-04-impl-session_state_migration_group1.md` (closed) — Group 1 completed
- Roadmap: `docs/devlog/roadmap.md` — compacted Group 1, Group 2 tasks under `Pending — pre-clean remediation`
- Policies: `docs/operations/handover_policy.md`, `docs/operations/iteration_policy.md`, `docs/operations/roadmap_policy.md`, `docs/operations/documentation_policy.md`

---

## Recovery checks

- **Trigger B:** Not pending — interactive confirmation flag, Group 2, Group 3 still open under M2.3.
- **Compaction:** Group 1 compacted (replaced 3 checklist items with conceptual outcome sentence).

---

## Scope

### In scope (Group 2 — all 6 tasks)

| # | Task | File(s) to change | Nature |
|---|---|---|---|
| 1 | **Update sandbox_lifecycle.md** | `docs/architecture/sandbox_lifecycle.md` | Replace INIT_SHA write description with SESSION_STATE behaviour; update downstream references |
| 2 | **Remove stale roadmap duplicate** | `docs/devlog/discussions/roadmap.md` (delete), cross-reference fixes in other docs | File deletion, grep-and-update |
| 3 | **Update design_diff_and_branch_packaging_workflow.md** | `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` | Replace INIT_SHA file references with SESSION_STATE key-value store |
| 4 | **Clean up project_index.md** | `docs/development/project_index.md` | Remove deleted-file entries; cross-reference all .sh entries against `git ls-files` |
| 5 | **Remove baseline.tar from git** | `baseline.tar` (git rm), `.gitignore` | File removal, gitignore entry |
| 6 | **Fix sandbox.Dockerfile stale comment** | `libs/sandbox.Dockerfile` (line 47) | Comment update only |

### Not in scope (deferred)

- **Group 3 (test additions)** — deferred to a subsequent session. These require reading and writing test files, which would mix concerns with documentation-only Group 2.
- **Interactive confirmation flag** — requires capability layer to be operational; deferred per roadmap (dormant).
- **Any code changes** — Group 2 is strictly documentation and stale file removal. If a documentation task reveals a code discrepancy, it is flagged but not fixed this session.
- **Architecture documentation beyond the 5 files listed** — only files touched by the SESSION_STATE migration need updating.

### Questions

None — scope is well-defined by the existing roadmap entries.

---

## Key decisions

None yet.

---

## Mid-session findings

None yet.

---

## Completed this session

None yet.

---

## Deferred items

None.

---

## Acceptance criteria

| # | Criterion | Verification |
|---|---|---|
| 1 | `sandbox_lifecycle.md` has no `INIT_SHA` references outside historical-context paragraphs | `grep -c "INIT_SHA" docs/architecture/sandbox_lifecycle.md` returns 0 |
| 2 | Stale roadmap duplicate deleted, cross-references cleaned up | `ls docs/devlog/discussions/roadmap.md` exits 2; `grep -rn "discussions/roadmap.md" docs/` returns no results |
| 3 | `design_diff_and_branch_packaging_workflow.md` has no `.git/INIT_SHA` references | `grep -c "\.git/INIT_SHA" docs/discussions/design_diff_and_branch_packaging_workflow.md` returns 0 |
| 4 | Every `.sh` entry in `project_index.md` (Scripts/Lib/Tests sections) corresponds to a tracked file | `while read f; do git ls-files --error-unmatch "$f" >/dev/null 2>&1 || echo "missing: $f"; done < <(grep -oP '`\K[^`]+\.sh(?=` )' docs/development/project_index.md)` exits 0 |
| 5 | `baseline.tar` is untracked and `.gitignore` has an entry for it | `git ls-files --error-unmatch baseline.tar` exits 1; `grep -c "baseline\.tar" .gitignore` returns >= 1 |
| 6 | `sandbox.Dockerfile` line 47 no longer mentions `staged.diff` | `sed -n '47p' libs/sandbox.Dockerfile | grep -c "staged\.diff"` returns 0 |
| 7 | Architecture documents in scope describe the system as built | All 5 files touched are self-consistent and the SESSION_STATE migration is correctly reflected

---

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline — Pre-clean (continued)

**Context handover:** Group 2 (documentation and stale file cleanup) is complete — 6 tasks, all verified against AC. Tree has no code or test changes.

**Remaining under M2.3:**
- **Group 3 (test additions)** — 1 task: add `session_state_read` tests to `tests/test_session.sh`
- **Interactive confirmation flag** — 3 tasks (dormant, requires capability layer operational)

**Trigger B:** Not pending — Group 3 and interactive flag still open.

**Recommended next scope:** Group 3 (test additions) — standalone, test-only, no dependencies on Group 2.
