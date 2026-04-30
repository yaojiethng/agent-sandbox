# Agent Handover

**Session date:** 2026-04-29
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Design
**Status:** Closed

## Objective
Amend the CLI command contract for `apply` and `draft` to support an `--interactive` flag, and record the agreed design in the design document and roadmap. Scope was split mid-session into a two-session sequence: Session A (refactor) then Session B (interactive).

## Scope

1. **Evaluate contract amendments** — assess removing absolute-path `--session`, unifying `draft`/`apply` around a `SOURCE_DIR` contract, adding `AUTOSAVE=1`/`BUNDLE=1` flags, and narrowing `apply` to `output/diffs/` only.
2. **Record the amended contract** — update `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` with a new "Contract Amendments" section capturing: agreed contract changes, `SOURCE_DIR` + folder structure contract, apply/draft channel boundary, deferred questions, and open markers for unresolved items.
3. **Update roadmap task descriptions** — split M2.3 pending work into Session A (refactor) and Session B (interactive), with Session B dependent on Session A.

**Explicitly deferred:**
- Implementation of the refactor (Session A) — reserved for a subsequent implementation session, which will open with an alignment step before scoping
- Implementation of `--interactive` (Session B) — reserved for a subsequent implementation session, dependent on Session A
- Test updates for any new contract — reserved for implementation sessions
- M2.3 Trigger B and sub-milestone close (cannot run until all pending tasks are complete)
- Decision on whether `package_diff` should cross-write into `session-diffs/` — deferred to a future design session

## Carried forward

| Item | From handover |
|---|---|
| Interactive confirmation flag (`--interactive` for `make apply` and `make draft`) | 20260429-02-impl-test_harness_verbosity.md |

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | CLI entry point — flag parsing and subcommand dispatch for apply/draft/confirm/reject |
| [`libs/diff_workflow.sh`](libs/diff_workflow.sh) | `apply_run` function signature and behaviour contract |
| [`libs/draft_workflow.sh`](libs/draft_workflow.sh) | `draft_run`, `confirm_run`, `reject_run` signatures and behaviour contract |
| [`libs/package_diff.sh`](libs/package_diff.sh) | Output path and filename contract for uncommitted diffs |
| [`libs/package_branch.sh`](libs/package_branch.sh) | Output path and folder structure for bundled diffs |
| [`libs/diff.sh`](libs/diff.sh) | `diff_on_exit` and `diff_on_autosave` output structure |
| [`docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md`](docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md) | Design document recording the intended diff/branch workflow contract |
| [`docs/devlog/roadmap.md`](docs/devlog/roadmap.md) | M2.3 pending task list and acceptance criteria |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `--session` becomes name-only; absolute paths removed | Simplifies resolution; escape hatch retained via `--diff=<path>` | design_diff_and_branch_packaging_workflow.md — Contract Amendments |
| `changes.diff` renamed to `uncommitted.diff` everywhere | Unambiguous; matches unified contract | design_diff_and_branch_packaging_workflow.md — Contract Amendments |
| `output/bundles/<session>/` gains `patches/` subfolder | Standardises structure across all channels | design_diff_and_branch_packaging_workflow.md — Contract Amendments |
| Unified `SOURCE_DIR` contract: `patches/` + optional `uncommitted.diff` | Decouples `draft_run`/`apply_run` from resolution logic | design_diff_and_branch_packaging_workflow.md — Contract Amendments |
| `draft_run` takes `SOURCE_DIR` (absolute); applies `patches/*.diff` then optional `uncommitted.diff` | All resolution happens upstream; contract is data-only | design_diff_and_branch_packaging_workflow.md — Contract Amendments |
| `apply_run` takes `SOURCE_DIR` (absolute); applies `uncommitted.diff` only; `--diff=<path>` override retained | Narrowed to output channel; escape hatch preserved | design_diff_and_branch_packaging_workflow.md — Contract Amendments |
| `apply` resolves under `output/diffs/` only; `draft` resolves under `session-diffs/` and `output/bundles/` | Clear channel boundary per command | design_diff_and_branch_packaging_workflow.md — Contract Amendments |
| `AUTOSAVE=1` and `BUNDLE=1` as Makefile flags; underlying CLI uses `--source` and `--mode` | Makefile stays declarative; CLI stays explicit | design_diff_and_branch_packaging_workflow.md — Contract Amendments |
| Session A (refactor) precedes Session B (interactive); Session B is blocked on Session A | Refactor changes the data model that interactive mode consumes | design_diff_and_branch_packaging_workflow.md — Contract Amendments; roadmap.md |
| `package_diff` cross-write question deferred | Channel-boundary decision; does not block either session | design_diff_and_branch_packaging_workflow.md — Open Questions |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/handovers/20260429-03-design-command_shape_and_contract.md` | Created — active handover |
| `docs/devlog/roadmap.md` | Compacted completed test-infrastructure task group; replaced "Pending — interactive confirmation flag" with Session A (refactor) and Session B (interactive) task lists |
| `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` | Added "Contract Amendments (Session A & B)" section: `--session` name-only, `uncommitted.diff` rename, `patches/` subfolder for bundles, unified `SOURCE_DIR` contract, revised `draft_run`/`apply_run` signatures, channel boundary, Makefile flags, session sequence, open questions |

## Deferred items

| Item | Reason | Next destination |
|---|---|---|
| Session A: refactor implementation | Too large for design session; requires alignment step first | Next implementation session (Session A) |
| Session B: `--interactive` implementation | Blocked on Session A data-model changes | Implementation session after Session A closes |
| `package_diff` cross-write into `session-diffs/` | Channel-boundary decision; no concrete use case yet | Future design session or Session A alignment |
| Whether `draft` interactive table should also show `output/diffs/` entries | Depends on whether apply/draft channel boundary is strict | Session A alignment |
| Makefile `--interactive` target wiring | Part of Session B | Session B implementation |

## Next session

**M2.3 — Session A: Command contract refactor**

**Session type:** Implementation (with alignment opening)

**Objective:** Execute the Session A refactor as defined in the amended design document and roadmap.

**Alignment required before scoping:** The operator will interview / align on the refactor design at session open. Do not assume the contract is fully specified — verify `SOURCE_DIR` resolution flow, exact flag names (`--source` vs `--mode` vs alternatives), and whether `apply_run` should consume `session-diffs/` in addition to `output/diffs/`.

**Key files to read at session start:**
- `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` — Contract Amendments section
- `docs/devlog/roadmap.md` — Session A task list
- `scripts/agent-sandbox.sh` — current flag parsing and dispatch
- `libs/diff_workflow.sh` — current `apply_run`
- `libs/draft_workflow.sh` — current `draft_run`
- `libs/diff.sh` — `diff_on_exit` / `diff_on_autosave` output paths
- `libs/package_diff.sh` — `changes.diff` output path
- `libs/package_branch.sh` — bundle output structure
- `libs/_templates/Makefile.template` — Makefile targets to update

**Trigger B status:** Not yet fired. M2.3 still has Session A and Session B pending.

**Context handover:** This session supersedes the prior implementation thread for `--interactive` (from handover `20260429-02-impl-test_harness_verbosity.md`). The `--interactive` work is now sequenced behind Session A. Resume from the amended design document, not from the prior handover's Next session.
