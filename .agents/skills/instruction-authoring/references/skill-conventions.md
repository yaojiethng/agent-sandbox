# A skill's conventions

A skill is a directory a reader opens by name. Where it lives decides who loads it, and its body is a `SKILL.md` plus the siblings it names.

## Where a skill lives

| Root | Who gets it | Source |
|---|---|---|
| provider | every session, seeded from the image | `src/reasoning/agent-runtime/pi/config/agent/skills/<name>/` |
| module | every session that enables the module | `workflow/<module>/skills/<name>/` |
| project | this repository only | `.agents/skills/<name>/` |

Do not write in `$AGENT_HOME/agent/skills/` directly. The config home is seeded from the image at every start, so a file written there is lost on the next start, and no gate reads it while it lives.

## Frontmatter

`name` and `description` are the signpost: the only words a reader holds before the body loads. [`../patterns/signposting.md`](../patterns/signposting.md) states how to choose them, and `communication-principle-maximize-conceptual-leverage` supplies the leading word, recorded as `metadata: leitwort:`.

`disable-model-invocation: true` removes the skill from the model's prompt, so the model can neither discover nor fire it and only the operator invokes it by name. Set it on a skill the operator fires deliberately.

The value is a boolean and the document gate holds it. A hidden skill's description is read from the operator's list, so write that one for the operator, while a model-invoked description is written for the model's discovery.

A principle skill is a skill first. Its frontmatter, its body and the questions that file it are [`principle-skills.md`](principle-skills.md); nothing about a principle skill belongs in this file besides that sentence.

## The body

No fixed section order is mandated. `writing-for-agents` gives the two content types, steps and reference, and the split a document earns.

A skill is a `SKILL.md` and the siblings it names, and a sibling the `SKILL.md` does not name is a file nothing loads. [`../patterns/nested-patterns.md`](../patterns/nested-patterns.md) states what stays inline, what earns a file, and the index rule.

## Where its references resolve

A skill runs from its own root, so a link is relative to the directory the skill is delivered in: `.agents/skills/<name>/` for a project skill, `$AGENT_HOME/agent/skills/<name>/` for a provider skill. A reference to a sibling skill takes this form, relative to the skill's own directory:

```text
[`<skill-name>`](../<skill-name>/SKILL.md)
```

It resolves in the repository and in the installed tree. The `linking` convention states the test.

## The review

[`../runbooks/review.md`](../runbooks/review.md) reads a skill against the rule-loss and length bars. A set of skills that has grown by accretion goes to `prose-review`'s `instruction-cleanup` runbook instead.
