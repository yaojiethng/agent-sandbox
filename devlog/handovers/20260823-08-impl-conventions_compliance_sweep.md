# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6  --  Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Conventions compliance sweep (roadmap "Campaign findings 2026-08-21" bullet): bring `prune.sh`, `onboard.sh`, `start_agent.sh` up to rule 1.11/rule 3.2 dual-use guard rules and `validate_wsl_path` up to rule 3.1 return-never-exit; delete the sed-extraction test seams those violations forced.

## Scope

The three named scripts plus the three affected test files. One additional micro-fix inside scope"s blast radius: `template_version` now returns 0 with empty output on absent marker (was leaking grep"s rc=1 under pipefail; every caller masked it anyway).

## Carried forward

| Item | From handover |
|---|---|
| Compliance-sweep recommendation from campaigns 2026-08-21; fix shape prescribed there | roadmap / HARNESS_ASSESSMENT S1-S2 |

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | All three scripts source cleanly without executing; functions callable in-process | `source X && type main` per script  --  clean | accepted |
| AC2 | Direct execution unchanged | test_prune 20/0, test_onboard 11/0, test_start_agent 32/0  --  all drive the scripts via bash subprocess as before | accepted |
| AC3 | `validate_wsl_path` returns 1 instead of exiting | Called in-process by unit test without killing harness | accepted |
| AC4 | Extraction seams deleted; tests source-and-call directly | grep for `_env_field_probe`/`_template_version_probe`/`_wsl_path_probe`: clean | accepted |
| AC5 | Suite green and deterministic x2 | 628 tests / 38 files / 0 failed, two consecutive runs | accepted |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `template_version` leaked grep"s exit 1 through the pipefail pipeline on absent marker; all callers masked it via `local V=$(...)` (the rule 4.1 pitfall absorbing it silently). Made deterministic (`\|\| true` idiom, rule 4.3)  --  pinned contract was already rc=0+empty | latent bug (benign) | Fixed here; callers unchanged |
| Restructuring top-level flow into `main()` is mechanical but error-prone: an off-by-one in line-range extraction silently dropped prune.sh"s first flag-parsing loop  --  caught only because the suite exercises flag behaviour. Extraction-by-line-number of live code needs a full-suite run immediately after, not eyeballing | process note | Suite caught it same-iteration; worth a GOTCHAS candidate |
| `onboard.sh`"s ERR trap registration was also a sourced-mode side effect; moved into `main()` alongside the other prologue state | finding | Fixed in same change |

## Completed

| File | Change |
|---|---|
| [`scripts/prune.sh`](../../scripts/prune.sh) | Flag parsing + validation + flow wrapped in `main()`; rule 1.11 guard added |
| [`scripts/onboard.sh`](../../scripts/onboard.sh) | Prologue state (incl. ERR trap) + parsing + dispatch into `main()`; guard added; `template_version` deterministic |
| [`scripts/start_agent.sh`](../../scripts/start_agent.sh) | Parsing/validation/wizard-dispatch/prelude/flow into `main()`; guard added; `validate_wsl_path` returns |
| [`tests/test_prune.sh`](../../tests/test_prune.sh) | `_env_field_probe` -> source-and-call `env_field` |
| [`tests/test_onboard.sh`](../../tests/test_onboard.sh) | `_template_version_probe` -> source-and-call `template_version` |
| [`tests/test_start_agent.sh`](../../tests/test_start_agent.sh) | `_wsl_path_probe` -> source-and-call `validate_wsl_path` |

Roadmap "Conventions compliance sweep" sub-bullet marked complete.

## Deferred items

None new. Remaining campaign-fix bullets (empty-diff decision, savepoint bug, container_sig defects, header contradictions, shellcheck cleanup) stay on the roadmap for their own iterations.

## What"s Next

M2.6 continues per roadmap.
