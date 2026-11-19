---
date: 2026-11-19
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - one owner for the sandbox directory path

## Objective

Settle which side owns `SANDBOX_DIR`, the resolution ladder at onboard or the runtime in `start_agent.sh`, and make the code and `docs/adr/resolution_model.md` state that one rule.

## Scope

Iteration scope: the roadmap row `The runtime SANDBOX_DIR derivation contradicts the resolution ladder` under M3.4.2. The operator ruled that the ladder owns the value, so `start_agent.sh` derives nothing and the identity call resolves the path from the explicit `--sandbox`, `AGENT_SANDBOX_SANDBOX_DIR`, then the `.env`, then the error naming onboard.

The remaining M3.4.2 rows stay on the roadmap as their own iterations.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One owner is stated: `resolution_model.md` and the code name the same side | The ADR's edge-case paragraph now records the drift as gone; `start_agent.sh` holds no derivation and hands the ladder an empty value | Accepted |
| The reading the ruling rejects cannot return silently | `tests/test_env_read_discipline.sh::test_sandbox_path_is_a_ladder_value` fails if start invents a path: it asserts the refusal names `onboard`, and asserts no `proj-sandbox` path appears | Accepted |
| No second site derives `SANDBOX_DIR` from `PROJECT_DIR` | `grep -rn 'basename' scripts/ src/libs/ \| grep -i sandbox` returns nothing; `scripts/start_agent.sh` carries no `dirname`/`basename` pair for the sandbox | Accepted |
| The suite is green | `make lint` (29 gates) and `TEST_PARALLEL=1 bash scripts/run_tests.sh`: 1633 passed, 0 failed across 125 files | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `SANDBOX_DIR` is a ladder value; the runtime derives nothing. | R3 forbids a computed default, and a derived path occupied the explicit level, so the value onboard writes into the `.env` could never win it. | [`resolution_model.md`](../../docs/adr/resolution_model.md), edge-case paragraph |
| An explicit `--sandbox` is canonicalized before resolution; a ladder-supplied value after it. | Keeps a misspelt path reporting as a path rather than as the `.env` the resolver could not find inside a directory that does not exist. | `scripts/start_agent.sh`, `_canon_sandbox_dir` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row overstated where the defect bit: the supported entry (`agent-sandbox start`) already resolved through the ladder, and only a direct `scripts/start_agent.sh` invocation guessed. The ruling is unchanged; the exposure is narrower than the row implied. | record | The row's premise was wider than the code. | The ADR's edge-case paragraph states it as the script's drift; this record. |
| Two tests pinned the removed behaviour, and one of them caught a regression I introduced: moving the canonicalisation after the identity call made a misspelt `--sandbox` report as `/.env not found` inside a path that does not exist, instead of as a path. | code | A worse diagnostic for the same failure, found by `test_unresolvable_sandbox_reports_canonicalisation`. | Fixed in this commit by `_canon_sandbox_dir`, called on both sides of the resolver. |
| `tests/test_start_agent.sh::test_derived_sandbox_dir_uses_sandbox_suffix` asserted the derivation itself. | code | The test was a carrier of the removed contract. | Replaced by `test_env_supplies_sandbox_dir_over_the_sibling`, which sets a decoy sibling and asserts the onboarded value wins and the sibling is never used. |
| `env_resolve_identity` treats its default `.env` as a specified one, so a resolved sandbox with no `.env` prints `A specified --env path must exist` to a caller who specified nothing. Observed here, not fixed: outside this row's scope. | code | A misleading remedy in an adjacent path. | Added as a clause to M3.4.2's open row `The resolution primitive's failure text names the identity setting`. |

## Completed

| File | One-line change summary |
|---|---|
| `scripts/start_agent.sh` | The sibling derivation is gone; `SANDBOX_DIR` resolves through the identity ladder, and `_canon_sandbox_dir` canonicalizes an explicit value before resolution and a resolved one after it. |
| `tests/test_env_read_discipline.sh` | New `test_sandbox_path_is_a_ladder_value`: start refuses rather than inventing a path, names `onboard`, and names no sibling. |
| `tests/test_start_agent.sh` | `test_derived_sandbox_dir_uses_sandbox_suffix` replaced by `test_env_supplies_sandbox_dir_over_the_sibling`, which proves the `.env` value beats a decoy sibling. |
| `docs/adr/resolution_model.md` | The edge-case paragraph records the drift as gone rather than filed. |
| `devlog/roadmap.md` | The row marked, with this handover; the failure-text row gains the default-`.env` clause. |
| `devlog/handovers/M3.4/20261119-01-impl-sandbox_dir_owner.md` | This record. |
