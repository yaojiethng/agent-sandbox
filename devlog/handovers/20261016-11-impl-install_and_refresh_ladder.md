---
date: 2026-10-16
milestone: M3.4.2 - Environment declaration seam
type: Implementation
status: Closed
---

# Handover - the last two reads move onto the ladder

## Objective

Take the last two configuration reads that bypassed the precedence primitive and put them on it. `scripts/install.sh` read `INSTALL_DIR` from a file nothing writes, and `scripts/onboard.sh` read `PROJECT_DIR` with no env level. Both called `env_file_value`, the low-level read that applies no precedence.

## Scope

In: `scripts/install.sh` resolves `INSTALL_DIR` through `env_resolve_one` and gains `--env=<path>`; `scripts/onboard.sh`'s refresh read goes through the same primitive; `src/libs/env_resolve.sh` drops `env_file_value`, which is left with no caller; `tests/test_install.sh` replaces the unit that pinned the dead rung and adds the env-level unit; `tests/test_env_read_discipline.sh` keeps `env_file_value` in the idiom list as a tripwire.

Out: R5, the `.draft-state` record.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The install ladder resolves at every rung | `bash tests/test_install.sh` | 19 passed, 0 failed |
| The refresh read still works | `bash tests/test_onboard.sh` | 23 passed, 0 failed |
| The census still matches, and no call bypasses the ladder | `bash tests/test_env_read_discipline.sh` | 3 passed, 0 failed |
| The consumers of the resolver are unaffected | `bash tests/test_env.sh`, `bash tests/test_start_agent.sh`, `bash tests/test_resume.sh` | 17, 32 and 34 passed |
| The whole suite is green | `bash scripts/run_tests.sh` | 1169 passed, 1 failed; the failure is the pre-existing `test_model_refresh_node_suite`, a T12 row |
| Gates clean | `bash scripts/lint.sh`, `bash scripts/check_shell.sh`, `bash scripts/check_lib_contract.sh` | clean across 9 gates; clean; clean |
| No definition or call of `env_file_value` remains | `grep -rn env_file_value src/ scripts/` | no hit |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `install.sh` gains `--env=<path>`, normalized once into `ENV_FILE` by `install_main` | the sandbox `.env` the ladder must read is named by `--env`; without it the script can only guess the CWD. The normalization is one place, so `install_dir` and `do_uninstall` resolve the same file | `scripts/install.sh` |
| The bare `INSTALL_DIR` stays the explicit rung | the documented form is `INSTALL_DIR=<path> bash scripts/install.sh`, and the suite drives the install path through it. The ADR's rejected alternative concerns a sourced export acting as the *env level*; that level is now `AGENT_SANDBOX_INSTALL_DIR` | `scripts/install.sh` |
| `AGENT_SANDBOX_INSTALL_DIR` is added as the env level | without it `INSTALL_DIR` had no host level, so only a file could set it | `scripts/install.sh` |
| The `<repo>/.env` rung is deleted rather than repaired | onboard writes the sandbox `.env`, never the repo root, so the rung named a file nothing produces | `scripts/install.sh` |
| The refresh read keeps its `.env` existence guard | a miss must leave `PROJECT_DIR` empty and let refresh proceed, as it did before; without the guard the primitive's error message becomes refresh's output | `scripts/onboard.sh` |
| `env_file_value` is deleted | it had no caller in `src/`, `scripts/` or `tests/`, and its own docstring stated the policy the ADR reversed: a consumer that wants one key from a `.env` calls it rather than the ladder. Reversal word `keep-public` | `src/libs/env_resolve.sh` |
| The deleted function's name stays in the census idiom list | the pattern anchors to a command position, so the name is now a tripwire: a future call to it is a read that bypasses the ladder, and the census fails | `tests/test_env_read_discipline.sh` |
| No new assertion pins the deletion | an assertion that the library does not define a function passes however the tree changes, so it cannot fail and is not a test | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `install.sh`'s `.env` rung was dead. `onboard` writes `INSTALL_DIR=~/.local/bin` into the sandbox `.env` at `onboard.sh:255`, while `install_dir` read `$REPO_ROOT/.env`, which onboard never writes. Measured: the written value could not be read by any path. | defect, measured | fixed | this-record |
| `install.sh`'s first rung was a bare host variable, which the ADR's rejected alternatives forbid as an env level. The rung is kept as the explicit level and the env level is added beside it. | defect, measured | fixed, with the reason recorded | this-record |
| `env_file_value` went dead in this unit. It was not part of the design: the port introduced it to move `install.sh` off its own `grep` and `cut` read, so it was an intermediate rung that the ladder then superseded. | dead code, measured | removed | this-record |
| The census count is unchanged at 10 calls across 7 files. Both reads remain calls and are now ladder calls, so this unit's outcome is a property of the callee, not a shrinking pin. | measurement, measured | record | this-record |
| `tests/test_lint_umbrella.sh` timed out on its declared 10s budget on one suite run in three, and passed alone and on re-run. `check_markdown.sh` at 7s is the umbrella's floor. The budget was not raised, because the file states that its declaration is a budget rather than a licence. | flake, measured | open | the-roadmap |

## Completed

| File | Change |
|---|---|
| `scripts/install.sh` | `install_dir` resolves through `env_resolve_one`; `install_main` parses `--env=` and normalizes `ENV_FILE`; the header states the four rungs |
| `scripts/onboard.sh` | the refresh `PROJECT_DIR` read goes through `env_resolve_one` with `AGENT_SANDBOX_PROJECT_DIR` as the env level |
| `src/libs/env_resolve.sh` | `env_file_value` is removed; the resolution primitive is the library's public read |
| `tests/test_install.sh` | `test_install_dir_reads_env_file` replaces the unit that pinned the repo-root rung; `test_install_dir_env_level_beats_the_env_file` is new; the default unit no longer sets `REPO_ROOT` |
| `tests/test_env_read_discipline.sh` | the idiom list documents its tripwire |
