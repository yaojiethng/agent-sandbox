# model-failover

`model-failover` keeps a pi session on a working model. The operator declares a chain: an ordered list of routes, each a provider and model. pi dispatches the first healthy route in the chain. A route that fails enough times steps aside for a cooldown window; a route that answers returns immediately. Under a route, the extension also chooses the edge address the request is pinned to, so a provider's intermittent edge failures do not become session failures. The chain is declared in one JSON file beside this module, so adding a route or changing a cooldown is a config edit, not a code change.

This document is the design record. It states the measured behaviour the design rests on, the configuration surface, the algorithm, its state model and invariants. The code follows this document.

## The measured behaviour

All measurements come from this deployment's own traffic: 458 recorded provider errors across the session logs, plus 80 controlled gateway requests in a per-IP experiment on 2026-10-12.

| Measurement | Value | Consequence for the design |
|---|---|---|
| Failure episodes per model | 453 of 458 errors on `step-5-preview-free` | the failure follows the model's upstream, not the account or the client |
| Failure classes on `opencode-go` | 484 endpoint-unavailable (transient), 5 usage-limit (non-retryable), 25 connection and timeout errors | two classes with different lifetimes need different cooldowns |
| Error episode shape | 68 of 212 episodes are a single error; the rest are bursts of 2 to 24 | a threshold below 1 manufactures switchovers on blips |
| Outage self-recovery | 40 consecutive failures became a success about 5 minutes later, same IP, same prompt | cooldowns are short and eligibility returns on success; nothing is pinned |
| Whole-pool outage | all four edge IPs failed 40/40 across two interleaved rounds | the chain degrades to its head rather than refusing the turn |
| Per-IP success at one moment | 5/5 on one edge IP against 0/5 on two others, same session and key | the flat per-provider view hides the variance; the per-IP signal decays within minutes |
| Edge colo stability | the same pinned IP served PHX, SMF and PDX across windows | an availability zone is not a property of an IP; IP pinning is out of scope |

## The configuration surface

One file, `routes.json`, beside this module. One chain per protected model:

```json
{
  "chains": [
    {
      "id": "step-5-preview-free",
      "transientFailuresBeforeCooldown": 3,
      "cooldownMs": { "transient": 120000, "limited": 3600000 },
      "routes": [
        { "provider": "opencode-go", "model": "step-5-preview-free" },
        { "provider": "opencode-go", "model": "space-bunny-free", "thinkingLevel": "high" }
      ]
    }
  ]
}
```

Rules the loader enforces, refusing the whole file with a named error when any fails (R8):

- `id` is unique across the file and names the protected model; it becomes the virtual model `failover/<id>`.
- `routes` is non-empty and every route names a provider and a model.
- One physical route belongs to exactly one chain in the file: the ledger holds one entry per route key, so two declarations of one route would contend over that key. The loader refuses the file.
- `transientFailuresBeforeCooldown` is an integer of at least 1; it defaults to 3.
- `cooldownMs` values are positive integers; `transient` defaults to 120000, `limited` to 3600000. Every chain gets its own object, so one chain cannot alias another's defaults.
- `thinkingLevel` on a route is one of the six level names and clamps to the physical model's supported levels.

A top-level `selection` block chooses the edge reselection policy: `policy` is `epsilon` (default) or `rate`, and `epsilon` is the exploration rate, a number at least 0 and below 1. The loader refuses an unknown policy or an out-of-range epsilon with a named error.

The extension is inert unless the `MODEL_FAILOVER_ENABLED` environment variable names a truthy value (`1`, `true`, `on` or `yes`). The flag defaults off, and a disabled factory returns before it reads `routes.json`, registers a virtual model, installs the network adaptor or observes an outcome. The default follows the measurement in the parent design record: no session carries a `model-failover/outcome` entry and the only shipped chain declares one route, so failover has never run, and the off state keeps an unproven feature from touching a request until a comparison earns it. Set the variable to enable the extension. A coarse alternative is pi's own `--no-extensions` flag, which disables every extension rather than this one.

The shipped `routes.json` carries one chain with one route. That matches the measured state of this deployment: the models the chain would otherwise list were quiet on 2026-10-12 (`space-bunny-free` answered model-unavailable, `deepseek-v4-flash` and `glm-5.3-flash` answered usage-limit), and `opencode` cannot serve this model at all. A second route is a declaration edit away; the loader validates it and the ledger cools it when it fails, so the surface accepts a route before it is needed.

The extension is parked un-enabled until a model with flaky semantics exists to evaluate it against: no model in this deployment fails often enough to persist through, so the off state is the parking, and the comparison that would earn the flag -- quality held fixed while the retries are priced -- is the `T12` row for flaky-model handling in the repository's `devlog/roadmap.md`.

## The algorithm

### Requirements

| # | Requirement | Anchor |
|---|---|---|
| R1 | Dispatch walks the chain in declared order | the order is the operator's preference |
| R2 | A transient failure demotes the route on the N-th consecutive failure, N declared per chain | 68 of 212 episodes are single errors |
| R3 | A quota-class failure demotes on the first occurrence | the usage limit persists across the observation window |
| R4 | Any successful response clears a cooldown and the failure streak | recovery is spontaneous |
| R5 | A chain whose every route is cooling still dispatches the chain head | the whole pool went down at once for over 5 minutes |
| R6 | Dispatch stays on the last successful route at every reason, across turns, until a health transition | turns sit seconds apart; a per-turn reset re-enters a flapping route |
| R7 | Every classified outcome appends exactly one tracking entry to the session log | the live distribution stays readable from the transcript |
| R8 | A malformed declarations file refuses at load with a named error | a silently broken chain reads as healthy |
| R9 | The ledger survives across sessions | the flap crosses sessions |
| R10 | Thresholds, cooldowns and order are declarations | multiple chains, no code change per model |

### State model

One machine per route. Two states:

| State | Carries | Meaning |
|---|---|---|
| `eligible` | `streak` | dispatchable; initial state |
| `cooling` | `until`, `class` | skipped until the deadline, by derivation |

```text
                    outcome.received
          +-------------------------------+
          |                               |
          v                               |
     .---------.  failed[transient;       |
     | eligible|        streak+1 < N] --> (internal: streak++)
     | streak  |  failed[transient;       |
     '---------'        streak+1 >= N] --.
          |  failed[limited] -----------.
          |                             v
          |                        .---------.
          |                        | cooling |
          '-----------------------| until,  |
                 outcome.received | class   |
                 (streak reset)   '---------'
```

The transitions, with guards and effects:

| # | From | Event | Guard | Effect | To |
|---|---|---|---|---|---|
| T1 | eligible | `outcome.received` | always | success count; streak := 0; append entry; persist | eligible |
| T2 | eligible | `outcome.failed` | class = transient AND streak + 1 < N | streak++; failure count; append entry; persist | eligible (internal) |
| T3 | eligible | `outcome.failed` | class = transient AND streak + 1 >= N | until := now + cooldown(transient); append entry; persist | cooling |
| T4 | eligible | `outcome.failed` | class = limited | until := now + cooldown(limited); append entry; persist | cooling |
| T5 | cooling | `outcome.received` | always | success count; clear until and class; streak := 0; append entry; persist | eligible |
| T6 | cooling | `outcome.failed` | any class | until := now + cooldown(class); append entry; persist | cooling |

Two facts about this model that the diagram does not show as transitions:

- Eligibility is a guard, not a state: `eligibleAt(r, now)` holds when the route is `eligible`, or when it is `cooling` and `until <= now`. The deadline lapses by derivation at read time. No timer runs, no sweep runs, and a stored `cooling` state with a past deadline is never wrong, only unreaped.
- An unresolvable route (the registry holds no credentialed model for it) never enters the machine. The walk skips it and the report notices it. It is an ignored event here.

### Error classification

The observer reads the finalized assistant message at `message_end` and classifies the error text:

| Class | Matched text | Cooldown |
|---|---|---|
| `transient` | 429 endpoint-unavailable, 400 model-unavailable, connection errors, terminated, timed out, stream ended early | 120000 ms |
| `limited` | 429 usage-limit, monthly limit, balance and quota errors | 3600000 ms |

Non-error outcomes fire `outcome.received`. The classification is deliberate and local: pi's own retry machinery has the same split, but reading the finalized message keeps the classes in one place, where the tracking entry and the cooldown both read them.

### The dispatch walk

`route()` runs before every request made with a chain's virtual model:

```text
healthy   = [r in chain.routes : registry resolves r AND eligibleAt(r, now)]
if request.previous in healthy:
    chosen = request.previous        # sticky at every reason; turn boundaries are non-events
else if healthy:
    chosen = healthy[0]              # after a switchover: first healthy in declared order
else:
    chosen = chain.routes[0]         # degrade: dispatch the head, never refuse the turn
```

Three tiers, in order: the served route holds while it is healthy; a health transition walks to the first healthy route in declared order; a fully cooled chain degrades to the head, and the degraded dispatch doubles as the probe that detects recovery. A switchover fires on a health transition only, never on a turn boundary and never on a timer.

The degrade tier dispatches the head even when the registry cannot resolve it: a broken chain must surface as pi's own error naming the route, not as a silently refused turn.

### Tracking entries and the report

Each transition appends one custom session entry with the timestamp, the route, the outcome class, the resulting eligibility, and the streak at that moment, so the success distribution for every chain is reconstructible from the transcript without a sidecar. At `session_start` the report lists each chain, each route's state, and any route cooling on a quota-class error, because that one needs operator action rather than patience.

### Persistence

The ledger is a JSON map beside this module, loaded at `session_start` and never read from the factory. The file is version 1: a file another version wrote reads as empty and re-learns, because another version's shape is not this version's shape even when its keys look familiar. Each outcome writes the changed route by read-merge-write with an atomic rename. The read-merge-write keeps concurrent processes (subagent fan-out) from clobbering each other's route keys; a rare lost update leaves one route's state stale for at most one cooldown window, and the next outcome on that route corrects it. The file holds one entry per declared route, so it is bounded by the configuration and never grows with traffic.

### Complexity

| Operation | Cost | Note |
|---|---|---|
| dispatch (`route()`) | O(r), r = chain length | hash lookups only; no network, no timer |
| outcome, in memory | O(1) | one map write |
| outcome, persisted | O(r) | read-merge-write of the ledger file |
| load and validate | O(R), R = all declared routes | once per session start |
| ledger memory | O(R) | fixed fields per route |

### Invariants

State invariants:

| # | Invariant |
|---|---|
| S1 | every ledger key is a declared route of a declared chain, and every declared route has at most one entry |
| S2 | a cooling entry carries an `until` and a class; an eligible entry carries a streak |
| S3 | `eligibleAt` is the only admissibility test a dispatch performs |

Transition invariants:

| # | Invariant |
|---|---|
| TI1 | T3 fires only when the incremented streak reaches N; T4 fires on the first limited-class failure regardless of streak |
| TI2 | `until` is written only by T3, T4 and T6, and only as now plus the cooldown of the class that fired the transition |
| TI3 | `outcome.received` clears `until` and the class wherever it arrives |
| TI4 | every transition appends exactly one tracking entry |

Guard invariants:

| # | Invariant |
|---|---|
| G1 | the sticky guard chooses the previous route only when that route is in `healthy` |
| G2 | the streak resets only on `outcome.received`, never on a cooldown lapse |
| G3 | a factory without a truthy `MODEL_FAILOVER_ENABLED` returns before it reads `routes.json`, registers a virtual model, installs the network adaptor or observes an outcome |

## The edge layer

The route layer chooses a provider and a model; the edge layer chooses the address under it. They are independent: the operator chooses a model, and this layer keeps the request on a clean address of that provider's host. It reads the request URL and body and pins the connection below them; it never writes the provider registry, the model registry or `models.json`.

### The network adaptor

The extension wraps the process fetch once at load. For a host it manages - derived from the base URL of a provider a chain names - it resolves the address itself (`node:dns`) and issues the request with Node's `https` and a custom `lookup`, so the connection lands on the chosen address while SNI and `Host` stay the provider's host. The response comes back as a `Response` over `Readable.toWeb`. Every other request is delegated to the original fetch, so the catalog fetch `model-refresh` performs is untouched. `undici` is not importable from an extension, so the transport is built on `node:https` and `Response`.

The adaptor remembers the chosen address per `(host, model)`, so the outcome observer can charge the right edge. Under concurrent requests to one host and model that record is last-writer-wins; the shared edge ledger tolerates it.

### The address set (submachine A)

Per provider host:

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

Freshness is the `needsRefresh` guard (`now > resolvedAt + ttl`, ttl 60s), not a state. A stale set is still used; it only asks for a refresh. A is session-scoped and is not persisted.

### The edge health (submachine B)

Per `(host, model, address)`. `eligible` carries the window record of recent outcomes; `cooling` carries the window record and `until`. The streak and the success rate are derived from the window, so neither is stored.

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

N = 3 and window = 3 min, the same window that ages out the record. A `limited` outcome and an abort are ignored events: neither is edge-attributable. A success never erases the recent failures, so a flapping edge keeps a non-zero chance of being tried.

### The selection

The selection is a pure guard over the two submachines, not a state. `eligibility` is derived at read time; `lastUsed` is the edge with the newest outcome, so no third variable is needed.

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

Sticky on success: the edge that just succeeded serves again. On failure, reselect through the configured policy. When every edge is cooling, the soonest-to-recover edge is the probe that detects recovery. `rand` is an input, so a fixed sample gives a fixed answer.

### The edge ledger

The edge health persists in its own file, `edges.json` beside the route ledger, keyed `(host, model, address)`, version 1. It is separate because the route ledger is written once per assistant message and the edge ledger once per HTTP attempt. The write is a read-merge-write of one key and an atomic rename, so concurrent processes keep each other's keys.

### The edge invariants

| # | Kind | Invariant |
|---|---|---|
| A-S1 | state | `resolved` carries a non-empty address list and a `resolvedAt`; `unresolved` carries neither |
| A-T1 | transition | A1 and A3 store only a non-empty set |
| A-T2 | transition | A4 leaves `resolvedAt` unchanged, so a failed refresh cannot make a stale set look fresh |
| A-G1 | guard | `needsRefresh` never blocks selection, so a stale set stays usable |
| B-S1 | state | both states carry the window record; only `cooling` carries `until` |
| B-S2 | state | the streak derived from the window never exceeds the failures it holds |
| B-T1 | transition | B3 fires exactly when the incremented streak reaches N, and B2 below it |
| B-T2 | transition | `until` is written only by B3 and B5, and only as `now + window` |
| B-T3 | transition | B1 and B4 reset the streak; B5 does not |
| B-T4 | transition | a limited or aborted outcome writes nothing |
| B-T5 | transition | one transient outcome updates exactly one edge record |
| B-G1 | guard | `eligibleAt` is the only admissibility test the selection performs |
| B-G2 | guard | a cooling edge is admissable when `until <= now`, derived at read time |
| Sel-G1 | guard | sticky is chosen only when the last-used edge succeeded and is clean |
| Sel-G2 | guard | when any clean edge exists, the chosen edge is clean |
| Sel-G3 | guard | when no clean edge exists, the chosen edge minimises `until` |
| Sel-G4 | guard | every clean edge has non-zero probability under `policy.pick` |
| Sel-G5 | guard | the choice is a pure function of `(edges, health, now, rand)` |

Creation and load get their own ids and cases: A0 (extension load to `unresolved`), B0 (a new edge record to `eligible`), B6 (ledger load populates the edge map, or starts empty on a version mismatch). Every transition invariant has a mutation row beside the control row, and a mapping check asserts that every transition id has a case and every case names a transition or state id. Guard overlap is resolved: A1 and A2 split on the received set being non-empty or empty, and B2 and B3 split on the incremented streak being below or at N.

## What this does not do

| Not done | Why |
|---|---|
| Success scoring or probability weighting across routes | the model-level data is class-shaped, not graded; declared order carries preference and the tracking entries carry the evidence a future learned ordering would need |
| Static IP pinning or colo selection | the per-IP signal decays within minutes and colo is not a property of an IP; the edge layer adapts to the current edge instead of pinning one |
| Session-header rotation | not separable from pool state in the measurement |
| Per-model retry tuning inside pi | pi exposes one retry policy; the chain handles the failure class the policy cannot |

## Status

Shipped. The extension is in the tree, in the installed copy the runtime loads, and in the suite; the roadmap row under `M3` records the work, and this document is the design record the code was written against. The route layer chooses a provider and a model; the edge layer keeps the request on a clean address of that provider's host, with the address set and the edge health as two submachines and the reselection policy configurable. The capture of `x-opencode-log-id` was dropped: the edge identity is known by construction because the extension chooses the edge.
