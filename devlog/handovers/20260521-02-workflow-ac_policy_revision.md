# Agent Handover

**Date:** 2026-05-21
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Workflow
**Status:** Closed

## Objective

Revise the acceptance criteria policy rules across three documents based on lessons from the dry-run bugfix session: document the `bash -n` blind spot, adopt a delta-based AC model, require paired checks for renames, and expand the testing policy to cover all file types in `tests/knowledge/`.

## Scope

Policy amendments to three documents, driven by the following gaps exposed during a bugfix session:

1. **`bash -n` blind spot** — used as a hygiene AC in every session, but does not catch runtime-only bash errors like `local` outside a function.
2. **Universal preconditions used as ACs** — "make test passes clean" and "bash -n passes" appeared in every handover but add no session-specific information.
3. **No paired checks for rename/delete** — the old `dry_run.sh` rename was recorded as complete with "new file exists" but never checked "old file removed."
4. **No companion-file scope for renames** — `diagnose_dry_run.sh` was not renamed alongside the production file.
5. **Testing policy only knew about one file category** — `tests/knowledge/` actually contains three distinct types (knowledge tests, diagnostic scripts, workflow tests) but only `knowledge_*.sh` was documented.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `docs/operations/handover_policy.md` AC template describes delta model with bugfix/feature/rename guidelines + Step 5 includes precondition rule and validation tool blind spot note | ✅ |
| 2 | `docs/operations/iteration_policy.md` AC principle shortened to "describe a delta" | ✅ |
| 3 | `docs/development/testing_policy.md` Knowledge Tests section expanded to 3 documented categories with distinct AC rules | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `docs/operations/handover_policy.md` | AC template rewritten to delta model; Step 5 added precondition rule + validation tool note |
| `docs/operations/iteration_policy.md` | AC principle shortened and tightened |
| `docs/development/testing_policy.md` | Knowledge Tests section replaced with 3-category `tests/knowledge/` Directory section |

## Decisions made this session

| Decision | Rationale |
|---|---|
| AC model: describe a delta, not static state | Every AC frames a before/after observable change. Bugfix: "error X no longer appears." Feature: trace to story pain point or design decision. |
| Verification preference: unit test > integration > manual | Use minimal automation that reliably asserts the delta. |
| Universal preconditions are not ACs | `make test passes clean`, `bash -n passes` gate every session equally — omit from AC table. |
| `tests/knowledge/` has 3 categories, not 1 | Knowledge tests (external tools, not ACs), diagnostic scripts (internal invariants, AC-eligible as regression guards), workflow tests (system behaviour, AC-eligible). |
| Regression guards target the bug class, not the file | One repo-wide grep for all `.sh` files, not a per-file test for each fixed script. |

## Completed this session

| File | Change |
|---|---|
| `docs/operations/handover_policy.md` | AC template rewritten to delta model; Step 5 added precondition rule + validation tool blind spot note |
| `docs/operations/iteration_policy.md` | AC principle shortened: "describe a delta" |
| `docs/development/testing_policy.md` | Knowledge Tests section replaced with 3-category `tests/knowledge/` Directory section |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.7 — Session Identity and Harness Versioning

The settings.json ownership collision fix (M2.7 item 8) is the most-coupled with pending deferred items from earlier sessions.

> **Commit message:** docs: revise acceptance criteria policy based on bugfix learnings
