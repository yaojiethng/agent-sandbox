---
name: communication-principle-name-the-value-not-a-literal
description: "Apply when a snippet, command, or instruction carries a value the reader must set. Name the value; do not fix a literal that reads as the chosen one."
metadata:
  claim: scope
---

# Name the value, not a literal

A literal in a snippet reads as the sanctioned value, so the reader stops choosing one.

**The pattern.** Replace the fixed number with the field the reader fills.

| Instead of | Give |
|---|---|
| `timeout 1800` | `run_timeout=<seconds>` |
| a count the reader should own, typed into a command | the field the reader sets |
| a fixed path or model id in an example the reader adapts | the variable, with what to set it to |
| a literal the reader must change but cannot see they must | the unbound variable, named in the surrounding sentence |

**Why.** A literal is a decision the writer made. The reader takes it as the answer and runs it, so the guidance does not change behaviour against the default. An unbound variable moves the decision back to the reader, who then reaches for the right value at the point of use.

**The test.** Does this snippet carry a value the reader must choose? If yes, does it read as a fixed choice or as a field to fill? Name the field.
