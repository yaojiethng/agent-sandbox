---
date: 2026-10-16
milestone: M3.4.2 - Environment declaration seam
type: Implementation
status: Closed
---

# Handover - the chain entry resolves the identity once

## Objective

Move identity resolution out of the shared prelude and into the chain entry, so the prelude consumes a resolved triple and parses the `.env` once. Cure the resume red that the parked draft branch left in the same change.

## Scope

Harvested per file from the parked draft branch's squash `3dbc5dda`, not ported as a unit. In: `src/libs/session_env.sh` renames `session_env_common_init` to `resolve_and_init`, flips its argument order to `<project_name> <project_dir> <sandbox_dir>`, and removes its resolver call; `scripts/start_agent.sh` resolves before the prelude; `scripts/resume_agent.sh` does the same and fixes two defects the squash carried; `src/libs/env_resolve.sh` gains the `ENV_REL` default and the missing-`.env` path check; `tests/test_session_env.sh` and the census pin follow.

Out: the squash's `Makefile.template` read removal, its `kv_update`, and its dry-run probe changes, which are units R2, R3 and R4.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The resume red is cured | `bash tests/test_resume.sh` | 34 passed, 0 failed |
| The prelude consumes rather than resolves | `bash tests/test_session_env.sh` | 17 passed, 0 failed |
| The census pin matches, with the prelude at one site and the entry named | `bash tests/test_env_read_discipline.sh` | 3 passed, 0 failed |
| The two consumers of the prelude still behave | `bash tests/test_start_agent.sh`, `bash tests/test_run_agent.sh` | 32 passed and 41 passed |
| The whole suite is green | `bash scripts/run_tests.sh` | 1165 passed, 1 failed; the failure is the pre-existing `test_model_refresh_node_suite`, a T12 row |
| Gates clean | `bash scripts/lint.sh`, `bash scripts/check_shell.sh`, `bash scripts/check_lib_contract.sh` | clean across 9 gates; 0 warnings across 175 files; 0 findings across 24 files |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Harvest the squash per file rather than port it | the squash does not apply, and the two files that conflict are the two the port already improved | this handover |
| `resume_agent.sh` carries one resolution site with a deferred failure, not a tolerant enrichment plus a dispatch resolution | two calls is two parses of one `.env` per chain, which is the thing this milestone removes; the census gate caught the two-site version | this handover |
| `env_resolve_identity` defaults its fourth argument to `ENV_REL` | `${ENV_REL:-}` written at a call site expands before a command-prefix assignment applies, so the resolved path was empty and the resolver read the wrong file; inside the function body the assignment is visible. ShellCheck reports the call-site form as SC2097 and SC2098 | `src/libs/env_resolve.sh` |
| The prefix-assignment call sites in `test_session_env.sh` pass three arguments, not four | with the resolver default in place the fourth is redundant, and it was the line ShellCheck flagged | this handover |
| The listing keeps its tolerant contract | a listing is a registry diagnostic, so a resolution failure degrades its columns and never ends it; the resume proper needs the triple and exits when the flag is false | `scripts/resume_agent.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The squash's `resume_agent.sh:227` chained `env_resolve_identity ... && resolve_and_init ...` where `start_agent.sh:376-377` uses `\|\| exit 1` and a separate call. Measured: four of the seven resume failures report `exec=''`, because a resolver failure skipped `resolve_and_init` and the script ran on unresolved. That is the red's cause. | bug, measured | fixed | this-record |
| The squash also deleted the listing enrichment from above the inventory render and placed its replacement below it, so `--list` rendered before anything resolved. Measured: `test_list_env_resolves_project_dir_when_sandbox_only` and `test_interactive_env_resolved_branch_hint` reported empty STATE cells. | bug, measured | fixed | this-record |
| The squash's `tests/test_session_env.sh` line 1 is `X#!/usr/bin/env bash`. The file runs under an explicit `bash`, so no test caught it. | bug, measured | fixed on harvest | this-record |
| `kv_record.sh`'s `kv_update` has no test at all on the branch, for either its replace or its append arm. It is unit R3. | gap, measured | its own unit | this-record |
| The census pin's purpose is stated nowhere as a number, so the milestone's reduction needs counting by hand each unit. The pin is 12 sites across 9 files at this unit, unchanged from before it, because the prelude lost one parse and the entry gained one. The net reduction comes from R2, R4 and R5. | observation, measured | none | the-roadmap |

## Completed

| File | Change |
|---|---|
| `src/libs/session_env.sh` | `resolve_and_init` takes the resolved triple in `<name> <dir> <sandbox>` order and resolves nothing; the header and its argument messages name the new function |
| `scripts/start_agent.sh` | sources the resolver, resolves the triple, exits 1 on failure, then calls `resolve_and_init` |
| `scripts/resume_agent.sh` | one up-front resolution with a deferred failure; the listing keeps its tolerant columns; the dispatch exits when the flag is false; stale comments retargeted |
| `scripts/run_agent.sh` | a comment names `resolve_and_init` |
| `src/libs/env_resolve.sh` | `env_ref` defaults to `ENV_REL`; a specified `.env` that does not exist fails naming the path |
| `tests/test_session_env.sh` | the prelude tests drive the entry then the prelude; four call sites drop the redundant fourth argument |
| `tests/test_env_read_discipline.sh` | the pin reads `session_env.sh 1` and names `scripts/start_agent.sh 1`; the third unit asserts one prelude site |
