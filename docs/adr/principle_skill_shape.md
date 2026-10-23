# Principle Skill Shape

**Current:** 2026-10-21

## 2026-10-21 -- A principle skill carries six parts in one shape, and a gate holds it

**Decision:** Every skill whose directory name carries `principle-` carries the same body: a sentence-case title, one sentence stating the judgement, `**The pattern.**`, `**Why.**`, zero or more named parts, each a bold label ending on a period and labelled for what it carries, and `**The test.**`. The pattern states the wrong form beside the right one, and its vehicle follows the material: a table where a contrast exists, a list where the parts are steps. The title is the file's only heading. `scripts/check_document_shape.sh` reads those rules off every such skill and fails the gate on a departure, so the shape is a rule with an observer rather than a judgement. A writer reads the shape in `docs/development/prompt-authoring-conventions.md` `## The principle shape`.

**Rationale:** The corpus held two shapes for the same parts, so the exemplar that M3.3.4 measures a new principle against was one of two answers, and a writer copying it met a third answer in the next file. Adopting the exemplar's own form keeps the roadmap's exemplar sentence and the acceptance criterion built on it unchanged. The shape is a rule by the test in [`norm_kinds.md`](norm_kinds.md): it asserts structure and asks the author to follow it, and a gate detects a departure, so it needs a home in the authoring convention and an observer in the lint umbrella. The gate's subject is derived from the name instead of listed, so a new principle is covered the day its directory exists.

**Rejected alternatives:**

- *Convert the corpus to `##` headings.* Ten files already used them, and a rendered skill gains a table of contents and named anchors. The exemplar would be the non-conforming file until it converted, so the acceptance criterion could not be read mid-iteration, and the roadmap's exemplar sentence needed rewriting.
- *State the shape and leave the files.* A statement with no observer is a model, and the drift returns at the next author, which is how it arrived.
- *Require the pattern table.* Ten of the 22 state the pattern as a list, and a table there would assert a contrast the judgement does not draw. The required part is the contrast, not the vehicle.
- *Exempt `principle-guard-the-context-window`.* Its body is a bulleted procedure under `**Why:**` and `**Pattern:**`. An exemption is a second shape, which is the defect the decision removes.

**Edge cases / drivers:** A principle declares the claim it applies in the frontmatter's `metadata` key, as `metadata:` then `claim: <name>`, and the claim names are declared once in `docs/development/prompt-authoring-conventions.md` `## The principle claims`. The gate reads the set from that table and fails a principle that declares none or names one the table lacks, while which claim a given skill picks stays a judgement. A part is any bold label ending on a period, not the `Where ...` form alone, because the corpus labels parts for what they hold as well as for when they apply. A title that needs an acronym or a proper noun fails the rule until a non-first word may begin uppercase, and that widening is one edit to the rule rather than a per-file exception. A skill whose subject is a procedure rather than a judgement keeps the runbook shape and sits outside the rule's subject, which the `principle-` segment of the name draws.
