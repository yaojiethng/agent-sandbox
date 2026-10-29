# Cost-aware dispatch: the settled shape

**Status:** settled

## Context

M3.6 opened as eight flat task rows that mixed three kinds of work: a runner seam, a cost-measurement system, and a dispatch-routing model. Two rows landed before this session: the OpenCode instruction transport and the pi source of the cost ledger.

The session began from a claim that the `model-failover` extension mis-routed a physical model. That claim was wrong, and the check that overturned it produced the finding this design rests on.

## The finding that reframes the milestone

Across 592 sessions in the store, exactly zero carry a `"type":"model-failover/outcome"` entry. The extension has never recorded a failover outcome in any accessible session.

The only chain in `routes.json` is `step-5-preview-free`, and it declares one route. A chain with one route cannot fail over, so the configuration cannot exercise the feature.

The extension landed at commit `ba170963`, when the image pinned pi 1.2.0. The image pins 1.3.0 now. The code was written against a runtime that has since moved once.

So the extension's value is unmeasured, and its only configuration cannot show one. The milestone's first question is not how to extend it, but whether it earns its place.

## The ordering

1. **Disable it.** A flag, default off, with a test that the extension is inert when off. Cheap and reversible.
2. **Ship OpenCode dispatch.** The runner seam that makes `opencode run` a dispatch backend, so a swarm runs on the free models. This is the ASAP goal and it needs no failover.
3. **Measure.** A per-request outcome and latency instrument in the ledger, keyed by `(provider, model)`.
4. **Decide.** An A/B with the extension off then on, comparing success rate, cost and wall clock. Then rebuild the extension from a spec the measurement writes, or delete it.

The order matters because step 2 makes step 4 cheap to run at scale.

## The measurement is runtime-agnostic

The outcome instrument lives in the ledger, not in the extension. It must read a pi session and an OpenCode dispatch alike. An instrument inside the extension could never see the OpenCode backend, and the A/B could never compare the two runtimes.

The ledger has two grains. The storage grain is one record per request. The reading grain is an aggregate: per subagent call, per main-agent call, and a cost summary at the close of an iteration. The one-record-per-dispatch output landed as the storage grain, and it is the foundation rather than the surface.

The capacity signal belongs to the reading grain. The agent reads its context-window use; the operator reads total tokens, cache-hit rate and cost.

## The router boundary

One shared state and policy, keyed by `(provider, model)`: health, outcome history, cost, quota, capability.

One adapter per runtime: the pi extension, and the `opencode run` invocation.

The extension today holds both halves, which is why its state is unreachable from an OpenCode dispatch. A chain that registers a virtual model is a deliberate interface, select a chain by name and receive a fallback list. Re-keying to `(provider, model)` is a different interface, name a model and let the router move around it. The second composes with dispatch routing, and it is the direction the measurement will judge.

## The failure taxonomy

Every request ends in one of these, and the ledger records which.

- **success** -- the request completed.
- **transient** -- a retryable transport or provider fault.
- **quota** -- a rate or usage limit, with a reset horizon.
- **capability** -- the model cannot do the task, independent of health.
- **timeout** -- the request exceeded its budget.

The taxonomy is the union of what pi records in a session and what OpenCode emits per step. Which classes the existing records can already distinguish is the first measurement, not an assumption.

## Attribution

No dispatch misrepresents its client. The free tier is reached through the real OpenCode CLI. A policy that would require spoofing is rejected rather than softened. This binds every sub-milestone.

## The sub-milestones

| Sub-milestone | Content |
|---|---|
| M3.6.1 Disable and ship OpenCode dispatch | the disable flag and its inert test; the runner seam with two backends; the provider decision; the one launch site the seam proves |
| M3.6.2 Measure | the per-request outcome and latency ledger; the three aggregates; the capacity signal; the two-model side-by-side |
| M3.6.3 Route and decide | the model-catalog track tied to `model-recommendations`; the dispatch-rule surface; the failover A/B; the rebuild-or-delete verdict; the policy bakeoff |

## Consequences

The failover extension is disabled before it is judged, so the A/B runs against a smaller base.

The runner seam arrives before the measurement, so the measurement can be taken at the scale the seam enables.

The fifteen launch sites keep their current form until the seam is proven on one of them, and the sweep is deferred to M3.6.3.

The run directive under `.agents/drafts/` is a hypothesis. Parts of it are superseded, and it should be re-derived against this design rather than followed.
