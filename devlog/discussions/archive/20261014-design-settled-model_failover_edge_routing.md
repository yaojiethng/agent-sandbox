# Edge routing under a chosen provider in model-failover

**Status:** settled

Settled and folded into the extension's design record, [`README.md`](../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/README.md); the README is the live design document, and this archived document keeps the exploration that produced it.

## Context

`model-failover` keeps a session on a working model. Its chains declare routes at provider/model granularity, and its ledger records health per route ([README](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/README.md)). That layer is the operator's choice - "use `opencode-go/step-5-preview-free`" - and it is the right unit for choosing a provider and a model.

It is not the unit where the failures live. The `opencode-go` gateway fans a request out to a few edge addresses, and the 2026-10-12 measurement found that success varies sharply by edge at one moment, that the signal decays within a few minutes, and that the edge colo is not a stable property of an address. A chain of one route therefore cannot route around a bad edge: when the route cools, the walk's degraded tier re-dispatches the same route, so the cooldown is inert and the extension is telemetry on the single-route chain.

The operator's intent, stated directly: honour the choice of `opencode-go/step-5-preview-free`, keep a rolling tally of which edges are unclean, and send each request to a clean edge. That is the design here.

Two facts fix the shape. First, the candidate edges are a property of the provider, because every model under it is reached through the same URL. Second, edge quality is a property of the model, because the gateway can route two models to different servers, so one edge can be good for one model and bad for another. The health key is therefore `(provider, model, edge)`, and the endpoint set is derived, not configured.

The configuration surface stays empty. pi's `models.json` already declares the provider URL, and that URL is the endpoint declaration. The extension reads the host from the model's `baseUrl` and does the resolution itself, so the operator never writes an address.

## Options Considered

**A process-global HTTP dispatcher.** Replace the global undici dispatcher with one whose `lookup` returns a chosen edge. It is generic and needs no provider knowledge, but the lookup sees only the hostname, so attributing an outcome to a model is a race when subagents run concurrently.

**A provider stream wrapper.** Register the provider with a wrapped stream that injects `options.fetch`, so the model is in scope at the point the edge is chosen. Attribution is exact. It costs an import of the built-in provider and a re-registration.

**An external local proxy.** A process that fronts the gateway and pins the edge. Rejected: it adds a process, and the existing README already rejects a proxy because it cannot see the error class inside the tunnel.

**Provider/model routing only.** The status quo. It cannot act on the edge, which is where the intermittency is.

## Decision

Adopt the process-wide network adaptor, and add an edge dimension to the ledger.

- **Transport.** The extension wraps the process fetch once, at load. For a request to a managed host it resolves the address itself and issues the request with Node's `https` and a custom `lookup`, while the request keeps the provider's hostname as SNI and `Host`. The response is handed back as a `Response` over `Readable.toWeb`. The wrap is verified to reach the provider SDK, because the OpenAI client resolves `globalThis.fetch` at request time. The provider registry, the model registry and `models.json` are not touched; only hosts the extension is told about are managed, and every other request is delegated to the original fetch, so the catalog fetch model-refresh performs is unaffected. `undici` is not importable from an extension, so the transport is built on `node:https`, `node:dns` and `Response`.
- **Resolution.** The extension resolves the provider host itself (`node:dns`) and refreshes on a short cadence. This is the "manual resolution" step: the URL is not resolved by the ambient resolver.
- **Edge ledger.** One entry per `(host, model, address)`, with the two-state shape, `eligible` or `cooling`, and a cooldown. The key is the model's edge, not the provider's, so two models under one host keep separate tallies. It persists in its own file beside the route ledger, because the route ledger is written once per assistant message and the edge ledger once per HTTP attempt.
- **Selection.** Sticky on success: the edge that just succeeded serves again. On failure, reselect through the configured policy, which ships as `rate` (weighted by the Laplace success rate) and `epsilon` (exploit the best rate, explore with probability `epsilon`). When every edge is cooling, the soonest-to-recover edge is the probe. The selection is a pure guard, not a state.
- **Attribution.** The adaptor chose the edge, so it records the chosen edge per `(host, model)`. The outcome observer classifies the finalized message once and applies it to both layers: a `transient` outcome cools that `(host, model, edge)`, a `limited` outcome stays a route cooldown, and a route cools only when every one of its edges is unclean.
- **Config.** No endpoint list. The only declaration is the provider URL in `models.json`; a top-level `selection` block chooses the policy and its exploration rate.
- **Report.** The session-start report lists each managed host's edges with their derived rate and streak.

### Reuse of the route machine

The route ledger's machine is a pure function over a key, and an edge is a key one level down, so the shape transfers without a redesign. `applyOutcome` and `eligibleAt` in `ledger.ts` already take the threshold and the cooldowns as arguments and are generic over the key.

| Part | At the route level | At the edge level |
|---|---|---|
| States | `eligible` with a streak, `cooling` with a deadline and a class | the same two states; the class is always `transient`, because `limited` is an account fact, not an edge fact |
| Eligibility | derived at read time, no timer | the same |
| Transitions | T1-T6, fired by one classified outcome | T1, T2, T3, T5 and T6; T4 (`limited`) stays on the route |
| Threshold | 3 consecutive transient failures, because switching route is expensive | 3, on the same tolerance, because a single blip is not evidence about the edge |
| Persistence | read-merge-write per outcome | the same, keyed by `host`, `model` and `address` |
| Probe | the degraded tier dispatches the chain head | the degraded tier rotates to the least-recently-failed edge |

Sticky selection needs one new field: the route walk reads pi's `request.previous`, but pi knows nothing about edges, so the extension tracks the last successful edge for each route itself. That is a field, not a transition.

The clearing rule is the one place the route machine does not fit. The edge model keeps the route machine's exclusion transition, a losing streak cools the edge, but it does not let a success erase the recent failure evidence: `eligible` carries the window record, and the selection reads a recent rate from it. The streak drives exclusion and the window drives reselection, both derived from one record, so a flapping edge keeps a non-zero chance of being tried.

### The edge state model

Two submachines, because the address set and the edge health have different update cadences and lifetimes. Submachine A holds the address set for one provider host; submachine B holds one edge's health for one model. The network layer is the event producer, the selection is a guard over both, and the session-start report is the output.

Submachine A - the address set, per provider host:

| State | Holds | Initial |
|---|---|---|
| `unresolved` | no usable set has been received | yes |
| `resolved` | the address list and `resolvedAt` | |

| # | From | Event | Guard | Effect | To |
|---|---|---|---|---|---|
| A1 | unresolved | resolution.received | addresses non-empty | store the set; `resolvedAt := now` | resolved |
| A2 | unresolved | resolution.received, or resolution.failed | addresses empty, or the source did not answer | nothing | unresolved |
| A3 | resolved | resolution.received | addresses non-empty | replace the set; `resolvedAt := now` | resolved |
| A4 | resolved | resolution.failed | - | keep the set; `resolvedAt` unchanged | resolved |

`needsRefresh` (`now > resolvedAt + ttl`) is a guard that asks for a refresh without blocking selection. A is session-scoped and is not persisted.

Submachine B - edge health, per `(host, model, address)`. `eligible` carries the window record of recent outcomes, from which both the streak and the recent rate are derived; there is no separate counter:

| State | Holds | Initial |
|---|---|---|
| `eligible` | the window record | yes |
| `cooling` | the window record and `until` | |

| # | From | Event | Guard | Effect | To |
|---|---|---|---|---|---|
| B1 | eligible | attempt.succeeded | - | record success; streak := 0 | eligible |
| B2 | eligible | attempt.failed | class transient AND streak + 1 < N | record failure; streak++ | eligible |
| B3 | eligible | attempt.failed | class transient AND streak + 1 >= N | record failure; `until := now + window` | cooling |
| B4 | cooling | attempt.succeeded | - | record success; streak := 0; clear `until` | eligible |
| B5 | cooling | attempt.failed | class transient | record failure; `until := now + window` | cooling |

Ignored events: `attempt.failed` with class limited, and `attempt.aborted`; neither is edge-attributable. B is persisted in the ledger.

The selection is a pure guard over A and B, not a state:

```text
eligibleAt(health, now) := health.state = "eligible" or health.until <= now
lastUsed(edges, health) := argmax over edges of max(lastOkAt, lastFailAt)

next_edge(edges, health, now, rand):
  if edges is empty: undefined
  if lastUsed exists and lastOkAt(lastUsed) > lastFailAt(lastUsed)
     and eligibleAt(health[lastUsed], now): return lastUsed
  clean = [e in edges : eligibleAt(health[e], now)]
  if clean is empty: return argmin over edges of until
  return policy.pick(clean, health, rand)
```

`policy.pick` is configurable under a top-level `selection` block and ships two shapes: `rate`, a weighted pick by a Laplace success rate, and `epsilon`, which exploits the best rate and explores the rest with probability `epsilon`. The state machine is identical for both; only the guard differs.

### Invariants and the test worklist

The values the model fixes: N = 3, window = 3 min for both the cooling duration and the age-out of the window record, ttl = 60s for the resolution refresh.

Submachine A:

| # | Kind | Invariant |
|---|---|---|
| A-S1 | state | `resolved` carries a non-empty address list and a `resolvedAt`; `unresolved` carries neither |
| A-T1 | transition | A1 and A3 store only a non-empty set; a received-empty or failed resolution never populates it |
| A-T2 | transition | A4 leaves `resolvedAt` unchanged, so a failed refresh cannot make a stale set look fresh |
| A-G1 | guard | `needsRefresh` asks for a refresh and never blocks selection, so a stale set stays usable |

Submachine B:

| # | Kind | Invariant |
|---|---|---|
| B-S1 | state | both states carry the window record; only `cooling` carries `until` |
| B-S2 | state | the streak derived from the window never exceeds the failures it holds |
| B-T1 | transition | B3 fires exactly when the incremented streak reaches N, and B2 below it |
| B-T2 | transition | `until` is written only by B3 and B5, and only as `now + window` |
| B-T3 | transition | B1 and B4 reset the streak; B5 does not |
| B-T4 | transition | a limited or aborted outcome writes nothing |
| B-T5 | transition | one transient outcome updates exactly one edge record |
| B-G1 | guard | `eligibleAt` is the only admissibility test the selection performs |
| B-G2 | guard | a cooling edge is admissable when `until <= now`, derived at read time, with no timer |

Creation and teardown, which the skill treats as transitions with their own ids:

| # | Transition | Invariant |
|---|---|---|
| A0 | extension load -> `unresolved` | A-S1 |
| B0 | a new edge record -> `eligible` with an empty window | B-S1 |
| B6 | ledger load populates the edge map, or starts empty on a version mismatch | B-S1 |

Selection guards:

| # | Kind | Invariant |
|---|---|---|
| Sel-G1 | guard | sticky is chosen only when the last-used edge succeeded and is clean |
| Sel-G2 | guard | when any clean edge exists, the chosen edge is clean |
| Sel-G3 | guard | when no clean edge exists, the chosen edge minimises `until` |
| Sel-G4 | guard | every clean edge has non-zero probability under `policy.pick` |
| Sel-G5 | guard | the choice is a pure function of `(edges, health, now, rand)` |

The test worklist follows the skill's six rules. Every transition above names an invariant. Every state and transition invariant gets a case, including the blocked paths: a failed resolution from `unresolved`, an empty resolution, a transient failure below N, a sticky candidate whose edge is cooling, and the all-cooling degenerate selection. Every transition invariant (A-T1, A-T2, B-T1 to B-T5) gets a mutation row that must turn its case red, beside the control row that replays the unedited suite. A0, B0 and B6 each get a case that can turn red on its own. A mapping check asserts that every transition id has a case and every case names a transition or state id. Guard overlap is resolved: A1/A2 split on the received set being non-empty or empty, and B2/B3 split on the incremented streak being below or at N, so no two transitions on one event share a state with overlapping guards.

## Consequences

- The operator's intent is realized without any endpoint configuration, and the extension can finally act on the failure locality its own measurement found.
- The edge health persists in its own ledger file beside the route ledger, version 1; it is not merged into the route ledger, because the two have different writers and cadences.
- The extension wraps the process fetch once, so a host it manages is pinned for every request to that host; a host it does not manage is delegated untouched.
- `x-opencode-log-id` is moot. Edge identity is known by construction because the extension chooses the edge, so no response header is needed and the earlier capture follow-on is dropped.
- The fetch wrap is process-global and installed once; edge state is the shared `edges.json` by read-merge-write, so concurrent subagent processes keep each other's keys.
- This design replaced the earlier provider/model split direction, and it changes the follow-ons recorded in handover `20261012-02` and the extension README.
