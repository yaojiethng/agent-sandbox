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

`disable-model-invocation: true` removes the skill from the model's prompt, so the model can neither discover nor fire it and only the operator invokes it by name. Set it on a skill the operator fires deliberately. A principle skill does not set it, because a writer reaches for a judgement mid-draft and must find it.

The value is a boolean and the document gate holds it. A hidden skill's description is read from the operator's list, so write that one for the operator, while a model-invoked description is written for the model's discovery.

A principle's frontmatter is held by `scripts/check_principle_frontmatter.sh`: `name`, `description`, `metadata.neighbours`, `metadata.intent` and `metadata.mechanism` are required, `metadata.leitwort` is validated when present, and a principle does not set `disable-model-invocation`.

A principle skill also declares `metadata: neighbours:`, a list of the full skill names of the principles whose judgements it touches. `[]` states that no neighbour is declared; a principle the corpus survey finds with no neighbour is recorded on the survey map. An absent field is undeclared, which the gate fails. The list holds neighbours only, and a handoff ("apply this next") is prose. [`../patterns/admission.md`](../patterns/admission.md) decides the list; `scripts/check_principle_frontmatter.sh` holds presence and liveness.

A principle also declares `metadata: intent:` and `metadata: mechanism:`. Both are operator-led: they record the judgement the operator made when the skill was created or ratified, and the agent reads them rather than inferring them. `intent` states the judgement the skill serves. `mechanism` states the way that judgement expresses itself, or the specific way the principle exerts influence on the workflow. The admission record that holds the case is the provenance. Every principle carries both fields; the survey map's provisional value is not the field.

## The body

No fixed section order is mandated. `writing-for-agents` gives the two content types, steps and reference, and the split a document earns.

A skill is a `SKILL.md` and the siblings it names, and a sibling the `SKILL.md` does not name is a file nothing loads. [`../patterns/nested-patterns.md`](../patterns/nested-patterns.md) states what stays inline, what earns a file, and the index rule.

## A principle skill

A principle skill carries a judgement, and its body follows the convention: a sentence-case title, one sentence stating the judgement, a rule part the card names, `**Why.**`, any named parts, and `**The test.**`, in that order. The rule part is the first bold lead-in, and a boundary part may follow the test.

`docs/adr/principle_skill_shape.md` records the shape. The body is a convention, held by this section and the exemplar; `scripts/check_principle_frontmatter.sh` holds the frontmatter, not the body. The artifact and the norm are separate axes: [`docs/reference/terminology.md`](../../../../docs/reference/terminology.md#principle-skill) defines the principle skill, and the same registry's `modality` entry defines the judgement it carries.

The exemplar is `communication-principle-show-dont-describe`. Selection reads the description alone, so a description names a situation the agent is in rather than a property of finished text, because a property can be read only once the text exists. A principle claims no moment: it is in force whenever the work is in front of the reader, and a part naming where it applies says what to look at.

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

[`../runbooks/review.md`](../runbooks/review.md) reads a skill against the rule-loss and length bars. A set of skills that has grown by accretion goes to `prose-review`'s `instruction-cleanup` runbook instead.
