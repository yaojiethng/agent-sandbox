# Maintenance record

## Source

Distilled inside this repository from its own `linking` convention, which this project states as a convention-skill under `.agents/skills/`. It was not forked from an upstream skill set, so there is no upstream revision to name. The convention is project-scoped and the judgement inside it was scoped to this repository's documents, while the judgement holds for any writer pointing at any target.

## Adapted

**Moved in.** The judgement sentence, "link a target the reader may open, name one they may not", and the reach rule, that a link resolves where its document is read. Both stated in the project convention and nowhere a receiving project could read them, while the provider layer and the `linking` convention already assumed them.

**Kept as the convention's, not this skill's.** What to link from each document kind, where a handoff link belongs, how to form one, the four use-case stories, and the gate the convention names. Those are this project's structure, so the convention keeps them and points here for the judgement.

**Added.** `**The test.**`, which the source clause lacked. The convention's own test case is the one that surfaced the defect: a shipped document naming a project-scoped path, where no gate observed the name because it was a code span rather than a link.

## Name

`communication-principle-link-what-the-reader-can-open` states the judgement rather than the subject. The `communication-principle-` prefix is correct because the judgement governs every prose surface, a chat reply included, and it fires wherever a pointer is written rather than only in a document.

**Install path.** The skill is installed to `$AGENT_HOME/agent/skills/communication-principle-link-what-the-reader-can-open/`, seeded from this repository's pi config tree.
