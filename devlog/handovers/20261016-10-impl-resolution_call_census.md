---
date: 2026-10-16
milestone: M3.4.2 - Environment declaration seam
type: Implementation
status: Closed
---

# Handover - the census gate counts what it claims

## Objective

Make `tests/test_env_read_discipline.sh` measure the thing its header names. The header called it a parse census and the pin was a mention census, so one pinned site was not a site and the pin's number could not move when a call site was removed.

## Scope

`tests/test_env_read_discipline.sh` only. In: the idiom pattern matches at a command position; the pin drops `src/libs/env.sh`; the header states what the census counts and what it cannot see; two units are renamed to say "call" where they said "read".

Out: the two non-entry reads the census still lists, `scripts/install.sh:133` and `scripts/onboard.sh:459`, which are unit R4b.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The census excludes the error-message text and keeps every real call | `bash tests/test_env_read_discipline.sh` | 3 passed, 0 failed |
| The census is 10 calls across 7 files, down from 11 across 8 | the gate's own pattern, printed | the ten calls are listed in this handover's Findings |
| The whole suite is green | `bash scripts/run_tests.sh` | 1168 passed, 1 failed; the failure is the pre-existing `test_model_refresh_node_suite`, a T12 row |
| Gates clean | `bash scripts/lint.sh` | clean across 9 gates |
| No document names a renamed unit | `grep -rn` over `*.sh` and `*.md` | no hit |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The census stays static and counts calls, rather than counting passes | a true pass count needs a traced run of each chain, and the unit suite runs without Docker, so a dynamic gate would skip exactly where it is needed | the gate's header |
| The pattern anchors to a command position | the previous pattern matched any occurrence of the idiom string, so a function definition and a call were the same site and a name inside an error message was a site | `READ_IDIOS` in the gate |
| `src/libs/env.sh` leaves the pin | `env_load` is defined there and called nowhere in that file; its one textual hit was `local FILE="${1:?env_load requires a file path}"` | the gate's `test_env_resolution_call_census` comment |
| The header states that a chain makes up to two passes | the file claimed one boundary per chain while the tree makes an identity pass at the entry and a bulk pass at the prelude; both go through the one loader, and that is the property the gate can hold | the gate's header |
| The header names no migration unit letter | three sources labelled these units differently, and a gate header is the wrong place to carry a label that drifts | the gate's header |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The pin counted `src/libs/env.sh 1`, and that one hit is the name `env_load` inside the function's own argument error message. Measured: `grep -nE 'env_load ' src/libs/env.sh` returns the comment on line 6, which the comment filter drops, and `local FILE="${1:?env_load requires a file path}"` on line 28. | defect, measured | fixed | this-record |
| The corrected census is ten calls across seven files: `src/libs/env_resolve.sh` 4, and one each in `src/libs/session_env.sh`, `scripts/agent-sandbox.sh`, `scripts/resume_agent.sh`, `scripts/start_agent.sh`, `scripts/onboard.sh`, `scripts/install.sh`. | measurement, measured | record | this-record |
| R4 is not a port unit. A3 and A5 are absent from the parked branch's squash, unlike A1, A2 and A4. R4b is new work under an existing decision. | measurement, measured | the next unit | this-record |
| The chain's identity parse is already single. `env_resolve_identity` exports the triple, so the child's call over the router's exported values takes the explicit branch and reads no file. Measured by reading `src/libs/env_resolve.sh:135` against the child's call at `scripts/start_agent.sh:376`. The child's call stays, because a script invoked without the router must still resolve. | measurement, measured | record | this-record |

## Completed

| File | Change |
|---|---|
| `tests/test_env_read_discipline.sh` | `READ_IDIOS` anchors to a command position; the pin drops `src/libs/env.sh`; the header states the census's metric, its limit and the two-pass chain; two units renamed to `test_env_resolution_call_census` and `test_prelude_carries_exactly_one_call_site` |
