---
name: communication-principle-write-for-the-reader
description: "Apply when writing a commit message, a code comment, a document, a record or a note. The reader has the artifact, not your session. Name the thing, not the chat label, the option letter, the session id, or the narration of how the writing went."
---

# Write for the Reader

An artifact is written for its reader, not for the session that produced it.

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

**Why.** The chat is not shipped with the artifact. A label only the chat defines makes the reader guess, and the guess cannot be checked later. A narration of how the artifact was written displaces the subject the reader came for.

**Where the session is the subject.** A session log or a meeting record narrates one session, because that session is its subject. Even there, a reference into the chat carries its referent, because the chat is not shipped with the record.

**The test.** Ask two questions of the sentence. Would the reader need the session to use it? If yes, state the thing. Is it about the subject, or about how the artifact was written? If the latter, state the state.
