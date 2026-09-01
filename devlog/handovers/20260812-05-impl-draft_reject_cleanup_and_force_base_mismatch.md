# Agent Handover

**Date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Implementation
**Status:** Closed

> This is **sub-task 3 (of an operator-orchestrated 3-way split)** of session
> `20260812-05`. The originating investigation (wholesale) is preserved below as
> context; **this handover's own scope is only Task 3 — tidy up the leftover
> `.rej`**. Task 1 (rollback-branch bug) is handover `20260812-06`; Task 2
> (whitespace round-trip hardening) is handover `20260812-07`.

## Objective (Task 3)

Tidy up the leftover `docs/development/testing_policy.md.rej` on the draft
branch and resolve `testing_policy.md` to the patch `0009` intent, so zero
`.rej` files remain. Also remove the incidental GOTCHAS trailing-blank-line
whitespace blemish. Do **not** touch the rollback bug (Task 1) or the whitespace
round-trip hardening (Task 2).

## Files in scope (Task 3)

| File | Action |
|---|---|
| `docs/development/testing_policy.md` | resolve to the `0009` patch intent: removed duplicated how-to sections, added a `## See Also` link to `testing-conventions.md` |
| `docs/development/testing_policy.md.rej` | delete after resolution (this is the sole `.rej`) |
| `devlog/GOTCHAS.md` | remove the single trailing blank line at EOF (whitespace warning from patch `0006`) |

## Out of scope (other tasks)

- Task 1 (handover `20260812-06`): run-1 rollback must restore the source branch (currently only does `git reset --hard`).
- Task 2 (handover `20260812-07`): trailing-whitespace round-trip root cause fix.

## Context for Task 3

The sandbox snapshot is the **post-FORCE draft-branch state** of bundle
`20260812-070024-add_format_patch_support-9f8cdc`: all 10 patches applied, the
`0009` hunk-2 rejection committed as `docs/development/testing_policy.md.rej`.

Patch `0009`'s rejected hunk #2 for `testing_policy.md` (`@@ -273,334 +210,7 @@`)
removed the duplicated how-to sections — `## Common Anti-Patterns`,
`## Test Structure Template`, `## [FINDINGS: 2026-05-22]`, `## Debugging Test
Failures`, `## Checklist for New Tests` (+ Mock Infrastructure) and
`## Checklist for Lib and Script Changes` — which now live in
`docs/development/testing-conventions.md`, replacing them with:

```
## See Also

[`testing-conventions.md`](testing-conventions.md) — fixture patterns, anti-patterns, templates, checklists, and debug steps.
```

The removed sections (incl. the `[FINDINGS: 2026-05-22]` entries) are all recoverable
from the bundle output channel (patch `0009` + `all-changes.diff`), so no content
is permanently lost by applying this intent.

**Warning — do not edit the whitespace char on line 237 of `testing_policy.md`
as part of this resolution unless resolving the `.rej` requires it.** The exact
trailing-whitespace root-cause is Task 2's domain. Task 3's correct result is the
*documented* final content of `testing_policy.md`; resolving it may legitimately
involve the 2-space blank line at line 237, but record any such handling in the
handover so Task 2 can account for it.

## Root cause (established by the originating investigation)

The rejection is a **single trailing-whitespace byte**: fork-base
`testing_policy.md` line 237 (blank line inside Anti-Pattern 1 "Correct" block)
carries 2 trailing spaces; the exporter's strip collapses it to empty, and
`git apply` won't re-match removed lines with whitespace drift. Proven by minimal
repro (details in Task 2 / findings). This means the correct resolved file for
Task 3 must still contain `## Common Anti-Patterns` *removed* and `## See Also`
*added* — i.e. the `.rej`'s new-side intent.

## Acceptance criteria (Task 3)

- [ ] `docs/development/testing_policy.md` reflects the `0009` intent: duplicated how-to sections removed, `## See Also → testing-conventions.md` present
- [ ] `docs/development/testing_policy.md.rej` deleted; `find . -name '*.rej'` returns nothing
- [ ] `devlog/GOTCHAS.md` trailing blank line removed
- [ ] Resolution recorded in the handover (what was removed/added; any handling of the line-237 whitespace flagged for Task 2)
- [ ] the rest of the `testing_policy.md` content (before the removed region) untouched by this task
- [ ] no unrelated changes introduced

## Deferred

- Rollback-branch bug → Task 1 (handover `20260812-06`)
- Whitespace round-trip hardening → Task 2 (handover `20260812-07`)

## Completed this session

- [x] Resolved `docs/development/testing_policy.md` to the `0009` patch intent: removed the duplicated how-to sections (`## Common Anti-Patterns`, `## Test Structure Template`, `## [FINDINGS: 2026-05-22]`, `## Debugging Test Failures`, `## Checklist for New Tests` incl Mock Infrastructure, `## Checklist for Lib and Script Changes`) which now live in `docs/development/testing-conventions.md`, replaced with a trailing `## See Also` block linking to `testing-conventions.md`. File now ends with the See Also block.
- [x] Deleted `docs/development/testing_policy.md.rej`; `find . -name '*.rej'` returns nothing.
- [x] Removed the single trailing blank line at EOF of `devlog/GOTCHAS.md`.
- [x] Confirmed content before the removed region (lines 1–210, through `## Keeping Tests Current` and its `---`) is byte-identical to HEAD; single hunk change only.
- [x] No unrelated changes (diff = the 3 files in scope only).

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Apply the `0009` intent; do not preserve the removed FINDINGS content inline (recoverable from bundle) | operator-confirmed |
| 2 | Task 3 must not touch the rollback bug or whitespace hardening | operator-orchestrated split |
| 3 | Removed the entire duplicated how-to region (line 213 → EOF) including the 2-space blank line at former line 237, matching the `0009` new-side intent from the `.rej` | the `.rej` new-side (331/334) is the authoritative intent; the whitespace line was inside the replaced region, so it was removed with it — flagged for Task 2 |
| 4 | Used the exact See Also block text from the `.rej` new-side (2 added lines: `## See Also` + the `testing-conventions.md` link); left one blank line between the trailing `---` and `## See Also` | match patch formatting exactly; final file ends with the See Also block
| 5 | (orchestrator correction) removed one extra blank line the subagent had left between the trailing `---` and `## See Also` | authoritative `git apply` re-application of patch 0009 (test-C) showed exactly one blank line there; repo docs end with a single newline (no trailing blank), so none was added |

## Reference material (elsewhere on disk)

- Raw `0009` patch: `output/bundles/20260812-070024-add_format_patch_support-9f8cdc/patches/0009-*.diff`
- `all-changes.diff`: same bundle dir
- Fork-base `testing_policy.md`: `input/testing_policy-c5a3f96.md` (input mount)
