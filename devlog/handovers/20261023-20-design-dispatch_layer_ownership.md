---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Design
status: Closed
---

# Handover - Dispatch layer ownership

## Objective

Settle what owns dispatch and how a workflow calls it, for the problem as defined: a dispatch made from inside pi, between a pi subagent and an OpenCode CLI worker. The answer records as a principle whose boundary is stated, so a larger problem re-decides the principle rather than extending it.

## Scope

The roadmap row **Who owns dispatch logic** under M3.6.3, the design record it carries, [`20261016-design-settled-dispatch_ownership.md`](../discussions/20261016-design-settled-dispatch_ownership.md), and the ADR the record settles into.

The problem was narrowed on operator direction during the iteration: dispatch is a problem met from inside pi when choosing between a mixture of pi and OpenCode subagents, and for that problem the current shape is the answer. The record states what the shape does not cover, and each boundary is a trigger to re-open the decision rather than a gap to fill later.

Out of scope: any change to `scripts/dispatch.sh`, `src/libs/dispatch/`, `src/libs/dispatch_worker.sh`, the `opencode-dispatch` skill or the launch-site gate. The decision is recorded against the mechanism as built; changing the mechanism belongs to the dispatch-rule surface or to the M3.6.5 wiring. The `opencode-dispatch` skill's own default model stays out of scope for the same reason, and is filed instead. The word `layer` is not given a controlled definition here; that is the open T8 row **A controlled vocabulary for `layer`**, and this record uses the part names the design record already carries.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The design record describes the mechanism in the tree, not the stopgap it opened on | `devlog/discussions/20261016-design-settled-dispatch_ownership.md`, Context and Decision: `scripts/dispatch.sh` over `src/libs/dispatch/` and `dispatch_worker.sh`, three callers, one allowlisted fixed run | Agent [x] |
| The design record's status and filename both read `settled` | `ls devlog/discussions/ \| grep dispatch_ownership` | Agent [x] |
| An ADR holds the principle, its rejected alternatives with failure loci, and its boundary | `docs/adr/pi_subagent_dispatch.md` | Agent [x] |
| `dispatch.md` links that ADR from its decision section | `grep -n pi_subagent_dispatch docs/reference/dispatch.md` | Agent [x] |
| The roadmap row closes, and the record carries no claim that dispatch ownership runs before work that has landed | `grep -n "Who owns dispatch logic" devlog/roadmap.md` | Agent [x] |
| A carrier of the retired token `pair`, met in this iteration, has a destination | `grep -n "The word \`pair\` survives" devlog/roadmap.md` | Agent [x] |
| The gate is clean across every lint rule the record set answers to | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One door decides the runtime, and the principle is scoped to the pi dispatch problem | the cheapest pool is unreachable from pi's own clients, and the operator's preference across executables is data rather than a per-caller decision | [`pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md) |
| The ADR is named `pi_subagent_dispatch.md` | the name carries the problem domain, so the scope the decision rests on is not only in the prose | the ADR, and the roadmap row |
| A scope increase re-decides the principle rather than extending it | the four changes named each alter the table's format, the runtime rule, the door's contract, or the walk's order, so a strategy that extended the record would accumulate exceptions the record cannot state | the ADR's edge cases |
| The design record settles and takes the `settled` filename | the work-log convention carries the status in the filename and the design became an ADR | [`20261016-design-settled-dispatch_ownership.md`](../discussions/20261016-design-settled-dispatch_ownership.md) |
| The closed reach row gains no correction marker | its two pointers now resolve to closed rows, and a marker requires a successor entry carrying work, of which there is none | the F4 finding below |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The design row's premise had outrun its record: the record named `src/libs/dispatch.sh` as the seam, which no longer exists, said the front door had no live caller, and said the `opencode-dispatch` skill was its only consumer, while the launch-site sweep gave the door three callers and a fixed-run exception | record | the record described a mechanism that was not in the tree, so a reader could not tell the lean from the delivered shape | settled here: the record is rewritten to the delivered shape and reads `settled` |
| [`dispatch.md`](../../docs/reference/dispatch.md) stated the layer split in its `## The Launch Sites` section, but `## Where This Was Decided` named only the role-table ADR | doc | the ownership principle the document embodied had no ADR behind it, so the next change to it would re-derive the question | settled here: `## Where This Was Decided` links [`pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md) |
| The row's sequencing clause said it runs before `The launch-site sweep`, which landed at handover `20261022-19` | record | a stale ordering claim misleads the next task choice | settled here: the clause is gone with the row's closure |
| The closed row **A mechanism constrains which models an agent can reach** said its remainder sits under two rows, and both have closed | record | a done row points a reader at work that has landed | no edit, by the Decisions table: the pointers resolve to `[x]` rows, so a reader following them learns what became of the remainder, and a marker plus a successor entry would assert work that does not exist |
| The `opencode-dispatch` skill still states a default model and a tier in its description, while its caller passes `--role` and the table owns the value | mechanism | the skill restates the routing layer's data on the one path the launch-site gate does not read, so a role's value can still be shadowed | the roadmap's **The dispatch-rule surface** row under M3.6.3, which already names that shadow as its subject |
| The reserved-terms document's `## launch site` entry uses the retired token `pair` ("takes its pair from its caller"), and eight further lines across both `AGENTS.md` layers, the role-table ADR and two skill-scaffolder pages name a `pair` where they mean an assignment | doc | a reader learning the vocabulary from its source of truth meets the token it retires on the same page | the roadmap's new **The word `pair` survives the rename** row under M3.6.3 |
| Route state is session-scoped and the container's `/opt/sandbox/lib` predates `src/libs/dispatch/`, so the installed surface carries no dispatch library and this iteration verified the tree, not the image | environment | a reader of the ADR would assume the installed mechanism matches the tree | flagged, and unchanged by this iteration: it is the blocked build item, not a record defect |

## Completed

| File | Change |
|---|---|
| [`docs/adr/pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md) | new: the ownership principle, its rationale, three rejected alternatives with failure loci, and the four scope changes that re-decide it |
| [`devlog/discussions/20261016-design-settled-dispatch_ownership.md`](../discussions/20261016-design-settled-dispatch_ownership.md) | renamed from the `active` record; Context, Options, Decision and Consequences rewritten to the delivered shape, settling into the ADR |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | `## Where This Was Decided` links the new ADR |
| [`devlog/roadmap.md`](../roadmap.md) | **Who owns dispatch logic** closes with its scope stated; the sequencing clause is gone; the retired token `pair` gains a row |
| [`../../.agents/drafts/dispatch-mechanism-run.md`](../../.agents/drafts/dispatch-mechanism-run.md) | its link to the design record follows the rename |
| [`../AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | one entry: a shipped document linked a target the image does not carry, which the linking gate caught |
