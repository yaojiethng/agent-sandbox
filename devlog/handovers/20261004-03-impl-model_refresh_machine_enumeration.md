---
date: 2026-10-04
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Implementation
status: Closed
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
| 1 | The enumeration names every transition with an id, and every invariant in the catalog is classified as a state, transition, or guard property | `invariants.ts` carries `STATES`, `TRANSITIONS` and `CLASSIFICATION`; the totality case fails on an unclassified invariant. Read against the README section and the renamed ids `X1`-`X13` | Agent [x] |
| 2 | Every transition names at least one invariant, or records why it has none | the totality case fails on a transition that does neither; `X7`, `X8`, `X9` and `X10` carry a `noCaseReason` naming the ignored event and unit B's rewrite | Agent [x] |
| 3 | Each of the three lifecycle transitions - the pre-session refresh (`X11`, A14), the failing-source narrowing (`X12`), and the pre-UI report hold (`X13`, A13) - carries an invariant id and a case that goes red when the behaviour is removed | invariants `L3`, `L4`, `L5`, each with a case and a `proven` mutation row (`index:attach-never-runs`, `report:pre-ui-report-dropped`, `refresh:failure-empties-the-catalog`) | Agent [x] |
| 4 | Every invariant holds a mutation row except R1, exempt with its reason recorded | the gate reports 44 rows, all as expected, and `no row names: R1`; fifteen rows are new - M2, M4, M6, G2, L1, L2, C2, C3, T1, T4, W1, D1, and the lifecycle L3, L4, L5; the exemption is stated in the README | Agent [x] |
| 5 | A machine-run totality check asserts every transition id has a case and every case names a transition or state id | `node --test tests/extensions/pi/model-refresh/invariants.test.ts`; the `totality` case passes | Agent [x] |
| 6 | The union's identity key is pi's `type + id`, so a same-id pair of different types is served as two entries where pi's `mergeModels` serves two, pinned by a G2 case | the G2 case `keeps a same-id pair of different types apart` drives pi's `getAllModels` and passes | Agent [x] |
| 7 | A7's text names only the formats that emit a `reasoning_effort`, and the deepseek-format case is outside its domain rather than a probe gap | read the README A7 row | Agent [x] |
| 8 | The `model-refresh` node suite runs under `make test`, with a registration guard so a new test file cannot rot | `bash scripts/run_tests.sh` reports 72 files and includes the new harness unit with its file count | Agent [x] |
| 9 | The `model-refresh` knowledge script is reachable by the `bash -n` smoke check | `bash scripts/check_test_smoke.sh` counts 7 excluded scripts, including it | Agent [x] |
| 10 | No state carries two transitions on one event whose guards can both hold | the guard-overlap loop in `checkTotality`; a shared event without distinct guards is a finding | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the enumeration and diagram; the invariant classification table; A7's row |
| [`tests/extensions/pi/model-refresh/invariants.ts`](../../tests/extensions/pi/model-refresh/invariants.ts) | the catalog gains the three lifecycle cases; `CLASSIFICATION`, `TRANSITIONS` and `STATES` carry the classification and the machine, and the totality check reads them |
| [`tests/extensions/pi/model-refresh/invariants.test.ts`](../../tests/extensions/pi/model-refresh/invariants.test.ts) | the three lifecycle cases and the totality check |
| [`tests/extensions/pi/model-refresh/mutation/catalog.ts`](../../tests/extensions/pi/model-refresh/mutation/catalog.ts) | fifteen new rows; the R1 exemption is recorded in the README, not as a row |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts) | the union's identity key |
| `tests/extensions/pi/model-refresh/catalog.test.ts` | the identity-key cases |
| [`tests/test_model_refresh.sh`](../../tests/test_model_refresh.sh) | new: wires the extension node suite and its registration guard into `make test` |
| [`scripts/check_test_smoke.sh`](../../scripts/check_test_smoke.sh) | reaches the extension knowledge scripts |
| [`src/reasoning/agent/skills/state-machine-specification/SKILL.md`](../../src/reasoning/agent/skills/state-machine-specification/SKILL.md) | the classification vocabulary and the six suite checks the enumeration is held to |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The enumeration carries an id per transition, and every invariant is classified state, transition, or guard | an invariant with no class cannot be checked against the model it claims, and a transition with no id cannot be paired with a case | this record; the README section |
| Unit A lands as one released scope, and the enumeration takes the `state-machine-specification` skill's vocabulary | operator, 2026-10-04: the skill's three proposal steps were already run by the plan session, so the states and the diagram do not need three more confirmations; the vocabulary is unified because two names for one concept - "application policy" and guard - would let the model and the cases drift apart | this record; the README section |
| R1 is exempt from a mutation row | R1 is the bijection between the catalog and the test file, so mutating it mutates the gate itself | the mutation catalog, at the R1 row's note |
| The union carries `type` and keys identity on `type + id` at every site | option (a), operator-released 2026-10-04: it is the only option that matches pi's `mergeModels`, and G2's `agrees with pi` case is a claim about the extension's own key, so a chat-only filter would make the case attest a divergence instead | this record |
| The two 2026-10-04 handovers take frontmatter, folded into their own commits | the format window reaches them; the gate skipped them because a record with no frontmatter block carries no date for the cutover test to read | this record; commits `0327ad0` and `7d84230` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The two handovers dated 2026-10-04 (`20261004-01`, `20261004-02`) carried the bold-header form, not the YAML frontmatter the format window requires from 2026-10-01. Traced: no live document carries that form; it survives only in the pre-cutover records, and `scripts/lint/handover-format.mjs` treats an absent frontmatter block as history in cutover mode, so a new record missing the block is unreachable by the date test. Fixed: both take frontmatter, folded into their own commits (`0327ad0`, `7d84230`) | record defect | resolved this iteration | Triaged to: commits `0327ad0` and `7d84230`; the gate change landed in `20261004-04` |
| The operator landed a `state-machine-specification` skill mid-iteration (commit `2b46238`). It renames the classification to **state / transition / guard**, makes the date comparison a guard rather than an "application policy", adds rule 6 (no state has two transitions on one event whose guards can both hold), and prescribes three operator-confirmed proposal steps | steering | resolved: the skill's steps are treated as already run, unit A stays one released scope, and the vocabulary is unified into the README, the roadmap row and this record | Triaged to: `model-refresh/README.md`, `devlog/roadmap.md` T12 unit A, this record's Decisions |
| `scripts/run_tests.sh` discovers only `tests/test_*.sh`, so the 3000-line `model-refresh` node suite is not in `make test` | gap | this iteration, criterion 8 | Triaged to: `tests/test_model_refresh.sh` |
| `scripts/check_test_smoke.sh` globs `tests/{knowledge,integration,eval}/*.sh` only, so `tests/extensions/**/knowledge/*.sh` is unreachable and has never been syntax-checked by a gate | gap | this iteration, criterion 9 | Triaged to: `scripts/check_test_smoke.sh` |
| `ModelDefinition` declares no `type`, and the union decides identity at three sites (`unionFirstWins`, `overlayPreservingOrder`, the metadata pass); the `type + id` key therefore needs the type carried and the key applied consistently | design gap | this iteration: resolved by the composite-key decision | Triaged to: `model-refresh/types.ts`, `model-refresh/catalog.ts` |
| `unionFirstWins` copies unknown keys through `fillMissing`, so a stored entry's `type` reaches the served entry even though the interface does not declare it; the collapse is reachable, not hypothetical | defect | this iteration, criterion 6 | Triaged to: `model-refresh/catalog.ts`; the G2 case |
| pi's `withRemoteCatalog` filters its chat-facing `getModels` to `isModelType(model, "chat")` and keeps the unfiltered list in `getAllModels`, so a same-id two-type pair is observable only through `getAllModels`; the G2 differential drives that method | capability | this iteration, criterion 6 | Triaged to: the G2 case in `invariants.test.ts` |
| Transition ids written as `T1`-`T13` collided three ways: the invariant catalog already uses `T1`-`T4` for the thinking map, and `roadmap.md` uses `T1`-`T12` for its tracks. Renamed to `X1`-`X13` before the code was written | record defect | this iteration: the README and the roadmap row carry `X1`-`X13` | Triaged to: `model-refresh/README.md`, `devlog/roadmap.md` |
| The `C3` case composed pi's provider with no extension, so no extension mutation could break it. It now composes the real registration and keys the override on a pi-served id, so `index:baked-catalog-emptied` can prove it | design gap | this iteration: the case is extension-dependent and the row is `proven` | Triaged to: `invariants.test.ts` C3 case, `mutation/catalog.ts` |
| A mutation that makes the product throw is not `proven`: the gate requires a failing case to name the invariant on an assertion. The first `L2` row threw from `storeEntriesFor` and was rejected; the row now lets a malformed metadata source drop the baked catalog, which fails an `assert.ok` | method | this iteration, criterion 4 | Triaged to: `mutation/catalog.ts` L2 row |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts) | `ModelDefinition` carries an optional `type`, so a stored entry's kind survives the union |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts) | new `modelKey`; `unionFirstWins`, `overlayPreservingOrder` and the metadata pass all key on `type + id` |
| [`tests/extensions/pi/model-refresh/invariants.ts`](../../tests/extensions/pi/model-refresh/invariants.ts) | the G2 catalog gains the same-id two-type case; `STATES`, `TRANSITIONS`, `EXTERNAL_EDGES` and `CLASSIFICATION` carry the machine as data, and `checkTotality` runs the completeness and guard-overlap checks |
| [`tests/extensions/pi/model-refresh/invariants.test.ts`](../../tests/extensions/pi/model-refresh/invariants.test.ts) | the G2 differential case, driven through pi's `getAllModels`; the `L3`, `L4`, `L5` lifecycle cases; the rewritten extension-dependent `C3` case; the `totality` test |
| [`tests/extensions/pi/model-refresh/mutation/catalog.ts`](../../tests/extensions/pi/model-refresh/mutation/catalog.ts) | the U3 anchor re-pointed to the composite-key sort; fifteen rows added, for M2, M4, M6, G2, L1, L2, C2, C3, T1, T4, W1, D1, L3, L4 and L5 |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the enumeration takes the statechart vocabulary, transition ids `X1`-`X10` and `X11`-`X13`, and the invariant classification table; the classification and transition tables are stated as the data `invariants.ts` carries; the R1 exemption is recorded; A7 narrows; the `make test` paragraph updates |
| [`tests/test_model_refresh.sh`](../../tests/test_model_refresh.sh) | new: the node suite and its registration guard, under `make test` |
| [`scripts/check_test_smoke.sh`](../../scripts/check_test_smoke.sh) | reaches `tests/extensions/**/knowledge/*.sh` |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the unit A row takes the vocabulary and the transition ids |
| `devlog/handovers/20261004-02-plan-model_refresh_startup.md` | correction tag on decisions 8 and 10 |
| `devlog/handovers/20261004-03-impl-model_refresh_machine_enumeration.md` | the single-scope and vocabulary decisions, the resolved pending row, the new findings |
