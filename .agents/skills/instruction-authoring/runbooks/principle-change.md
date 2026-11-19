# Change a principle

A change to the principle corpus starts here. Name the change, settle whether a live principle already answers it, and record the decision where the next reader looks. One change per pass, because a change carrying two intents is two changes.

The corpus is at its most valuable when a principle changes, so this file owns the whole change: the five intents, the overlap case that decides admission, the edges the corpus records, and where the decision lands. It replaces the admission pattern and the corpus survey, which mapped the corpus once and will not run again.

## Called from

- `/iter`, when the iteration's row changes a principle.
- The operator, for any change to the corpus.
- No other workflow dispatches it. A change arriving from elsewhere names this file to the operator rather than deciding on its own.

The survey's result is [`20261116-report-concluded-principle_corpus_map.md`](../../../../devlog/discussions/20261116-report-concluded-principle_corpus_map.md). Read it when you need the corpus as it stands. It is an index, not a procedure to rerun.

## Steps

1. **Name the change as one of five intents.** Add, consolidate, split, rename, remove. Say which intent, and name the artefact it touches: a skill, a section, a field, a prompt. Done when the intent is one of the five and the artefact is a path you can open.

2. **Find the nearest principles before writing anything.** Name the principles whose judgement shares the subject, narrows it or splits from it, and say why each one is near. Read their descriptions and their `**The test.**` parts, not their bodies, because the body answers a different question. `node scripts/principle_inventory.mjs` lists the cross-links and any missing declaration, and its candidates are a start rather than an answer. Done when the nearest set is named with a reason each, drawn from the inventory rather than from memory.

3. **Settle the overlap with one case.** Two artefacts overlap when they give the same outcome for the same input. Take one case from the record, a sentence the corpus misread, a document it produced or a decision it took, say what each artefact determines about it, and compare. Both claim it and agree, and they carry one judgement, so the change does not land as a new principle. Both claim it and differ, and the case is their boundary, which goes into both. One claims it, and they are distinct, so the change goes ahead. Quote the case and both determinations. Done when the record carries the case and the comparison, or the change names no overlapping artefact and says so.

4. **Collect what the operator needs, and say which decision it feeds.** Each finding carries a witness: a decision record, a commit, a quoted pair or a chat exchange. Three sources say what the corpus meant, and each is read for the intent alone: the decision records, the git history of the surface (`git log -S` on the line) and the chat logs. A finding with no witness is a preference, and it stays in the chat. Done when every finding carries its witness and names the decision it serves.

5. **Land the change where the decision lives.** A principle skill's body shape is [`principle_skill_shape.md`](../../../../docs/adr/principle_skill_shape.md), and this file does not restate it. Record the decision in the iteration's `## Decisions` table, and take a judgement that outlives the iteration to an ADR. Done when `bash scripts/check_principle_frontmatter.sh` and `bash scripts/lint.sh` are clean, and each decision names the file that holds it.

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

- The intent, out of the five.
- The nearest set, with a reason each.
- The overlap case and both determinations, or the statement that none overlaps.
- The edge, when the change adds or moves one.
- A witness for every finding.
- The decision, in the iteration's `## Decisions` table.
