---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save the handoff document to `.scratchpad/handoff.md` in this workspace.

Include a "suggested skills" section in the document, naming which skills the next agent should read.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the handoff document accordingly.

Some handoffs have a fixed form, and the form decides the document rather than the general summary this skill otherwise asks for:

- **A prompt describing a work item workshopped in this conversation.** Write the prompt verbatim to `.agents/drafts/<name>.md` with `**Status:** draft`. If it is to be released, follow the release rule in `instruction-authoring`.
- **An error report.** Write it to `.agents/drafts/` with `**Status:** draft`, as a runnable brief for the session that fixes it, carrying what makes it actionable: the error, the steps that reproduce it, the evidence of the encounter, and the consequence suffered.
- **A skill.** A skill is not handed off here: one to be created or workshopped is settled by the `instruction-authoring` convention, which names its type and its root.

Name each file you write in the handoff document.
