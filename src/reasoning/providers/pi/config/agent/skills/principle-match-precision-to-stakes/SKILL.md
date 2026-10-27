---
name: principle-match-precision-to-stakes
description: Apply when an instruction could be followed wrongly without anything reporting it. Set its precision by the assumption it rests on, how far a wrong move reaches, whether the move can be undone, and what reports it.
metadata:
  claim: authority
---

# Match precision to stakes

An instruction's precision follows what the writer can establish, not what the consequence would cost.

**The pattern.** Ask four questions, in this order.

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

**Why.** An agent cannot measure the cost of an error before making it, so a rule that needs that measurement cannot be followed. Assumptions, gaps, reach, reversibility and reporting are establishable while writing.

**Fires on.** An instruction whose wrong reading is silent, wide-reaching, or unreversible.

**Assumptions and gaps.** An assumption is a condition the instruction relies on, and you state it. A gap is a fact you could not establish: you name it, and it makes the move one way.

If you cannot tell whether the move is reversible, that is a gap, so treat the move as one way.

A gap you do not name cannot be checked, so a wrong result it hides arrives as a surprise. An assumption is the sentence a breach contradicts instead.

**What it does not cover.** What the instruction is about, how much room it costs, or how bad the consequence would be. The last cannot be known before the move. Its scope: `principle-own-the-scope-you-declare`. Where one document stops: `communication-principle-hand-off-by-naming-the-boundary`.

**The test.** Name the assumption, the gaps, the undo path and the reporter. Name one thing you did not verify, and say why the instruction stands without it.
