# Change a principle

A change to the principle corpus starts here. The operator writes every part of the skill and this file carries the questions that draw them out; the agent asks, assembles and checks. One change per pass, because a change carrying two intents is two changes.

The corpus is at its most valuable when a principle changes, so this file owns the whole change: the five intents, the overlap case that decides admission, the edges the corpus records, and where the decision lands. It replaces the admission pattern and the corpus survey, which mapped the corpus once and will not run again.

## Called from

- `/iter`, when the iteration's row changes a principle.
- The operator, for any change to the corpus.
- No other workflow dispatches it. A change arriving from elsewhere names this file to the operator rather than deciding on its own.

The corpus as it stands is `node scripts/principle_inventory.mjs`: the fields, the declared neighbours, the cross-links and any missing declaration. What a principle skill carries is [`../references/principle-skills.md`](../references/principle-skills.md).

## The sequence

Ask one question, take the answer, then ask the next. Nothing enters the skill before its answer is in hand. A question the operator answers with a change to an earlier answer reopens that answer, and the later ones follow from it.

| The agent asks | The operator writes | The agent brings |
|---|---|---|
| What changes, and by which of the five intents? | the change and the artefact, in one sentence | the five intents with the question each asks, and the inventory for the artefact |
| Which live principles are nearest, and why? | near or not near, and the reason, for each candidate | the inventory's candidates with their descriptions and `**The test.**` parts, and the cross-links |
| Does a live principle already answer it? | the case, and what each artefact determines about it | candidate cases from the decision records, `git log -S` on the line, and the chat logs |
| What is the judgement, in one sentence? | the sentence, in their words | the shape's requirement for that part, and the exemplar |
| What fails without it? | the `**Why.**` text | the shape's requirement for that part |
| What does the test ask? | the `**The test.**` text, and any named part the shape allows | the shape's requirement, and the exemplar's test |
| What is it called? | the name | the existing names, the gate's naming rule, and what a cold reader predicts from it |
| What situation does the description name? | the description | the routing rule, that selection reads this alone, and the exemplar's description |
| What are `intent`, `mechanism` and the leitwort? | the three values, or `none` for the leitwort | the field meanings and the gate's rule for each |
| Which neighbours does it declare? | the list, ruled from the candidates | the candidates ruled near above, and the symmetry the gate checks |

Three rules hold the sequence together.

1. **One question at a time.** The sequence is the procedure, not a form, and a batch of questions is a form.
2. **Assembly is verbatim.** The agent writes the frontmatter keys, the bold lead-ins and the order the shape fixes, and no clause of its own. A part missing from an answer is a question back, never a sentence the agent adds.
3. **Each answer lands the moment it arrives**, in the iteration's `## Decisions` table, with the question it answers. A lost context resumes at the next question, and the diff is checkable against the record.

## The five intents

| Intent | The question it asks | What settles it |
|---|---|---|
| Add | Does a live principle already answer this? | The overlap case: no live artefact claims it |
| Consolidate | Do two artefacts carry one judgement? | The case both claim, with one determination |
| Split | Does one artefact carry two judgements? | One case whose answer depends on which half you read |
| Rename | Does the name predict the judgement? | A reader who meets the name cold and cannot predict the test |
| Remove | Does anything still hold this? | No carrier: no owner row, no live pointer, no test |

An intent is not a method. The row that triggers the change states the problem and the evidence, and how to integrate it is the doer's proposal, ruled at the gate. `communication-principle-state-intent-delegate-method` holds that split.

## The edges the corpus records

| Kind | Meaning | Disposition |
|---|---|---|
| USE / UF | two names for one judgement | a merge case |
| BT / NT | one judgement narrows the other | a hierarchy case |
| RT | same subject, different judgement | a neighbour |
| see-also | a handoff ("apply this next") | prose, not a neighbour |
| contested | an open conflict | the docket, provisional |

`metadata.neighbours` holds the neighbours only, a symmetric list of full skill names, and `[]` says no neighbour is declared. An absent field is undeclared and fails the gate. A shared mechanism is not a neighbour: the field records the judgement's subject, and a shared mechanism is recorded in prose, as a broader and narrower judgement.

Three axes describe an artefact, and a shared value on any of them is not an edge. **Defect** is what fails. **Grain** is what the judgement inspects: term, sentence, passage, document, artifact, corpus. **Moment** is when it fires: propose, write, revise, review, admit. Two artefacts sharing a facet are co-located, not related.

A **family** is a defect shared by two or more artefacts. Order a family by grain. A singleton stays unsorted, and the map is provisional and lossy, an index rather than an ontology.

## A conflict

A conflict is a **case**: the id, the parties, the issue written as a question rather than a verdict, the evidence (the two cases), the status (`open`, `stayed`, `resolved`) and the disposition. A stayed case marks only its own pair provisional, and it never closes over the pair's neighbours.

Resolve by precedence before merging. Try *lex specialis* first, a BT/NT edge that changes neither body. Then *lex posterior*, the later decision governing when it was made with the earlier in view. Then a one-line scope note on each artefact saying what it does not cover. Only then stay the case. RT is never transitive, and a conflict stays pair-local.

## What a change owes the record

- Every answer, with the question it answers.
- The case and both determinations, or the statement that nothing overlaps.
- The edge, when the change adds or moves one.
- A witness for every finding.

The answers are the decision, which is why they are recorded rather than summarised.
