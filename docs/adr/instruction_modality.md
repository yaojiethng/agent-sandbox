# Instruction modality

**Current:** 2026-11-02

## 2026-11-02 -- The kinds are tools for choosing a mechanism, not a classification of a sentence

**Decision:** The five kinds are tools a writer uses to test the mechanism against the problem. The strength a kind buys comes from what holds it, so the same rule written as prose is much looser than the same rule enforced by a gate, and what a machine can decide belongs in code or a gate rather than in paper.

**Rationale:** The derivation is Kratzer's, and the citation records it along with the one thing the taxonomy added: the consequence for enforcement. Applied per sentence the kinds reinstate the retired ledger's discipline without its data, because two readers assign different kinds to the same sentence and nothing reports the disagreement.

**Rejected alternatives:**

- *Keep the per-sentence classification and drop only the ledger* -- rejected on execution: the assignment survives as a habit nobody can check.
- *Rank the kinds by strength and require the strongest* -- rejected on intent: the base decides the kind before the strength does, so the ranking pushes a permission toward a rule.

**Edge cases / drivers:** A judgement and a rule can hold the same wording; what separates them is whether a machine decides the outcome.

## 2026-11-02 -- The kinds are five, by base and force, and the classification is a standard

**Decision:** A sentence of instruction text is classified by the base it appeals to and the force it carries. The base is deontic when the sentence states what a reader owes, and epistemic when it states what is the case. The force is necessity, graded, or possibility, which RFC 2119 names MUST, SHOULD and MAY. The five kinds are `rule` (deontic necessity), `judgement` (deontic, graded), `permission` (deontic possibility), `fact` (epistemic necessity) and `claim` (epistemic possibility). The framework is Angelika Kratzer's relational semantics, in *What 'must' and 'can' must and can mean*, Linguistics and Philosophy 1:3 (1977), collected in *Modals and Conditionals* (Oxford University Press, 2012) at [doi.org/10.1007/BF00353453](https://doi.org/10.1007/BF00353453): a modal is read against a modal base and an ordering source, so the kinds are derived rather than asserted. What we took from it and what we dropped is `.agents/registry/citations/kratzer-relational-modality.json`. Each claim about the taxonomy has one home, and a later claim follows the same split: this entry for the decision, `docs/reference/terminology.md` `## modality` for the definition, the `instruction-authoring` convention for what a kind owes a writer, and `docs/reference/agent_workflow.md` for the description. That convention's home was created for it, so each later unit moves content into a place that already exists. The definitions live in `docs/reference/terminology.md` `## modality`, the obligations a writer owes live with the `instruction-authoring` convention, and this record holds the decision. The terms `norm` and `statement` retire, `claim` replaces `statement`, and this record is renamed from `norm_kinds.md`.

**Rationale:** The three-kind test asked one question, whether an artifact detects a breach, so it answered a question about enforcement rather than about the sentence. Two cells went missing and both produced defects a reader cannot see: a number with no source read as a description, because nothing detects it, and a permission read as a rule, because nothing detects it either. Separating the base from the force tells apart what a sentence appeals to from whether anything catches a breach of it, which is the difference between an epistemic and a deontic failure. It also explains the 2026-10-22 result rather than working around it: two readers agree on an artifact's existence in a way they cannot agree on a force, because the standard a sentence is ranked against is context the sentence does not carry. The classification is therefore a standard, applied by a reader, and a gate over it would guess.

**Rejected alternatives:**

- *Three kinds, with evidence a requirement on descriptions* -- it hides the failure the taxonomy exists to name inside a kind that owes nothing, so an unevidenced claim reads exactly like a fact.
- *Four kinds labelled prescriptive, empirical, evaluative and hypothetical directive* -- a claim is not a directive, and the split between the deontic and the epistemic is the taxonomy's spine; `hypothetical` also names a claim's content rather than its force.
- *Classify by keyword, with MUST, SHOULD and MAY as the signal* -- the 2026-10-17 sample gave 12 of 20 agreement between two readers on a semantic test, and a keyword reads the word a writer reached for rather than the force the sentence carries.
- *Gate the classification, or keep a ledger of it* -- retired on 2026-10-22 for the reasons above, which this split makes structural rather than incidental.

**Edge cases / drivers:** A permission that names no granter is a suggestion, and saying so is what stops a reader treating advice as a grant. A MUST and a SHOULD governing one situation is one requirement written twice with two forces, which is a scope defect before it is a modality one.

## 2026-10-22 -- The kind test stands, and its ledger does not

**Decision:** The test above is unchanged and the instrument that held it is retired. `scripts/check_norm_ownership.sh` and its two data files are deleted. The test is applied by a reader against `## Norm kinds` in `docs/reference/agent_workflow.md`, as it was before the ledger existed.

**Rationale:** The ledger stored one typed pair per sentence, the mark and the observer, and generated nothing that carried meaning: the four derived cells came from the tree and the two meaningful ones could only be typed. Its gate asked whether a named observer exists, never whether it fires on the sentence. Of 99 rows, 22 named an observer and 46 were the negation "nothing catches this", which no check can settle. The cost was a reclassification of every sentence a person edited, paid at the moment of the edit, and the return was one census line. A record that announces itself as generated while its only meaningful cells are typed is worse than no record, because a reader cannot tell the two apart.

**Rejected alternatives:**

- *Keep the ledger and demote its gate to a report* -- the report still needs the typed pair per sentence, so the maintenance stays and only the red build goes.
- *Prove the 22 observers by perturbation and keep the rest as assertions* -- that would make the classification measured rather than typed, and it is the only version worth building, but it is a different tool: it needs a perturbation per sentence and it cannot cover the 46 negations, so the uniform file it replaces is not the same artifact.

## 2026-10-17 -- A norm is a rule when an observer detects its violation; a judgement is its principle skill's own

**Decision:** Classify a norm by what detects a breach of it, not by where the sentence sits. A norm is a rule when a gate, a lint rule or a dispatched reading procedure fails on a violation, and it is a judgement when nothing does. A judgement lives in the principle skill that states it, and that skill is its only home, so a principle carries no gate and no authority claim. A norm that asserts structure and asks the author for nothing is a model. A ledger recorded the kind and observer of every prose line of the two prose standards until 2026-10-22, when it was retired for the reasons recorded above.

**Rationale:** The 2026-09-30 framing made the policy home the test of authority, and its definition of a rule presupposed an obligation. A judgement imposes none, so the doctrine never reached one, and a reader meeting a judgement had to file it as a rule and then satisfy a requirement the judgement could not meet. The principle corpus inherited that contradiction. Observation replaces the semantic test because it is the only one two readers can apply and get the same answer, and the ledger makes the answer checkable: 99 lines, 16 gated, 6 reviewed, 46 judgement, 31 description, 12 sourced at the 2026-10-22 regenerate.

**Rejected alternatives:**

- *Keep the policy-home test and exempt judgements.* The exemption is a second test with no observer either, and the exemption's own boundary is the question that failed.
- *Delete the authority section at the judgement carriers.* It removed the canonical-owner test, the producer rule, the no-bridge rule and policy membership to answer a question the definition of a rule never raised.

## 2026-09-30 -- Rules are authoritative only where a policy canonically states them; concepts and ADRs describe but do not bind

**Decision:** A rule is authoritative only where a policy document canonically states it. A concept document or ADR may describe a rule in readable form, but it links to the policy and is not the rule's home. A rule with no policy home is descriptive, not binding. Separate the two by kind: a statement is a rule when it imposes an obligation a document or its author must meet, and belongs in policy; a statement is a model when it describes the system's structure as a consequence of earlier decisions, and belongs in a concept document, which states it readably and links the rules behind it.

**Rationale:** The declarative framing covered workflow rules against skill files and prompt templates. It did not cover the general case: a rule that lives only in a concept document or an ADR, or that exists only implicitly across several documents. The document promotion topology -- a discussion promotes to an ADR, an ADR informs a concept, a concept feeds an architecture document -- was spread across `adr_policy.md` and `documentation_policy.md` with no single home. It is a view, the accumulated consequence of individual ADR decisions, so it belongs in a concept document. Its edges are obligations -- when an ADR must be spawned, what an ADR owns -- and each is a rule that must have exactly one policy home. The authority principle gives a decisive test: any MUST that lives in a concept or ADR without a policy home, or any rule stated twice, is a defect a review can flag.

**Rejected alternatives:**

- *Let concepts and ADRs be authoritative in their own right* -- recreates the cross-document gap and the duplicate-content defect the framing exists to remove.

**Reason superseded by 2026-10-17:** the test of authority moved from the document that hosts a norm to the observer that detects its violation, because a judgement imposes no obligation and the hosting test could not classify one.
