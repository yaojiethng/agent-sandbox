# Agent Handover

**Date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Implementation
**Status:** Closed

> This is **sub-task 2 (of an operator-orchestrated 3-way split)** of session
> `20260812-05`. Task 2 (whitespace round-trip hardening) is now IMPLEMENTED and
> ready to close. Tasks 3 and 1 are Closed and committed separately (see
> `20260812-05`, `20260812-06`; commits `f84beef`, `482dcc6`).

## Objective (Task 2)

Harden the diff pipeline against the proven root cause: a single trailing-whitespace
byte on a line inside a removed block causes `git apply` to reject a whole patch, and the
pipeline produces exactly such patches (it strips trailing whitespace from `-`/`+` line
content during export), so round-trips are fragile. Determine the correct hardening
approach **with the operator** (grilling), then implement.

## Proven root cause (established; do not re-derive)

Fork-base `testing_policy.md` (c5a3f96) **line 237** — a blank line inside the Anti-Pattern 1
"Correct" `make_session()` code block — carries **2 trailing spaces**. The exporter strip
step (`sed -e '/^[+]/ s/[[:space:]]*$//' -e '/^[-]/ s/[[:space:]]*$//'` in
`src/libs/package_branch.sh` ~136, mirrored in `src/libs/diff.sh` ~176/239) collapses that
line to empty in the generated patch. `git apply` requires exact pre-image matching on
removed (`-`) lines, so — even with `--ignore-whitespace` and `-C1` — the hunk is rejected.
Removing that one byte (test C) or normalizing both sides (test B) makes it apply; every
other byte in the rejected region matches.

Key facts:
- `--ignore-whitespace`/`--ignore-space-change` only relax `+`/`-` matching against the
  file's context; the repo's own
  `tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh` documents that git
  apply generally cannot be coaxed for removed-line whitespace drift.
- NOT a fork-base vs generation-base content divergence (the divergence warning is a red
  herring for this failure). The `71bdfb1` generation base is not a reachable commit; it was
  a transient/derived state (`.export-status` records it as `INIT_SHA`).
- FORCE-mode behavior in `src/libs/diff.sh::_apply_patch_file`
  (`git apply --reject ... || echo warning; return 0`) **is deliberate per the operator** —
  it must finish applying everything, not halt. Do NOT change it.

## Minimal repro (reference for the required test)

1. File with a blank line carrying trailing whitespace inside a region a patch **removes**
   (the line-237 shape).
2. Patch generated via the pipeline with that line's whitespace stripped (as
   `package_branch`/`diff.sh` do).
3. `git apply` (even `--ignore-whitespace`, `-C1`) → rejects the hunk.
4. Fixing only that one byte → `git apply` succeeds.

**Operator-directed:** this exact minimal shape MUST be captured as a test (extend
`knowledge_trailing_whitespace_context_mismatch.sh` or add a workflow/draft test). Explicit
acceptance criterion.

## Candidate approaches (for grilling — NOT yet decided)

- **(a) Diagnostic hardening** — on `git apply` reject, detect and report whitespace-only
  mismatches (offending line/byte). Least invasive; no semantic change; turns "patch does
  not apply" into an actionable message. Does not make it apply.
- **(b) Preserve removed-line trailing whitespace in exports** — stop stripping `-`/`+` line
  trailing whitespace so the patch pre-image equals the file. Direct fix, but competes with
  the reason the cleaning exists (clean diffs / whitespace-error hygiene).
- **(c) Apply-time tolerance** — **blocked** (knowledge test): `--ignore-whitespace`/`-C1`
  cannot be coaxed.
- **(d) Other** — e.g. targeted working-tree whitespace normalization of only the files being
  applied (content mutation — risky), or encode the trailing whitespace differently. Decide
  during grilling.

Grill: which layer owns the fix (export vs apply); whether diagnostic-only satisfies
"harden"; whether touching export's strip re-introduces whitespace errors.

## Constraints

- FORCE-mode behavior is deliberate — do not regress it.
- Follow `docs/development/bash-coding-conventions.md`; shellcheck-clean.
- Keep full suite green (`make test` == `bash scripts/run_tests.sh`; baseline
  **475 tests, 28 files, 469 passed, 0 failed, 6 skipped**).
- The `-`/`+`-line strip lives in BOTH `package_branch.sh` and `diff.sh` — changing it is a
  **propagation task** spanning both + consumers/tests.

## Files in scope (Task 2)

| File | Role |
|---|---|
| `src/libs/package_branch.sh` | exporter strip step (~136) — strip sed REMOVED (verbatim export) |
| `src/libs/diff.sh` | strip step (~176/239) — strip sed REMOVED (verbatim export); `_apply_patch_file` FORCE site (deliberate, unchanged); doc comment updated |
| `tests/test_diff_helpers.sh` | **+3 unit tests**: preserves removed-line trailing ws; verbatim round-trip; 8-case funny-whitespace/CRLF matrix |
| `tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh` | **DELETED** (superseded — conveyed stale strip-based approach) |

## Acceptance criteria (Task 2)

- [x] Plan AGREED with operator (grilling/planning gate) — Model 1 (git-verbatim export)
- [x] Minimal whitespace-rejection repro test added — as UNIT tests in `test_diff_helpers.sh` (removed-line trailing ws; verbatim round-trip; 8-class matrix incl. CRLF) — the valuable assertions are in the `make test` suite, not a manual knowledge test (per operator guidance)
- [x] Fix implemented and shellcheck-clean (no NEW findings; pre-existing SC2086/SC1003/SC1091 unchanged)
- [x] Full suite green (before close: **478 tests / 472 passed / 0 failed / 6 skipped**)
- [x] Root cause + chosen approach documented(this handover + this commit)
- [x] Stale knowledge test superseded + deleted (recorded here)

## Completed this session

- [x] Grilled the approach with the operator; agreed **Model 1 — git-verbatim export** (delete the content-strip sed at all 3 export sites; keep `strip_index_lines` metadata strip)
- [x] Empirically established: git apply NEVER refuses trailing whitespace under default `warn` policy; removed-line trailing ws elicits no warning; CRLF/space-only/blank-at-EOF/no-EOF all round-trip byte-perfectly when verbatim
- [x] Audited existing unit tests for strip-dependence (test_package_branch, test_diff_export, test_diff_helpers, test_draft_workflow): none depend on the whitespace-strip; only `strip_index_lines` is asserted (unchanged)
- [x] Removed the strip sed from `package_branch.sh` and `diff.sh` (×2)
- [x] Added 3 unit tests in `test_diff_helpers.sh` (all green)
- [x] Deleted the obsolete `knowledge_trailing_whitespace_context_mismatch.sh` (superseded)
- [x] End-to-end reproduced the exact 0009 scenario: verbatim patch applies (exit 0); old-strip patch → "No valid patches in input"

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | **Model 1 — git-verbatim export**: remove the `sed` content-strip at all 3 sites, keep `strip_index_lines` | the strip mutates patch bytes (trailing ws, and CR via `[[:space:]]`), breaking/ corrupting apply; verbatim fixes all funny-line classes and matches the operator's consistency/no-unrecoverable-mutation principle |
| 2 | Put the valuable round-trip assertions in the **unit suite** (`test_diff_helpers.sh`), not a manual knowledge test | operator: actual, useful tests belong under `make test`; drop knowledge test |
| 3 | **Delete** `knowledge_trailing_whitespace_context_mismatch.sh` | superseded; conveyed stale strip-based approach; useful invariant folded into unit tests |
| 4 | Leave FORCE-mode (`_apply_patch_file`) and the divergence warning unchanged | deliberate per operator/design; out of scope |

## Mid-session findings

| # | Finding | Disposition |
|---|---|---|
| 1 | Trailing-whitespace **linting** is a separate content-sanity concern (`git diff --check`, a markdown/whitespace linter, or a find+grep checker); deliberately out of scope for the patch tool, which is now content-agnostic | **deferred** to a future session (recorded here, not implemented) |
| 2 | git `apply.whitespace` default is `warn`, not `error`; the only hard-refusal path is `apply.whitespace=error` (unset here) — so "clean git apply" never prevented a refusal, only warned | documented; no config change needed |

## Deferred

(none — Task 2's in-scope work only; resolved 05/06 work is committed and out of scope)

## Operational notes for resumption

- Subagents under this harness are bash subshells in the SAME context/workspace as the
  primary; they CAN persist edits and run git. (An older AGENTS.md note claiming they are
  read-only reviewers is INCORRECT — do not act on it.)
- Each handover is Closed + separately committed as it completes (operator directive),
  keeping the workspace clean. Commit-as-close: docs-only = `docs`; code+test fix = `fix`.
- Reference artifacts on disk: raw `0009` patch at
  `output/bundles/20260812-070024-add_format_patch_support-9f8cdc/patches/0009-*.diff`;
  fork-base `testing_policy.md` at `input/testing_policy-c5a3f96.md`.
