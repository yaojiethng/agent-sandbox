---
status: rejected
date: 2026-10-24
---

# Design - The model-catalog track is retired

## Context

The M3.6.3 row **The model-catalog track** asked for the live inventory of models across both runtimes  --  what each is good for, its cost, its rate limits and its provenance  --  tied to the role table, with a refresh and a staleness check. The first draft of this record took that as a requirement and designed the artifact. The operator rejected the premise, and the premise is what this record now answers.

Four things in the tree decide the question.

- The dispatch utility keys on the model string and records what happens to it. A route record holds `ready`, `cooling` or `dead`, the reason, the strike count, the moment it may be tried again, and the provider's own sentence. A string that parses but names nothing real comes back from the provider and marks the route `dead` with that text; a malformed line is refused by `parseAssignment` before any attempt exists. Observed evidence about a model is produced by use, and belongs to the route.
- The list of what the runtime knows is a command: `pi --list-models` prints provider, model, context window, maximum output, thinking support and image support, and the OpenCode runtime answers the same question the same way. A committed copy of that output is a derived artifact with no reader that the command does not already serve.
- A listing is not a service claim, and the tree measured this twice. The ADR `single_source_model_recommendations.md` rejected catalogue validation after a name read from a list was reported as available and the provider refused it, and after a listing was found not to be a service claim at all.
- `docs/reference/dispatch.md` `## Failure and Its Vocabulary` refuses to record a quota remainder, because two sessions spending one pool make any remainder a fiction. A declared rate limit is that remainder under another name.

Cost is M3.6.2's subject and that sub-milestone has not started; the free pool is spent in requests rather than tokens, so a price table would rank the wrong resource anyway.

## Options Considered

### A. Build the inventory as a reference document with a structural gate

One live document, one row per `provider/model`, each fact dated and attributable, held to the role table by a gate. The earlier draft took this option and its own consequence exposed the defect: the document's only consumer would have been the gate built to keep it true. A registry a program does not read is a document with worse editing, which is the class the 2026-10-23 derived-artifacts census recorded.

### B. Retire the track, and let the utility's evidence and the runtime's list stand

Every column the row asked for is already answered: preference is the role line's order, cost is M3.6.2's ledger, a rate limit is the route record's cooled-until with its reason, provenance is the provider's own sentence plus the scope, and the model list is a command. Nothing is added, so a new model stays one role-line edit and nothing else.

### C. Retire the artifact but add a pointer to the listing command

One line in `dispatch.md` naming the command that lists models. Cheaper than A and it closes the one gap the audit found: no live document says how a reader sees what exists. It is taken, on the condition that the line states the listing is information for the reader rather than a validation step, so it does not blur the requirement beside it.

## Decision

**B**, with **C**'s pointer. The row is retired and no artifact is built, on operator direction of 2026-10-24. Option **A** is rejected on execution: its subject is a copy of facts the utility already observes, and its gate exists only to keep the copy true. Option **C** is taken as one line in `dispatch.md` beside the sentence that forbids catalogue validation: a caller asked what models are available answers from the runtime, with `pi --list-models` for pi and `opencode models [provider]` for the OpenCode CLI, and the line says in the same breath that a listing is information for the reader and not a validation step. The line names no table the tree keeps and adds no artifact.

## Consequences

- The dispatch utility keeps one behaviour: try a model string, record what happened, and let the record decide the next attempt. No registration step exists between a model appearing and a dispatch using it.
- A reader asked what exists has a command to run rather than a document to search, and the requirement that nothing validates an assignment is untouched: the listing says what a runtime knows, not what it will serve.
- The facts the row wanted a home for are distributed by nature rather than collected: measured spend to M3.6.2's ledger, observed health to the route record, identity to the runtime's own list, and operator preference to the role line.
- If a price or a limit ever needs to be read before an attempt rather than after one, that is a new premise with its own evidence, not a revival of this row.
- This record is the answer for the next reader who proposes an inventory, a catalogue or a capability probe: the measurements and the rejections are here, and the tree holds no artifact to mistake for a source of truth.
