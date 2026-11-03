# A workflow document's body, and its form

A workflow document is a prompt or a skill, and its **form** is a second axis, decided by what the body carries. The type sheets hold the mechanics, [`prompt-conventions.md`](prompt-conventions.md) and [`skill-conventions.md`](skill-conventions.md); this file holds the body both types share, then the forms it takes. Where a rule may live is [`agent_workflow.md`](../../../../docs/reference/agent_workflow.md) `### Where the rules live`, and which kind each sentence is, [`../SKILL.md`](../SKILL.md) `## The five kinds`.

## The body's common shape

A document carries the sections its work needs, and a short one may carry none. Where the parts are needed, this order has read well:

1. **Title and scope.** A title, then a `Scope` line stating the boundary.
2. **Purpose.** What it is for, and what it is not.
3. **When to use.** The conditions that invoke it, and what replaces it otherwise.
4. **The work.** Steps, each ending on a completion criterion; or a reference region, which has no step to finish.
5. **The handoff.** The next document and the boundary, where this one hands on.
6. **Non-goals.** What it deliberately does not do.
7. **Failure modes and invariants.** What can go wrong, and what must stay true.

**The project conventions block.** A document that reads or writes project records opens with a `## Project conventions` section before its first step. It lists the conventions it uses, each read at `.agents/skills/<name>/SKILL.md`, and states the failure when that file is absent or holds the seeded stub: control passes to the agent, which decides with the steering it has loaded, and the document prescribes no fallback. It names the convention, never the project's paths, so a project with a different layout is served by its own skill. `gm` is the minimal case.

## Runbook

A runbook holds ordered steps, whether it is a prompt or a skill. Each step ends on a criterion that says when the step is done, per `principle-say-what-done-looks-like`. A runbook is not the form a dispatched worker takes: a worker runs one segment and reports, per the `dispatch` convention, so a runbook that wants fan-out dispatches the work rather than being dispatched itself. One that hands to another document names the boundary in four moves, per `communication-principle-hand-off-by-naming-the-boundary`.

## Advisor

An advisor holds reference and judgement, and runs against a document or a change to find defects. It is a diagnostic checklist: it names the rule a document broke, and leaves the prescriptive rule in the document that owns it. The triage and consensus after it returns belong to the runbook that dispatched it. A review is `prose-review`'s shell plus one runbook, and the shell states its seats and the brief.

## Reference and helper

Flat rules with no order and no decision: the form a body takes when its reader consults it rather than performs it. A helper that wraps a mechanism stops at the command line, per [`prose-entrypoint.md`](../patterns/prose-entrypoint.md).

## Choosing the form

| The work is | The form |
|---|---|
| repeated identically, in an order | a runbook |
| a judgement over an artifact someone else produced | an advisor |
| a body of rules or a capability its reader consults | a reference or a helper skill |
