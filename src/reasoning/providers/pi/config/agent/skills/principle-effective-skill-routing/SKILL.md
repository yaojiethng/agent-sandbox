---
name: principle-effective-skill-routing
description: Spend a skill's name and description on words an agent matches and an operator recalls, so they route the skill to the situations that need it, and name what the skill does and when it applies rather than how it is built. Use when writing or reviewing a skill's name, its description, its frontmatter, or the list entry an operator searches.
disable-model-invocation: true
metadata:
  claim: reader
---

# Spend the name and the description on routing

A skill is advertised by its name and its description, and its body is loaded only after a reader decides. Those two fields are therefore the only thing that routes the skill.

**The pattern.** Spend the description on words an agent can match: the work the skill does, named by its object, and the situations that call for it.

Make the name the shortest true summary of that description. A name that summarises it lets an operator recall the skill when a situation needs it, and lets a reader who meets the name in another document know what it points at.

A phrase that names how the skill is built spends space with no keyword in it. Two phrases for one situation spend the space twice.

**Why.** Pi puts the name, the description and the path in the agent's context and holds the body back until the agent asks for it, so a word in neither field cannot cause the skill to load. A word repeated across the two fields spends the space without adding a situation. The name is also the only part of a skill another document can cite, which makes it the skill's public handle.

**The name.** The name is read by three readers: the agent, which sees it advertised beside the description; the operator, who recalls it when the work calls for it; and another document, which cites it.

A name another skill already holds does not load: the first skill discovered keeps it. A name that understates the skill is not recalled, and one that overstates it is recalled for the wrong situation.

A rename reaches every document that cites the name, so a rename is a change with a carrier list.

**What it does not cover.** What the skill does once it is loaded, and how its body is written. The frontmatter is not the documentation.

For a skill only the operator invokes, the description is read from the operator's list, so its words are the words that operator searches with.

**The test.** Read the name alone. Does it say what the description says, in fewer words, and would an operator recall it from the situation that needs it? Then underline every word in the description that an agent would match. A sentence with nothing underlined is cut or rewritten. Two underlined words that select the same situation become one. A name another skill holds is changed.
