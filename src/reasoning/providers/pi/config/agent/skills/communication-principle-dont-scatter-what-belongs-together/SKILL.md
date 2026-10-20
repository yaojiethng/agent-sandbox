---
name: communication-principle-dont-scatter-what-belongs-together
description: "A definition, its rules, and its caveats sit together, so a reader who needs one meets the others. Apply when writing or moving a caveat or a definition, or when a caveat sits away from the rule it qualifies."
---

# Don't scatter what belongs together

Keep a definition, its rules, and its caveats in one place, with each caveat beside the rule it qualifies.

## The pattern

| Instead of | Give |
|---|---|
| a caveat three sections from the rule it qualifies | the caveat under that rule |
| a definition wherever the term first appears | the definition with its rules and caveats, where the reader first needs it |
| a caveat recorded only in a second document | the caveat beside the rule it qualifies |
| parts ordered as the author wrote them | parts ordered as the reader needs them: definition, rule, caveat |

## Why

A reader who meets a rule without its caveat applies the rule too widely. The reader then meets the caveat, and no longer holds the rule.

Nothing reports the split. Each half reads as complete.

## Where another rule wins

A second copy is a different defect: the norm then has two homes. `principle-one-home-per-rule` owns that defect, at `$AGENT_HOME/agent/skills/principle-one-home-per-rule/SKILL.md`, and the copy points at the home.

This rule covers the other case: one home, with parts the reader does not reach.

## The test

Read the document in the order it is written. At each caveat, ask whether the reader still holds the rule it qualifies. A caveat that reaches back further than one section means the parts are apart.
