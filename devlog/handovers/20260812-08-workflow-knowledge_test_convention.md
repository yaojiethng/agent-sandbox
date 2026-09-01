# Agent Handover

**Date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Workflow
**Status:** Closed

## Objective (resolved)

Established a clear **Test Placement** convention separating knowledge tests (unmodifiable external seams / legacy mid-refactor) from unit tests under `make test` (maintained code with an API) and `tests/integration/` (still-not-runnable flows). Reclassified the wrongly-classified knowledge tests and enforced the **`make test` failed-0-skipped-0** invariant. Answer to the question: **yes — we were abusing the knowledge test as a primitive** for 3 of 8 knowledge tests that probed our own maintained seams; they are now unit tests. See Completion sections below.

## Working thesis (from operator)

> Knowledge tests are for investigative probing of the seam of legacy code (during refactoring old code) or external binaries/network/libs not modifiable by the user. Modern, maintained seams should have an API, and unit tests written directly against it. Do we abuse the knowledge test as a primitive?

## Prior-session context (relevant)

- Session `20260812-07` (whitespace round-trip hardening) **deleted** `knowledge_trailing_whitespace_context_mismatch.sh` and, per operator guidance, moved the valuable assertions into `test_diff_helpers.sh` as **unit tests** rather than keeping a manual knowledge test. That was a concrete precedent for this exact question: a "knowledge test" that tested our own maintained diff pipeline was converted to a unit test under `make test`.

## Current policy (as documented)

`docs/development/testing_policy.md` → `## tests/knowledge/ Directory` defines three categories, **none run by `make test`** (runner glob `tests/test_*.sh`, non-recursive):

| Category | Stated purpose | Let-run via |
|---|---|---|
| `knowledge_*.sh` | attribute assumptions about **external tools** (git, docker, rsync, pi) recorded during investigation; **not** acceptance criteria | manual only |
| `diagnose_*.sh` | internal invariants for troubleshooting a production script/subsystem; may be an AC regression guard | manual only |
| `workflow_*.sh` | end-to-end operator workflow (draft→confirm/reject) against a mock repo; may be AC | manual only |

## Audit of current knowledge tests (pending scope confirm — pre-analysis only)

Suspected **legitimate** (probing external/unmodifiable seams — git/pi, with an existing `libs/` API for the internal bits):
- `knowledge_binary_diff_apply.sh` — probes **git** binary diff/apply.
- `knowledge_pi_config_cycle.sh` — probes **pi** config lifecycle.
- `knowledge_draft_confirm_lock_trace.sh` — probes **git** `index.lock`.

Suspected **abuse** (probing our own maintained, modern seams as if external → should be unit tests):
- `knowledge_diff_export_container.sh` — explicitly an "integration test for the diff_export pipeline," sources `libs/diff.sh`/`dirs.sh`/`session.sh`/`routing.sh` + `package_branch` — all **maintained** internal code, **not regression-guarded**.
- `knowledge_session_diffs_path_resolution.sh` — tests internal `dirs.sh` CHANGES_DIR resolution (host + container) — maintained internal code.
- `knowledge_diff_rename.sh` — mixed: probes git rename handling (external, legitimate) AND our `package_branch`/`diff_export` integration (internal, should be unit-tested).

`diagnose_*.sh` and `workflow_*.sh` are corroborating but the stated task is knowledge tests specifically.

## Files in scope (Task)

| File | Role |
|---|---|
| `docs/development/testing_policy.md` | the `## tests/knowledge/ Directory` section (convention to revise/clarify) |
| `docs/development/testing-conventions.md` | conventions home ("Checklist for New Tests") — likely cross-ref |
| `tests/knowledge/knowledge_*.sh` | audit candidates (may be reclassified/moved) |
| `src/libs/diff.sh`, `dirs.sh`, `package_branch.sh`, `session.sh` etc. | the internal seams probed by suspected-abuse knowledge tests |
| `tests/test_*.sh` | where internal behaviors should be unit-tested instead |

## Deferred

(none yet)

## Completed this session

- [x] Read current testing-policy knowledge-test convention
- [x] Inventoried all `tests/knowledge/` files (13) and audited the `knowledge_*.sh` subset against the external-vs-internal seam test
- [x] Confirmed the runner glob (`tests/test_*.sh`, non-recursive) excludes `tests/knowledge/` from `make test`
- [x] Confirmed prior precedent: session `20260812-07` converted a maintained-pipeline knowledge test into unit tests
- [x] Classified each suspect against the operator's two measures (promote-if-now-testable vs keep-in-integr/diagnostics)
- [x] Audited the 6 skipped tests to the exact skip sites

## Important discrepancy (flags before implementing)

The operator's stated premise: the 6 skipped tests "cannot be run due to lack of certain utilities inside the container." **The code disagrees.** The exact 6 skips (fresh run) are:
- `test_run_agent.sh`: `claude-ai` (no setup.sh, no compose overlay, no serve overlay), `hermes` (no setup.sh), `opencode` (no setup.sh, no compose overlay)
- (`test_onboard.sh` passed — did not skip)

These are **optional provider-file presence checks** over the repo's own provider tree (`src/reasoning/providers/{claude-ai,hermes,opencode,pi}`), NOT missing-container-utility skips. pi has setup.sh+overlay+serve; hermes has hermes+serve; opencode has serve only; claude-ai has none. The skips occur because the test iterates all providers and `skip`s when an optional file is absent.

**These are now testable** (the expected provider layout is our committed repo state, i.e. Measure-1), so the correct resolution is likely to make them **deterministic pass/fail** (assert the known-expected layout or internal-consistency invariants), achieving "failed 0, skipped 0" without moving to integration/. This needs operator confirmation because it contradicts the "move skips to integration/" framing.

## Classification (operator's two-measure test)

All three wrongly-classified knowledge tests probe **pure, host-sourceable internal shell functions** and are **harness-testable → Measure 1 (promote to unit tests under `make test`)**:

| Test | What it probes | Measure | Reclassify to |
|---|---|---|---|
| `knowledge_session_diffs_path_resolution.sh` | internal `dirs.sh` CHANGES_DIR resolution (host+container via env sim) | **1 (testable)** | unit test `test_dirs.sh` under `tests/` |
| `knowledge_diff_export_container.sh` | internal `diff_export`→`package_branch` pipeline (pure function chain; no Docker needed per header) | **1 (testable)** | integration test under `tests/` |
| `knowledge_diff_rename.sh` | **git-external** rename probing (legit) + **internal** `package_branch`/`diff_export` (maintained) | **mixed: 1 for internal parts, 2 for git probing** | split: promote internal parts to unit tests; keep git probing as knowledge test |

`diagnose_*.sh` (4 files) run **inside containers** for troubleshooting; they legitimately occupy the Measure-2 niche (chunky/no-threshold/output-for-interpretation). The wrongly-classified knowledge tests DO NOT fall on that branch.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | **Test Placement rule**: a test belongs under `make test` when the seam is maintained code with an API; knowledge tests are only for **unmodifiable** seams (external binary/lib/network, legacy mid-refactor); `tests/integration/` holds still-not-runnable flows | operator principle: do not abuse the knowledge test as a primitive for our own code |
| 2 | **`make test` invariant**: failed 0, skipped 0, enforced by the runner (skip treated as failure); 6 provider-structure skips made deterministic | operator directive; keeps the unit suite deterministic |
| 3 | Promote the 3 internally-owned knowledge tests to unit tests; delete the 2 broken ones (they referenced a nonexistent `libs/` path and were never run) | Measure 1 — harness-testable maintained seams |
| 4 | `tests/integration/` is the home for not-runnable end-to-end/container/daemon flows (no current occupants; README documents the rule) | operator choice: integration in a `tests/` subdir, excluded from `make test` |
| 5 | **Option B** for the provider skips — deterministic internal-consistency invariants, not relocation to integration | operator confirmed |

## Mid-session findings

| # | Finding | Disposition |
|---|---|---|
| 1 | The 6 `make test` skips are **optional-provider-file presence checks**, not "missing container utility" skips (operator's premise) — the provider layout is committed repo state, so they were Measure-1, not Measure-2 | made deterministic in `test_run_agent.sh` (internal-consistency invariants) |
| 2 | `knowledge_diff_export_container.sh` and `knowledge_session_diffs_path_resolution.sh` referenced a **nonexistent `libs/` path** (repo restructured to `src/libs/`) and did not run — they rotted because not in `make test` | deleted; the internal coverage they intended is now real unit tests (`test_dirs.sh`, `test_diff_rename.sh`) or already covered (`test_package_branch.sh`, `test_diff_export.sh`) |
| 3 | `knowledge_diff_rename.sh` was mixed: ~12 git-external (legit) + 3 internal (should be unit) | split: internal 3 → `test_diff_rename.sh`; file trimmed to git-external probing |

## Acceptance criteria

- [x] Scope confirmed with operator (reclassify; keep git-external as knowledge; option B for skips; `tests/integration/`)
- [x] Convention documented in `testing_policy.md` (Test Placement rule) + `testing-conventions.md` (placement checklist)
- [x] Wrongly-classified knowledge tests reclassified: `dirs.sh`→`test_dirs.sh`, internal rename→`test_diff_rename.sh`, broken pair deleted, `knowledge_diff_rename.sh` trimmed to git-only
- [x] `make test` invariant enforced (failed 0, skipped 0); 6 provider skips made deterministic
- [x] Full suite green: 470 passed, 0 failed, 0 skipped
- [x] Stale/wrong policy wording removed (knowledge-test section rewritten); cross-refs updated

## Completed this session

- [x] Wrote the Test Placement rule + `make test` invariant into `testing_policy.md`/`testing-conventions.md`
- [x] Created `tests/test_dirs.sh` (unit test of `src/libs/dirs.sh` path resolution; 5 assertions)
- [x] Created `tests/test_diff_rename.sh` (unit test of internal package_branch/diff_export rename pipeline; 3 assertions)
- [x] Deleted broken `knowledge_diff_export_container.sh`, `knowledge_session_diffs_path_resolution.sh`
- [x] Trimmed `knowledge_diff_rename.sh` to its 12 git-external assertions
- [x] Made the 6 provider-structure skips deterministic in `test_run_agent.sh` (option B)
- [x] Enforced `make test` failed-0-skipped-0 in `scripts/run_tests.sh` (verified skip triggers error exit)
- [x] Created `tests/integration/README.md` documenting the folder's purpose
- [x] Updated `devlog/roadmap.md`; suite green (470/0/0)

## Operational notes

- Follow `docs/development/bash-coding-conventions.md`; unit tests must run under `make test`.
- Each handover Closed + separately committed.
