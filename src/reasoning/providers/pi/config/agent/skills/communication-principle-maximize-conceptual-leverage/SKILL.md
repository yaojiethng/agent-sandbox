---
name: communication-principle-maximize-conceptual-leverage
description: "Apply when writing prose in a technical domain, a document, a prompt or a skill. Choose the word that carries the most distinction for the least reader effort, subject to one constraint, no distinction may be lost."
metadata:
  claim: reader
  leitwort: leverage
---

# Maximize conceptual leverage

Choose the word that carries the most distinction for the least reader effort, and lose none to shorten it.

**The pattern.** Compare the chosen word against the words a reader would need without it. The shorter form stays when it carries the same distinctions. The longer form replaces it when it carries one the shorter form drops, and the domain's own term replaces it when that term is the distinction.

| Instead of | Give |
|---|---|
| a plainer word that drops the distinction the domain reader needs | the domain term, defined once at first use |
| a condition struck so the sentence reads smoother | the claim with its condition intact |
| jargon the writer has not finished compressing | the reader's word for the same thing |
| an ornate verb where a common verb says the same | the common verb |
| a metaphor standing in for a mechanism | the mechanism |
| an unmarked hedge ("somewhat", "fairly", "arguably") | the claim, marked as an inference where that is what it is |
| a paragraph of analysis | the decision it supports |

**Why.** The domain model is exact, and the delivery is shorter than the model. A word dropped from the delivery takes a distinction with it, and the reader cannot see the loss, because the sentence still reads correctly. A model left at full resolution costs the reader work, and the reader notices, because the point is not on the page. The first loss cannot be repaired and the second can.

**The leading word.** A principle's leading word is this judgement applied to the principle itself. It is the one word that holds most of what the principle says, drawn from the domain the principle works in, and the corpus records it as `metadata: leitwort:`, a keyword tag beside the claim rather than a controlled vocabulary. `principle-skill-signposting` at `$AGENT_HOME/agent/skills/principle-skill-signposting/SKILL.md` decides where the word is placed and tested. Choosing it is this skill's question, and placing it is that one's.

**The test.** Two readers, because each catches a failure the other accepts. The domain reader checks that nothing false was added. A reader outside the domain checks that nothing they needed was removed.

New and changed prose in this corpus meets ASD-STE100, and this skill states the rules that meet it. A phrase dictionary is a source for wording, and these rules live here.

A term the reader may not hold is defined at first use, per `principle-define-terminology-before-use` at `$AGENT_HOME/agent/skills/principle-define-terminology-before-use/SKILL.md`.
