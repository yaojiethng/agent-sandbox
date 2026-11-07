---
name: principle-propagation-discipline
description: Apply when a change removes or renames something, or lands across more than one file. Every carrier of the old state is part of the task, and a deletion's carriers include the descriptions as well as the references.
---

# Propagation discipline

A change is not done while anything in the tree still asserts the old state.

**The pattern.**

- Before the first edit, list every carrier in chat. A carrier is a file, a test, a record, or a sentence that describes the thing rather than naming it.
- An issue inside the artifact you are changing is a carrier, not an adjacent issue. A reference to the thing you just deleted is part of the deletion.
- For a rename, the key is the old name. Search the tree for it and update every hit.
- For a deletion, the key is the phrase the tree uses to describe the artifact. Record that phrase before you delete, then search for it. A filename key cannot find prose that never names the file.
- Every carrier that survives the sweep gets a destination. It is fixed here, or it becomes an open task row.

**Why.** The two obvious keys fail in opposite directions. A filename key is precise and blind to descriptions, so a record that says "the stub fails closed" survives a clean grep for `stub.md`. A vocabulary key is broad and finds everything, so it costs more to read than the change did to make. The artifact's own phrase is the only key that lands on the prose.

**The audit.** The trigger list, the checklist and the coverage audit are in the `propagation-check` skill. This principle carries the decision. That skill carries the procedure.

**The test.** Name every file that still asserts the old state. If you cannot list them, the change is not done. For a deletion, name the phrase you searched for.
