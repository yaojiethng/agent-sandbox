# Greenfield documentation

Greenfield documentation is a document whose subject exists in the code and nowhere in the document set. A document usually starts from one already in the tree; this page covers the other start, where the operator names a slice of the system and wants documentation for it.

1. **Scope the slice.** Take the subject from the operator's sentence, not from a file list, and settle three things before the first sentence.
    - **Ownership.** Does a document already make this claim? If one does, edit that document; a new file would be a second home for one fact. Search the document set for the subject and for the words it would naturally use.
    - **Truth.** Read the code the slice names, never a document that describes it. A slice that does not exist as described is a finding to raise.
    - **Vocabulary.** A term the slice uses may already name something else here. Settle which word the reader will hold; a document that renames a concept splits it, and every later reader carries both names.
2. **Place and type it.** The folder and the document type are in [`../SKILL.md`](../SKILL.md). A prompt or a skill takes [`prompt-authoring-conventions.md`](../../../../docs/development/prompt-authoring-conventions.md), which borrows `writing-for-agents`.
3. **Confirm the skeleton.** Propose the sections in chat, one line each on what the section holds, and wait for the operator. Without that confirmation a reference document is written twice.
4. **Write for the reader who acts.** The standards are the `communication-principle-*` corpus and `../SKILL.md`. The reader acts on the slice next, so the draft says what the reader can do with the system and stops there.
5. **Hand back.** Return the drafted text, the ownership conflicts the scope check found, and the questions the slice could not settle. The operator edits the draft, and nothing in this procedure commits.

A request to say what is wrong with an existing document is not this case. Run the [`reference-staleness`](../../../../workflow/coding-agent/skills/prose-review/runbooks/reference-staleness/SKILL.md) review, which reads a document and reports findings; diagnosing inside a rewrite produces a finding nobody can check.
