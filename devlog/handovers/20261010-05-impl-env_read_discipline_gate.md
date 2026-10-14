---
date: 2026-10-10
milestone: M3.4 - Configuration and Persisted Record Formats
type: Implementation
status: Closed
---

# Handover - Implementation: the env read-site census gate

## Objective

Make the env-load boundary a fact about the tree: one pinned census of every site that parses the `.env`, a gate that fails on a new site or a second parser, and the last second parser removed.

## Scope

New `tests/test_env_read_discipline.sh` pins the census per file and fails when a site appears outside it, a sanctioned file gains a call, or a shell pipeline parses a `.env`. `scripts/install.sh` moves its `INSTALL_DIR` fallback off its own `grep|cut` read onto `env_file_value`, which closes the one unsanctioned parser in the tree. The gate was proven able to fail: the census pipeline against a planted site in a scratch tree reports the site and ignores comment lines.

The census at this unit, 12 read lines across 8 files:

| File | Sites | Role |
|---|---|---|
| `src/libs/env.sh` | 1 | the loader definition |
| `src/libs/env_resolve.sh` | 4 | the resolution primitive and its three per-key calls |
| `src/libs/session_env.sh` | 2 | the prelude: identity resolution and bulk load |
| `scripts/agent-sandbox.sh` | 1 | the CLI entry's identity resolution |
| `scripts/resume_agent.sh` | 1 | the inventory enrichment read |
| `scripts/onboard.sh` | 1 | its own entry |
| `scripts/install.sh` | 1 | its own entry |
| `scripts/templates/Makefile.template` | 1 | the make-level `-include .env` |

Named migration units, each shrinking the census: U2 collapses the prelude's two parses into one snapshot at the chain entry, U3 removes the resume enrichment site and the router's own resolution, U4 gives the Makefile chain argument passing instead of `-include .env`, U5 makes every leaf's configuration part of its invocation so no leaf resolves.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The census matches the pinned set exactly, per file | `bash tests/test_env_read_discipline.sh` | accepted: 3 passed, 0 failed |
| No shell pipeline parses a `.env` | the same file | accepted |
| The prelude carries exactly two named sites for U2 | the same file | accepted |
| `install_dir` still resolves env, `.env`, then default | `bash tests/test_install.sh` | accepted: 18 passed, 0 failed |
| Gates clean | `bash scripts/check_shell.sh`, `bash scripts/check_lib_contract.sh`, `bash scripts/lint.sh` | accepted: 0 warnings, 0 findings, clean |
| The gate can fail | the census pipeline against a planted site in a scratch tree | accepted: the site is reported, comment lines are not |

## Hot files

| File | Why in scope |
|---|---|
| [`tests/test_env_read_discipline.sh`](../../tests/test_env_read_discipline.sh) | new: the census pin and the second-parser scan |
| [`scripts/install.sh`](../../scripts/install.sh) | its `.env` read moves onto the sanctioned loader |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Pin the census per file rather than a global count | a global count hides a site moving between files; the per-file pin makes every removal a deliberate census amendment | this handover |
| The gate carries a shrinking census, not an allowlist of paths | each entry names the unit that removes it, so the debt is scheduled rather than parked | this handover |
| `install.sh` sources the loader at file scope | the test drives `install_dir` sourced, so the reader must be defined by the time it runs; sourcing at top keeps the standalone path working | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| One `make start` chain parses the `.env` at least seven times today: the Makefile's include, the router's resolution, the prelude's two parses and its three per-key reads, plus a leaf enrichment. The operator's single-load directive is the fix; the census is the measurement. [A] 2026-10-10 | contradiction | roadmap |
| The Makefile template's `-include .env` is a whole parallel resolution surface: it resolves the identity triple itself and fails with its own error text, so the Makefile and the CLI can disagree about the same file. [A] 2026-10-10 | bug | roadmap |

## Completed

| File | Change |
|---|---|
| [`tests/test_env_read_discipline.sh`](../../tests/test_env_read_discipline.sh) | new: the pinned census, the second-parser scan, the prelude count |
| [`scripts/install.sh`](../../scripts/install.sh) | `install_dir` reads through `env_file_value`; the ad-hoc parser is gone |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the T10 environment row records the census and the migration units |
