# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: coding-agent workflow file layout)
**Type:** Workflow
**Status:** Closed

## Objective
Relocate the coding-agent workflow files to their M3-ready homes -- `gm` into `workflow/coding-agent/`, the audit-skill family into `workflow/coding-agent/audits/` -- and record the full surface-area categorization (use case, current or not, consolidation targets) as the M3 reorganization input.

## Scope
Operator-directed (chat 2026-09-11), gates pre-released; runs autonomously to close:

- Move `src/reasoning/agent/prompts/gm.md` to `workflow/coding-agent/gm.md`; keep it deployable: all three provider dockerfiles COPY it into `/opt/workflow/agent/prompts/`, and `_agent_sig_sources` includes it (the prompts dir no longer holds the file, so the wiring must name it).
- Create `workflow/coding-agent/audits/`; move the seven audit-family skills there from `src/reasoning/agent/drafts/`: architecture-doc-reviewer, audit, bash-audit, dhh-code-audit, handover-audit, kelsey-code-reviewer, roadmap-audit. Not deployed before (drafts/ was never COPYed) and not deployed after -- repo-side only.
- Propagate all references: provider dockerfiles, `src/libs/container_sig.sh`, `tests/test_container_sig.sh` (fixture), docs (`bash-coding-conventions.md`, `conventions.md`, `handover_policy.md`, `iteration_policy.md`, `project_index.md`), internal relative links inside moved files.
- Write the surface-area categorization report to `workflow/coding-agent/audits/`: every file in the former `drafts/` + `prompts/` surface, one use-case category each, current or non-current, M3 consolidation targets (dedup, merge, drop).
- Add the M3 reorganization task to `devlog/roadmap_future.md` (M3 section, next to the workflows-folder task) referencing the report.
- The reorganization itself (merges, drops, format porting) is deferred to M3 -- this session moves files and records state only.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | `gm.md` lives at `workflow/coding-agent/gm.md`, absent from `src/reasoning/agent/prompts/`; every provider dockerfile (`pi`, `hermes`, `opencode`) COPYs it into `/opt/workflow/agent/prompts/` | grep dockerfiles + ls | Agent -- pass (3/3 dockerfiles, old path gone) |
| AC2 | `workflow/coding-agent/audits/` holds the seven audit skills; `drafts/` retains the five non-audit files (`bugfix`, `recovery`, `refactor-mv-rename-file`, `roadmap-management`, `toc.sh`) | ls both dirs | Agent -- pass (7 and 5) |
| AC3 | Zero stale path references outside historical records (closed handovers, archived ADR): repo-wide grep for `agent/drafts/<moved>` and `agent/prompts/gm` returns only historical hits | grep sweep | Agent -- pass (0 non-historical hits) |
| AC4 | `_agent_sig_sources` includes `workflow/coding-agent/gm.md`; `tests/test_container_sig.sh` fixture creates it; `bash -n` clean on both files | grep + `bash -n` + live run | Agent -- pass (bash -n clean; test_container_sig 18/18) |
| AC5 | The report at `workflow/coding-agent/audits/` covers every file of the former drafts+prompts surface with a use-case category, current/non-current status, and an M3 consolidation target | read report against file list | Agent -- pass (20 rows: 19 files + header row) |
| AC6 | `devlog/roadmap_future.md` M3 carries the reorganization task referencing the report | grep | Agent -- pass |
| AC7 | Touched test suites pass: `tests/test_trace_build.sh` source-list assertion updated (9 elements) | live run | Agent -- pass (12/12) |
| AC8 | Handover closed with Status Closed | operator review at iteration end | Operator |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/agent/prompts/gm.md`](src/reasoning/agent/prompts/gm.md) | Moved to `workflow/coding-agent/` |
| [`src/reasoning/agent/drafts/*.skill.md`](src/reasoning/agent/drafts) | Seven audit-family skills moved to `workflow/coding-agent/audits/` |
| [`src/reasoning/providers/*/provider.dockerfile`](src/reasoning/providers) | Deployment wiring: COPY gm.md from its new repo path |
| [`src/libs/container_sig.sh`](src/libs/container_sig.sh) | Sig source list gains the new gm.md path |
| [`tests/test_container_sig.sh`](tests/test_container_sig.sh) | Fixture gains the new sig-source file |
| [`docs/development/bash-coding-conventions.md`](docs/development/bash-coding-conventions.md), [`docs/development/conventions.md`](docs/development/conventions.md), [`docs/operations/handover_policy.md`](docs/operations/handover_policy.md), [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md), [`docs/development/project_index.md`](docs/development/project_index.md) | Path references updated to the new homes |
| [`workflow/coding-agent/audits/surface-area-report.md`](workflow/coding-agent/audits/surface-area-report.md) | The categorization report (new) |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | M3 reorganization task |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Move gm.md but keep it deployed via a per-provider COPY line from the new path | `src/reasoning/agent/prompts/` is the deployed prompt surface; removing gm.md from it without rewiring would drop the `/gm` command from the built image. The repo-side home follows the operator's layout; the dockerfile maps it into `/opt/workflow/agent/prompts/` | Provider dockerfiles; this handover |
| Audit skills are repo-side only | `drafts/` was never COPYed nor sig-listed; `workflow/coding-agent/audits/` inherits that status | This handover |
| Seven files count as the audit family | architecture-doc-reviewer, audit, bash-audit, dhh-code-audit, handover-audit, kelsey-code-reviewer, roadmap-audit -- every skill whose function is auditing or reviewing existing work. bugfix, recovery, refactor-mv-rename-file, roadmap-management are procedures, not audits | The report's categorization |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Three audit skills (architecture-doc-reviewer, dhh-code-audit, kelsey-code-reviewer) are Claude-format imports: YAML frontmatter with `tools:`/`model:` and Claude tool APIs (Glob, TodoWrite, WebFetch, model: opus) that do not exist in pi; they are not pi-native skills and are not deployed (drafts/ was never in the deployment wiring) | contradiction | report; M3 fork-and-strip or drop |
| File `dhh-code-audit.skill.md` carries frontmatter `name: dhh-code-reviewer` -- filename and internal name disagree | contradiction | report; M3 merge/drop resolves it |
| `audit.skill.md` (content: Handover Audit) and `handover-audit.skill.md` cover one use case in two files at different formality levels | contradiction | report; M3 consolidation |
| Deployment wiring discovery: gm.md's move requires propagation through three provider dockerfiles, `_agent_sig_sources`, and the sig test fixture -- the prompts-dir COPY made the move a contract change, not an inert mv | scope change | this iteration (propagated) |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/prompts/gm.md` -> `workflow/coding-agent/gm.md` | Relocated (git mv); deployed prompt wiring preserved via dockerfile COPY |
| `workflow/coding-agent/audits/` | New directory; seven audit skills relocated from `src/reasoning/agent/drafts/` |
| `src/reasoning/providers/{pi,hermes,opencode}/provider.dockerfile` | COPY line added: gm.md into `/opt/workflow/agent/prompts/` |
| [`src/libs/container_sig.sh`](src/libs/container_sig.sh) | `_agent_sig_sources` gains `workflow/coding-agent/gm.md` |
| [`tests/test_container_sig.sh`](tests/test_container_sig.sh) | Fixture creates the new sig-source file; live run 18/18 |
| [`tests/test_trace_build.sh`](tests/test_trace_build.sh) | Agent[pi] source-list assertion updated to 9 elements; live run 12/12 |
| [`docs/development/bash-coding-conventions.md`](docs/development/bash-coding-conventions.md) | bash-audit path updated (2 references) |
| [`docs/development/conventions.md`](docs/development/conventions.md) | Skills-location row updated |
| [`docs/operations/handover_policy.md`](docs/operations/handover_policy.md) | Audit skill links updated |
| [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md) | Audit skill link updated |
| [`docs/development/project_index.md`](docs/development/project_index.md) | Coding-Agent Workflow section added |
| `workflow/coding-agent/audits/bash-audit.skill.md`, `handover-audit.skill.md` | Internal relative links fixed for the shallower directory depth |
| [`workflow/coding-agent/audits/surface-area-report.md`](workflow/coding-agent/audits/surface-area-report.md) | New: surface-area categorization report |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | M3 task: coding-agent workflow consolidation, referencing the report |

## Deferred items

The M3 reorganization itself (merging the handover-audit pair, consolidating bash review, porting or dropping the Claude-format imports, entrypoint-map document) -- recorded as the M3 task; the report is its input.

## What's Next

Sub-milestone: M2.6.6 -- Mount Model (unchanged; its runnability task remains the active delivery item).

Watch-out: the audits directory is repo-side; only `workflow/coding-agent/gm.md` is deployed, via the dockerfile COPY lines. A future move of the remaining prompts (new-iteration, wrapup, defer, propagation-check, package-branch, agent-sandbox) must repeat the same wiring propagation.
