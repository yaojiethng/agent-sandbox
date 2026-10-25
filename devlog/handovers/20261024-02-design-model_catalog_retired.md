---
date: 2026-10-24
milestone: M3.6.3 - Route and decide
type: Design
status: Closed
---

# Handover - The model-catalog row is retired, and the listing is a command

## Objective

Retire the model-catalog row on operator direction, record why the dispatch utility's own evidence and the runtime's model list already answer it, and leave one line in `dispatch.md` so a caller asked what models exist runs a command instead of looking for a table.

## Scope

The roadmap row **The model-catalog track** under M3.6.3, and one sentence of [`dispatch.md`](../../docs/reference/dispatch.md) `## Requirements`.

The row was proposed as an inventory of each model's cost, rate limits and provenance. The operator rejected the premise: the utility keys on the model string and records what happens to it, a model string that names nothing real is already marked dead with the provider's text, and nothing about the dispatch algorithm becomes more correct with a declared list in front of it. What the operator kept is the reader's question, answered as a command rather than an artifact.

Out of scope, each with its reason. Any inventory document, schema, refresh or gate, because the ruling retires the artifact the row asked for. Cost, because it is M3.6.2's subject and the free pool is spent in requests rather than tokens. A probe or validation of an id, because `dispatch.md` forbids it and the ADR `single_source_model_recommendations.md` rejected it on two measured failures.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The row is retired and the decision stands under M3.6.3 | `grep -c "The model-catalog track" devlog/roadmap.md` prints 0; `grep -c "^\*\*Decision (2026-10-24)" devlog/roadmap.md` prints 1 | Agent [x] |
| No inventory artifact was created | `ls docs/reference/model_inventory.md docs/adr/model_inventory.md` fails for both, and `git show --stat HEAD` names no new file under `docs/` | Agent [x] |
| The rejection record states the option it beat and what already answers each column | `grep -c "^### [A-C]\." devlog/discussions/20261024-design-rejected-model_catalog.md` prints 3, and `sed -n '/^## Decision/,/^## Consequences/p'` reads B with C's pointer | Agent [x] |
| The listing line names both runtimes' commands and keeps the no-validation requirement | `grep -c "pi --list-models" docs/reference/dispatch.md` and `grep -c "opencode models \[provider\]" docs/reference/dispatch.md` each print 1, the line says "not a validation step", and `grep -c "Nothing validates an assignment" docs/reference/dispatch.md` still prints 1 | Agent [x] |
| Every decision this iteration recorded is realized in the files | one grep per `## Decisions` row, listed below | Agent [x] |

## Decisions

| # | Decision | Rationale | Where recorded |
|---|---|---|---|
| D1 | The model-catalog row is retired; no inventory artifact is built | each column is already answered -- preference by the role line, cost by M3.6.2's ledger, a limit by the route record's cooled-until, provenance by the provider's sentence and scope, the model list by the runtime -- so a second declaration would constrain the utility without changing correctness or latency, and a gate over it would exist only to keep the copy true | [`20261024-design-rejected-model_catalog.md`](../discussions/20261024-design-rejected-model_catalog.md); the roadmap decision under M3.6.3 |
| D2 | One line in `dispatch.md` names each runtime's listing command and calls the listing information, not validation | a caller asked what models are available should ask the runtime; the sentence must not read as a service claim, because the tree measured twice that a listing is not one | [`dispatch.md`](../../docs/reference/dispatch.md) `## Requirements`; the same design record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `catalogue` already names the runtime's baked model list in `dispatch.md` and in `single_source_model_recommendations.md`, which rejected reading it as validation on two measured failures | record | naming the artifact a catalogue would have overloaded the one sense the tree needs sharp | D1: no artifact exists, so no new term is needed |
| The row's "per-model rate limit" premise does not hold: the measured free tier is one shared 200-request pool per IP per day, and the metered `429` is a family limit | record | a per-model column records a number that does not exist and invites a false comparison | the design record's Context; the row that carried it is retired |
| `.agents/drafts/close-the-model-bypass-run.md` already filed "a capability record published by dispatch and probed per backend", and its own 2026-10-18 measurements show the opencode-go backend cannot be probed out of band | record | two records proposed one artifact, one of them with a probe the tree forbids and the backend cannot answer | the design record: the probe is rejected with its measurement, and the artifact it would have filled is retired |
| The handover index `20261024-01` is held by two records, and this one takes `02`, the index the earlier check-in proposed for the route-cause record | record | a second collision is latent if that record is later renumbered | the check-in's escalation, still with the operator |
| The agent read a measurement note inside a roadmap row as a requirement, designed an artifact for it, and then proposed a gate whose only subject was that artifact | agent experience (class B) | the pattern adds a constraint to a clean design and buys neither correctness nor latency; the operator caught it, and the same reading would recur on any row that carries measurements | published: [`AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) `## [O] 2026-10-24  --  A roadmap measurement note became an artifact and a gate` |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261024-design-rejected-model_catalog.md`](../discussions/20261024-design-rejected-model_catalog.md) | the rejection: three options, the operator's ruling, and what already answers each column the row asked for |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | one sentence in `## Requirements`: `pi --list-models` and `opencode models [provider]` are how a caller finds what exists, and a listing is information rather than a validation step |
| [`devlog/roadmap.md`](../roadmap.md) | the row retired, the decision recorded under M3.6.3, and the sub-milestone's scope paragraph narrowed to the subjects it still holds |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | one class-B entry on reading a row's measurement note as a requirement, with the mitigation that names the artifact's reader before designing it |
