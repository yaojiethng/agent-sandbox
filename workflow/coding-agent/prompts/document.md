---
description: Documentation-session runbook for a session that produces documentation rather than runtime behaviour. Defines how acceptance criteria apply when there is no standard runtime AC, and drives compliance with the documentation standards. Stub -- carries the design infodump; formalization is its own roadmap task.
argument-hint: "[documentation goal or target document - optional]"
---

> $@

# Document - Documentation-session acceptance criteria and runbook

This prompt is a stub. It records the intended scope (the infodump) so the decisions are not lost. Its relative name (`document`) is a placeholder; expect a rename once a better name is found.

Run `/iter` for runtime-behaviour work. Run this prompt for a session that produces or rewrites documentation and has no standard runtime acceptance criterion.

## Scope (infodump - formalize into a runbook)

The docs-session runbook covers:

- **Acceptance criteria as read/lint-observable deltas.** A docs session has no runtime to run. Its ACs are deltas the operator verifies by reading or by linting: `head -N` of a section, a grep for a phrase, a lint run. This extends the observable-delta rule (an AC is something observable that was false before the iteration) to the docs domain. "Not file state" still applies -- a criterion must be operator-verifiable by reading the produced document, not by asserting the source contains a token.
- **Advisor use.** State when to dispatch the review advisor on the documentation.
- **Standard compliance.** Compliance with `documentation-pass.md`, `conventions.md`, and the writing standards (ASD-STE100, one term one meaning, active voice). Each produced document is checked against these.
- **Grill-me alignment.** Use grill-me to align on rewrite requirements ahead of the rewrite, not just for planning. A rewrite that changes the meaning of an existing document is a negotiation, not a mechanical edit.
- **Workflow-document identification.** How to tell a document is a workflow document (a prompt or skill) as opposed to a reference or policy document. Workflow documents follow the presentation rules in the authoring-guidelines convention ([`prompt-authoring-conventions.md`](../../../docs/development/prompt-authoring-conventions.md)).
- **Acceptance-criteria machinery.** How the AC machinery applies when the session type has no standard AC: a docs session defines ACs as read/lint-observable deltas rather than runtime-verified deltas.
- **Consolidated close.** The docs-session close runs from [`/wrapup`](wrapup.md) Part B, as one of the active-operator prompts (`/iter`, `/plan`, `/document`).

## Non-goals

- Runtime-behaviour work -- use `/iter`.
- The per-prompt quality passes for the four loop prompts -- they have their own roadmap tasks.
