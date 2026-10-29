# The instruction-surface problem

**Owner:** operator. The agent reads this file and does not write it.

**Lifecycle:** written once, not amended, deleted when the framing stops holding. It states the problem the instruction surface is reduced for, and what follows from it. It states no plan: the roadmap holds the work, and this file carries no task.

## The regime

The agent usually does what it was asked. Instructions are specified well enough to follow, a wrong one is noticed and repaired, and a rule that gets followed faithfully is doing its job.

The cost is not wrongness. It is that the corpus is expensive to be right by: text that has to be interpreted before it can be acted on, and volume that grows because a repair is added rather than applied.

## Two mechanisms

**A repair lands as an addition.** A rule that failed gains a qualifier beside it, or a new rule beside that, and both stay. No single addition is large, and the total rises with every repair.

**An instruction is guessable but not self-evident.** The agent reads it, works out what it could mean, and starts late. The working-out is paid twice: once as time before the first move, and again as context, because the reasoning stays in the transcript and travels with the session. The guess is usually right, so nothing fails loudly and nothing gets repaired.

## How the cost propagates

Unsupervised write-back is where text enters the corpus: a handover, a roadmap row, a design record, an instruction. Nobody is answering while it is written, so its register is the agent's rather than the operator's. Compaction then drops the conversation that held the phrasing the two of them settled, and the agent's own write-back becomes the example it writes from. A fresh agent loads that corpus, and it reaches the operator's register only after being corrected in chat.

Slop is a symptom of this, not the mechanism. It reads badly, and it makes the corpus grow faster than the thinking in it.

## What follows

- A repair replaces the text it corrects. Prose added beside an unclear rule leaves the rule unclear and the corpus longer.
- An instruction that a reader has to interpret states its own domain: what fires it, what it may touch, and what its nearest neighbour owns.
- A rewording pass is not the remedy. It cleans text that is already too long, and it loses the specificity that made the text worth keeping.
- The phrasing the operator and the agent settled on is carried forward as written. A paraphrase is a second draft of a decision already taken.

## What this does not settle

The measure, its threshold, the order the remedies land in, and what the instruments cost. Those belong to the roadmap.

## The operator's words

Selected and elided. Wording is unchanged; capitals and dashes are normalized to the repository's ASCII rule.

> If the instructions are given, and we have a lengthy back-and-forth for alignment, the agent usually follows instructions faithfully. The failure mode appears when the agent is undersupervised for work, such as when writing text meant to be read by the next agent [...] on chat compaction, the agent loses the operator written context; it falls back to the sloppy write-back.

> Sometimes, fixes apply as additions to the instruction rather than replacement [...] Sometimes, instructions are confusing to the agent - and it spends reasoning tokens guessing what the instruction could mean, with a delay between the invocation of the instruction and when it starts doing it [...] it usually ends up guessing correctly, because wrong instructions get fixed. We are in a limbo of not-wrong but expensively-right.

> The operator's own text is also not always perfect. The operator frequently invites the agent to propose edits, and they collaborate on the tone of the text until it is correct. That is what is meant to be kept.
