---
date: 2026-11-19
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The rule that structures instructions imperatively

## Objective

Admit the judgement that an instruction carries its verb in the imperative form, as the 28th principle, with the two sources quoted in their own words and both recorded.

## Scope

The judgement, its leaf, its place in the index, its neighbours, the two citation records, and the `task-list` rule that a row header names the work. The voice rule stays the separate item it was split into, and the modality rendering stays deferred, both as [`20261119-04`](20261119-04-plan-act_rule.md) decided.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The leaf states the judgement, and the rule, the why and the test are taken from the sources in their words with locators. | `grep -c "Write instructions in the imperative (command) form"` and the Google sentence both read 1, and each carries its rule number or its page. | Accepted. |
| The leaf cites both sources and each citation record parses with the five record fields. | `node -e 'JSON.parse(...)'` over both files, and the leaf names both in `**Where it comes from.**`. | Accepted. |
| The index routes on the act, under `Communication`. | `grep -n "structure-instructions-imperatively" src/reasoning/agent-runtime/pi/config/agent/AGENTS.md` reads one line with its defect. | Accepted. |
| The neighbours are declared symmetrically on both sides. | `bash scripts/check_principle_neighbours.sh` is clean, and both neighbours list the leaf. | Accepted. |
| `task-list` carries the rule that a row header names the work. | The `Row headers` paragraph reads in the file, with its two principle links. | Accepted. |
| The roadmap row closes with its outcome, and the header sweep is filed as one row. | `grep -c "Structure instructions imperatively"` and `grep -c "Rewrite the condition-shaped"` each read 1. | Accepted. |
| The leaf passes its own test: every directive in it opens on a verb, and the only prohibition left is inside a source's quoted sentence. | Read the leaf against its own `**The test.**`; `grep -c "not permitted"` reads 1 and it sits inside the Section 6 quote. | Accepted. |
| The corpus gate, the lint umbrella and the suite pass. | `scripts/check_principle_frontmatter.sh` reads 28 principles, `scripts/lint.sh` is clean, and the suite passes at `TEST_PARALLEL=2`. | Accepted. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The title is the operator's, `structure-instructions-imperatively`, as the H1 in sentence case and the slug with the corpus prefix. | The corpus names a judgement, and the operator dictated this one. | The leaf's `name` and title. |
| The defect is the standard's three ambiguities about agency, not a comprehension cost. | Rule 5.3 states the reader will not know whether the step matters, whether someone else did it, or whether someone else must do it later, which is checkable where a cost is not. | The leaf's `**Why.**` and `**The test.**`. |
| The rule states the directive half, and the descriptive bar is the mode boundary. | The standard states them as two rules in two sections, so the leaf carries the imperative rule and bars it where the text explains. | The leaf's `**Where the mode decides.**`. |
| The sources supply the sentences, and the leaf quotes them rather than paraphrasing. | Each sentence is a rule someone publishes, so a paraphrase would be a copy that can drift from its pin. | The leaf's body, and both citation records. |
| The family is `Communication`. | The rule is that the text says what its sender means, which is the sender's meaning rather than the reader's context. | The index line. |
| The leaf is written as its own reader, since its content is itself an instruction. | A leaf that tells a writer to open on the verb and then buries its own directive fails the test it publishes, so the passes are run on it before release. | This record's `## Findings`, and the leaf. |
| The leaf carries no reason of its own, and `vacuous` gains the case a definition hides. | "Since an instruction tells the reader to do something" restates the term it justifies, so the leaf's judgement states the two forms and leaves the reason to the source's three ambiguities. | The leaf's first line, and `principle-vacuous`'s `**The test.**` |
| Two citation records, one per source. | Each source supplies a different part, the standard the rule and its reason, the guide the check and the example that fails it. | `.agents/registry/citations/`. |

## Decisions pending

| Question | Options | Recommendation |
|---|---|---|
| Whether the corpus carries a gate on the imperative rate | a count that a reader checks, or no gate | no gate: the mode decides where the imperative is barred, and mode is not in the sentence, so a count would fail descriptive prose for obeying the rule |
| Whether `grain` earns an entry of its own | a `## grain` entry, or the Relationships line that now states it | the line, until a second document needs the term |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Google pairs its guideline with a step that states a need before the act, "You need the project ID later in this document. Retrieve the project ID." | Evidence | The published failure mode is the act arriving second, which is the defect this leaf's test catches. | The leaf's `**Where the mode decides.**` |
| The standard's reason for the rule is ambiguity about agency, not a re-parse and not a cost to the reader. | Evidence | The clear, "the reader must convert a state into an act", was replaced by the three questions the standard names, which a writer can check. | The leaf's `**Why.**` and `**The test.**`. |
| The first draft failed its own rule in six places: a directive buried mid-sentence in the judgement, three prohibitions, one sentence narrating what a source does, and one clause repeating the mode point. | Evidence | The negation form drags the banned behaviour into the reader's context, and the narration spends attention on the source instead of the rule. | The leaf, rewritten under `writing-for-agents` and `cut-metadiscourse`. |
| `principle-vacuous` let a definitional reason through, since the reader answers "is there an observation?" with the term's own meaning and never reaches the tautology branch. | Evidence | The gap costs a reader the reason a rule is worth following, and the leaf shipped with one until the operator named it. | The clause added to `**The test.**`, and the census in this row. |
| `devlog/handovers/M3.3.7/README.md` states that `01-18` are used and the next record takes `19`, and the series has numbered per date since `20261117`. | Record | The milestone's index sentence names a state two days old, so a reader takes the wrong next id. | Not filed; it predates this iteration and belongs to the record's own maintenance. |

## Completed

| File | One-line change summary |
|---|---|
| [`communication-principle-structure-instructions-imperatively/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-structure-instructions-imperatively/SKILL.md) | The leaf: the rule, the source's why, the mode boundary, the test, and the provenance, rewritten under `writing-for-agents` and `cut-metadiscourse` so it obeys its own rule, and carrying no reason of its own. |
| [`principle-vacuous/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/principle-vacuous/SKILL.md) | `**The test.**` names the definitional reason, which the tautology branch had been hiding. |
| `.agents/registry/citations/asd-ste100.json` | The standard's rule borrowed, with the dropped sections named. |
| `.agents/registry/citations/google-developer-style.json` | The guide's check and its failing example borrowed, and the pages dropped named. |
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](../../../src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The index routes on the act, under `Communication`. |
| `communication-principle-attach-as-you-read/SKILL.md` | The voice leaf declares the new leaf as a neighbour. |
| `communication-principle-state-intent-delegate-method/SKILL.md` | The brief-grain leaf declares the clause-grain one as a neighbour, taking a list it did not have. |
| [`.agents/skills/task-list/SKILL.md`](../../../.agents/skills/task-list/SKILL.md) | A row header names the work, opens on a verb, and leaves the condition to the row's text. |
| [`devlog/roadmap.md`](../../roadmap.md) | The act row closes with its outcome, and the header sweep is filed as one row. |
