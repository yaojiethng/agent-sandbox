---
description: "An abstract-goal statement of the instruction cleanup task: the problem, the goal, the method in one line, and the non-negotiables, with no prescribed format. Use to compare a goal-only prompt against the detailed runbook."
argument-hint: "[the instruction surface to clean, or nothing to work from the goal alone]"
---

> $ARGUMENTS

# Instruction Cleanup - The Goal

**The problem.** The review instructions in this repository were written by accretion. Each iteration added a prompt, an audit, a skill or a policy clause, and nothing retired what it superseded. The same rule now lives in several files, in different words, sometimes with opposite requirements, and some of those rules make a reviewer behave worse than no rule would. Because the files are grouped by history rather than by purpose, no reader can tell which file owns which rule.

**The goal.** One operator-directed pass that walks a single instruction surface, decides by human judgement which rules harm, duplicate, contradict or cannot be acted on, and lands the surface as a small set of base skills -- `prose-review` and `code-review` -- each holding one runbook per use case, with the rules every runbook must agree on in one shared body. The pass is the instrument for the whole corpus, not a one-off: it will run again over every other instruction surface, so what it leaves has to be reusable.

**The method.** Inventory every unit of logic with its site and where it came from; group the units by use case; form a judgement on each candidate fault; put candidates to the operator one at a time; apply what the operator accepts one file at a time, deleting each file it absorbs.

**Non-negotiable.** The agent proposes and the operator decides. No rule is removed that the operator has not seen. The operator's wording is authoritative, so the agent may restructure it and may not re-word what it requires. The pass measures nothing, dispatches nothing and evaluates nothing, because a corpus nobody has deconflicted cannot attribute a finding to a file.

**Done looks like** a surface that can be run, improved and trusted -- no contradictions, no rule stated twice, nothing actively harmful -- plus a procedure reusable over the next surface. Not perfect, not measured, not final.
