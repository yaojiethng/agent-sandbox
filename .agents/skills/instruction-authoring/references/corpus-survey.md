# Corpus survey

Open this when the principle corpus needs a loose organization or a conflict register, rather than an admission decision on one proposed principle. [`../patterns/admission.md`](../patterns/admission.md) decides one proposal; this survey maps the corpus. The field `metadata.neighbours` is not its output: the existing corpus declares `[]`, and the survey map carries the edges.

## The card

One card per principle, built from what the skill already carries: the name, the one-sentence judgement, `**The test.**`, the description, the defect it prevents, and the grain it inspects (term, sentence, passage, document, artifact, corpus). The body is not catalogued.

## The facets

Three independent axes: **defect**, **grain**, and **moment** (propose, write, revise, review, admit). A shared facet value is not an edge. Two cards sharing one are co-located, not related.

## The families

A **family** is a defect value shared by at least two cards. Order within a family by grain. A singleton stays unsorted, and the map is provisional and lossy: it is an index, not an ontology.

## Candidate edges

Propose a pair only within a family, as **RT**, or across families when one defect is a special case of another, as **BT/NT**. Propose nothing otherwise. Every proposal carries one relation kind.

| Kind | Meaning | Disposition |
|---|---|---|
| USE / UF | two names for one judgement | merge case |
| BT / NT | one judgement narrows the other | hierarchy case |
| RT | same subject, different judgement | neighbour |
| see-also | a handoff ("apply this next") | prose, not a neighbour |
| contested | an open conflict | docket, provisional |

## The docket

A conflict is a **case**: the id, the parties (skills), the issue as a question rather than a verdict, the evidence (the two test sentences), the status (`open`, `stayed`, `resolved`), and the disposition. A stayed case marks only its own pair provisional. It never closes over the pair's neighbours.

## Precedence

Try, in order: *lex specialis* (write a BT/NT edge and change neither body); *lex posterior* (the later decision governs if it was made with the earlier in view); a one-line scope note on each card, saying what it does not cover; only then stay the case.

## The rules

- A shared facet is not an edge.
- RT is never transitive.
- A conflict is pair-local.
- A conflict may be stayed.
- Resolve by precedence before merging.

The first run is the five reader-context principles; the full run covers the 25. A principle the survey finds with no neighbour stays `[]` in the field and is recorded on the survey map.
