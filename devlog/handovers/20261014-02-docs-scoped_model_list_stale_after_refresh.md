---
date: 2026-10-14
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Documentation
status: Closed
---

# Handover - Documentation: the scoped model list staleness is reported upstream

## Objective

Produce a draft report against `@earendil-works/pi-coding-agent` for the scoped model list going stale after a catalog refresh, and fold it into the `pi upstream` roadmap row.

## Scope

One operator-directed change, mapped to no roadmap task. It continues the T12 `pi upstream` row, whose artifacts were enumerated by name in the parent row, and it adds the newly found defect as a fourth report beside the two existing drafts.

The change covers: the new draft report `devlog/discussions/20261014-report-draft-scoped_model_list_stale_after_refresh.md`; and the `pi upstream` row in `devlog/roadmap.md`, which drops its artifact count and gains one subtask per artifact, including the new report. The upstream disclosure itself is not in scope: the row stays on hold pending the operator's disclosure decision.

Out of scope. The extension README `## Wanted from pi` gains no row, per operator direction (2026-10-14): it records feature requests, and this is a defect report. No change to pi, and no decision to send the report upstream.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The draft report exists and carries the bug-report shape: three findings, a fix, version drift and a verification method | `grep -n '^## '` on the report shows `Finding 1`, `Finding 2`, `Finding 3`, `The fix`, `Version drift`, `Verifying a fix` | Agent [x] (6 headings) |
| Every cited line resolves in the installed 1.1.0 build | read each cited line against `dist/`; the sites are `main.js:659`, `agent-session-services.js:111`, `interactive-mode.js:828`, `:4461`, `:4484`, `:4535`, `:4541`, `:4546`, `model-selector.js:103`, `agent-session.js:1990` and `types.d.ts:1639` | Agent [x] (all resolve) |
| The findings hold against the pinned 1.2.0 build | diff `dist/core/model-resolver.js` and `dist/modes/interactive/components/model-selector.js` between 1.1.0 and the 1.2.0 package; the two are identical, and `interactive-mode.js` differs only in status-indicator colouring | Agent [x] (identical at the cited sites) |
| The three-row measure reproduces the gap | drive the shipped `resolveModelScopeFromModels` with a catalog that gains an id and the pattern `opencode-go/*`: the patterns re-resolved include the new id, the startup concrete ids do not | Agent [x] (reports `brand-new-model` in row 2 only) |
| The roadmap `pi upstream` row drops the count and carries one subtask per artifact | `grep -n 'pi upstream'` and the five rows beneath it; no count phrase remains | Agent [x] (5 subtasks) |
| The new report is named in the roadmap row | `grep -n 'scoped_model_list_stale_after_refresh' devlog/roadmap.md` returns the subtask | Agent [x] (1 line) |
| The Markdown gate is clean over the two changed files | `bash scripts/check_markdown.sh` | Agent [x] (0 findings) |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/discussions/20261014-report-draft-scoped_model_list_stale_after_refresh.md`](../discussions/20261014-report-draft-scoped_model_list_stale_after_refresh.md) | the new draft upstream report |
| [`devlog/roadmap.md`](../roadmap.md) | the T12 `pi upstream` row, restructured to one subtask per artifact |
| [`devlog/handovers/20261014-02-docs-scoped_model_list_stale_after_refresh.md`](20261014-02-docs-scoped_model_list_stale_after_refresh.md) | this record |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The report is a `report` discussion document at `draft` status | it is an upstream bug report, not an operation record; it follows the shape of the two existing drafts, `20260930` and `20261002`, whose findings, fix, version-drift and verification sections a maintainer can act on | the report header; this record |
| The report is measured on 1.1.0 and cross-checked on 1.2.0 | the container runs pi 1.1.0 while `base.dockerfile` pins 1.2.0; the cited sites are identical, so the finding holds for the pinned target without a second running install | the report `## Version drift`; this record |
| The `pi upstream` row lists one subtask per artifact and drops the count | per operator direction, 2026-10-14: a count goes stale as the set grows, and each artifact is work in its own right with its own outcome | `devlog/roadmap.md`; this record |
| The default-model report's `## Version drift` update folds into that report's subtask | it is work on one report item, not a separate artifact; one subtask per item keeps the parent row a list of artifacts | `devlog/roadmap.md` |
| The extension README gains no row | per operator direction, 2026-10-14: `## Wanted from pi` records feature requests, not defects | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The container's installed pi is 1.1.0 while `src/reasoning/providers/pi/base.dockerfile` pins 1.2.0. The report is therefore measured on 1.1.0 and cross-checked against the 1.2.0 package rather than re-measured on the pinned build. The two are identical at every cited site, so the cross-check carries the finding, but the next iteration that touches the report on the pinned build can re-run the measurement directly | record | next iteration |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261014-report-draft-scoped_model_list_stale_after_refresh.md`](../discussions/20261014-report-draft-scoped_model_list_stale_after_refresh.md) | new: the draft report, with the resolve-then-refresh root cause, the two stale scoped surfaces, the missing extension setter, the fix and its provenance rule, version drift and a verification method |
| [`devlog/roadmap.md`](../roadmap.md) | the T12 `pi upstream` parent drops its artifact count and gains one subtask per artifact: the two existing reports, the new scoped-model-list report, and the two feature requests |
