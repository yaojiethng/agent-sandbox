---
name: principle-single-source-of-truth
description: "Apply when two places seem to carry the same material: every judgement, piece of logic and value is stated once, and a second restatement is a collision."
metadata:
  intent: "Clarity in organization: each judgement, piece of logic and value is stated once, so the reader does not get conflicting statements, and maintenance is easy."
  mechanism: "A collision: one of the three stated twice, so no reader can tell which statement is authoritative. The repair splits it, points at the one statement, or justifies the copy as a view."
  leitwort: ownership
  neighbours:
    - communication-principle-cut-metadiscourse
    - communication-principle-organize-by-diataxis
    - principle-justify-materialization-cost
    - communication-principle-keep-context-in-view
---

# Single source of truth

Single source of truth is the practice of structuring documents such that every judgement, piece of logic and value is stated once.

**The kinds of fact.**

- A **judgement**, a rule, a principle or a convention, is stated once, in one document, and every other document names it and links there.
- A **piece of logic** has one canonical implementation, and a second is a copy unless it behaves differently.
- A **value** has one stored copy, and a second store is a materialized view; a count or total stated in prose is the same value, and it carries the command that regenerates it.

**Why.**

- **Authoritative ownership.** Each of the three is stated once, in one document, and updated there; this repository first assigns that document its Diataxis mode, per [`communication-principle-organize-by-diataxis`](../communication-principle-organize-by-diataxis/SKILL.md).
- **Downstream consumption.** Other documents read from or reference that statement instead of repeating it in their own text.
- **Regeneration, not editing.** A change at the statement does not reach a copy by itself, so a copy needs something that catches its drift.

When one is stated twice anyway, the statements collide: the reader cannot tell which is authoritative. Multiple statements are harder to keep in sync, so they drift apart, go stale, and contradict each other. Catching a collision early is cheap; after the work is built, the copy has readers of its own, and the boundary is harder to redraw.

**The test.** Where is this stated?

- **The material spans more than one mode.** Then no single statement can hold it. Split it, and [`communication-principle-organize-by-diataxis`](../communication-principle-organize-by-diataxis/SKILL.md) places each part.
- **This document restates content it is not responsible for.** Point at the statement that holds it. A link stays a link only while it names its source; remove the name and it is a copy.
- **A second file copies or derives the content without being responsible for it.** If it asserts what the responsible document asserts, at the same time and in the same form, it is a second statement, and that is the collision. If it asserts something else, an as-of time or a named transformation, it is a materialized view, and [`principle-justify-materialization-cost`](../principle-justify-materialization-cost/SKILL.md) decides whether it is justified.

Only the operator splits content across documents, deletes a copy, or widens what a document is responsible for. The agent adds the pointer, names the content, the document that states it, and the document that would end up with the copy, then stops.
