# Handover 20260901-10 — fix runner warning path, artefact-path doc drift, AF reconcile

**Milestone:** M2.6 - Session Persistence
**Type:** impl
**Status:** Closed
**Session date:** 2026-09-01

## Objective

Three verified low-hanging fixes in one `fix:` delivery commit (operator
directive):

1. **Runner warning-path bug**: `scripts/run_tests.sh:36` references
   `$PATTERN`, never defined — under the script's `set -u` the
   empty-discovery branch crashes ("unbound variable") instead of warning.
2. **Artefact-path doc drift**: the two identity concept docs state
   contradictory export-folder formats; pin the code truth and align docs
   (and the session-identifier ADR line if wrong).
3. **AF reconcile** per the new preamble rule: two entries whose fixes
   landed after they were written — escalate to probation with a body
   amendment, per operator instruction.

## Acceptance Criteria

- AC1: Empty-discovery runner run prints the warning and exits non-zero
  without an unbound-variable crash; self-test case locks it.
- AC2: Both concept docs (and ADR line if applicable) state the code-true
  artefact folder format.
- AC3: The two AF entries are `state: probation` with reconciliation
  amendments in the body.
- AC4: Single `fix:` commit; handover closed in it; suite shows no new
  failures.

## Completed

- AC1 ✅ `run_tests.sh:36` now references `$TEST_DIR` (was undefined
  `$PATTERN` — an unbound-variable crash under the script's own `set -u`
  on the empty-discovery path). Self-test case 10 locks it: warning
  printed, non-zero exit, no crash. Added `assert_not_contains` helper to
  `test_common.sh` (mirrors `assert_contains`).
- AC2 ✅ Code truth pinned (`routing.sh export_path` + `diff_export.sh`):
  session exports `<EXPORT_TIME>-<SESSION_ID>`, autosave single
  `<SESSION_ID>/` dir, bundles `<EXPORT_TIME>-[<LABEL>-]<SESSION_ID>`;
  `EXPORT_TIME` is a fresh export timestamp, not `SESSION_TS`; branch name
  is not in the path. Aligned: `sandbox_identity.md` Artefact Paths table +
  intro; `sandbox_host_correspondence_model.md` (package-branch row,
  artefact-directory row, diagram lines, non-collision invariant). ADR
  `session_identifier.md` left unchanged — its claim (SESSION_TS not in
  artefact paths) is consistent with the code truth.
- AC3 ✅ Both AF entries (`fixture lifecycle`, `dual-use guards`) escalated
  to probation with `reconciled:` body amendments; guards verified
  end-to-end (start_agent flag parsing is inside `main()`, behind the
  guard).
- AC4: verification — self-test 20/0/0; full suite 773/706/67, the 67
  identical pre-existing docker-absence failures (baseline-established
  in `20260901-08`).

## Findings

- The AF entry "dual-use guards" was partially wrong when written and
  fully stale now; the reconcile check (including re-verifying with a
  correct grep — the first check used a broken pattern and initially
  misconfirmed the entry) is exactly what the new scoping-gate rule is
  for.
- Follow-up candidate (not taken): delete the now-redundant sed-extraction
  probe layer in the three test files and source the guarded scripts
  directly.
