---
name: communication-principle-write-for-the-reader
description: "Apply when writing a reply, a commit message, a code comment, a document, a record, a note, a skill or a prompt. The reader has the text, not your session and not its own earlier draft. Name the thing, not the chat label, the option letter, the session id, the narration of how the work went, or the text this version replaced."
metadata:
  claim: scope
---

# Write for the reader

Every text is written for the reader who holds it, not for the session that produced it.

**The pattern.** A sentence about the session is a sentence the reader cannot use. Give the thing the reader needs, or link the session record once.

| Instead of | Give |
|---|---|
| "Implemented option 3 from the chat" | "Refactor auth to use JWT tokens" |
| "option B of the three" | the chosen behaviour, named, with the rejected alternatives stated |
| "Per the last prompt update" | the rule, stated |
| "TODO: clean up transient log for session 482a" | "TODO: remove the debug log" |
| a bare commit hash, record name or session id | the fact, or one durable link to the record |
| "we first chose X, then switched to Y" | the current state, with X in an alternatives section |
| a resolved question and its reply left in place | the answer, stated as the current state |
| an absolute scratchpad or run path | a relative path or an environment variable |

**Why.** The chat is not shipped with the text. A label only the chat defines makes the reader guess, and the guess cannot be checked later. A narration of how the text was written displaces the subject the reader came for.

**Where the session is the subject.** A session log or a meeting record narrates one session, because that session is its subject. Even there, a reference into the chat carries its referent, because the chat is not shipped with the record.

**Where the editor is the reader.** A skill, a prompt, or either `AGENTS.md` layer is read by an agent that has never seen an earlier version of the file. That agent holds the current text and nothing else, so a clause that rebuts a sentence the file no longer contains has nothing to point at. The clause is addressed to the person who made the edit. Route it to the record layer, which has the edit as its subject, and leave the instruction surface stating only what the reader is to do.

| Instead of | Give |
|---|---|
| "Do not estimate the window any more, read it" | "Read the window with `--context`, and quote the reading" |
| "Set a turn budget names nothing an agent can count" | "Name the unit and the count before starting" |
| "the payload, not a summary, used to go in the main thread" | "The main thread keeps the summary" |
| "this replaces the version that said X" | the rule as it now reads |
| a note that a package bump will overwrite this edit | a record-layer entry naming the overwrite condition |

**Where the sentence names only the prohibition.** The reader holds only the form the sentence gives, so a prohibition alone leaves the reader to invent one. Name the action and write the permitted form. Write "a space-separated hyphen", not "do not use an em-dash"; write "apply the durable fix the entry's `scoped:` row names", not "avoid or re-check those patterns".

**The same judgement on a prompt.** A correction appended to a prompt is read by the model as an instruction about a behaviour, not as history, so it survives only if it reads as one. "Do not do Y, do X instead" works when the model might do Y. It fails when Y was a phrase the prompt used to contain, because the model never met it. Name the behaviour, not the retired sentence.

**The test.** Ask four questions of the sentence. Would the reader need the session to use it? If yes, state the thing. Would the reader need an earlier version of the file? If yes, state the current rule and move the comparison to the record. Is it about the subject, or about how the text was written or revised? If the latter, state the state. Does it leave the reader to invent the permitted form? If yes, write that form.
