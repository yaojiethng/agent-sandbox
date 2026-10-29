# Principle Skill Shape

**Current:** 2026-10-28

## 2026-10-28 -- The principle shape carries no claim field

**Decision:** A principle skill carries the body shape and nothing else. The `metadata.claim` declaration is removed from every principle, the authoring convention's claim table is replaced by five question headings that group the corpus, and the gate drops the claim rule and its `--map` mode. The 2026-10-21 entry's Edge cases clause declaring the field is retired; the entry otherwise stands. The five questions live in `docs/development/prompt-authoring-conventions.md` `## The five questions`: can this sentence be checked, is this the source or a copy, does this name resolve where it is read, can the reader build the model the text assumes, who owns this decision. Each carries a linked member list, and the convention states that the lists are navigation and that no gate reads them.

**Rationale:** The field was a stored classification that nothing decided on. The gate checked that a claim was named and that the table held it, never that the filing was right, so swapping two filings passed and a mis-filing was undetectable. The five names were not exclusive either: `scope` and `authority` both bounded a text, and `evidence` and `source` both traced where a fact came from. A stored judgement that no check can falsify and no reader acts on charges a declaration per file and teaches an author to classify rather than to write. The tests are the useful part, and a reader meets them in one place, so the labels go and the tests stay.

**Rejected alternatives:**

- *Give the field a consumer.* **Intent failure**: the consumer would inherit the overlap, because `scope` and `authority`, and `evidence` and `source`, would each claim the same principle, so it would need a tie-break the field cannot supply.
- *Re-derive the axis bottom-up from the twenty-seven tests.* **Neither**: the tests were already written per skill, so a re-derivation would land near the same five, and it would still need a reader to be worth storing.
- *Gate the member lists for coverage.* **Intent failure**: the lists are navigation for a writer using the conventions and the description is the routing surface, so a missing name costs a reader nothing and a gate would guard a copy the text does not need.

**Edge cases / drivers:** The rule that no skill or prompt declares a claim is prose only, with no detector: it is verified once at the close that removed the field, and nothing guards it after that. The five questions name where a decision fails to cross from the writer to the reader-agent, and the fourth is deliberately stated as whether the model gets built rather than as one technique for building it. A principle may bear on more than one question, and the index does not adjudicate.

## 2026-10-21 -- A principle skill carries six parts in one shape, and a gate holds it

**Decision:** Every skill whose directory name carries `principle-` carries the same body: a sentence-case title, one sentence stating the judgement, `**The pattern.**`, `**Why.**`, zero or more named parts, each a bold label ending on a period and labelled for what it carries, and `**The test.**`. The pattern states the wrong form beside the right one, and its vehicle follows the material: a table where a contrast exists, a list where the parts are steps. The title is the file's only heading. `scripts/check_document_shape.sh` reads those rules off every such skill and fails the gate on a departure, so the shape is a rule with an observer rather than a judgement. A writer reads the shape in `docs/development/prompt-authoring-conventions.md` `## The principle shape`.

**Rationale:** The corpus held two shapes for the same parts, so the exemplar that M3.3.4 measures a new principle against was one of two answers, and a writer copying it met a third answer in the next file. Adopting the exemplar's own form keeps the roadmap's exemplar sentence and the acceptance criterion built on it unchanged. The shape is a rule by the test in [`norm_kinds.md`](norm_kinds.md): it asserts structure and asks the author to follow it, and a gate detects a departure, so it needs a home in the authoring convention and an observer in the lint umbrella. The gate's subject is derived from the name instead of listed, so a new principle is covered the day its directory exists.

**Rejected alternatives:**

- *Convert the corpus to `##` headings.* Ten files already used them, and a rendered skill gains a table of contents and named anchors. The exemplar would be the non-conforming file until it converted, so the acceptance criterion could not be read mid-iteration, and the roadmap's exemplar sentence needed rewriting.
- *State the shape and leave the files.* A statement with no observer is a model, and the drift returns at the next author, which is how it arrived.
- *Require the pattern table.* Ten of the 22 state the pattern as a list, and a table there would assert a contrast the judgement does not draw. The required part is the contrast, not the vehicle.
- *Exempt `principle-guard-the-context-window`.* Its body is a bulleted procedure under `**Why:**` and `**Pattern:**`. An exemption is a second shape, which is the defect the decision removes.

**Edge cases / drivers:** A principle declares the claim it applies in the frontmatter's `metadata` key, as `metadata:` then `claim: <name>`, and the claim names are declared once in `docs/development/prompt-authoring-conventions.md` `## The principle claims`. The gate reads the set from that table and fails a principle that declares none or names one the table lacks, while which claim a given skill picks stays a judgement. A part is any bold label ending on a period, not the `Where ...` form alone, because the corpus labels parts for what they hold as well as for when they apply. A title that needs an acronym or a proper noun fails the rule until a non-first word may begin uppercase, and that widening is one edit to the rule rather than a per-file exception. A skill whose subject is a procedure rather than a judgement keeps the runbook shape and sits outside the rule's subject, which the `principle-` segment of the name draws.
