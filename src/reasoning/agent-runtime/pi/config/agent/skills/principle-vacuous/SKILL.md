---
name: principle-vacuous
description: "Apply when a statement asserts something no observation could settle: a predicate with no check, a premise that cannot be tested, or a claim that holds or fails whatever the case. Name the check the statement carries, and cut the statement that has none."
metadata:
  intent: "Every statement earns its place by carrying a check, since prose that cannot be checked spends the reader's time and returns nothing."
  mechanism: "Name the observation that settles the statement's predicate: one that separates its cases keeps the sentence, and its absence cuts the sentence."
  leitwort: vacuous
  neighbours:
    - communication-principle-provide-evidence
    - communication-principle-dont-forecast-undone-work
---

# Name the check a statement carries

A statement is vacuous when no observation separates its holding from its not holding, so its predicate carries a check or the sentence goes.

**The pattern.** Take the statement's predicate and name the observation that settles it.

| Vacuous | Informative twin |
|---|---|
| This step is not optional and not a formality. | Run this step every time; skipping it fails the handover gate. |
| Document repository suitability is a remaining unknown. | The document repository has not been tested above 500 files; that test is W1. |
| The system handles errors gracefully. | A failed fetch retries three times, then reports the status code. |

**Why.** A vacuous statement reads as content and carries none, so the reader spends attention on a claim nothing can act on, and the line survives review because it looks like its neighbours. The cost lands twice, once to read it and once to find that nothing followed.

**The faces.** Four shapes, one test, and the fix depends on which way the check fails.

| Face | Fails because | The fix |
|---|---|---|
| a predicate with no check | no observation settles the word | name the criterion |
| a premise that cannot be tested | the evidence is unavailable to anyone | state it as an assumption |
| a tautology | every case satisfies it | cut it, or name the case that differs |
| a contradiction | no case satisfies it | pick the clause that holds |

**The test.** Name the predicate, then the observation that would settle it. An observation that separates its cases keeps the statement. None at all, and the statement is cut, or it becomes the assumption it is. Every case, and the claim is a tautology. No case, and two clauses disagree. A definition settles what a word means, not whether a claim holds, so a reason that restates it supports nothing. A report of the writer's own reasoning is checkable when it names its evidence, and an assumption when it does not.

**Where the vacuous form earns its place.** "It is what it is" concedes and ends the exchange, "either we ship or we do not" closes a debate, and "nothing else changes" bounds a wider reading by naming a guard. Each does something the reader can act on, which is what the test asks for.

**Where it comes from.** Operationalism, P. W. Bridgman's rule that a concept is a set of operations, and falsifiability, Karl Popper's criterion that a claim carries content only where an observation could refute it. Both are cited here unverified at source.

**What it does not cover.** One word carrying two meanings, where a contradiction is only apparent: [`communication-principle-define-terminology-before-use`](../communication-principle-define-terminology-before-use/SKILL.md). The same proposition carried twice: [`principle-single-source-of-truth`](../principle-single-source-of-truth/SKILL.md). A literal the reader must fill in: [`communication-principle-name-the-value-not-a-literal`](../communication-principle-name-the-value-not-a-literal/SKILL.md).
