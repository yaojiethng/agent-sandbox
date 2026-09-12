# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: coding-agent workflow file layout)
**Type:** Workflow
**Status:** Closed

## Objective
Amend the audit file reorganization: extend the audit family with the campaign and documentation-pass files, create the `workflow/coding-agent/prompts/` mirror with the deployed prompt surface, switch the dockerfile COPY to the folder level, fold the entrypoint-map study into the surface-area report, and drop the roadmap entrypoint-map task.

## Scope

- Assess `test-quality-campaign.md`, `test-quality-campaign-run.md`, `documentation-pass.md` against the audit-family criterion (reviews existing work against policy, produces findings). All three qualify.
- `git mv` `test-quality-campaign.md` and `documentation-pass.md` into `workflow/coding-agent/audits/`; `git mv` `test-quality-campaign-run.md` into the new `workflow/coding-agent/prompts/` together with `gm.md` (the run file is the invocation template; the campaign file is the audit payload).
- Dockerfiles: replace the per-file `gm.md` COPY with a folder COPY of `workflow/coding-agent/prompts/`.
- `container_sig.sh` sig source: `workflow/coding-agent/gm.md` -> `workflow/coding-agent/prompts`; update the sig test fixture and the trace-build source-list assertion.
- Surface-area report: recategorize the three moved files, add the entrypoint-map section (gm / new-iteration / audit skills -- when to use, what it produces, where output goes), update the deployment-boundary section.
- Roadmap: drop the `Entrypoint map document` open item (its study content now lives in the report). Update `roadmap_future.md` M3 task text for the new homes.
- Doc reference updates: `documentation_policy.md` (documentation-pass path), `project_index.md` (workflow section).

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | `workflow/coding-agent/audits/` holds the seven original audit skills plus `test-quality-campaign.md` and `documentation-pass.md` | ls | Agent -- pass (9 files + report) |
| AC2 | `workflow/coding-agent/prompts/` holds `gm.md` and `test-quality-campaign-run.md`; old paths gone | ls | Agent -- pass |
| AC3 | All three provider dockerfiles COPY `workflow/coding-agent/prompts/` (no per-file gm.md COPY) | grep dockerfiles | Agent -- pass (3/3) |
| AC4 | `_agent_sig_sources` lists `workflow/coding-agent/prompts`; `test_container_sig` and `test_trace_build` pass live | make test | Agent -- pass (full suite 731/731) |
| AC5 | Surface-area report carries the entrypoint-map section and the recategorized rows | read | Agent -- pass |
| AC6 | Roadmap entrypoint-map item removed; `roadmap_future.md` M3 text matches the tree | grep | Agent -- pass |
| AC7 | Zero stale references to the old file paths outside historical records | grep sweep | Agent -- pass (0 hits) |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/gm.md`, `test-quality-campaign.md`, `test-quality-campaign-run.md`, `documentation-pass.md` | Relocated |
| `src/reasoning/providers/*/provider.dockerfile` | Folder COPY |
| `src/libs/container_sig.sh`, `tests/test_container_sig.sh`, `tests/test_trace_build.sh` | Sig source list |
| `workflow/coding-agent/audits/surface-area-report.md` | Recategorization + entrypoint map |
| `devlog/roadmap.md`, `devlog/roadmap_future.md` | Task drop + M3 text |
| `docs/operations/documentation_policy.md`, `docs/development/project_index.md` | Path references |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| All three assessed files count as audits | Each reviews existing work (tests, documents) against a policy document and produces findings; the campaign additionally fixes, but its contract is a proposal report, which is the audit pattern | Surface-area report |
| The run file lives in `prompts/`, not `audits/` | It is invocation tooling for the main agent (pi prompt template), not the audit procedure itself; the campaign file it spawns stays in `audits/` | Surface-area report |
| Folder-level COPY | Removes the per-file dockerfile wiring that made the last move a contract change; future prompt additions to `workflow/coding-agent/prompts/` deploy without dockerfile edits | This handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Folder COPY merges `workflow/coding-agent/prompts/` into `/opt/workflow/agent/prompts/` alongside `src/reasoning/agent/prompts/`; name collisions between the two source folders would silently overwrite | risk | Recorded here; no current collisions |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/gm.md`, `test-quality-campaign-run.md` | git mv into the new `workflow/coding-agent/prompts/` |
| `workflow/coding-agent/test-quality-campaign.md`, `documentation-pass.md` | git mv into `workflow/coding-agent/audits/` |
| `src/reasoning/providers/{pi,hermes,opencode}/provider.dockerfile` | Per-file gm.md COPY replaced by folder COPY of `workflow/coding-agent/prompts/` |
| [`src/libs/container_sig.sh`](src/libs/container_sig.sh) | `_agent_sig_sources`: `workflow/coding-agent/prompts` replaces `workflow/coding-agent/gm.md` |
| [`tests/test_container_sig.sh`](tests/test_container_sig.sh), [`tests/test_trace_build.sh`](tests/test_trace_build.sh) | Fixture and source-list assertion updated for the prompts folder |
| [`workflow/coding-agent/audits/surface-area-report.md`](workflow/coding-agent/audits/surface-area-report.md) | Recategorized rows (campaign, documentation-pass), entry point map section, deployment boundary updated |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Entrypoint-map open item removed (study folded into the report) |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | M3 task text records the new homes |
| [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md), [`docs/development/project_index.md`](docs/development/project_index.md) | Path references updated |

## Deferred items

None.

## What's Next

Sub-milestone: M2.6.6 -- Mount Model (unchanged). Next queued iteration: the sed-probe deletion.
