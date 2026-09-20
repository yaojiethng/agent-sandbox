# Agent Handover

**Date:** 2026-09-19
**Milestone:** M2.6 - Session Persistence
**Type:** Workflow
**Status:** Closed

## Objective

Verify the delivered correspondence mechanism claims across copy/mount deliveries and flatten modes; audit the correspondence code bundle for reuse, SRP, DRY, and interpretability; produce grounded recommendations. No production or documentation changes in this iteration.

## Scope

Targets the M2.6 general open row "Mount worktree with full git history" (roadmap.md) and the claims it cites (`20260818-02`, `20260912-14`), plus the correspondence bundle:

- Export/apply pipeline: `src/libs/package_branch.sh`, `src/libs/diff_export.sh`, `scripts/workflows/draft.sh`, `src/libs/draft_state.sh`, `src/libs/diff.sh`, `src/libs/export_status.sh`, `src/libs/session_state.sh`
- Delivery materialization: `src/capability/seed_volume.sh` (snapshot_deliver), `scripts/start_agent.sh`, `scripts/resume_agent.sh`
- Dry-run verification surface: `scripts/dry_run_capability.sh`, `src/libs/dry_run_harness.sh`, trace tests (`tests/test_trace_*.sh`, `tests/test_start_agent.sh`, `tests/test_seed_volume.sh`)
- Records under verification: `docs/concepts/sandbox_host_correspondence_model.md`, `docs/adr/container_host_correspondence_mechanism.md`

Three operator-directed verification questions, expanded with a code-path walk, a {copy, mount} x {flatten on, off} correspondence matrix, and a code-quality audit of the bundle. Operator confirmed: any decisions on roadmap, ADR, or docs land this iteration. Operator accepted the trace/harness depth boundary for Q2, with live-container checks delegated as operator-run items. Steering received at Gate 2: the two Q3 DRY candidates also land this iteration (session_state_write_set relocation; verify_parity/verify_baseline scaffolding extraction).

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Q1/Q2 evidence reproducible: byte-identical export artefacts across full/flatten via production functions; identical round-trip | `bash /tmp/q2_matrix.sh` -> PASS | accepted (Agent [x] re-run at pre-close: PASS) |
| 2 | No git transport (push/pull/fetch/merge/remote/clone/cherry-pick/am) invoked in `src/` or `scripts/` beyond one tag comment | grep | accepted (Agent [x]: only `draft.sh:447` comment) |
| 3 | Host apply commands carry zero delivery/flatten awareness | grep `scripts/workflows/` | accepted (Agent [x]: zero hits) |
| 4 | Q2 cell tests green: seed_volume 32, start_agent 34, run_agent 10, compose-gen 12, resume-trace 25 | run each | accepted (Agent [x]) |
| 5 | Q3 audit recorded: bundle metrics + 2 DRY candidates in handover | read-back | accepted (Agent [x]) |
| 6 | Roadmap row re-scoped; "git-based port-back becomes possible" language gone | grep roadmap | accepted (Agent [x]: 0 hits; row closed `- [x]`) |
| 7 | ADR gains 2026-09-19 entry per adr_policy (mandated fields; `Current:` pointer) | read-back | accepted (Agent [x] presence; Operator [x] read-back) |
| 8 | Architecture/concept docs in scope describe the system as built | Agent + Operator | accepted (Agent [x]: concepts already consistent; no change needed) |
| 9 | Live dry-run e2e across {copy, mount} x {flatten on, off} passes on docker host | `make dry-run` | pushed - operator-run (no docker in this environment) |
| 10 | DRY1: `session_state_write_set` defined in `src/libs/session_state.sh`, absent from `seed_volume.sh`; entrypoint mount-init uses the setter; suite green | grep + suite | accepted (Agent [x]: 854/854) |
| 11 | DRY2: `verify_parity` / `verify_baseline` share `_nul_streams_equal`; messages preserved; seed_volume 32/32 | grep + test | accepted (Agent [x]) |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/concepts/sandbox_host_correspondence_model.md`](../../docs/concepts/sandbox_host_correspondence_model.md) | The correspondence claim under verification (core principle, diff format, init_sha) |
| [`docs/adr/container_host_correspondence_mechanism.md`](../../docs/adr/container_host_correspondence_mechanism.md) | Rejected git-mediated alternative; does the code match the ADR |
| [`src/libs/package_branch.sh`](../../src/libs/package_branch.sh) | Export pipeline: per-commit diffs since init_sha |
| [`src/libs/diff_export.sh`](../../src/libs/diff_export.sh) | Exit-time export path (session-save sibling) |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) | Host-side apply path |
| [`src/libs/draft_state.sh`](../../src/libs/draft_state.sh) | Message resolution, draft-state guard |
| [`src/capability/seed_volume.sh`](../../src/capability/seed_volume.sh) | snapshot_deliver: full vs flatten materialization; now sources the moved `session_state_write_set`; shared NUL-stream comparator |
| [`src/libs/session_state.sh`](../../src/libs/session_state.sh) | DRY1 home: `session_state_write_set` relocated here |
| [`tests/stubs/libs/session_state.sh`](../../tests/stubs/libs/session_state.sh) | stub mirror updated for the relocated setter |
| [`scripts/start_agent.sh`](../../scripts/start_agent.sh) | Delivery wiring, FLATTEN flag, export exit path |
| [`scripts/resume_agent.sh`](../../scripts/resume_agent.sh) | FLATTEN record/worktree cross-check |
| [`tests/test_trace_compose_gen.sh`](../../tests/test_trace_compose_gen.sh) | Trace-level delivery coverage evidence |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Q1: correspondence mechanism is delivery-agnostic and flatten-agnostic; no git-mediated port-back exists nor is needed | Code-path walk + transport sweep + matrix evidence; the ADR rejection stands | `container_host_correspondence_mechanism.md`, 2026-09-19 entry |
| Q2: full/flatten produce byte-identical artefacts and identical round-trips | Production-function matrix (snapshot_deliver, diff_export) + suite cells | handover AC 1/4; ADR entry |
| Q3: bundle modularization good; two DRY candidates landed | Audit (3430 LOC, 14 files, one responsibility each) | handover Findings; code |
| Roadmap mount-worktree row: close as landed + retired "git-based port-back" | Verification closes the open question; rejected alternative per ADR | `devlog/roadmap.md` row |
| DRY1 `session_state_write_set` relocation + DRY2 comparator extraction | Operator steering at Gate 2 "/ roll in your two DRY candidates"; suite green after | code; handover AC 10/11 |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| Roadmap row "Mount worktree with full git history" carried "git-based port-back becomes possible" framing contradicting ADR, docs, and code | contradiction | roadmap | resolved: row re-scoped `- [x]` + ADR 2026-09-19 entry (AC 6/7) |
| Q3 DRY candidates (write_set relocation; verify comparator) | code quality | this iteration | landed (AC 10/11); no further action |
| Closed-handover observation `20260912-14` (resume FLATTEN cross-check) already resolved in tree | contradiction (resolved in-tree) | none | closed as informational |
| Live dry-run e2e not runnable here | boundary | operator | AC 9 pushed; operator-run at review |
| Cross-context lib function moved out of a seeder-only file broke the suite stub (throw until `tests/stubs/libs/session_state.sh` mirrored the setter) | agent mistake (class B proposed) | next + | Proposed as GOTCHAS entry: "cross-context lib changes need `tests/stubs/libs` mirror parity + a suite run before close"; pending operator confirmation at review |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | mount-worktree full-history row closed `- [x]` as landed decision record; retired "git-based port-back" framing |
| `docs/adr/container_host_correspondence_mechanism.md` | 2026-09-19 verification entry (delivery/flatten axis does not reopen git-mediated correspondence); `Current:` pointer updated |
| `src/libs/session_state.sh` | `session_state_write_set` added (identity block; shared by seed and mount init paths) |
| `src/capability/seed_volume.sh` | local `session_state_write_set` removed (sourced now); `_nul_streams_equal` extracted; `verify_parity` + `verify_baseline` refactored onto it, messages preserved |
| `src/capability/entrypoint.sh` | mount init branch writes identity block via `session_state_write_set` (4 calls -> 1) |
| `tests/stubs/libs/session_state.sh` | mirror `session_state_write_set` added (suite stub parity) |
| `devlog/handovers/20260919-01-workflow-correspondence_mechanism_verification.md` | this handover |

## Deferred items

None.

## What's Next

Sub-milestone: M2.6 - Session Persistence. Roadmap maintenance is not pending.

Prior handover context: consolidation iteration `20260918-12` (history reorg + flag ingestion) closed with suite 854/854 green; its operator-optional items (dispatcher collect mode, folding residual asserts) are not carried tasks. Roadmap open rows: interface-contract compatibility (`20260901-02`) only - the mount-worktree row closed this iteration.

Operator-run at review: live dry-run e2e (`make dry-run`) across {copy, mount} x {flatten on, off} - AC 9 pushed.

No blocking design questions.

**Conclusions from this iteration:** correspondence mechanism verified delivery- and flatten-agnostic end to end; git-mediated port-back is a rejected alternative, not future work; the roadmap row's open question is closed; the export/apply pipeline needs no delivery-specific branch; the two DRY candidates landed.
