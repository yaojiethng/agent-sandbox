---
name: principle-effective-skill-routing
description: Spend a skill's description on words an agent matches, so the description routes the skill to the situations that need it, and name what the skill does and when it applies rather than how it is built. Use when writing or reviewing a skill description, a skill's frontmatter, or the list entry an operator searches.
disable-model-invocation: true
---

# Spend the description on routing

A skill is advertised by its name and its description, and its body is loaded only after a reader decides. The description's words are therefore the only thing that routes the skill.

## The pattern

Spend the description on words an agent can match: the work the skill does, named by its object, and the situations that call for it.

A phrase that names how the skill is built spends space with no keyword in it. Two phrases for one situation spend the space twice.

## What it does not cover

What the skill does once it is loaded, and how its body is written. The description is not the documentation.

For a skill only the operator invokes, the description is read from the operator's list, so its words are the words that operator searches with.

## Why

The model sees the name and the description, and nothing else, before it decides to load the skill. A word outside the description cannot cause the skill to load, and a word repeated spends the space without adding a situation.

## The test

Underline every word in the description that an agent would match when deciding whether to load the skill. A sentence with nothing underlined is cut or rewritten. Two underlined words that select the same situation become one.
