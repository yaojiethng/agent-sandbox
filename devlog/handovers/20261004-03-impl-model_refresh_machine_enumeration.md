---
date: 2026-10-04
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Implementation
status: Active
---

# Handover - Implementation: the `model-refresh` machine is enumerated

## Objective

Enumerate the `model-refresh` refresh path as the three recorded systems, with a named id per transition, and make the invariant catalog total over that enumeration - every invariant classified, every transition held by a case, every invariant except R1 held by a mutation row - with the extension suites running under `make test`.

## Scope

Continues the `model-refresh improvements` parent row from the plan handover [`20261004-02-plan-model_refresh_startup.md`](20261004-02-plan-model_refresh_startup.md), unit A: *the machine is enumerated and the invariant set is total*.

Targets the `## The update and catalog state machine` enumeration in the extension README, the invariant catalog `tests/extensions/pi/model-refresh/invariants.ts`, the mutation catalog `tests/extensions/pi/model-refresh/mutation/catalog.ts`, the union's identity key in `catalog.ts`, A7's assumption row, and the harness wiring that brings the extension suites into `make test`.

Out of scope: unit B's announcement rewrite and unit C's cache, both their own roadmap rows. The three lifecycle transitions gain ids and falsifiable cases; their behaviour is unchanged. The two `pi upstream` reports stay on hold.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The enumeration names every transition with an id, and every invariant in the catalog is classified as a state, transition, or guard property | read the README section; the totality case below fails on an unclassified invariant | Agent [ ] |
| 2 | Every transition names at least one invariant, or records why it has none | the totality case fails on a transition that does neither | Agent [ ] |
| 3 | Each of the three lifecycle transitions - the pre-session refresh (A14), the failing-source narrowing, and the pre-UI report hold (A13) - carries an invariant id and a case that goes red when the behaviour is removed | `node --test tests/extensions/pi/model-refresh/invariants.test.ts`; the three new cases pass, and each has a mutation row that proves it | Agent [ ] |
| 4 | Every invariant holds a mutation row except R1, exempt with its reason recorded in the catalog | `MUTATION=1 bash scripts/run_tests.sh` reports 13 new rows proven and no survivors; the R1 exemption is stated in `mutation/catalog.ts` | Agent [ ] |
| 5 | A machine-run totality check asserts every transition id has a case and every case names a transition or state id | `node --test tests/extensions/pi/model-refresh/invariants.test.ts`; the check passes, and its mutation row proves it fails on an unpaired transition id | Agent [ ] |
| 6 | The union's identity key is pi's `type + id`, so a same-id pair of different types is served as two entries where pi's `mergeModels` serves two, pinned by a G2 case | `node --test tests/extensions/pi/model-refresh/invariants.test.ts tests/extensions/pi/model-refresh/catalog.test.ts` | Agent [ ] |
| 7 | A7's text names only the formats that emit a `reasoning_effort`, and the deepseek-format case is outside its domain rather than a probe gap | read the README A7 row | Agent [ ] |
| 8 | The `model-refresh` node suite runs under `make test`, with a registration guard so a new test file cannot rot | `make test` reports the new harness unit and its file count; the guard fails on an unregistered file | Agent [ ] |
| 9 | The `model-refresh` knowledge script is reachable by the `bash -n` smoke check | `bash scripts/check_test_smoke.sh` counts it in its total | Agent [ ] |
| 10 | No state carries two transitions on one event whose guards can both hold | the guard-overlap check in the suite; read against the diagram | Agent [ ] |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the enumeration and diagram; the invariant classification table; A7's row |
| [`tests/extensions/pi/model-refresh/invariants.ts`](../../tests/extensions/pi/model-refresh/invariants.ts) | the catalog gains a `kind`, the three lifecycle cases, and the transition ids the totality check reads |
| [`tests/extensions/pi/model-refresh/invariants.test.ts`](../../tests/extensions/pi/model-refresh/invariants.test.ts) | the three lifecycle cases and the totality check |
| [`tests/extensions/pi/model-refresh/mutation/catalog.ts`](../../tests/extensions/pi/model-refresh/mutation/catalog.ts) | twelve new rows and the R1 exemption |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts) | the union's identity key |
| `tests/extensions/pi/model-refresh/catalog.test.ts` | the identity-key cases |
| [`tests/test_model_refresh.sh`](../../tests/test_model_refresh.sh) | new: wires the extension node suite and its registration guard into `make test` |
| [`scripts/check_test_smoke.sh`](../../scripts/check_test_smoke.sh) | reaches the extension knowledge scripts |
| [`src/reasoning/agent/skills/state-machine-specification/SKILL.md`](../../src/reasoning/agent/skills/state-machine-specification/SKILL.md) | the classification vocabulary and the six suite checks the enumeration is held to |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The enumeration carries an id per transition, and every invariant is classified state, transition, or guard | an invariant with no class cannot be checked against the model it claims, and a transition with no id cannot be paired with a case | this record; the README section |
| R1 is exempt from a mutation row | R1 is the bijection between the catalog and the test file, so mutating it mutates the gate itself | the mutation catalog, at the R1 row's note |
| The union carries `type` and keys identity on `type + id` at every site | option (a), operator-released 2026-10-04: it is the only option that matches pi's `mergeModels`, and G2's `agrees with pi` case is a claim about the extension's own key, so a chat-only filter would make the case attest a divergence instead | this record |
| The two 2026-10-04 handovers take frontmatter, folded into their own commits | the format window reaches them; the gate skipped them because a record with no frontmatter block carries no date for the cutover test to read | this record; commits `0327ad0` and `7d84230` |

## Decisions pending

| Question | Blocks | Options |
|---|---|---|
| Does unit A's enumeration follow the three-step proposal flow of the `state-machine-specification` skill, or the single released scope? | how the enumeration's states and diagram are confirmed before the code changes | (a) **Follow the skill**: this iteration first proposes the state set for confirmation, then the labelled diagram `event [guard] / effect`, then the invariants and tests; three operator stops. (b) **Single stop**: the plan handover already confirmed the model, and the enumeration lands as one reviewed scope. The skill's checks 1 to 6 apply either way; only the confirmation cadence differs. |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The two handovers dated 2026-10-04 (`20261004-01`, `20261004-02`) carried the bold-header form, not the YAML frontmatter the format window requires from 2026-10-01. Traced: no live document carries that form; it survives only in the pre-cutover records, and `scripts/lint/handover-format.mjs` treats an absent frontmatter block as history in cutover mode, so a new record missing the block is unreachable by the date test. Fixed: both take frontmatter, folded into their own commits (`0327ad0`, `7d84230`) | record defect | resolved this iteration |
| The operator landed a `state-machine-specification` skill mid-iteration (commit `2b46238`). It renames the classification to **state / transition / guard**, makes the date comparison a guard rather than an "application policy", adds rule 6 (no state has two transitions on one event whose guards can both hold), and prescribes three operator-confirmed proposal steps | steering | this iteration: the Decisions pending question above |
| `scripts/run_tests.sh` discovers only `tests/test_*.sh`, so the 3000-line `model-refresh` node suite is not in `make test` | gap | this iteration, criterion 8 |
| `scripts/check_test_smoke.sh` globs `tests/{knowledge,integration,eval}/*.sh` only, so `tests/extensions/**/knowledge/*.sh` is unreachable and has never been syntax-checked by a gate | gap | this iteration, criterion 9 |
| `ModelDefinition` declares no `type`, and the union decides identity at three sites (`unionFirstWins`, `overlayPreservingOrder`, the metadata pass); the `type + id` key therefore needs the type carried and the key applied consistently | design gap | this iteration: resolved by the composite-key decision |
| `unionFirstWins` copies unknown keys through `fillMissing`, so a stored entry's `type` reaches the served entry even though the interface does not declare it; the collapse is reachable, not hypothetical | defect | this iteration, criterion 6 |

## Completed

No file changes this iteration.
