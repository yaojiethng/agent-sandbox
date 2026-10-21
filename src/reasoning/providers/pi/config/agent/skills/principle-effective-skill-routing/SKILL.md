---
name: principle-effective-skill-routing
description: Put a skill's name and description to work as a signpost, so an agent matches the situation that needs the skill and an operator recalls it. Carry one leading word, drawn from the skill's domain, through the name, the description and the body. Use when writing or reviewing a skill's name, its description, its leading word, or the list entry an operator searches.
disable-model-invocation: true
metadata:
  claim: reader
---

# Make the name and the description a signpost

A skill reaches a reader through its name and its description, and its body arrives only after that reader decides to load it.

**The pattern.** Spend the description on words an agent can match, the work the skill does named by its object and the situations that call for it.

Make the name the shortest true summary of that description. A name that summarises it lets an operator recall the skill when a situation needs it, and lets a reader who meets the name in another document know what it points at.

A phrase that names how the skill is built spends space with no keyword in it. Two phrases for one situation spend the space twice.

**Why.** Pi puts the name, the description and the path in the agent's context and holds the body back until the agent asks for it, so a word in neither field cannot cause the skill to load. The name is also the only part of a skill another document can cite, which makes it the skill's public handle.

**The name.** The name is read by three readers: the agent, which sees it advertised beside the description; the operator, who recalls it when the work calls for it; and another document, which cites it.

Make the name state the judgement or the defect it prevents. Keep it to five words or fewer, and use the word the domain already holds. A property name states a quality and leaves the writer to invent the act. `locality` names a quality, and `keep a subject local` names the act.

A name another skill already holds does not load, because the first skill discovered keeps it. A name that understates the skill is not recalled, and one that overstates it is recalled for the wrong situation.

A rename reaches every document that cites the name, so a rename is a change with a carrier list.

**The signpost.** A skill's name and description are its signpost. They are the only words an agent holds before it loads the body, so they decide whether the body is loaded at all.

Put one leading word on the signpost, and repeat it through the name, the description and the body. The word steers. An agent that repeats it has taken the direction the skill gives. `deep modules`, `test seams` and `tracer bullets` each carry a whole judgement in two or three tokens.

Draw the word from the domain the skill works in, because the domain supplies its carrying power. A skill about code takes a word from programming or domain modelling. A skill about prose takes one from rhetoric or linguistics, where `signposting` names the cues that direct a reader.

Point the signpost at the situation, and name the situation in the words a reader would use for it. Do not advertise how the skill is built, because that sends the reader past the sign.

Carry the domain's precision, and deliver it in words the reader already holds. `principle-define-terminology-before-use` owns defining a term the reader may not hold. No gate checks whether a word leads, because no gate sees a thinking trace, so a reviewer judges it.

**Linguistic fidelity.** Two errors degrade a skill equally, and each has its own repair.

- **Invented jargon.** A technical word the domain does not hold hides the concept. Replace it with the exact domain term.
- **Vague generalities.** A generic word where the domain holds a precise one dilutes the concept. Replace it with the precise domain term.

**The domain exception.** When a skill works within a well-specified domain, the domain's native vocabulary is the precise language. No arbitrary list of banned words overrides the established terms of the field.

**What it does not cover.** What the skill does once it is loaded, and how its body is written. The frontmatter is not the documentation. The signpost is the one exception, because it sets the word the body keeps.

For a skill only the operator invokes, the description is read from the operator's list, so its words are the words that operator searches with.

**The test.** Read the name alone. Does it say what the description says, in fewer words, and would an operator recall it from the situation that needs it? Then underline every word in the description that an agent would match. A sentence with nothing underlined is cut or rewritten. Two underlined words that select the same situation become one. A name another skill holds is changed.

Then find the leading word three times, in the description, at the rule in the body, and on the rows of the pattern table. A word missing from one of the three is used once.
