---
name: principle-match-precision-to-stakes
description: Set an instruction's precision by what you can establish about it, from the assumption it rests on to how far a wrong move reaches, whether the move can be undone, and whether anything reports it. Use when writing a procedure, a prompt, or a skill, and when deciding between an exact command and a range of approaches.
disable-model-invocation: true
---

# Match precision to stakes

An instruction's precision follows what the writer can establish, not what the consequence would cost.

## The pattern

Ask four questions, in this order.

1. What does the instruction assume about the conditions it runs in?
2. How far does a wrong move reach: this file, this command, the whole tree, something published?
3. Can it be undone?
4. Will anything report it?

State the assumption, and name each gap.

Answer the last three from the operation, not from its consequences. Overwriting, deleting, publishing and sending are one way. A diff, a gate, a test, or a reader who did not do the work reports. Where the reporter would be the writer's own memory, nothing reports.

Where the move reaches wide, cannot be undone, or goes unreported, state the exact action and offer no alternative. Where it reaches narrow, can be undone and is reported, state the range and a default, and name the alternative for the exception.

| Tight guidance, because a wrong move is silent | Open guidance, because a different choice shows |
|---|---|
| `iter.md` states "use `make test`" and forbids the `tests/knowledge/` tests, since a wrong command returns a green nothing checks | `grill-me` asks for a recommended answer per question, since a different phrasing is read and corrected next turn |
| The regeneration rule for `norm-ownership.tsv` states the exact command, since a hand edit is overwritten with no report | `principle-say-what-done-looks-like` lists a step, a procedure, a task and an assignment, since the reader picks the one that applies |

## Assumptions and gaps

An assumption is a condition the instruction relies on, and you state it. A gap is a fact you could not establish: you name it, and it makes the move one way.

If you cannot tell whether the move is reversible, that is a gap, so treat the move as one way.

A gap you do not name cannot be checked, so a wrong result it hides arrives as a surprise. An assumption is the sentence a breach contradicts instead.

## What it does not cover

What the instruction is about, how much room it costs, or how bad the consequence would be. The last cannot be known before the move.

## Why

An agent cannot measure the cost of an error before making it, so a rule that needs that measurement cannot be followed. Assumptions, gaps, reach, reversibility and reporting are establishable while writing.

## The test

Name the assumption, the gaps, the undo path and the reporter. Name one thing you did not verify, and say why the instruction stands without it.
