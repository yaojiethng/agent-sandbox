---
name: communication-principle-state-intent-delegate-method
description: "Apply subsidiarity to an instruction: state the intent and delegate the method to the party closest to the work. Use when writing a prompt, a brief or a dispatch that asks an agent to do work, and when a draft has grown into a procedure."
metadata:
  claim: authority
  leitwort: subsidiarity
---

# State the intent; delegate the method

An instruction states what the work must achieve, and the route through it belongs to the party who holds the context.

**The pattern.**

| Micro-management | The intent |
|---|---|
| detailing the exact loop structures and variable initializations | defining the optimization invariants and the input-output bounds |
| scripting the precise class hierarchies the agent must generate | stating the architectural defect the module must prevent or resolve |
| instructing the agent on what functions to call and in what order | stating the behaviour the finished system must show |

**Why.** The decision belongs to whoever holds the context, and the doer holds it: the files, the tooling, the failure the last attempt hit. The writer holds the want. A method written in advance predicts that context, so it is wrong exactly where the work is hard. Subsidiarity names the rule: a higher party decides only what the lower cannot. The method is that decision, so the instruction leaves it out, and that is where the doer's autonomy lives.

**When the method is the outcome.** An order that must be followed exactly is the outcome, not a method: a migration sequence, a publish step, a command the operator runs. Ask for the procedure as the deliverable, with the constraints it must meet, so the doer designs it before running it. Subsidiarity is not abstention: a decision the doer cannot take stays with the writer.

**The brief's other half.** The bound and the acceptance criteria belong to [`principle-say-what-done-looks-like`](../principle-say-what-done-looks-like/SKILL.md); subsidiarity governs only the route. An instruction that leaves the method open and never says what done looks like has delegated nothing.

**The test.** Ask which decisions the draft leaves to the doer. If the answer is none, the draft has taken a decision subsidiarity leaves with the doer, and the doer's only remaining job is to comply.
