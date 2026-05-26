# Agent Handover

**Session date:** 2026-04-22
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Design
**Status:** Closed

## Objective

Audit the baseline advancement design for model gaps, then redesign the diff packaging and apply workflow from first principles based on findings.

## Scope

Design session. Broader than the original brief — the session expanded from a single Change 6 fix into a full redesign of the diff format, packaging commands, and apply workflow.

## Carried forward

None.

## Acceptance criteria

Not yet defined. Acceptance criteria deferred to implementation session — this session produced the design only.

## Hot files

| File | Why in scope | Status |
|---|---|---|
| [`docs/discussions/design_apply_workflow_and_baseline_advancement.md`](docs/discussions/design_apply_workflow_and_baseline_advancement.md) | Original design — SUPERSEDED markers inserted inline | ✓ Complete |
| [`docs/discussions/design_diff_and_branch_packaging_workflow.md`](docs/discussions/design_diff_and_branch_packaging_workflow.md) | New design document — created this session | ✓ Complete |
| [`docs/concepts/sandbox_host_correspondence_model.md`](docs/concepts/sandbox_host_correspondence_model.md) | Full rewrite — three-case structure, updated primitives, new diagrams | ✓ Complete |
| [`docs/architecture/sandbox_lifecycle.md`](docs/architecture/sandbox_lifecycle.md) | Phase 3 rewritten — `INIT_SHA`, new command shapes, updated references | ✓ Complete |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | M2.3 section condensed, change numbering removed, pending work respecified | ✓ Complete (section artifact only) |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Original Change 6 explicitly rejected | Original design had a fatal timing flaw: patches are produced on container exit, but advancement required `docker exec` into a running container — the two states cannot coexist in normal workflow | Design doc SUPERSEDED markers; new design doc |
| Git is not the correspondence mechanism | Sandbox and host are independent git repos; diff files are the transport, not git objects, patches, or SHAs | `sandbox_host_correspondence_model.md` — Core Principle |
| One diff format replaces two primitives | `format-patch` / `git am` path removed; single unified diff (index lines stripped, applied via `git apply`) used in both directions | `design_diff_and_branch_packaging_workflow.md` — Diff Format |
| `INIT_SHA` replaces advancing `BASELINE_SHA` | Fixed session origin marker, written once at container init, never updated; full re-export on demand replaces incremental tracking | Design doc; `sandbox_lifecycle.md` |
| `package-branch` added alongside `package-diff` | `package-diff` handles uncommitted changes; `package-branch` handles committed branch history since `INIT_SHA` as numbered `.diff` files | Design doc — Packaging Commands |
| Checkpoint git tags removed | Pollute remote for all users; harness bookkeeping has no place in git history | Design doc; roadmap |
| Change numbering removed from roadmap | Numbers became confusing after mid-stream redesign; design doc and handovers are the implementation record | Roadmap M2.3 section |
| `make draft` redesigned | Checkpoint tag lookup → `FROM=<hash>` arg; `git am` → sequential `git apply`; `SESSION=` → branch-name folder + `DIFFS=<start>..<end>` range | Design doc — Apply Workflow |
| `make confirm` simplified | Operator runs `git rebase -i` manually; confirm is branch cleanup only — no rebase, no `docker exec` | Design doc — Apply Workflow |
| `make sync` and `SYNC=1` removed | Entire baseline advancement-via-container mechanism removed; no replacement needed | Design doc; roadmap |
| `ADVANCED_SESSIONS` removed | No harness-side tracking of applied state; operator manages range via `DIFFS=` argument | Design doc; correspondence model |
| `make apply` symmetric on host and container | Same command, same script, same diff format in both directions | Design doc — Command Map |
| Pre-close gap 1 closed: mixing `make apply` and `make draft` | Under new model the two paths use separate artefact locations (`workspace/output/` vs `session-diffs/<branch>/`) and no shared application mechanism — undefined behaviour is gone | `sandbox_host_correspondence_model.md` — Model Gaps |
| Pre-close gap 2 closed: mixed session types | Explicitly out of scope and not intended behaviour; harness makes no claim to coordinate across session types | `sandbox_host_correspondence_model.md` — Model Gaps |

## Completed this session

| File | Change summary |
|---|---|
| `docs/discussions/design_apply_workflow_and_baseline_advancement.md` | Original content fully preserved; SUPERSEDED markers inserted inline at each changed decision; reference to new design doc added |
| `docs/discussions/design_diff_and_branch_packaging_workflow.md` | New document created — full design for diff packaging and branch review workflow |
| `docs/concepts/sandbox_host_correspondence_model.md` | Full rewrite — three-case structure (live sandbox, stopped sandbox, new container); updated primitives; bidirectional flow diagrams; new command map |
| `docs/architecture/sandbox_lifecycle.md` | Phase 3 rewritten — `INIT_SHA` documented in `snapshot_init_git`; apply workflow updated; references updated |
| `docs/development/roadmap.md` | M2.3 section — change numbering removed; completed work condensed; pending work respecified as A–G unit checklist; rejected Change 6 removed; pre-close design tasks closed |
| `docs/concepts/sandbox_host_correspondence_model.md` | Model Gaps section — both gaps closed with resolution statements; section retained as closed record |

## Deferred items

| Item | Reason | Where next |
|---|---|---|
| Acceptance criteria | Design session only — criteria defined at implementation Step 6 | Next session (implementation) |
| Implementation of pending work | Out of scope for design session | Next session — upload `scripts/apply_workspace.sh`, `scripts/checkpoint.sh`, `libs/diff.sh`, `libs/snapshot.sh`, `start_agent.sh`, `.skills/package-diff.md` |

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.

**First task: Unit A — INIT_SHA at container init.**

Read the roadmap (`docs/development/roadmap.md` — M2.3 pending section) for the full A–G unit list and dependency order. Implement only Unit A this session. Subsequent units are scoped one per session in dependency order: B can follow A in any order; C depends on A; E depends on C; F depends on E; D and G are independent.

**Unit A scope:**
- File: `libs/snapshot.sh`
- Change: in `snapshot_init_git`, after the baseline commit is created, write `git rev-list --max-parents=0 HEAD` to `sandbox/.git/INIT_SHA`. Remove any `BASELINE_SHA` write or update logic.
- Verify: start a container; confirm `sandbox/.git/INIT_SHA` exists and contains the root commit SHA; confirm no `BASELINE_SHA` file is written.

**Design reference:** `docs/discussions/design_diff_and_branch_packaging_workflow.md` — INIT_SHA section.

**Watch-outs (relevant to Unit A):**
- Confirm no other script reads from `BASELINE_SHA` before removing writes — grep `libs/` and `scripts/` for `BASELINE_SHA` callers first.
- `INIT_SHA` is written once and never updated — do not add any update logic.