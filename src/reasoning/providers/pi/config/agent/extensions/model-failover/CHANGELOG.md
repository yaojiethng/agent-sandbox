# Changelog

Implementation changes to the model-failover extension, newest first. One heading per change, dated by the day the change landed in the tree. The design record for every change is README.md.

## [0.2.0] - 2026-10-14

- The edge layer lands: the extension wraps the process fetch and pins each managed host's inference request to a chosen edge address, resolving the address itself and keeping the provider's host as SNI and `Host`. The provider registry, the model registry and `models.json` are not touched; an unmanaged host is delegated untouched.
- Two submachines: the address set per host, refreshed on a 60s ttl, and the edge health per `(host, model, address)`, with transitions B1-B5, N = 3 and a 3-minute window. A losing streak cools an edge; a success records evidence without erasing the recent failures, so a flapping edge keeps a non-zero chance of being tried.
- The selection is a pure guard: sticky on success, reselect through a configurable policy (`epsilon` or `rate`) after a failure, and the soonest-to-recover edge when every edge is cooling.
- The edge health persists in `edges.json` beside the route ledger, keyed `(host, model, address)`, by read-merge-write. The session-start report lists each managed host's edges with their derived rate and streak.

## [0.1.0] - 2026-10-12

- The extension lands: one pi extension that keeps a session on a working model. The operator declares chains in `routes.json`; each chain becomes a virtual model under the `failover` provider, and the extension dispatches the first healthy route of the chain.
- The health ledger holds two states per route, `eligible` and `cooling`, with transitions T1-T6 and the eligibility guard that derives a lapsed deadline at read time. A transient failure demotes on the declared consecutive-failure count (default 3); a quota-class failure demotes on the first occurrence; any success restores the route at once. The ledger persists beside the module as JSON by read-merge-write, so concurrent processes keep each other's keys, and it survives across sessions.
- The dispatch walk is sticky at every request reason: the last successful route serves while it is healthy, a health transition moves to the first healthy route in declared order, and a fully cooled chain degrades to its head so a provider outage never becomes a session outage.
- Every classified outcome appends one custom entry to the session log, so the live success distribution for each chain is reconstructible from the transcript. `session_start` reports each chain's state and calls out a route cooling on a quota-class error.
- A thermo-nuclear review of three rounds hardened the contracts before delivery: one physical route belongs to exactly one chain across the file (the loader refuses a cross-chain duplicate, so two chains cannot contend over one ledger key), a route's thinking level is one of six validated names (the dispatch boundary no longer casts a string), the ledger file carries its version and another version reads as empty, every chain owns its cooldown defaults, and the report has a single construction path. The mutation catalog grew from 8 rows to 12 to hold the new rules.
- The instrumentation of the gateway that drives the design: the failure is per model and per upstream endpoint, episodes are single-error or bursts of 2 to 24, the pool self-recovers on a minutes timescale, and the edge IP of the request does not decide the outcome. The per-IP signal decays within minutes, so nothing is pinned.
