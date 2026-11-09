---
date: 2026-10-16
milestone: M3.4.2 - Environment declaration seam
type: Implementation
status: Closed
---

# Handover - the Makefile stops reading the .env

## Objective

Remove the make-level `.env` read, so the Makefile is not a second resolution surface. Every target already hands the CLI `--env=$(ENV_FILE)`, so the Makefile needs no identity of its own.

## Scope

Harvested from the parked draft branch's squash `3dbc5dda`. In: `scripts/templates/Makefile.template` drops `-include .env` and the three `PROJECT_NAME ?=` / `PROJECT_DIR ?=` / `SANDBOX_DIR ?=` guards that produced the Makefile's own error text, and the `refresh` target passes `--env=$(ENV_FILE)` instead of the triple; `tests/test_makefile_template.sh` expects the new invocation; `tests/test_onboard.sh`'s generated-Makefile assertion follows; the census pin drops the template.

`ENV_FILE := $(CURDIR)/.env` and the per-target `--env=$(ENV_FILE)` arguments were already in the template before this unit, so the removal changes no invocation except `refresh`.

Out: the dry-run probe's channels and the leaf contract, which are unit R4.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The template carries the expected invocation per target | `bash tests/test_makefile_template.sh` | 11 passed, 0 failed |
| The generated Makefile bakes no identity and points at `.env` | `bash tests/test_onboard.sh` | 23 passed, 0 failed |
| The census pin matches, with the template gone | `bash tests/test_env_read_discipline.sh` | 3 passed, 0 failed |
| The consumers of the make chain still behave | `bash tests/test_start_agent.sh`, `bash tests/test_resume.sh` | 32 passed and 34 passed |
| The whole suite is green | `bash scripts/run_tests.sh` | 1165 passed, 1 failed; the failure is the pre-existing `test_model_refresh_node_suite`, a T12 row |
| Gates clean | `bash scripts/lint.sh`, `bash scripts/check_shell.sh` | clean across 9 gates; 0 warnings across 175 files |
| The census shrank by one site and one file | the census pipeline | 11 read sites across 8 files, from 12 across 9 |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The template keeps `ENV_FILE := $(CURDIR)/.env` and gains no replacement identity block | every target already passes `--env=$(ENV_FILE)`, so the CLI resolves the triple and the Makefile stops needing one | `scripts/templates/Makefile.template` |
| `refresh` passes `--env=$(ENV_FILE)` rather than the triple | it was the one target that read the identity from the make scope, and `onboard --refresh` accepts `--env` | `scripts/templates/Makefile.template` |
| `test_onboard.sh` asserts the absence of an identity assignment rather than a forwarded `--name` | the property the test exists for is that identity lives in the `.env` and not in the Makefile; the mechanism that delivers it changed | `tests/test_onboard.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The squash's `scripts/templates/Makefile.template:394` is corrupted. The line reads `--env=20 20ENV_FILE)` where it must read `--env=$(ENV_FILE)`. Measured: the branch's own blob carries the same corruption, so `git apply` reproduced it faithfully rather than introducing it. | bug, measured | fixed | this-record |
| The squash left `tests/test_onboard.sh` red: `test_fresh_onboard_makefile_reads_name_from_env` asserts the generated Makefile forwards `--name=$(PROJECT_NAME)`, which is exactly what this unit removes. No test in the squash touched that file. | bug, measured | fixed | this-record |
| Three artifacts of the bad-agent squash are now catalogued, each caught by a different check: the `&&` chain and the misplaced enrichment by the resume tests, the `X` shebang by reading the harvested file, and this line by ShellCheck and the suite. None was found by the squash's own commit message. | observation, measured | record | this-record |

## Completed

| File | Change |
|---|---|
| `scripts/templates/Makefile.template` | `-include .env` and the three identity guards are gone; `refresh` passes `--env=$(ENV_FILE)`; the corrupted path argument is repaired |
| `tests/test_makefile_template.sh` | the refresh expectation names `--env=` |
| `tests/test_onboard.sh` | the generated-Makefile unit asserts no identity assignment and a forwarded `--env=$(ENV_FILE)` |
| `tests/test_env_read_discipline.sh` | the pin drops `scripts/templates/Makefile.template 1` |
