# Norm kinds

**Current:** 2026-10-17

## 2026-10-17 -- A norm is a rule when an observer detects its violation; a judgement is its principle skill's own

**Decision:** Classify a norm by what detects a breach of it, not by where the sentence sits. A norm is a rule when a gate, a lint rule or a dispatched reading procedure fails on a violation, and it is a judgement when nothing does. A judgement lives in the principle skill that states it, and that skill is its only home, so a principle carries no gate and no authority claim. A norm that asserts structure and asks the author for nothing is a model. The ledger `scripts/lint/norm-ownership.tsv` records the kind and observer of every prose line in `.agents/skills/docs/SKILL.md` and `prompt-authoring-conventions.md`, and `scripts/check_norm_ownership.sh` holds it both ways.

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
