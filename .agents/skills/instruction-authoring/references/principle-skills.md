# A principle skill

A principle skill carries a judgement about a text. Every other skill here carries a procedure, a mechanism's wrapper or a project convention, and this corpus is the one place a judgement lives, so a writer reaches for one mid-draft without being told to.

The corpus is the `principle-` skills under the repo-owned provider root, `src/reasoning/agent-runtime/pi/config/agent/skills/`. `$AGENT_HOME` may carry more, and those are not the corpus. [`terminology.md`](../../../../docs/reference/terminology.md#principle-skill) defines the artifact, and [`principle_skill_shape.md`](../../../../docs/adr/principle_skill_shape.md) is its design record.

## The frontmatter

`scripts/check_principle_frontmatter.sh` holds five of the six fields.

| Field | What it carries | The gate |
|---|---|---|
| `name` | the skill's name, `principle-` for a repo-owned judgement | required |
| `description` | a situation the agent is in, because selection reads this alone | required |
| `metadata.neighbours` | the principles whose judgements this one touches, by full skill name | required |
| `metadata.intent` | the judgement the skill serves, as the operator stated it | required |
| `metadata.mechanism` | how the judgement exerts influence, as the operator stated it | required |
| `metadata.leitwort` | the word the reader thinks with, when one earns it: a single word, or a phrase where no word carries the distinction | validated when present |

A principle never sets `disable-model-invocation`, because a writer reaches for a judgement mid-draft.

`neighbours` is a symmetric list of neighbours only, and a handoff ("apply this next") is prose. `[]` says no neighbour is declared, which is not the same as finding none. An absent field is undeclared and fails the gate. [`../runbooks/principle-change.md`](../runbooks/principle-change.md) decides the list.

The operator dictates a principle and the agent writes the file. The words, the domain and the scope come from the dialogue, and the reflow, the order and the checks are the agent's; [`../runbooks/principle-change.md`](../runbooks/principle-change.md) carries the five decisions the dialogue settles. The agent reads a dictated value rather than inferring it, because the judgement is obvious to the operator and re-derived wrong by the agent. The recorded decisions are the provenance, and the gate checks presence, never whether the value is right.

## The body

A sentence-case title, one sentence stating the judgement, a rule part that the first bold lead-in names, `**Why.**`, any named parts, and `**The test.**`, in that order. `**Why.**` answers why the reader, writer, agent or operator should care: the benefit the judgement brings, and the consequence of violating it. It is not why the principle was written this way. The rule part carries the general rule, whether it is a pattern, a test or a principle, and a boundary part may follow the test. No gate reads the body; the review and the exemplar carry it.

The exemplar is `communication-principle-show-dont-describe`. A description names a situation rather than a property of finished text, because a property can be read only once the text exists. A principle claims no moment: it is in force whenever the work is in front of the reader.

## The five questions

Every principle answers one of five, and the question decides where a new one files.

| Question | What the principle asks |
|---|---|
| Can this sentence be checked? | does the claim carry the artifact that proves it |
| Is this the source or a copy? | does the rule live where its producer is |
| Does this name resolve where it is read? | can the reader find the thing the text names |
| Can the reader build the model the text assumes? | does the text supply the model before asking for it |
| Who owns this decision? | does the text take only the decisions its author holds |

The membership of each question is not maintained here. A principle's description is its routing surface, so a list of the corpus would be a copy that goes stale.
