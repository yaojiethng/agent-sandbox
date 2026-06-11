# Agent Handover

**Session date:** 2026-05-04
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Study / Implementation
**Status:** Closed

## Objective

Investigate and fix the patch-003 binary diff failure in the draft/apply pipeline, consolidate the duplicated index-stripping filter, revive dead test files, and add missing coverage for binary patch handling.

## Scope

**Confirmed scope (expanded from investigation to include fix + test cleanup):**

1. **Root cause investigation** — trace patch generation (`package_commits`) vs application (`draft_run`, `apply_run`); verify hypothesis with live test.
2. **Extract `strip_index_lines`** into `libs/diff.sh` — consolidate 7 duplicated filter call sites (6× `grep -v '^index '` + 1× inline awk) behind a single function.
3. **Fix the bug** — replace all 7 call sites with `strip_index_lines`.
4. **Fix dead test files** — `test_package_branch.sh` (17 functions, 0 executed) and `test_diff_helpers.sh` (19 functions, 0 executed): add `test_common.sh` sourcing, fix function references, add `run_test` calls.
5. **Clean up redundant tests** — merge 4 artefact-existence tests → 1, merge 4 numbering tests → 1.
6. **Add missing coverage** — 4 `strip_index_lines` unit tests in `test_diff_helpers.sh`; 2 new binary patch tests in `test_package_branch.sh`.
7. **Update knowledge test** — add Section 6 (proving `grep -v '^index '` breaks binary patches) and Section 7 (sequential mixed patches).
8. **Fix `test_draft_workflow.sh` fixture** — replace `grep -v '^index '` with `strip_index_lines`.

**Out of scope:**
- Documentation alignment (A.3) — still deferred.
- Trigger B — blocked by A.3 completion.

## Carried forward

None.

## Acceptance criteria

| Criterion | Status |
|---|---|
| `bash scripts/run_tests.sh` exits 0 | Accepted (242 tests, 241 pass, 1 skip) |
| `bash tests/knowledge/knowledge_binary_diff_apply.sh` exits 0 | Accepted (19 pass, 0 fail) |
| `grep -rn "grep -v.*index" libs/ --include="*.sh"` returns no results | Accepted (0 results in libs/) |
| All test files that were previously dead code now execute their full test suite | Accepted (test_package_branch.sh: 10 tests; test_diff_helpers.sh: 24 tests) |

## Hot files

| File | Why in scope |
|---|---|
| [`libs/diff.sh`](../../libs/diff.sh) | Added `strip_index_lines` function; replaced 2× `grep -v '^index '` |
| [`libs/package_branch.sh`](../../libs/package_branch.sh) | Replaced inline awk filter with `strip_index_lines` call |
| [`libs/draft_workflow.sh`](../../libs/draft_workflow.sh) | Replaced 2× `grep -v '^index '`; added `diff.sh` source |
| [`libs/diff_workflow.sh`](../../libs/diff_workflow.sh) | Replaced 2× `grep -v '^index '`; added `diff.sh` source |
| [`tests/test_diff_helpers.sh`](../../tests/test_diff_helpers.sh) | Added `test_common.sh` source + `run_test` calls + 4 `strip_index_lines` unit tests |
| [`tests/test_package_branch.sh`](../../tests/test_package_branch.sh) | Rewrote from dead code to 10 executing tests; consolidated redundant; added binary tests |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | Fixed `make_real_session` fixture to use `strip_index_lines` |
| [`tests/knowledge/knowledge_binary_diff_apply.sh`](../../tests/knowledge/knowledge_binary_diff_apply.sh) | Added Sections 6 and 7 (grep-v failure + sequential mixed patches) |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `strip_index_lines` lives in `libs/diff.sh`, not a new `filters.sh` | Diff.sh already has the 2 generation-side call sites; all 3 consumer files source it. New module for one function has no depth. | Handover |
| Use `strip_index_lines < file` (stdin redirect) in apply contexts, not process substitution with function call | Simpler invocation; awk reads stdin by default; consistent with pipe use in generation contexts | Handover |
| Fix both generation and application sides | Generation-side bug (diff.sh) is latent today because application also strips, but fixing both prevents regressions if a different consumer reads these files | Handover |
| Fix `test_draft_workflow.sh` fixture | Test patches should match production format | Handover |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `test_package_branch.sh` and `test_diff_helpers.sh` define all their tests but never execute them — no `run_test` calls, no `test_common.sh` source, no production lib sourcing | bug | Both files contributed 0 to the test count. Fixed in this session. |
| `grep -c ... || echo 0` in bash double-prints when no match is found (grep prints "0" + exits 1, then `echo 0` fires) — use `|| true` instead | bug | Fixed in test assertions. |
| `[[ -f "path/"*.diff ]]` in `[[ ]]` context does NOT perform pathname expansion — must use `ls` or array | bug | Fixed in `test_dispatcher_creates_all_artefacts` |

## Completed this session

| File | Change |
|---|---|
| `libs/diff.sh` | Added `strip_index_lines` function; replaced `grep -v '^index '` with calls in `write_uncommitted_diff` and `write_all_changes_diff` |
| `libs/package_branch.sh` | Replaced inline awk filter with `strip_index_lines` call in `package_commits` |
| `libs/draft_workflow.sh` | Added `diff.sh` source; replaced 2× `grep -v '^index '` with `strip_index_lines` calls |
| `libs/diff_workflow.sh` | Added `diff.sh` source; replaced 2× `grep -v '^index '` with `strip_index_lines` calls |
| `tests/test_diff_helpers.sh` | Added `test_common.sh` source and `run_test` calls (24 tests now execute); added 4 `strip_index_lines` unit tests |
| `tests/test_package_branch.sh` | Added `test_common.sh` + `package_branch.sh` sources; added local `make_sandbox`; consolidated 17 ⇒ 10 tests; added binary patch tests; fixed `grep -v '^index '` → `strip_index_lines` |
| `tests/test_draft_workflow.sh` | Replaced `grep -v '^index '` with `strip_index_lines` in `make_real_session` fixture |
| `tests/knowledge/knowledge_binary_diff_apply.sh` | Added Section 6 (grep-v failure on binary) and Section 7 (sequential mixed patches) |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| A.3 — Documentation alignment | Not in scope for this session | Next session |
| Trigger B | Blocked on A.3 completion | After A.3 |

## Next session

**A.3 — Documentation alignment** (from roadmap § M2.3 pending tasks).

**Trigger B status:** Still pending. All A.0–A.5 implementation tasks are now complete (including the binary filter fix that was discovered mid-stream). A.3 (documentation) is the last block before Trigger B can fire.

**Blocking design questions for A.3:**
- None. The system is fully implemented; A.3 is purely documentation.

**Watch-out items for A.3:**
1. Layout changed to `session-diffs/{session,autosave}/<SESSION_TS>-<BRANCH>/` — update all folder path descriptions in architecture docs
2. Routers live in `libs/routing.sh`, not inline in `agent-sandbox.sh` — update `tool_interface.md` accordingly
3. `diff_on_exit`/`diff_on_autosave` replaced by `diff_export` + `session_export_path` — update `sandbox_lifecycle.md`
4. `changes.diff` → `uncommitted.diff`, `staged.diff` → `all-changes.diff` throughout docs
5. `strip_index_lines` function now in `libs/diff.sh` — mention in architecture docs as the single authority on index-line handling
6. Test files `test_package_branch.sh` and `test_diff_helpers.sh` are now live — update any stale references in docs

**Grep at session start:**
```
grep -rn "changes.diff\|staged.diff\|diff_on_exit\|diff_on_autosave\|diff_commit_pending\|BASELINE_SHA\|resolve_session_dir" docs/ --include="*.md"
```

**Conclusions from this session:**
- Root cause confirmed: `grep -v '^index '` strips index lines from binary patches → `git apply` rejects them.
- Fix: extract `strip_index_lines` (selective awk filter) into `libs/diff.sh`; use consistently in all 7 call sites.
- `test_package_branch.sh` and `test_diff_helpers.sh` were dead code (no `run_test` calls) going back to their creation. Now fully executing.
- Knowledge test now covers the specific failure mode (Section 6) and sequential mixed patches (Section 7).
- 242 automated tests pass (241 pass, 1 skip); 19 knowledge tests pass.

**Context handover for A.3:** The prior implementation handovers are `20260504-01-impl-cli_contract_channel_flag_routing.md` (A.2) and `20260504-02-design-host_path_resolution.md` (A.5 design). The binary filter fix is recorded here. No architecture docs have been updated to reflect the unified output format or the `strip_index_lines` function — that is A.3's scope.
