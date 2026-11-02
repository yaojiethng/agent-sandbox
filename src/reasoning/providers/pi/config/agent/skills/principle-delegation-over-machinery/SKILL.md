---
name: principle-delegation-over-machinery
description: "The judgement when a task reaches for new machinery beside a party that already answers the question: a pin, a filter, a schema, a second record of someone else's guarantee. Use when a change adds a mechanism whose job another party already does."
metadata:
  leitwort: delegation
---

# Hand the question to the party that already owns it

A job a party already owns does not need a second answer, and the machinery built beside it is a copy of that party's guarantee, which drifts from the original with nothing reporting the difference.

**The pattern.** Name the party that already answers the question, hand the question to it, and keep only what it cannot give.

| What a task reaches for | Who already answers it |
|---|---|
| A pin, a lockfile or a version selector | the package manager |
| A filter over installed bytes, or a reordering of what a loader reads | the loader |
| A review, a veto or a preference written into code | the person who chose |
| A schema or a form gate over bytes the tree does not hold | nobody, which is why both sides of the test are empty |
| A restatement of a runbook step, a rule or a review | the runbook, the rule, the review |

**Why.** The second answer cannot stay equal to the first. The owner's guarantee moves when the owner moves and the copy does not, so the copy is wrong at the moment it matters and nothing detects it. The upkeep is not the cost; the divergence is.

**The tell.** A boundary that needs several rules only to stop two systems using the same words for different things is a boundary between two things that should not both exist. One rule is a contract. A page of them is a seam in the wrong place.

**Surfacing a decision instead of repeating it.** When the owner decides but does not say so, the work is to surface the owner's decision, not to reimplement it: a report that names both parties and the path each holds, changing no bytes.

**Extending inside the owner's layer.** When the owner's guarantee is weaker than the need, extend it where the owner lives, so one mechanism answers the question for everyone rather than two answering it differently.

**A record owed to a party outside the tree.** A licence notice that must travel with shipped bytes is written for a reader who will never see the tree. That record is not a copy of the owner's guarantee, and it stays.

**The neighbouring judgement.** A store of derived results asks whether keeping the result is worth its upkeep; this principle asks whether to build the thing that would produce it. The first is `principle-justify-materialization-cost` at `$AGENT_HOME/agent/skills/principle-justify-materialization-cost/SKILL.md`.

**The test.** For each file, schema, gate or step the change adds, name the guarantee it provides that the owning party does not, and the failure it catches that the party's mechanism would miss. If both are empty, delete it. If the machinery is for bytes the tree does not hold, both are empty by construction.
