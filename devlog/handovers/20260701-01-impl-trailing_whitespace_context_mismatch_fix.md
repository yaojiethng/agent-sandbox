# Agent Handover

**Session date:** 2026-07-01
**Milestone:** M2.6 — Mount Model Redesign
**Session type:** Implementation
**Status:** Closed

## Objective

Diagnose the `make draft FROM=session SESSION=20260622-110323-feat-M2_6_mount_model_redesign-be010a` failure, fix the root cause in the diff pipeline, and document the failure mode.

## Scope

- Diagnose why patch 0001 fails to apply during `make draft`
- Fix the `sed 's/[[:space:]]*$//'` in the diff pipeline that strips trailing whitespace from context lines
- Add Case 7 to `devlog/discussions/story-patch_application_failures.md`
- Write a knowledge test documenting git apply's trailing-whitespace context matching behaviour

## Carried forward

None.

## Acceptance criteria

| AC | Status |
|---|---|
| `sed 's/[[:space:]]*$//'` replaced with `sed -e '/^[+]/ s/[[:space:]]*$//' -e '/^[-]/ s/[[:space:]]*$//'` in all three call sites (`package_commits`, `write_uncommitted_diff`, `write_all_changes_diff`) — verified by grep showing no remaining `sed 's/[[:space:]]*$//'` in `src/libs/package_branch.sh` or `src/libs/diff.sh` | Accepted |
| Knowledge test at `tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh` exists, all 15 assertions pass, exit 0 | Accepted |
| Case 7 entry added to `devlog/discussions/story-patch_application_failures.md` describing root cause, fix, and limitations of `-C1` fallback | Accepted |
| `make test` passes with 0 failures (baseline: 410 passed, 0 failed, 6 skipped) | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/package_branch.sh`](../../src/libs/package_branch.sh) | Contains `sed 's/[[:space:]]*$//'` in `package_commits()` at line 140 |
| [`src/libs/diff.sh`](../../src/libs/diff.sh) | Contains `sed 's/[[:space:]]*$//'` in `write_uncommitted_diff()` (line 81) and `write_all_changes_diff()` (line 144) |
| [`devlog/discussions/story-patch_application_failures.md`](../../devlog/discussions/story-patch_application_failures.md) | Story registry for patch application failure modes; Case 7 added |
| [`tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh`](../../tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh) | New knowledge test documenting trailing-whitespace context matching behaviour |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Strip trailing whitespace from only `+`/`-` lines, not context lines | `sed 's/[[:space:]]*$//'` on context lines breaks `git apply` matching; `-C1` is an insufficient fallback because it fails when ALL nearby context lines have trailing whitespace | `story-patch_application_failures.md` Case 7; knowledge test |
| Not adding `-C1` fallback to `draft_apply_patches` | The fix to the sed addresses the root cause; `-C1` is only conditionally effective and would add complexity without addressing all cases | This handover |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `-C1` works for the specific real-world patch but is NOT a general fix — fails when ALL context lines in a hunk have trailing whitespace | finding | Correctly scoped the fix to the sed pipeline rather than adding `-C1` fallback |
| `strip_all_trailing_ws` serves a real cleanliness purpose (prevents incidental trailing whitespace from appearing as changes) | finding | The fix preserves this by restricting the sed to `+`/`-` lines rather than removing it entirely |
| Existing `tests/libs/session_fixtures.sh` `make_session_fixture` creates `new file` diffs only, not edit hunks — tests using it wouldn't reproduce the trailing-whitespace context mismatch | finding | The knowledge test creates its own fixtures with proper edit hunks |
| `sed -i` with unescaped `*` in basic regex mode (`sed 's/**foo**/bar/'`) causes `Invalid preceding regular expression` | finding | Knowledge test uses `edit_in_file` wrapper with carefully escaped patterns |

## Completed this session

| File | Change summary |
|---|---|
| [`src/libs/package_branch.sh`](../../src/libs/package_branch.sh) | Changed `sed 's/[[:space:]]*$//'` to `sed -e '/^[+]/ s/[[:space:]]*$//' -e '/^[-]/ s/[[:space:]]*$//'` in `package_commits()` (line 140) |
| [`src/libs/diff.sh`](../../src/libs/diff.sh) | Same change in `write_uncommitted_diff()` (line 81) and `write_all_changes_diff()` (line 144) |
| [`devlog/discussions/story-patch_application_failures.md`](../../devlog/discussions/story-patch_application_failures.md) | Added Case 7 with root cause, error message, fix description, and `-C1` limitation analysis |
| [`tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh`](../../tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh) | New knowledge test: 15 assertions across 3 sections (A: problem demonstration, B: fix validation, C: no-degradation check) |

## Deferred items

None.

## Next session

Continue M2.6 Mount Model Redesign — Phase 2 design work on the remaining milestones.

**Conclusions from this session:**
- The diff pipeline's `sed 's/[[:space:]]*$//'` was the root cause of the draft failure, not a problem in the draft workflow itself.
- `--ignore-whitespace` and `--ignore-space-change` do NOT bypass trailing-whitespace context mismatches in `git apply` — they only relax matching for `+`/`-` lines.
- `-C1` is conditionally effective but not a general fix.
- The correct fix is to scope the trailing-whitespace strip to `+`/`-` lines only, which preserves context line fidelity while keeping the cleanliness benefit.
