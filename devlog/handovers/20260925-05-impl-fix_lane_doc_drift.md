# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Correct the documentation and operator-guidance drift the read-through named, so each document states what the code does.

## Scope

Fix lane F4 of the read-through close, 21 assigned rows (92, 93, 112, 127, 134, 138, 151, 174, 179, 195, 218, 221, 240, 249, 254, 257, 258, 259, 264, 266, 282). Documentation, requirement declarations, and stale path references.

## Carried forward

| Item | From handover |
|---|---|
| The documentation-drift rows of the immediate fix lane | roadmap M3.1 (`Read-through close: operator review, then a findings-to-tasks plan session`) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| Each named drift is corrected in the document that owns the claim | the document text against the code | Agent [x] |
| A stale path reference to a file that does not exist is replaced by the true one | `find` for the old name; the replacement checked against `scripts/build.sh` | Agent [x] |
| Lint clean and suite green | both runs | Agent [x] (782 units) |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/development/host_requirements.md`](../../docs/development/host_requirements.md) | a requirement declaration was missing |
| [`src/reasoning/providers/pi/onboard-readme.md`](../../src/reasoning/providers/pi/onboard-readme.md) | a stale build-context reference |
| `tests/test_run_agent.sh`, `test_resume.sh`, `test_confirm_workflow.sh` | the units whose subject the rows name |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Replace the `containers.sh` build-context reference with the repository root | no `containers.sh` exists anywhere in the tree, and `scripts/build.sh` documents "docker build using repo root as context" | the onboard readme |
| Leave row 282 unchanged | its finding is stale: the BDD block it names already states the three-valued guard order, and no earlier revision used the name it claims | this handover's Findings |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Row 282's finding is stale in the register: the block it names already reads correctly and `git log -S` finds no revision that named the other symbol. | contradiction | roadmap |
| Three rows (179, 195, 249) are triaged `fix (test)` but list only a production file, so the test edited is the one whose subject that file is; the triage's file list is incomplete for those rows. | contradiction | next iteration |
| The `lsof` requirement discovered in the instrument lane still needs its line in the installation requirements document. | bug | next iteration |

## Completed

| File | Change |
|---|---|
| `docs/development/host_requirements.md` | the requirement line corrected |
| `src/reasoning/providers/pi/onboard-readme.md` | the build-context reference corrected to the repository root |
| `docs/` and `devlog/` documents named by the rows | operator guidance and drift corrected |
| `tests/test_run_agent.sh`, `tests/test_resume.sh`, `tests/test_confirm_workflow.sh` | the units for the named production files |

## Deferred items

None. The `lsof` requirement line and the incomplete triage file lists are recorded in Findings.

## What's Next

The lesson plan is the last unit of the read-through close.

**Conclusions from this iteration:** a documentation claim can only be verified against the code, so a doc-drift row is a code-reading task wearing a documentation costume.
