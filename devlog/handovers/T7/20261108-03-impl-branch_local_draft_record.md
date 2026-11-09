---
date: 2026-11-08
milestone: T7 - Harness Specialization / Sandbox Persistence
type: Implementation
status: Closed
---

# Handover - Replace `.draft-state` with the branch-local draft record

## Objective

Remove the committed `.draft-state` file and make the draft record a branch-lifetime fact in local git config, so confirm and reject read the record without a metadata-drop transition.

## Scope

This iteration implements the second T7 sub-row, **Replace `.draft-state` with the branch-local draft record**, under **Git boundary and repository state**. It changes the draft record module, the three draft lifecycle workflows, their suites and fixtures, the mutation catalog rows that name the removed code, the current-behaviour reference documents, and two ADR carrier corrections. The ADR decisions are not reopened.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Draft writes `branch.<draft>.agent-sandbox-source` and `.agent-sandbox-fork` before creating the branch, and adds no `.draft-state` commit. | New `test_draft_writes_branch_record` in `tests/test_draft_workflow.sh`. | Agent [x] |
| A failed branch creation clears the recorded keys. | New `test_draft_branch_creation_failure_clears_record`. | Agent [x] |
| Distinct branch identities coexist; an exact branch-ref collision is refused. | Updated `test_draft_allows_distinct_branch_identities` and `test_draft_rejects_same_name_collision`. | Agent [x] |
| Confirm reads the record and merges without a metadata-drop step. | Existing confirm suite with config-backed fixtures. | Agent [x] |
| Confirm refuses a draft branch with no record. | New `test_confirm_rejects_missing_record`. | Agent [x] |
| Confirm's default target is the recorded source; `TARGET_BRANCH` still overrides. | Existing `test_confirm_merges_changes` and `test_confirm_target_branch`. | Agent [x] |
| Reject reads the recorded source and deletes the branch with its record. | Existing reject suite with config-backed fixtures. | Agent [x] |
| Reject with a deleted recorded source prints manual return commands and leaves the draft intact. | New `test_reject_reports_missing_recorded_source`. | Agent [x] |
| Git branch deletion removes the record. | New assertions after confirm and reject: `git config --get` fails. | Agent [x] |
| No executable `.draft-state` carriers remain; historical ADR/statechart mentions stay. | `rg` over `src`, `scripts`, `tests`, and current reference docs. | Agent [x] |
| The ADR and host interface state exact branch-ref identity, not a repo-wide singleton. | `rg` over `docs/adr/diff_packaging.md` and `docs/reference/sandbox_host_interface.md`. | Agent [x] |
| The mutation catalog drops the removed drop-step and state-commit rows and refreshes changed draft/confirm lines. | `rg` over `tests/mutations/catalog.jsonl`; targeted mutation rows. | Agent [x] |
| Suites and the lint umbrella are clean. | `bash scripts/run_tests.sh`; `bash scripts/lint.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Write `branch.<draft>.agent-sandbox-source` and `branch.<draft>.agent-sandbox-fork` before creating the branch; clear both if branch creation fails. | The record must exist for the whole branch life, and a failed creation must leave no inert section. `git branch -D` owns removal for the success path. | `src/libs/draft_state.sh` |
| Detect an existing draft by exact branch-ref identity: `refs/heads/draft/<session-identity>-<branch-slug>-<fork-sha6>`. Do not consult the bundle name, and allow distinct identities to coexist. | The guard already checks the exact ref. The branch name carries the session identity, the branch label and the fork prefix, so it is the one identity source. A bundle basename would add a second identity source. | `src/libs/draft_state.sh`, `scripts/workflows/draft.sh` |
| Confirm reads the record, captures the draft tip as its savepoint, and rebases directly. No metadata-drop step remains. | The record is invariant during the draft, so a drop transition no longer exists and its hung-state class disappears. | `scripts/workflows/confirm.sh` |
| Reject reads the recorded source and refuses with manual return commands when that branch no longer exists. | The record is the only source direction; guessing or detaching would strand the operator on `draft/*`. | `scripts/workflows/reject.sh` |
| Keep the module name `draft_state.sh` and replace its file-record API with the branch-record API. | The roadmap names the module, and a rename would add propagation without changing the record contract. | `src/libs/draft_state.sh` |
| Do not fall back to an old `.draft-state` file. | A compatibility path would retain the removed record and its drop transition. A draft without the branch record is not a draft this version recognizes. | `src/libs/draft_state.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `test_draft_allows_parallel_drafts` pins two simultaneous `draft/*` branches, while the ADR edge-case sentence and `sandbox_host_interface.md` say one active draft without naming the identity; the host interface says one per repo. | design ambiguity and record drift | The documents contradict the exact branch-ref guard and the distinct-identity test. | This iteration: record exact branch-ref identity in both, and keep the test that pins distinct identities. |
| The mutation catalog still names the removed `HEAD` default and divergence warning from the previous iteration. | record drift | Those rows are no-ops and hide the current `draft.sh` lines. | This iteration: refresh the draft/confirm rows and drop the removed drop-step and state-commit rows. |
| `docs/adr/container_host_correspondence_mechanism.md` still says one draft per repo, guarded by `draft-state`. | record drift | A current ADR asserts the removed record and the overbroad identity. | This iteration: state exact branch-ref identity and the branch-local record. |

## Completed

| File | Change |
|---|---|
| `src/libs/draft_state.sh` | Replaced the file-record API with `draft_record_write`, `draft_record_clear`, and record-based validation; removed the state-commit lookup. |
| `scripts/workflows/draft.sh` | Writes the record before branch creation, clears it on creation failure, and adds no metadata commit. |
| `scripts/workflows/confirm.sh` | Reads the record, removes the metadata-drop step, and saves the draft tip as the rollback point. |
| `scripts/workflows/reject.sh` | Reads the recorded source; a missing source prints manual return commands and leaves the draft intact. |
| `tests/test_draft_state.sh` | Rewritten around the branch record, exact-ref collision, field invariants, and eval escaping. |
| `tests/test_draft_workflow.sh` | Record, creation-failure, and distinct-identity tests; commit counts and fork assertions updated. |
| `tests/test_confirm_workflow.sh` | Config-backed fixtures, missing-record refusal, and record-removal assertion. |
| `tests/test_reject_workflow.sh` | Config-backed fixture, record-removal assertion, and missing-source arm. |
| `tests/mutations/catalog.jsonl` | Removed five removed-code rows and added the record-write and creation-cleanup rows. |
| `scripts/check_shell.sh` | Removed the obsolete `draft_state.sh` suppression entry. |
| `docs/reference/sandbox_host_interface.md` | Replaced the `draft-state` primitive and per-repo invariant with the branch record and exact branch identity. |
| `docs/reference/tool_interface.md` | Confirm and reject read the branch record; reject names the missing-source behaviour. |
| `docs/reference/sandbox_lifecycle.md` | States exact branch identity and the missing-source reject arm. |
| `docs/reference/draft_branch_statechart.md` | Describes the record as built rather than hypothetical. |
| `docs/adr/diff_packaging.md` | Clarifies that detection is by exact branch ref, not a repo-wide singleton. |
| `docs/adr/container_host_correspondence_mechanism.md` | Removes the stale per-repo/`draft-state` clause. |
| `devlog/roadmap.md` | Marks the sub-row landed. |
| `devlog/handovers/T7/20261108-03-impl-branch_local_draft_record.md` | This handover. |
