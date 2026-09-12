# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: documentation accuracy)
**Type:** Doc
**Status:** Closed

## Objective
Run the architecture-doc staleness sweep (roadmap open item), then compare the sweep's method against the documentation-audit files and record the comparison as input for compiling a single comprehensive documentation-audit prompt.

## Scope
- Fix the known `security.md` violation (copy row claims fresh `git init`; the helper-container seed copies the real host `.git`).
- Sweep `docs/architecture/` for behavior text predating landed redesigns.
- Experiment: stash the sweep, run a fresh `pi -p` subagent with the `architecture-doc-reviewer.skill.md` prompt (staleness + consistency only) over the pre-change tree, compare findings, restore, merge verified findings.
- Write `workflow/coding-agent/audits/documentation-audit-comparison.md`: (a) sweep gaps the audit files would have covered, (b) effectiveness of each audit file, framed toward the compiled pi-native prompt (M3).
- Update `roadmap.md` (sweep item done) and `roadmap_future.md` (M3 task references the comparison).

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | No known-stale terms remain in `docs/architecture/` (rsync, docker cp, baseline.tar, "fresh git init", stale "not yet implemented" mount status) | grep | Agent -- pass (only the genuine `headless` reservation, removed as I5) |
| AC2 | All 13 subagent findings (C1-C9, I1-I6) either fixed or explicitly dispositioned | read diff | Agent -- pass (all fixed after code verification) |
| AC3 | Comparison report exists with sections a and b and the compiled-prompt recommendation | read | Agent -- pass |
| AC4 | Roadmap sweep item marked done; M3 task references the comparison | grep | Agent -- pass |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Merge the subagent findings into the sweep rather than leaving them as report rows only | Each finding was code-verified; leaving verified false claims in architecture docs contradicts the sweep's purpose | This handover |
| Report lives in `workflow/coding-agent/audits/` | It evaluates the files in that directory and is the M3 compilation input; a devlog discussion would detach it from its subject | Comparison report header |
| `architecture-doc-reviewer` scope trimmed to staleness + consistency for the experiment | The iteration's task is the staleness sweep; complexity/vagueness lenses are out of scope and would have doubled the run | Comparison report |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The autonomous grep sweep found 3 of 13 verified findings; the reviewer-prompt subagent found all 13 | measurement | Comparison report -- term-list sweeps cannot find staleness whose terms are unknown |
| `security.md` invariant 2 was contradicted by the provider-config mount (a stated invariant the mount shape violates) | contradiction | Fixed: invariant now enumerates the explicit grants |
| `tool_interface.md` carried two conflicting `package-branch` sections, one with a wrong output path | duplication | Fixed: duplicate deleted, path corrected per `routing.sh` |

## Completed

| File | Change |
|---|---|
| [`docs/architecture/security.md`](docs/architecture/security.md) | Copy row, mount status wording, invariant 5 artefact names, invariant 2 grants, system name |
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | Named-volume contract, seed init steps, prune STALE semantics, draft branch pattern, duplicate section, provider path prefixes, CHANGES_DIR row, headless row removed |
| [`docs/architecture/sandbox_lifecycle.md`](docs/architecture/sandbox_lifecycle.md) | Prune staleness semantics, library paths, draft branch pattern |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | start_agent pre-flight description (rsync/checkpoint text removed) |
| [`docs/architecture/system_overview.md`](docs/architecture/system_overview.md) | apply command contract, nesting-invariant enforcement caveat |
| [`workflow/coding-agent/audits/documentation-audit-comparison.md`](workflow/coding-agent/audits/documentation-audit-comparison.md) | New: method comparison + compiled-prompt recommendation |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Sweep item marked done |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | M3 task references the comparison |
| [`docs/development/project_index.md`](docs/development/project_index.md) | Comparison report row |

## Deferred items

Compiled documentation-audit prompt itself -- M3 task (roadmap_future), per the comparison report.

## What's Next
Next queued iteration: stash-triage study (check-in item 4).
