---
date: 2026-10-14
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Implementation
status: Closed
---

# Handover - edge routing under a chosen provider in model-failover

## Objective

Give `model-failover` an edge layer. The route layer already chooses a provider and a model; the edge layer now chooses the address under it. Under a chosen route the extension pins each inference request to a clean edge address of the provider's host, tracks the health of each `(host, model, address)`, and reselects on failure, so a provider's intermittent edge failures do not become session failures. The address is resolved and chosen by the extension; the operator configures no endpoint.

## Scope

One new layer on the existing extension, its design record, its tests, and the wiring that reaches it. In scope: the process fetch adaptor, the address set, the edge health machine, the selection policy, the edge ledger, the session-start report, and the `selection` config block. Out of scope: a static IP pin or colo selection, session-header rotation, and per-model retry tuning, all recorded in the README's "What this does not do". The route layer and its ledger are unchanged.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A managed host's request lands on a chosen edge address while `Host` stays the logical host | `pinned-fetch.test.ts` drives a local server as the chosen address and a non-resolving logical host | accepted |
| An unmanaged host and an unresolvable managed host are delegated to the original fetch | `adaptor.test.ts` | accepted |
| The edge machine cools on the third consecutive transient failure and on a failure while cooling, and clears on success | `edges.test.ts` B1-B5 | accepted |
| A limited outcome and an abort write nothing | `edges.test.ts` | accepted |
| The reselection is sticky on success, policy-driven on failure, and probes the soonest-to-recover edge when all cool | `edges.test.ts` | accepted |
| A fixed random sample gives a fixed choice, for both policies | `edges.test.ts` | accepted |
| The edge health persists by key and another version reads as empty | `edge-ledger.test.ts` | accepted |
| The `selection` block parses with a default and refuses an unknown policy or an out-of-range epsilon | `config.test.ts` | accepted |
| The report names each managed edge by its derived rate and streak | `report.test.ts` | accepted |
| The fetch wrap reaches the provider SDK | a probe against the installed OpenAI client shows `globalThis.fetch` is resolved at request time | accepted |
| A fresh pi invocation loads the extension and sends a request through the adaptor | the knowledge script runs a local OpenAI-compatible mock and a real `pi -p` | accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The edge layer is a process-fetch adaptor, not a provider re-registration | model-failover owns the inference network path; the provider registry and `models.json` belong to the model-refresh layer, so the adaptor must not touch them | README and this handover |
| The edge health key is `(host, model, address)` | two models under one host can be served by different servers, so quality is model-scoped while the endpoint set is host-scoped | README |
| `eligible` carries the window record; the streak drives exclusion and the rate drives reselection | a consecutive streak alone forgives a flapping edge, which is the case this layer exists to handle | README |
| The selection is a pure guard; the reselection policy is configurable | the two shapes (`rate`, `epsilon`) can be compared offline without changing the machine | README |
| The edge ledger is its own file | the route ledger is written per assistant message and the edge ledger per HTTP attempt; merging them forces the route format to change for no gain | README |
| `x-opencode-log-id` is dropped | the extension chooses the edge, so the edge identity is known by construction and no response header is needed | README |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The OpenAI client resolves `globalThis.fetch` at request time, so an extension wrap at load reaches it | steering | current iteration |
| Concurrent requests to one `(host, model)` race the recorded edge; the record is last-writer-wins | obstacle | next iteration, if an exact per-request attribution is needed |
| The edge report appears from the second session start, because the address set resolves lazily on the first request | obstacle | current iteration, accepted |

## Completed

| File | Change |
|---|---|
| [`pinned-fetch.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/pinned-fetch.ts) | the pinned request and `canPinBody` |
| [`adaptor.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/adaptor.ts) | the `NetworkAdaptor` and `modelOfRequest` |
| [`edges.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/edges.ts) | the edge machine, `nextEdge`, the policies, resolution and the address set |
| [`edge-ledger.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/edge-ledger.ts) | the version-1 `edges.json` |
| [`config.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/config.ts) | `parseSelection`, `DEFAULT_SELECTION`, `EDGE_THRESHOLD`, `EDGE_WINDOW_MS` |
| [`types.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/types.ts) | `EdgeHealth`, `EdgeOutcomeRecord`, `AddressSet`, `EdgeLedgerFile`, `SelectionConfig` |
| [`report.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/report.ts) | `edgeLine` and `buildEdgeReport` |
| [`index.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/index.ts) | `installAdaptor`, the host management, the edge charge on `message_end` |
| [`README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/README.md) | the edge design folded into the design record |
| [`CHANGELOG.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/CHANGELOG.md) | the 0.2.0 entry |
| `tests/extensions/pi/model-failover/` | `pinned-fetch.test.ts`, `adaptor.test.ts`, `edges.test.ts`, `edge-ledger.test.ts`, `config`/`report` additions, and `knowledge/knowledge_edge_routing_e2e.sh` |
| [`devlog/roadmap.md`](../roadmap.md) | the row now records the edge layer and this handover |
