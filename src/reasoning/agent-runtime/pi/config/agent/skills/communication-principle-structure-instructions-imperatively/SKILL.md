---
name: communication-principle-structure-instructions-imperatively
description: "Apply when writing or revising a procedure, a step or a runbook: a sentence that tells the reader to act carries its verb in the imperative form, and a sentence that explains takes the declarative."
metadata:
  intent: "The reader does the step at once, because the verb tells them what to do."
  mechanism: "The clause type, chosen by what the sentence does: the imperative form where it tells the reader to act, the declarative where it gives information."
  leitwort: instruction
  neighbours:
    - communication-principle-attach-as-you-read
    - communication-principle-state-intent-delegate-method
---

# Structure instructions imperatively

Write the verb of an instruction in the imperative form, and write a sentence that explains in the declarative.

**The rule.** ASD-STE100 Issue 9, Part 1 Rule 5.3: "Write instructions in the imperative (command) form." The statement is the unit, so a step of two sentences opens on a verb and continues in the declarative.

| Instead of | Give |
|---|---|
| The test can be continued. | Continue the test. |
| Oil and grease are to be removed with a degreasing agent. | Remove oil and grease with a degreasing agent. |
| The component must be installed. | Install the component. |

**One instruction in each sentence.** ASD-STE100 Issue 9, Part 1 Rule 5.2: "Write only one instruction in each sentence unless two or more actions occur at the same time."

**Why.** The imperative form gives the reader a clear instruction, and another sentence structure causes ambiguity: "Thus, the reader will not know" whether it is important to do a work step, whether a different person did the work step, or whether a different person must do the work step in the future. One verb form answers all three, so the reader does the step.

**Where the mode decides.** Procedural writing takes the imperative, and descriptive writing takes the declarative: "Descriptive writing gives information, not instructions. Thus, the imperative form of the verb is not permitted." A note inside a procedure takes the declarative: "Write notes only to give information, not instructions" (Rule 5.5). Google puts the same rule on the first sentence of a step: "Make sure that the first sentence in a procedural step includes an imperative verb", against a step that states a need before the act, "You need the project ID later in this document. Retrieve the project ID."

**The test.** Name what the statement does. Where it tells the reader to act, the first word is the bare verb, as in "Clone the repository that contains the sample data." Where it explains, the sentence opens on its subject. A step written as a state fails, because the reader cannot tell whether to do it.

**Where another rule wins.** A condition the reader must know first opens the sentence as a descriptive statement, and the command follows the comma: "When the light comes on, set the switch to NORMAL" (Rule 5.4). Give the step its bare imperative, and keep `must` for a safety instruction or an important condition, "unless the instruction is very important for safety ... or when you give an important condition" (Rule 5.3). Which voice carries the clause is [`communication-principle-attach-as-you-read`](../communication-principle-attach-as-you-read/SKILL.md)'s.

**What it does not cover.** Whether a brief states the method where it owes the intent: [`communication-principle-state-intent-delegate-method`](../communication-principle-state-intent-delegate-method/SKILL.md). A sentence about the text rather than about its subject: [`communication-principle-cut-metadiscourse`](../communication-principle-cut-metadiscourse/SKILL.md).

**Where it comes from.** ASD-STE100 Issue 9, Part 1 Rules 3.6, 5.3, 5.4 and 5.5 and Section 6, from the free copy ASD publishes, and the Google developer documentation style guide's Procedures page. What each source carries and what this repository drops is recorded in `.agents/registry/citations/asd-ste100.json` and `.agents/registry/citations/google-developer-style.json`.
