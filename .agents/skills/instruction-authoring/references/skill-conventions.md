# A skill's conventions

A skill is a directory a reader opens by name. Where it lives decides who loads it, and its body is a `SKILL.md` plus the siblings it names.

## Where a skill lives

| Root | Who gets it | Source |
|---|---|---|
| provider | every session, seeded from the image | `src/reasoning/providers/pi/config/agent/skills/<name>/` |
| module | every session that enables the module | `workflow/<module>/skills/<name>/` |
| project | this repository only | `.agents/skills/<name>/` |

Do not write in `$AGENT_HOME/agent/skills/` directly. The config home is seeded from the image at every start, so a file written there is lost on the next start, and no gate reads it while it lives.

## Frontmatter

`name` and `description` are the signpost: the only words a reader holds before the body loads. [`../patterns/signposting.md`](../patterns/signposting.md) states how to choose them, and `communication-principle-maximize-conceptual-leverage` supplies the leading word, recorded as `metadata: leitwort:`.

`disable-model-invocation: true` removes the skill from the model's prompt, so the model can neither discover nor fire it and only the operator invokes it by name. Set it on a skill the operator fires deliberately. A judgement skill does not set it, because a writer reaches for a judgement mid-draft and must find it.

The value is a boolean and the frontmatter gate holds it. A hidden skill's description is read from the operator's list, so write that one for the operator, while a model-invoked description is written for the model's discovery.

## The body

No fixed section order is mandated. `writing-for-agents` gives the two content types, steps and reference, and the split a document earns.

A skill is a `SKILL.md` and the siblings it names, and a sibling the `SKILL.md` does not name is a file nothing loads. [`../patterns/nested-patterns.md`](../patterns/nested-patterns.md) states what stays inline, what earns a file, and the index rule.

## A judgement skill

A skill whose directory name carries `principle-` is a judgement, and its body is fixed: a sentence-case title, one sentence stating the judgement, `**The pattern.**`, `**Why.**`, zero or more named parts, and `**The test.**`, in that order.

`docs/adr/principle_skill_shape.md` records the decision and `scripts/check_document_shape.sh` holds it, so no copy of the shape is stated here.

Every principle answers one of five questions, and the question decides where a new one files:

| Question | What the principle asks |
|---|---|
| Can this sentence be checked? | does the claim carry the artifact that proves it |
| Is this the source or a copy? | does the rule live where its producer is |
| Does this name resolve where it is read? | can the reader find the thing the text names |
| Can the reader build the model the text assumes? | does the text supply the model before asking for it |
| Who owns this decision? | does the text take only the decisions its author holds |

The membership of each question is not maintained here. A principle's description is its routing surface, so a list of the corpus would be a copy that goes stale.

## Where its references resolve

A skill runs from its own root, so a link is relative to the directory the skill is delivered in: `.agents/skills/<name>/` for a project skill, `$AGENT_HOME/agent/skills/<name>/` for a provider skill. The `linking` convention states the test.

## The review

[`../runbook/review.md`](../runbook/review.md) reads a skill against the rule-loss and length bars. A set of skills that has grown by accretion goes to `prose-review`'s `instruction-cleanup` runbook instead.
