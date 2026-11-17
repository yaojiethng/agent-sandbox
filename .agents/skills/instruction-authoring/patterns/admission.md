# Admission

Open this when a principle is proposed, changed, or merged into another.

## The question

Does a live principle already answer this? A principle carries a judgement with a modal strength; the corpus is coherent when two skills do not carry the same judgement under different names, and when a proposed judgement is not already in force as part of a neighbour. Ask before the body is written, because the case and its nearest principles are the whole context at that moment.

## The neighbour search

Name the nearest existing principles: the ones whose judgement the new one shares a subject with, narrows, or splits from. Run `node scripts/principle_inventory.mjs`; its cross-links are candidates, and its missing-field report says which principles still carry no declaration. Read the candidates' descriptions and their `**The test.**` parts, not their whole bodies.

The field is `metadata: neighbours:`, a list of full skill names. It holds neighbours only; a handoff ("apply this next") is prose. `[]` declares that no neighbour is declared; a principle the corpus survey finds with no neighbour is recorded on the survey map. An absent field is undeclared and fails the gate.

## The case

State the artifact or the decision that demanded the rule, in one sentence. A principle with no case is a preference, and the case is what the operator weighs against the neighbour's existing judgement.

## The decision

The operator decides one question: is this a new judgement, a narrowing of a neighbour, or a duplicate? Record the answer in `metadata.neighbours` and land the body. A contested distinction is argued in the admission record, which is the corpus's case law, not in every skill. When the answer is a merge, the surviving skill takes the field and the other is retired.

The gate holds presence and liveness; it cannot judge whether the named neighbour is the right one. That half is the decision.

The design record is [`20261114-design-concluded-principle_corpus_admission.md`](../../../../devlog/discussions/20261114-design-concluded-principle_corpus_admission.md); the field's shape is [`../references/skill-conventions.md`](../references/skill-conventions.md#frontmatter).
