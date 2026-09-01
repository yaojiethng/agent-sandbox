# Handover — 20260831-08-impl prune label reliability (Rule 2 discovery key)

**Status:** Closed
**Iteration:** 20260831-08
**Type:** impl
**Milestone:** M2.6 - Session Persistence
**Predecessor:** 20260831-07 (impl) — single canonical session identity (closed `3ca6ae5`)

## Objective
Make prune's Rule 2 label-only discovery reliable and complete now that the
identity model is a single canonical `SESSION_ID
(sha256(canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS)[:6])`. The operator-visible
bug (iterate 20260831-05): prune showed `.yml` record removal but no resource
removal, because leftover `*-sandbox-data` volumes / dangling resources carry
inconsistent or absent labels and label-only discovery never sees them.

## Identity model context (from 20260831-07)
- `SESSION_ID` is now canonical: every path spelling of one `SANDBOX_DIR`
  folder converges to one id. So the `agent-sandbox.sandbox-dir` +
  `.session-id` label pair is now a reliable, spelling-independent filter key.
- Design doc `20260831-design-active-session_identity_prefactor.md`, ADR
  `session_identifier.md`.

## Constraints (from 20260831-05/06, operator-confirmed)
- **No docker name-pattern matching** (ambiguous across sandboxes, not durable
  under multi-`SANDBOX_DIR`). Matching stays strictly label-based.
- **No shift back to `docker system prune`** (would delete kept sessions'
  unreferenced volumes and break resume).
- One-time host-side cleanup is operator-run by hand (`docker system prune
  -a --volumes -f`), not a destructive diagnostic mode.

## Scope
- IN: settle the Rule 2 discovery key so label-based discovery is reliable and
  complete; relabel and/or canonicalize the resources prune manages; a
  regression/verification path that asserts labeling is applied + readable (incl.
  the `~` path-expansion fix already in the diagnostic); aligned stop.sh filters.
- OUT: reverting the 20260831-05 output-suppression change; reintroducing
  name-pattern matching; changing prune selection semantics.

## Carried forward
- Standing: SERVE mode integration (roadmap); Bug E (`make stop` template +
  duplicate-ID); image-digest tracking (decided, deferred).

## Acceptance criteria
- AC1: Rule 2 discovery uses the canonical `sandbox-dir` + `session-id` label
  pair; a resource created from one path spelling is discovered from any spelling.
  **DONE — `sandbox_dir_canon` moved to common.sh; prune indirectly canonicalizes
  via `--sandbox` (regression-tested). The `session-id` label is already canonical
  from `20260831-07`.**
- AC2: Relabeling mechanism (if adopted) is safe, label-only, no collateral damage
  to kept sessions.
  **DONE (canonicalization, not relabeling) — label value, not resource set, is
  normalized; no kept-session damage; no name-pattern matching.**
- AC3: stop.sh and the diagnostic align with the same canonical label key.
  **DONE — stop.sh canonicalizes before filter building; diagnostic canonicalizes
  via readlink -f.**
- AC4: Regression test(s) assert the label contract; suite + lint + smoke green.
  **DONE — `test_rule2_canonicalizes_sandbox_dir_spelling`; suite 746/0/0, lint
  0/101, smoke 6/6.**
- AC5: Docs (`sandbox_identity.md` label lifecycle, lifecycle docs) reflect the
  canonical labeling contract.
  **DONE — label-lifecycle table corrected (copy volumes carry session-id/ts) +
  canonical-label note added.**

## Hot files
- `scripts/prune.sh` (`rule2_orphan_resources`), `scripts/stop.sh`,
  `tests/knowledge/diagnose_prune_orphans.sh`,
  `src/build/docker-compose*.yml` (label schema), `tests/test_prune.sh`,
  `docs/concepts/sandbox_identity.md`.

## Findings
- 20260831-05: leftover volumes/resources carry inconsistent/absent
  `agent-sandbox.*` labels, invisible to label-only Rule 2.
- 20260831-07: identity is now canonical — the label pair can be a reliable key.

## Completed
- `src/libs/common.sh`: added canonical `sandbox_dir_canon` (single home, sourced
  by all four entrypoints; documented canonical-label contract).
- `src/libs/session_env.sh`: removed moved `sandbox_dir_canon`; `session_id_derive`
  calls the common.sh helper (available via source order).
- `scripts/start_agent.sh`: canonicalize SANDBOX_DIR at resolution (in main).
- `scripts/resume_agent.sh`: canonicalize SANDBOX_DIR after flag parse (guarded on
  non-empty so bare/list/interactive guidance still works).
- `scripts/stop.sh`: canonicalize SANDBOX_DIR after `check_base_flags`.
- `scripts/prune.sh`: canonicalize SANDBOX_DIR in main (Rule 2 filter).
- `tests/knowledge/diagnose_prune_orphans.sh`: canonicalize (`~`-expand +
  readlink -f) to mirror Rule 2; header note updated.
- Tests: `test_checkpoint.sh` + `test_start_agent.sh` source common.sh for the
  moved helper; new regression `test_rule2_canonicalizes_sandbox_dir_spelling`.
- Docs: `sandbox_identity.md` label-lifecycle table corrected + canonical-label
  note (copy volumes are per-session, carry session-id/ts).
- Roadmap: marked item 157 complete.
- Verification: suite 746/0/0, lint 0 warnings/101 files, smoke 6/6.

## Deferred items
- (none new)

## What's Next
M2.6 - Session Persistence.
Watch-outs: trailing-whitespace in semantic commit; dual-grep bridge; full-tree
close-out greps.