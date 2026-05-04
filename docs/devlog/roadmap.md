# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules — task granularity, cleanup on completion, section removal — are defined in [`docs/development/roadmap_policy.md`](../development/roadmap_policy.md).

---

## Milestone Summary

| Milestone | Status |
|---|---|
| M1 — Barebones Agent Container | [Complete — see changelog](changelog.md) |
| M1.1 — Interactive Virtual Workspace / Serve Mode | [Complete — see changelog](changelog.md) |
| M1.2 — Sandbox File Isolation & Diff Workflow | [Complete — see changelog](changelog.md) |
| M1.3 — Invocation Cleanup & Onboarding Workflow | [Complete — see changelog](changelog.md) |
| M1.4 — Image Staleness Detection | [Complete — see changelog](changelog.md) |
| M1.5 — Workflow Convergence & Directory Restructuring | [Complete — see changelog](changelog.md) |
| **Two-Layer Architecture** | |
| [M2 — Reasoning/Capability Layer Separation](#m2--reasoningcapability-layer-separation) | In progress |
| M2.1 — General Capability Layer Prototype | [Complete — see changelog](changelog.md) |
| M2.2 — Reasoning Layer Modularisation | [Complete — see changelog](changelog.md) |
| [M2.3 — Apply Workflow: Capability Layer Diff Pipeline](#m23--apply-workflow-capability-layer-diff-pipeline) | In progress |
| [M2.4 — Session and Config Persistence](#m24--session-and-config-persistence) | Complete |
| [M2.5 — Vault Capability Layer Prototype](#m25--vault-capability-layer-prototype) | In progress |
| M2.6 — Session Resume Across Provider Implementations | Not started |
| **Single-Agent Coordination** | |
| [M3 — Autonomous Task Execution, Manual Review Workflow](roadmap_future.md#m3--autonomous-task-execution-manual-review-workflow) | Not started |
| **Multi-Agent Coordination** | |
| [M4 — Metadata Seeding](roadmap_future.md#m4--metadata-seeding) | Not started |
| [M5 — Agent-Assigned Branch Management](roadmap_future.md#m5--agent-assigned-branch-management) | Not started |
| **Multi-Agent Orchestration** | |
| [M6.1 — Task Dispatch](roadmap_future.md#m61--task-dispatch) | Not started |
| [M6.2 — Constraint Enforcement](roadmap_future.md#m62--constraint-enforcement) | Not started |
| [M6.3 — Review & CI/CD Integration](roadmap_future.md#m63--review--cicd-integration) | Not started |
| **Standalone** | |
| [M7 — Safe vs Unsafe Mode (Policy Layer)](roadmap_future.md#m7--safe-vs-unsafe-mode-policy-layer) | Not started |
| [M8 — Skills / Templates](roadmap_future.md#m8--skills--templates) | Not started |

---

## Upcoming Milestones

### M2 — Reasoning/Capability Layer Separation

**Objective:** Separate the harness into a reasoning layer (agent container) and a capability layer (sandbox container, working content, optional MCP server). This is the foundational architectural change that enables vault workflows, webapp workflows, provider swapping, and autonomous task execution. All M1.x architecture documents are hot during this milestone and updated sub-milestone by sub-milestone.

Conceptual model: [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md)
Design rationale: [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md) — Conclusion

#### M2.4 — Session and Config Persistence

**Objective:** Establish the provider config lifecycle — onboarding-time population, copy-in at session start, copy-out at session end — replacing the implicit image-baking convention with an explicit bind-mount model.

**Depends on:** M2.2. **Status:** Complete. Design settled; implementation artifacts applied. Copy-out workflow validated (normal exit + SIGTERM). Acceptance criteria met — see handover `20260407-03-close-m2_4.md`.

**Scope note:** M2.4 established the infrastructure for state to survive between sessions (home directory bind mount, config copy-in/out). It does not define or validate provider-level session resume — the ability to continue a prior conversation. That is scoped to M2.6.

#### M2.3 — Apply Workflow: Capability Layer Diff Pipeline

**Objective:** Redesign the apply workflow to reflect the two-layer model: git-agnostic unified diffs generated from capability layer `sandbox/`, bidirectional diff flow between host and sandbox, draft branch pattern formalised for operator review.

**Depends on:** M2.1. **Status:** In progress.

**Design references:**
- [`docs/discussions/design_diff_and_branch_packaging_workflow.md`](docs/discussions/design_diff_and_branch_packaging_workflow.md) — current design
- [`docs/discussions/design_apply_workflow_and_baseline_advancement.md`](docs/discussions/design_apply_workflow_and_baseline_advancement.md) — prior design, preserved with SUPERSEDED markers

**Completed:**

The two-layer diff pipeline is fully implemented. `package_diff` produces unified diffs from the capability layer for operator `make apply`; `package_branch` packages sandbox commits as numbered per-commit diffs for `make draft`. The draft/confirm/reject workflow is operational: `make draft` resolves the latest session export, creates a typed draft branch with `.draft-state` as the first commit, and applies patches sequentially via `git apply`; `make confirm` drops the state commit, rebases onto target, and fast-forward merges; `make reject` returns to the source branch cleanly. Session artefact directories use 2-field names (`<SESSION_TS>-<SANITIZED_HOST_BRANCH>`), with `session/` and `autosave/` subfolders, `EXPORT-TIME.txt`, and unified path resolution across both commands. Checkpoint tags and `make sync` are removed. `INIT_SHA` is written once at container init. All diff output has index lines stripped for context-only `git apply`.

The apply workflow is consolidated under `agent-sandbox.sh`: `draft`, `confirm`, `reject`, and `apply` all resolve through the agent-sandbox entry point, and the deprecated `scripts/apply_workspace.sh`, `libs/draft.sh`, and their tests have been removed.

A durable `sandbox/.git/SESSION_STATE` key-value file persists `session_ts` and `init_sha` across the container lifetime, replacing the standalone `INIT_SHA` file and eliminating malformed artefact paths when environment variables are unset.

The `package-branch` skill instructions were amended to use the container-lifetime boundary framing ("all commits since `init_sha`") and the `SESSION_TS` fallback logic now correctly directs reading from `SESSION_STATE` first, with env-var fallback.

The test suite was fully repaired: all 13 test files pass (248 total assertions), including fixes for stale checkpoint tests, build-context function relocation, Docker-unavailable skip logic, provider-entrypoint environment leakage, `session_state_read` implementation, and `mktemp` hardening across all test files.

**Pending — interactive confirmation flag:**

Both `make apply` and `make draft` lack an operator review step before changes are applied. A shared `--interactive` flag (candidate for shared logic in `libs/session.sh` or equivalent) prints the resolved diff file(s) to be applied — one per line — then prompts for confirmation before proceeding. `make apply` always has one file; `make draft` has one or more. Output format should be consistent between the two commands.

- [ ] Implement `--interactive` flag in `apply_run` and `draft_run` — print resolved diff file list, prompt for confirmation, abort cleanly on rejection; extract print-and-prompt logic as a shared helper
- [ ] Add `--interactive` to `make apply` and `make draft` Makefile targets; update `agent-sandbox.sh` to pass the flag through
- [ ] Test interactive mode for both commands: confirmation proceeds, rejection aborts without applying, file list matches resolved session

**Design note — host→container direction:**

The two-layer model includes a host→container direction: operator runs `package-diff` on the host to push amendments into a running container session. This direction is present in the design but intentionally not implemented — no current use case warrants it. Not planned unless a concrete use case emerges.

**Acceptance criteria:**

- `scripts/apply_workspace.sh` does not exist; `agent-sandbox` is the sole entry point for `draft`, `confirm`, `reject`, `apply`
- `libs/session.sh`, `libs/draft_workflow.sh`, `libs/diff_workflow.sh` exist; `libs/draft.sh` does not exist
- `tests/test_draft_workflow.sh` and `tests/test_diff_workflow.sh` pass clean; `tests/test_apply.sh` and `tests/test_apply_workspace.sh` do not exist
- `grep -rn "apply_workspace" .` returns no results outside `docs/` (i.e. no caller references it and no stale archive links in implementation code)
- `make apply --interactive` and `make draft --interactive` print the resolved diff file list and prompt before applying; aborting at the prompt leaves the project directory unchanged
- diff and draft workflows produce correct artefact paths after tests have been run inside the container — verified by unsetting `$SESSION_TS` in the shell and confirming `SESSION_STATE` is read as fallback
- `sandbox/.git/SESSION_STATE` exists at container init and contains `session_ts` and `init_sha` keys; `sandbox/.git/INIT_SHA` does not exist
- `make test` runs all `tests/test_*.sh` files and exits 0 when all pass, 1 when any fail; `tests/libs/` files are not executed

**Pending — test infrastructure:**

Design complete — see `docs/discussions/spec_test_infrastructure.md`. Depends on the apply_workspace refactor establishing `tests/libs/`, `test_draft_workflow.sh`, and `test_diff_workflow.sh` before these are added. Recommended after test suite repair so the runner has a clean baseline.

- [x] Write `scripts/run_tests.sh` — discovers and runs all `tests/test_*.sh` files in a subshell, prints per-file pass/fail and totals, exits 1 if any fail; excludes `tests/libs/`
- [x] Add `make test` target calling `scripts/run_tests.sh`; verify no conflict with existing targets before adding
- [x] Write `scripts/check_test_coverage.sh` — given changed file paths as arguments, greps `tests/` (excluding `tests/libs/`) for references and prints which test files cover each; explicitly reports files with no coverage

**Pending — pre-clean remediation:**

These tasks address discrepancies between documented M2.3 acceptance criteria and the live tree — changes claimed in handovers that are not present or are incomplete. They must be resolved before Trigger B can fire.

**Dependency ordering:** Group 1 must execute first (SESSION_STATE data model change; first task leaves the tree red until the third restores it). Group 2 is independent. Group 3 must follow Group 1.

**Group 1 — SESSION_STATE/INIT_SHA migration (complete):** The container-init SESSION_STATE key-value store is fully operational. `session_state_write` and `session_state_read` are symmetric; `snapshot_init_git` records both `init_sha` and `session_ts` via SESSION_STATE; all consumers (`diff.sh`, `package_diff.sh`) read from SESSION_STATE instead of a standalone `INIT_SHA` file; the `INIT_SHA` file is no longer created or expected. All test fixtures write to `.git/SESSION_STATE` and verify `.git/INIT_SHA` is absent. Tree green (256 tests, 0 failed).

**Group 2 — Documentation and stale file cleanup (complete):** All 5 documentation files updated to reflect the post-SESSION_STATE codebase: `sandbox_lifecycle.md`, `design_diff_and_branch_packaging_workflow.md`, `project_index.md`, `sandbox.Dockerfile`, and `roadmap.md` (stale duplicate removed). `baseline.tar` removed from git tracking and ignored; `apply_workspace.sh` and `draft.sh` entries cleared from `project_index.md`; all `.sh` entries in the index correspond to tracked files.

**Group 3 — Test coverage additions:**

These tasks must run after Group 1 (they test SESSION_STATE behaviour).

- [x] **Add session_state_read tests and clean up dead env-var fallback.** Added 4 test functions (5 assertions) covering existing key, missing file, missing key, and malformed file to `tests/test_session.sh`. Removed dead `SESSION_TS="${SESSION_TS:-}"` fallback from `libs/package_diff.sh` — the local assignment shadows the outer env var, making the fallback a no-op.
  **AC:** `grep -c "session_state_read" tests/test_session.sh` shows 4+ test assertions; `grep -c "\${SESSION_TS:-}" libs/package_diff.sh` returns 0.

**Pending — Change A: unified output format and CLI contract:**

These tasks implement the unified output format, `--channel` CLI contract, router extraction, and documentation alignment defined in `design_change_a_contract.md`. Each entry is self-contained and executable without recovery context. All four must complete before Trigger B can fire.

**Dependency ordering:** A.0 (sourceability) must execute before A.1 (it's needed for testability, though A.1 tests do not depend on it directly). A.1 must execute before A.2 and A.4. A.2 and A.4 can execute in parallel after A.1 completes. A.3 must follow all of A.1, A.2, and A.4 since it documents the system as built.

---

#### A.0 — Sourceability refactor for `agent-sandbox.sh` (complete)

**Objective:** Make `scripts/agent-sandbox.sh` sourceable so that workflow functions defined within its dispatch logic can be unit tested directly. Currently the file executes top-level code on source (sets `set -euo pipefail`, sources libs, dispatches via `case`), which cannot be sourced without side effects.

**Scope:**
- Add a `main` guard (or equivalent) to `scripts/agent-sandbox.sh`: wrap the dispatch and top-level execution code in a function or guard condition, so sourcing the file defines functions without executing dispatch logic
- The guard must preserve existing behaviour when the file is executed directly (`bash scripts/agent-sandbox.sh apply ...`)
- No other code changes — this task is strictly a sourceability refactor

**Hot files:**
| File | Change |
|---|---|
| `scripts/agent-sandbox.sh` | Add `main` guard |

**Acceptance criteria:**
1. `bash -c "source scripts/agent-sandbox.sh; echo OK"` exits 0 and prints "OK" (file is sourceable)
2. `bash scripts/agent-sandbox.sh` (no subcommand) exits 1 with usage error (existing behaviour preserved)
3. `bash scripts/agent-sandbox.sh onboard --help` still forwards to `onboard.sh` (dispatch works when executed directly)
4. `scripts/run_tests.sh` exits 0 (tree green, no regressions)

**Test additions:**
- None for this task; the sourceability check is validated by the ACs above
- Router tests (which require sourceability) are scoped to A.2 where the routers are introduced

---

#### A.1 — Data model: unified output format, dispatcher, `diff_on_exit` repair

**Objective:** Restructure all diff packaging around a single unified output format. Rewrite `package_branch.sh` as a dispatcher orchestrating `package_commits`, `write_uncommitted_diff`, `write_all_changes_diff`, and `write_changed_files`. Rewrite `diff_on_exit` and `diff_on_autosave` as thin wrappers calling `package_branch` — no sweep commit, no `BASELINE_SHA` parameter. This is the largest entry in the sequence.

**Design reference:** `docs/devlog/discussions/design_change_a_contract.md` § 2–3, § 6.

**Scope:**

*Files to change:*
- `libs/diff.sh` — remove `diff_commit_pending`, `diff_generate`, `diff_format_patch` (old functions); add `write_uncommitted_diff` and `write_all_changes_diff`; rewrite `diff_on_exit` and `diff_on_autosave` as thin dispatchers calling `package_branch`; change signature: drop `BASELINE_SHA` param, read `init_sha` from `SESSION_STATE`
- `libs/package_branch.sh` — extract `package_commits` from old `package_branch` logic; rewrite `package_branch` as dispatcher calling `package_commits` + `write_uncommitted_diff` + `write_all_changes_diff` + `write_changed_files`; read `init_sha` from `SESSION_STATE`; source `diff.sh` at top level; **preserve the existing `BASH_SOURCE` main guard** so the file remains both directly executable and sourceable (used via `bash /opt/sandbox/lib/package_branch.sh` from `agent/prompts/package-branch.md`)
- `libs/package_diff.sh` — rename `changes.diff` → `uncommitted.diff`; remove `--baseline` flag and `resolve_baseline` function; use `git diff HEAD` as canonical; call `write_changed_files` (shared helper) instead of inline copy logic; **add a `BASH_SOURCE` main guard** — currently missing; file must remain directly executable (invoked as `bash /opt/sandbox/lib/package_diff.sh` from `agent/prompts/package-diff.md`) while also being sourceable as a library
- `libs/sandbox-entrypoint.sh` — remove `BASELINE_SHA` variable; update `diff_on_exit` / `diff_on_autosave` calls to match new 3-arg signature
- `libs/snapshot.sh` — already writes to `SESSION_STATE`; verify no `INIT_SHA` file writes remain

*Test files to update:*
- `tests/test_diff.sh` — remove `diff_commit_pending` tests; add tests for `write_uncommitted_diff`, `write_all_changes_diff`; rename `changes.diff` → `uncommitted.diff`, `staged.diff` → `all-changes.diff` in assertions; add `SESSION_STATE` setup; verify `patches/` subfolder; verify no sweep commit; **add end-to-end test for `diff_on_exit` non-empty output** (NDQ-1 test gap)
- `tests/test_package_branch.sh` — update for dispatcher pattern: `patches/` subfolder, `uncommitted.diff`, `all-changes.diff`, `write_changed_files`; extract `package_commits` tests
- `tests/test_package_diff.sh` — update for `uncommitted.diff` rename and `write_changed_files` shared helper
- `tests/test_snapshot_container.sh` — already has `SESSION_STATE` tests; verify no `INIT_SHA` assertions remain

**NDQ-1 resolution:** The empty `diff_on_exit` bug folds into this entry. Root cause: the old code path (sweep commit, `BASELINE_SHA` param) cannot produce output when called from the restructured entrypoint. A.1's rewrite as a thin dispatcher resolves the defect by construction. The test gap (no end-to-end `diff_on_exit` test) is closed by AC #5 below.

**NDQ-2 resolution:** Three separate `git diff` invocations exist (`diff_write_changes_diff` in `diff.sh`, `diff_generate` in `diff.sh`, inline diff in `package_diff.sh`). A.1 extracts `write_uncommitted_diff` and `write_all_changes_diff` as shared helpers called from all three sites.

**Hot files:**
| File | Change |
|---|---|
| `libs/diff.sh` | New helpers; remove old functions; thin dispatchers |
| `libs/package_branch.sh` | Dispatcher rewrite with `package_commits` extraction |
| `libs/package_diff.sh` | Rename `changes.diff` → `uncommitted.diff` |
| `libs/sandbox-entrypoint.sh` | Drop `BASELINE_SHA` variable; update call signatures |
| `tests/test_diff.sh` | New tests; rename assertions |
| `tests/test_package_branch.sh` | Dispatcher tests |
| `tests/test_package_diff.sh` | `uncommitted.diff` tests |

**Acceptance criteria:**
1. `scripts/run_tests.sh` exits 0 (all tests pass)
2. `package_branch` writes `patches/*.diff`, `uncommitted.diff`, `all-changes.diff`, and `changed-files/` to output directory
3. `diff_on_exit` produces `session/uncommitted.diff`, `session/all-changes.diff`, `session/patches/*.diff`, `session/changed-files/` — no `session/changes.diff`, no `session/staged.diff`, no sweep commit
4. `diff_on_autosave` produces `autosave/uncommitted.diff`, `autosave/patches/*.diff` — no `autosave/changes.diff`
5. `diff_on_exit` produces **non-empty output** for a session with changes (end-to-end test, NDQ-1 gating)
6. `package_diff.sh` writes `uncommitted.diff` (not `changes.diff`) and `changed-files/`
7. `sandbox-entrypoint.sh` has no `BASELINE_SHA` variable or reference to it
8. `write_changed_files` helper exists in `libs/diff.sh` and is called from both `package_branch` and `package_diff.sh`

**Depends on:** A.0 (sourceability — optional but recommended for test setup clarity)

---

#### A.2 — CLI contract: `--channel` flag and routing

**Objective:** Restructure `apply` and `draft` CLI contracts around a single `--channel` flag. Add router functions in `agent-sandbox.sh`. Make `--session` name-only (reject absolute paths). Update `draft_run` / `apply_run` to the file-path / `SOURCE_DIR` contract. Add Makefile flag mappings.

**Design reference:** `docs/devlog/discussions/design_change_a_contract.md` § 4.

**Scope:**

*Files to change:*
- `scripts/agent-sandbox.sh` — add `--channel` flag parsing with values `session`, `autosave`, `bundles` (draft) and `diffs`, `autosave`, `session` (apply); add `resolve_source_for_draft` and `resolve_diff_for_apply` router functions; add absolute-path rejection for `--session`; update `apply`/`draft` dispatch to call routers then pass resolved paths to workflow functions
- `libs/diff_workflow.sh` — rewrite `apply_run` to take file path directly (4 args: PROJECT_DIR, DIFF_FILE, BRANCH, FORCE); no hardcoded filename; no session resolution
- `libs/draft_workflow.sh` — rewrite `draft_run` to take SOURCE_DIR + SESSION_NAME (6 args); apply `patches/*.diff` sequentially, then `uncommitted.diff` if present; remove `resolve_session_dir` calls (router handles resolution)
- `libs/_templates/Makefile.template` — add `AUTOSAVE=1` → `--channel=autosave`, `BUNDLE=1` → `--channel=bundles` mappings; update `apply` and `draft` Makefile targets
- `libs/session.sh` — move `resolve_session_dir` to `agent-sandbox.sh` or mark as deprecated (it's replaced by channel-specific routers)
- `scripts/onboard.sh` — update stale `staged.diff` / `changes.diff` comments
- `libs/sandbox-entrypoint.sh` — update stale `staged.diff` / `autosave.diff` comments
- `libs/dirs.sh` — update stale comment about output format

*Test files to update:*
- `tests/test_diff_workflow.sh` — rewrite tests for new `apply_run` contract (file-path input, no resolution logic)
- `tests/test_draft_workflow.sh` — update test calls for new `draft_run` signature; add `test_draft_applies_uncommitted_diff`
- `tests/libs/session_fixtures.sh` — rename `changes.diff` → `uncommitted.diff` in fixtures; add `all-changes.diff`
- `tests/test_session.sh` — update or remove `resolve_session_dir` tests if function moves/deprecated
- Add **router unit tests** for `resolve_source_for_draft` and `resolve_diff_for_apply` — these are the first unit tests that require `agent-sandbox.sh` to be sourceable (which A.0 provides)

**NDQ-3 resolution:** A.0's scope is reduced to sourceability only (scope #1 confirmed). Router unit tests (scope #2) are absorbed into A.2 since the routers are introduced here. A.0 does not include router tests.

**NDQ-5 resolution:** Full scope pending — nothing from the settled A.2 contract has landed in the live tree. The list above is the full scope.

**Hot files:**
| File | Change |
|---|---|
| `scripts/agent-sandbox.sh` | `--channel` flag; routers; absolute-path rejection |
| `libs/diff_workflow.sh` | `apply_run` 4-arg file-path contract |
| `libs/draft_workflow.sh` | `draft_run` SOURCE_DIR + SESSION_NAME contract |
| `libs/_templates/Makefile.template` | AUTOSAVE/BUNDLE flag mappings |
| `tests/test_diff_workflow.sh` | New apply_run tests |
| `tests/test_draft_workflow.sh` | New draft_run tests |

**Acceptance criteria:**
1. `scripts/run_tests.sh` exits 0
2. `make draft` (no flags) resolves `--channel=session`, finds latest session export under `$CHANGES_DIR/`, applies `patches/*.diff` then `uncommitted.diff` if present
3. `make draft BUNDLE=1` resolves `--channel=bundles`, finds latest bundle export under `$OUTPUT_DIR/bundles/`
4. `make apply` (no flags) resolves `--channel=diffs`, finds latest `uncommitted.diff` under `$OUTPUT_DIR/diffs/`
5. `make apply AUTOSAVE=1` resolves `--channel=autosave`, finds latest `uncommitted.diff` under `$CHANGES_DIR/<session>/autosave/`
6. `--diff=<path>` bypasses all channel resolution; `--session=<name>` rejects absolute paths with clear error
7. `draft_run` applies `patches/*.diff` sequentially then `uncommitted.diff` if present (no other files processed)
8. `apply_run` applies any file path passed to it (no hardcoded filename)
9. Router unit tests exist for both `resolve_source_for_draft` and `resolve_diff_for_apply`, covering: default channel, explicit channel, name-only session, absolute-path rejection, missing session
10. Stale `staged.diff` / `changes.diff` references removed from `onboard.sh`, `sandbox-entrypoint.sh`, `dirs.sh`

**Depends on:** A.0 (sourceability), A.1 (unified output format — output files must exist for routing to resolve)

---

#### A.4 — `changed-files/` extraction and verification

**Objective:** Extract the inline `changed-files/` copy logic from `libs/package_diff.sh` into a shared `write_changed_files` function in `libs/diff.sh`. Wire it into both the `package_branch` dispatcher and `package_diff.sh`. Update tests.

**Design reference:** `docs/devlog/discussions/design_change_a_contract.md` § 3 (`write_changed_files`).

**NDQ-4 resolution:** `write_changed_files` does not exist in `libs/diff.sh`. Inline changed-files logic is still in `package_diff.sh` only. A.4 has full standalone scope and is retained in the sequence.

**Scope:**
- `libs/diff.sh` — add `write_changed_files(SANDBOX_DIR, SINCE_SHA, OUTPUT_DIR)` — two-source file list (`git diff --name-only SINCE_SHA` + `git ls-files --others --exclude-standard`), deduplication via `sort -u`, working tree copies preserving structure, deleted files skipped, empty cleanup; update function list in header
- `libs/package_branch.sh` — dispatcher calls `write_changed_files` after `package_commits` + `write_uncommitted_diff` + `write_all_changes_diff`; source `diff.sh` at top level (move existing source if needed)
- `libs/package_diff.sh` — replace inline 3-source copy logic with single `write_changed_files` call using `SINCE_SHA=HEAD`
- `tests/test_package_branch.sh` — 4 new tests: manifest, copies, uncommitted, dedup
- `tests/test_package_diff.sh` — 3 new tests: manifest, copies, untracked

**Hot files:**
| File | Change |
|---|---|
| `libs/diff.sh` | New `write_changed_files` function |
| `libs/package_branch.sh` | Call `write_changed_files` in dispatcher |
| `libs/package_diff.sh` | Replace inline copy logic with helper call |
| `tests/test_package_branch.sh` | 4 changed-files tests |
| `tests/test_package_diff.sh` | 3 changed-files tests |

**Acceptance criteria:**
1. `scripts/run_tests.sh` exits 0
2. `write_changed_files` exists in `libs/diff.sh`
3. `package_branch` output includes `changed-files/` directory with file copies and `MANIFEST.txt`
4. `package_diff.sh` output includes `changed-files/` directory (sourced from same helper)
5. Deleted files are not copied (skipped gracefully, not an error)
6. Untracked files appear in `changed-files/` (not skipped)
7. Deduplication: a file modified and untracked appears once in `changed-files/`

**Depends on:** A.1 (unified output format provides the `package_branch` dispatcher shape; `write_changed_files` is called alongside the other helpers)

---

#### A.3 — Documentation alignment

**Objective:** Update all architecture and development documents to describe the system as built after A.1, A.2, and A.4. Remove stale references to `changes.diff`, `staged.diff`, `BASELINE_SHA`, absolute `--session` paths, and sweep commits. Add recovery snippets for the new contract.

**Design reference:** `docs/devlog/discussions/design_change_a_contract.md` (full document).

**NDQ-6 resolution:** Pre-clean Group 2 covered SESSION_STATE-specific doc updates only (5 files: `sandbox_lifecycle.md`, `design_diff_and_branch_packaging_workflow.md`, `project_index.md`, `sandbox.Dockerfile`, `roadmap.md` stale duplicate). The unified contract documentation (filename renames, `--channel` flag, router architecture, `SOURCE_DIR` contract, `write_changed_files`) was not covered. Residue requires updating all architecture docs.

**Scope:**
- `docs/architecture/execution_model.md` — rename `changes.diff` → `uncommitted.diff`, `staged.diff` → `all-changes.diff` in directory tree and mermaid diagrams; add `changed-files/` to directory tree
- `docs/architecture/sandbox_lifecycle.md` — remove sweep commit description; rename filenames; update `make apply`/`draft` command descriptions for `--channel`/`--uncommitted.diff`
- `docs/architecture/tool_interface.md` — rewrite `make apply` and `make draft` descriptions for `--channel`, `--session` (name-only), `--diff=<path>` (escape hatch), `AUTOSAVE=1`, `BUNDLE=1`; update `make confirm`/`reject`
- `docs/concepts/sandbox_host_correspondence_model.md` — update correspondence cycle; rewrite command map with new flags and output paths
- `docs/architecture/system_overview.md` — update diff output description; remove "legacy" framing
- `docs/development/project_index.md` — update `Last touched in` for A.1/A.2 files; remove any stale entries found
- `docs/development/testing_policy.md` — rename `staged.diff` → generic "diff files" in anti-pattern examples
- `docs/development/quickstart.md` — recovery section: verify current (pre-clean updated) recovery paths are consistent with unified contract; add snippets for `--channel` and `--diff=<path>` usage if not already present
- `docs/devlog/discussions/design_change_a_contract.md` — verify the design doc is self-consistent (created by this bootstrap session)
- `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` — add forward-reference to `design_change_a_contract.md` for output format and CLI contract details

**Hot files:**
| File | Change |
|---|---|
| `docs/architecture/execution_model.md` | Filename renames; add `changed-files/` |
| `docs/architecture/sandbox_lifecycle.md` | Sweep commit removal; filename renames |
| `docs/architecture/tool_interface.md` | New CLI flags documentation |
| `docs/concepts/sandbox_host_correspondence_model.md` | Command map updates |
| `docs/architecture/system_overview.md` | Output format description |
| `docs/development/project_index.md` | Last-touched updates |
| `docs/development/quickstart.md` | Recovery section consistency check |
| `docs/development/testing_policy.md` | Anti-pattern example renames |

**Acceptance criteria:**
1. `scripts/run_tests.sh` exits 0
2. No stale references to `changes.diff`, `staged.diff`, `BASELINE_SHA`, `diff_commit_pending`, or absolute `--session` paths remain in `docs/` (excluding design discussions that describe the system as it was — these are historical records, not documentation bugs)
3. `execution_model.md` and `sandbox_lifecycle.md` directory trees match the unified format (§ 2 of design doc)
4. `tool_interface.md` documents `--channel`, `--session` (name-only), `--diff=<path>`, `AUTOSAVE=1`, `BUNDLE=1`
5. `design_diff_and_branch_packaging_workflow.md` has a forward-reference to `design_change_a_contract.md`
6. All operator-facing comments in `Makefile.template` are current (verified in A.2)

**Depends on:** A.1, A.2, A.4 (documents the system as built after all three)

---

**Trigger B status:** Not yet fireable. A.0–A.4 must all complete before Trigger B.

#### M2.5 — Vault Capability Layer Prototype

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first, then add MCP server as enhancement. Unblocks KV5.

**Depends on:** M2.1, M2.2, M2.3. **Status:** In progress.

**Scope:** Validate vault workflow with sandbox-only configuration. Evaluate and select MCP server candidate. Build vault capability layer image. Validate binary file handling and KV5 end-to-end.

**Tasks:**

- [ ] Validate vault workflow with sandbox-only configuration: agent accesses vault files directly via `sandbox/`, diff reviewed and applied to vault repo
- [ ] Evaluate MCP server candidates; select one (criteria: licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency — see [`investigation_mcp_server.md`](docs/discussions/investigation_mcp_server.md) candidates table)
- [ ] Build vault capability layer image: extends base capability layer image, adds selected MCP server
- [ ] Configure OpenCode to connect to MCP server; validate it routes vault operations through MCP tools when server is present
- [ ] Validate binary file handling (vault attachments) under selected MCP server
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to vault repo
- [ ] Update `execution_model.md` — document capability layer variants (general vs vault+MCP)

#### M2.6 — Session Resume Across Provider Implementations

**Objective:** Define and implement true session persistence — the ability to resume a prior conversation — for each supported provider. M2.4 established that state survives between sessions; M2.6 defines what resuming that state actually means per provider and how the harness supports it.

**Depends on:** M2.4. **Scope:** Investigation-first. Characterise session file format, export mechanism, and resume invocation for pi, Hermes, and opencode. Design harness support based on findings. Known starting points:

- **pi**: requires explicit `pi export` to write session files; resume requires session ID and specific invocation flags. Neither is currently triggered or passed by the harness.
- **Hermes**: assumed to live-load conversation history from home directory on startup — not validated.
- **opencode**: session persistence mechanism unknown. Requires investigation before any design work.

Each provider may result in a different integration pattern. Investigation findings should be recorded as named investigation documents before implementation begins.

#### M2.7 — Session Identity and Harness Versioning

**Objective:** Establish a stable, content-addressed identity model for sessions, containers, and the harness itself — eliminating stale image regressions, timestamp drift, and the lack of provenance tracing for session artefacts.

**Depends on:** M2.3. **Status:** Not started.

**Design reference:** [`docs/discussions/design_session_identity_hash_based.md`](docs/discussions/design_session_identity_hash_based.md)

**Scope:** Implement the hash-based session identity model, two-sig model, and container lifecycle redesign. Work falls into four groups:

**1. run_id derivation** (`scripts/start_agent.sh`): Add `RUN_ID` as 6-char hex hash of `${SESSION_TS}:${REPO_COMMIT}:${WORKTREE_ID}`. Replace timestamp-based container naming with run_id-based naming (`sandbox-<project>-<runid>`, `<provider>-<project>-<runid>`).

**2. Docker labels** (`libs/docker-compose.yml`): Add `agent-sandbox.project`, `agent-sandbox.worktree-id`, `agent-sandbox.run-id` labels for container lifecycle management. Retain `agent-sandbox.session-name` for backwards compatibility.

**3. make stop redesign** (`scripts/stop.sh`): Update to filter containers by `project + worktree-id` labels instead of Docker Compose project name. Enables parallel sessions from different worktrees without container collision.

**4. make prune implementation** (`scripts/prune.sh`, `libs/_templates/Makefile.template`): Add `make prune` target with:
   - Targeted cleanup: `project + worktree-id` (same scope as stop)
   - Time-based cleanup: `project + >3 days old` (ignores worktree-id)
   - Cleans: build cache, layer cache, system cache, volume cache

**5. Two-sig model** (`libs/containers.sh`, `scripts/start_agent.sh`): container-sig = hash(libs/ + providers/<n>/base.Dockerfile + providers/<n>/provider.Dockerfile) baked as Docker label agent-sandbox.container-sig at build time, checked at preflight — mismatch triggers rebuild; harness-sig = hash(scripts/ + providers/<n>/setup.sh + providers/*.yml + providers/<n>/*.yml) computed at runtime, compared against SANDBOX_DIR/.harness-sig.ref written at session end — mismatch warns only.

**6. Paired refactor** (`libs/`, `providers/`): move libs/docker-compose.yml and libs/docker-compose.dry-run.yml into providers/ so the harness-sig hash boundary matches the folder boundary. Image rename dropping <project> suffix (sandbox, <provider>-agent) — blocked on prerequisite code review: verify agents.md is not COPY-ed in any provider Dockerfile before proceeding.

**Sub-stories:**

- `story_parallel_sessions_worktree.md` — Resolved. WORKTREE_ID and checkpoint tag namespace implemented in M2.3 Change 1. Container naming updated in M2.7.
- `story_harness_packaging_and_install_versioning.md` — install workflow rewrite; deferred, does not block this milestone.

---

## Future Milestones

Detail sections for M2 onward are in [`roadmap_future.md`](roadmap_future.md). The summary table above links directly to each section.

Milestone definitions in `roadmap_future.md` are planning targets and expected to evolve. When a milestone becomes active, its section is promoted into this file under `## Upcoming Milestones`.

---

## Notes

- **Core minimum usable system:** M1 + M1.1 + M1.2
- M2 introduces the two-layer architecture; all current single-container architecture docs are hot during M2
- M3 introduces structured autonomy on top of the two-layer foundation
- Manual review remains mandatory until automation is formally trusted
- Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../architecture/security.md).

---

## Known Limitations

- **Submodules not supported** — `snapshot_enumerate_files` detects gitlink entries and aborts with a clear message. Full submodule support (recursive enumeration into nested repos) is deferred; operators must deinitialise submodules before running the harness.

- **Bad diff applied to host repo corrupts future snapshots** — `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`, so a bad run cannot corrupt the host repo during execution. The risk is after the operator applies a bad diff — the host repo is then in a bad state and future snapshots reflect it. See [Recovery](#recovery) in `docs/development/quickstart.md` for how to reset to a known-good state.

- **`make start opencode` and `make start hermes` do not share a capability layer** — each provider invocation builds and runs its own capability layer image independently. They should share a single capability layer per project, since the sandbox, snapshot pipeline, and diff pipeline are provider-agnostic. This is a known architectural gap; resolving it requires the capability layer build and lifecycle to be fully decoupled from the provider selection path. The image rename in M2.7 (dropping the `<project>` suffix) is a prerequisite step toward this.

- **Multi-service project composition not supported** — projects that run multiple services (e.g. a web app with a database and test containers) have no mechanism to inject additional services alongside the harness-managed sandbox and agent. A deferred design task is to define a composition method — likely an operator-supplied overlay that `start_agent.sh` merges with the generated base — that lets projects define their own containers without forking the harness template. See `execution_model.md` for the deferred discussion.

### Addressed in upcoming milestones

- **Stale container images** *(M2.7)* — the preflight gate currently checks only whether an image exists, not whether it was built from the current source. M2.7 introduces `container-sig` (hash of `libs/` and provider Dockerfiles, baked as a Docker label) checked at preflight, and `harness-sig` (hash of `scripts/` and compose files) checked at runtime with a warning on drift. See [`design_session_identity_hash_based.md`](discussions/design_session_identity_hash_based.md).

- **No automated Makefile or harness script staleness check** *(M2.7)* — `harness-sig` written to `SANDBOX_DIR/.harness-sig.ref` at session end will detect host-side script drift on subsequent runs. Full install-level isolation is a larger task deferred to [`story_harness_packaging_and_install_versioning.md`](discussions/story_harness_packaging_and_install_versioning.md).

---

### Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 — Structural Separation — folder ownership, temperature classification, root document audience separation
- [ ] Level 2 — Review Discipline — PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 — Temperature & Freeze Policy — hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 — Change Classification Matrix — explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 — Automated Enforcement — CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents
