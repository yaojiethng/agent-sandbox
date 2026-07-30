# Agent Handover

**Session date:** 2026-07-30
**Milestone:** M2.6 — Session Persistence
**Session type:** Housekeeping — Roadmap reorganization, heading fix, Q&A ban, Known Limitations removal
**Status:** Closed

## Objective

Compact completed sub-milestones, reorganize M2.6 into two competing implementation paths, fix heading nesting, move open questions to design docs and ban Q&A style, replace Known Limitations with per-milestone Not in scope sections.

## Scope

Five roadmap housekeeping changes in one session.

## Completed this session

| File | Change summary |
|---|---|
| [`devlog/roadmap.md`](devlog/roadmap.md) | M2.6 reorganized: M2.6.1–M2.6.4 compacted to completed foundation. Two paths: M2.6.5 (copy/volume) and M2.6.6 (mount/host). Heading levels fixed (h3→h5). Design questions moved to design doc; roadmap has single reference task. Known Limitations removed; three items relocated to `#### Not in scope` under M2. Stale opencode/hermes item deleted. Notes section removed (all entries stale or misplaced). |
| [`devlog/discussions/20260722-design-active-mount_model.md`](devlog/discussions/20260722-design-active-mount_model.md) | Added Open questions section (7 items) and Decision: Worktree backing deferred. |
| [`devlog/discussions/20260730-design-active-multi_volume_concurrency.md`](devlog/discussions/20260730-design-active-multi_volume_concurrency.md) | Converted Q&A-style resolved questions to named Decisions with rationale. |
| [`docs/operations/roadmap_policy.md`](docs/operations/roadmap_policy.md) | Added rules: open questions live in design docs, resolved as named decisions (not Q&A). Not in scope convention — `#### Not in scope` nested under each milestone. Known Limitations removed from persistent sections. |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| M2.6.5 (copy) and M2.6.6 (mount) as parallel competing paths | Both deliver session persistence with different trade-offs. Numbering implies sequence; explicit split makes the choice clear. | roadmap.md |
| Worktree backing permanently deferred | Complex mechanism (gitdir resolution, ref protection, safety audit). Mount delivery alone provides most of the value with less complexity. | mount_model design doc |
| Open questions → design docs, not roadmap | Roadmap is a task list; design docs are reasoning records. Q&A style banned — resolutions recorded as named decisions. | roadmap_policy.md |
| Known Limitations → per-milestone Not in scope | Global catch-all accumulates stale items. Per-milestone scoping ties limitations to what produced them. | roadmap_policy.md |

## Next session

M2.6.5 — Volume prune implementation or multi-volume concurrency implementation.

**Conclusions from this session:** Five housekeeping changes applied in sequence. The roadmap now cleanly separates completed foundation from two active implementation paths. Heading nesting corrected. Q&A style eliminated from design docs. Known Limitations retired.
