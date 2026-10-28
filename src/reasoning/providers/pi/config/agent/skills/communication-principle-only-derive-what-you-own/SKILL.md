---
name: communication-principle-only-derive-what-you-own
description: "Apply when a sentence states a total, a percentage, a count, or any value computed from data held elsewhere. The document stating a derived value does not own it, so an update to the underlying data misses the copy and the staleness is silent. State the primary data, or name the source that derives the value."
---

# Only derive what you own

A derived value is a copy of data held elsewhere, and the copy is what an update misses.

**The pattern.** The number reads as a fact about the subject, and it is a fact about a snapshot of another artifact. Nothing in the sentence names that artifact, so nothing shows when it moved.

| Instead of | Give |
|---|---|
| "two directions" | the list that follows, or "the directions" |
| "the three cases" where the list carries four | "the cases" |
| "22 orphaned skills" retyped into each record | the command that prints 22, run once |
| "clean across 90 files", quoted from a gate | the gate, run |
| a total beside its own list | the list, so the reader counts |
| a count in a roadmap row that later rows add to | the row's own scope, with the count left to the gate |

**Why.** The failure is silent. An update to the underlying data misses the aggregate, and no gate reports a copy that disagrees with its source. The reader also pays when the value is wrong. An understated total hides a case, and an overstated one sends the reader hunting for something that does not exist.

**Where the aggregate is the fact.** A value nobody can derive from the text beside it stays. A test result, a measurement, or a total over data the reader does not hold is primary data, and stating it loses nothing.

**Where the primary data is beside it.** The list is the primary data, so print the list and drop the total. A stated total beside its own list is a copy of what the reader can already see.

**Where many texts need the value.** The source owns it and every other text points at the source. A record of rows plus a deterministic reader over them is the durable form. A number typed into each record is one copy per record, and every copy but the last is wrong by the end.

**Where the value describes another artifact.** That artifact owns it. Name the artifact and let the reader look, or print the value beside the command that produced it. Never restate a value the artifact owns.

**The test.** Point at where each value comes from. A value the sentence cannot recompute from the text beside it needs a named source or the command that prints it, and a value whose source is named stays current when the source moves.
