# Agent Handover

**Session date:** 2026-05-04
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Update all architecture, concepts, and development documents to describe the system as built after A.1, A.2, A.4, and A.5. Verify drift items: sweep commit elimination and apply semantics.

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

None.

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

## Deferred items

None.

## Next session

**Trigger B — Sub-milestone close for M2.3.**

All A.0–A.5 groups are complete. Trigger B removes the M2.3 section from `roadmap.md`, promotes the next sub-milestone, and updates the changelog. The active handover for reference is this one (`20260504-03-impl-documentation_alignment.md`).

**Watch-out item for Trigger B:**
- A.5 inherited `--all`/`--baseline` flags that were originally documented in prompt templates but not implemented until A.5 — ensure they're included in any acceptance criteria summary
- `test_package_diff.sh` and `test_package_branch.sh` don't source `test_common.sh` and report 0 tests each — pre-existing, not blocking Trigger B

**Conclusions from this session:**
- All architecture, concept, and development docs now describe the system as built after A.1–A.5
- Sweep commit elimination confirmed: `uncommitted.diff` captures unstaged changes without committing
- Apply semantics confirmed: 4-arg `apply_run` applies resolved diff file unstaged; channel determines which diff file is applied
- Bundle/draft identity drift confirmed resolved: router-based resolution correctly extracts SESSION_TS from bundle folder names
