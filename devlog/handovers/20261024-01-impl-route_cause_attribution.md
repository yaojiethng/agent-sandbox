---
date: 2026-10-24
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - The route cause is decided from recorded evidence

## Objective

Decide, from the retained failure corpus, what evidence makes a dispatch failure the request's responsibility, and make the route memory hold that decision instead of a class fitted to the provider's error text.

## Scope

The roadmap entry **A request-scope failure still cools its route**, taken from its premise rather than from its proposed fix: the census, the corpus view, the attribution and its falsifier, the priced replay, the shape comparison, and then the mechanism change in the store the replay leaves live.

The prerequisite the roadmap maintenance check produced is in this iteration because it is the same record: the prior unit landed with no roadmap row.

Out of scope, with its reason. The entry **The failover A/B and the verdict** is not run here; the replay weights it and stops. A request the harness builds wrongly is reported by call site and becomes its own entry, because the launch site that builds it is a different surface from the route memory this entry owns. Three such entries were filed, from the census: the dropped reasoning, the rejected thinking level, and the doubled provider id.

Scope amendment, recorded at pre-close. The replay is a test of the extension's suite rather than a new script under `tests/dispatch/attribution/`, so it registers in `tests/test_model_failover.sh` beside the store it exercises. The live table is printed by that test under `CORPUS_ROOT`, and the fixture keeps `make test` deterministic.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A per-actor census reports failures per cause class per call site, runtime, provider and model, and reruns to the same counts | `node scripts/cost_ledger.mjs --root ~/.pi/agent/sessions --census` twice, outputs diffed: identical, 13 cells. The store carries no call site, so the census reports the working directory and the session instead, and the gap is a finding | Agent [x] |
| The corpus is a view or a gated copy, and the record states which class it is | no artifact is stored: `--failures`, `--census` and `--attribution` compute it on read from the same `entries()` walk the ledger uses | Agent [x] |
| Every request-attributed shape carries its provenance, and shapes with no cross-model pair are listed as absent | `node scripts/cost_ledger.mjs --root ~/.pi/agent/sessions --attribution`: 8 shapes, 8 absent pairs, each row carrying its models and working directories | Agent [x] |
| Cooldown-hours per cause class are stated per store on the recorded stream, before and after the change | `CORPUS_ROOT=... node --test tests/extensions/pi/model-failover/replay.test.ts`: before, request 8.57h; after, request 0.00h and the library 0.00h | Agent [x] |
| Every store the enumeration leaves holds one rule for one class of evidence | the differential replay passes over the fixture, and the live run prints 0.00 request-attributed hours in both stores | Agent [x] |
| A dropped attribution is caught by name, and the control row stays green | `bash tests/test_model_failover.sh`: 126 tests including the mutation gate; catalog row `A1:request-scope-cools` reaches `proven` against `ledger.test.ts` | Agent [x] |
| A cooling route's report line names both cause and provenance | the `report.test.ts` case asserts `p/m cooling on limited (account) for another 1h` | Agent [x] |
| The attribution rule and its two terms are stated where the taxonomy lives | `docs/reference/dispatch.md` `## Failure and Its Vocabulary` and `docs/reference/terminology.md` `## attribution`, `## provenance` | Agent [x] |
| Every decision this iteration records is realized in the files | the Decisions table read against `git diff --stat` at pre-close | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The iteration type is Implementation | the outcome is a mechanism change in a route store plus its tests; the measurement is how the shape is chosen, not the deliverable | this record |
| The shape is not chosen at the gate, the criteria for choosing it are | the corpus decides whether text attribution is sound at all, and a shape fixed before that measurement would be a fourth fix on the premise under test | the scope gate presentation, and this record |
| The failure corpus extends `scripts/cost_ledger.mjs` rather than adding a second reader | that script already streams the session store, and two readers of one store drift apart with nothing catching it | this record |
| A harness-built malformed request is reported, not repaired here | the entry owns the route memory; the request boundary is another surface, and its repair is one roadmap entry with its own acceptance | this record |
| The mechanism change lands in the extension's ledger, and the library's `R8`/`R9` is the reference rule | the corpus is pi's own turns, which the extension governs; the library already holds the same rule for dispatch-time attempts, so the work is to make the second store agree, not to invent a policy | `ledger.ts`, `dispatch.md` |
| An outcome carries the verdict's scope, and `request` or `unclassified` leaves the record untouched | the class alone cannot say whether the route is at fault, and the two scopes both mean the failure is not the route's. The library applies the same rule to `unknown` | `types.ts`, `ledger.ts`, `classify.ts` |
| A cooled entry keeps the scope that set it, and stores none when the scope is `none` | `limited` alone covers an exhausted account, a disabled model and an unconfigured provider; an absent scope means the class names all there is to know, so old files read unchanged | `types.ts`, `report.ts` |
| An unfunded balance is an account fault and is never retried | operator direction, 2026-10-24: no retry buys nothing when the account cannot pay. The funds pattern takes precedence over the request pattern, because the body's `code` names the envelope rather than the fault | `classify.ts` in both stores, and this record |
| The replay is a test with a fixture, and the live population is printed under `CORPUS_ROOT` | the fixture makes the assertion a literal and keeps `make test` offline; the live table is the measurement, and a live population changes under a test | `replay.test.ts` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The prior unit landed with no roadmap entry, so the work `20261023-32` completed was invisible to the next iteration and to the task list | record | the roadmap stopped being the sole task list for one unit, and its route-memory rule reached the tree with no row naming it | fixed here: the closed row is added under M3.6.3 with its landing note |
| The entry's own premise presupposes a single store, saying "the cooldown key the ledger reads" while the tree holds two stores whose rules for one class of evidence disagree | record | a fix written to the entry as phrased would harden one store and leave the other unmeasured | resolved here: the census and the replay both name the rule they apply, and the differential test holds them together |
| `docs/reference/dispatch.md` states that a malformed request leaves the route record untouched, and the failover extension's store did the opposite for the same class | doc | a reader of the reference believed a rule that held in one store and not the other | fixed here: the extension applies the rule, and both carriers say so |
| The three request-attributed defect shapes (the dropped thinking-mode reasoning, 11; a thinking level the provider rejects, 3; a model id namespaced by one provider and sent to another, 2) were recorded 2026-04-30 to 2026-05-01, before the failover extension existed on 2026-10-14 and before `scripts/dispatch.sh` on 2026-10-16 | record, corrected here on 2026-10-24 | they are pi's own request-builder failures from an earlier deployment, and filing them against the dispatch surface sent the next iteration after work no mechanism in this tree owns | retired here: no roadmap rows; the measurement stays in this record |
| No request-attributed shape has a cross-model pair: 8 shapes, 8 absent pairs, and 18 of 19 extension request-scope failures sit in one working directory | measurement | the corpus cannot establish "caller-caused" for any shape, so the attribution rests on the texts naming request fields, and the census shows the asymmetry is this harness rather than the population | the three entries above, and this record; the cooldown rule is a guard, not the root fix |
| The session store records no call site, so the census substitutes the working directory and the session | measurement | a census per call site is not derivable from the retained corpus, and the gap should not read as a measured zero | this record, and the criterion's verification cell |
| The census population is pi's session store, which holds the main agent's own turns, and the iteration reported it as dispatch evidence | measurement, corrected here on 2026-10-24 | every figure in this record describes the failover extension's population, not the dispatch path, whose attempts are logged under a run directory and never retained | corrected here: the closed entry states its population and calls the figure a counterfactual, and the dispatch instrument's gap is appended to the M3.6.2 row that owns it |
| The census read a six-month corpus and the handover reported it as current behaviour: the request-attributed population spans 2026-04 to 2026-10, and most of it predates the dispatch seam | measurement, corrected here | a historical population read as live sends the next iteration after defects that no longer exist | fixed here: every census cell and attribution row now carries its first and last date, and the three entries name their window |
| A balance error is attributed to the caller: `402 Insufficient Balance` carries a `code` of `invalid_request_error`, and the request pattern matched that code | defect, found after the release gate, fixed here on operator direction | an unfunded account was recorded as a malformed request, which is the one thing the attribution rule says it does not do | fixed in this commit: the funds pattern claims the text ahead of the request pattern in both classifiers, and each suite carries the case |

## Completed

| File | Change |
|---|---|
| [`scripts/cost_ledger.mjs`](../../scripts/cost_ledger.mjs) | one `entries()` walk shared by the session and failure projections; `--failures`, `--census`, `--attribution` as views computed on read |
| [`tests/test_cost_ledger.sh`](../../tests/test_cost_ledger.sh) | the failure view, the census and the absent-pair case |
| [`types.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/types.ts) | `FailureScope` moved here; the failure `Outcome` carries its scope; a cooling entry may carry the scope that set it |
| [`classify.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/classify.ts) | the outcome carries the verdict's scope; the stale two-value comment replaced |
| [`ledger.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/ledger.ts) | the attribution guard; the cooling entry keeps its scope; the parser reads an optional scope |
| [`report.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/report.ts) | a cooling line names the scope beside the class |
| [`replay.test.ts`](../../tests/extensions/pi/model-failover/replay.test.ts) | the differential replay over a fixture, and the live corpus table under `CORPUS_ROOT` |
| [`test_model_failover.sh`](../../tests/test_model_failover.sh) | the replay registered in the suite |
| [`helpers.ts`](../../tests/extensions/pi/model-failover/helpers.ts) | outcomes carry a scope; `limited(scope)` |
| [`classify.test.ts`](../../tests/extensions/pi/model-failover/classify.test.ts), [`ledger.test.ts`](../../tests/extensions/pi/model-failover/ledger.test.ts), [`report.test.ts`](../../tests/extensions/pi/model-failover/report.test.ts) | the scope on the outcome, the untouched record, the stored provenance, the report line |
| [`mutation/catalog.ts`](../../tests/extensions/pi/model-failover/mutation/catalog.ts) | row `A1:request-scope-cools`, and the `T4` anchor follows the new cooling line |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | the scope as attribution, and the two stores that apply it |
| [`docs/reference/terminology.md`](../../docs/reference/terminology.md) | `## attribution` and `## provenance` |
| [`devlog/roadmap.md`](../roadmap.md) | the entry closed with its population and counterfactual stated, the prior unit's row, and the balance attribution closed on the operator's ruling |
| [`classify.ts`](../../src/libs/dispatch/classify.ts), [`model-failover/classify.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/classify.ts) | the funds pattern claims `Insufficient Balance` before the request pattern reads the body's code field |
| [`classify.test.ts`](../../tests/dispatch/machine/classify.test.ts), [`classify.test.ts`](../../tests/extensions/pi/model-failover/classify.test.ts) | the 402 balance text asserted as the account's, and as no-retry |
