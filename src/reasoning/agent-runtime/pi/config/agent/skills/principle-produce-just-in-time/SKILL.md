---
name: principle-produce-just-in-time
description: "Apply before creating a file, a record, a section or a result the current scope does not ask for: unclaimed work clutters the tree and distracts from the work in hand."
metadata:
  intent: "Produce only work demanded by the current scope."
  mechanism: "Pull on demand: create an artifact only when the current scope demands it."
  leitwort: demand
  neighbours:
    - communication-principle-dont-forecast-undone-work
    - principle-justify-materialization-cost
---

# Produce just in time

Unclaimed work clutters the tree, so an artifact is created only when the current scope demands it.

**The pattern.** Align on the scope of the task before starting it and produce only work that fits the current scope. When the scope is adjusted, take the correction and restate it.

**Why.** In a clean worktree every artifact has a purpose, making work more targeted, concise, and easier to review. Unclaimed work is clutter that distracts from our core change. The subsequent writing and reviewing incurs a proportional processing tax, to separate the change from the clutter.

**The test.** Name the intent the work serves and the scope it fits. Work that serves the intent and fits the scope is produced. An intent outside the current scope changes the scope first.

**Where the demand is real.** A cache, a generated file or a lockfile serves a demand the scope names, so the question turns to the form its fulfilment takes. Two rules own that form. [`principle-justify-materialization-cost`](../principle-justify-materialization-cost/SKILL.md) asks what catches the drift of a stored result. [`principle-remove-the-passthrough`](../principle-remove-the-passthrough/SKILL.md) asks who reads the artifact for itself, and its factors name what pays for the write.

**Where it comes from.** The Toyota Way, Principle 3: "Use 'pull' systems to avoid overproduction", a pull system producing only what a subsequent operation signals a need for. The wording is corroborated by Wikipedia's summary of the fourteen principles and is unverified at source.
