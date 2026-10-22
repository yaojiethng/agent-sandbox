# The principle corpus carries one shape

**Status:** settled

## Context

The roadmap row **The principle corpus carries two document shapes** was raised at handover [`20261020-32`](../handovers/20261020-32-workflow-deconflict_the_communication_surfaces.md) against nine principle skills, five marking a part with a bold lead-in (`**The pattern.**`, `**Why.**`, `**The test.**`) and four marking it with a `##` heading. The corpus has since grown to the 22 skills whose directory name carries `principle-`, and a reading of those files finds four dimensions of drift rather than one.

| Dimension | Value A | Value B |
|---|---|---|
| Serialization | 12 skills mark a part with a bold lead-in | 10 mark it with a `##` heading |
| Pattern vehicle | 12 state the pattern as a two-column contrast table | 10 state it as a list |
| The test | 19 carry `**The test.**` | 3 carry no test |
| Title case | 13 open on a sentence-case title | 9 open on a title-case title |

The counts are a reading of the tree, not a statement to maintain. The gate this iteration adds prints them, and `communication-principle-only-derive-what-you-own` at `$AGENT_HOME/agent/skills/communication-principle-only-derive-what-you-own/SKILL.md` states why a record should not retype what another artifact owns.

M3.3.4's acceptance criterion 3 asks that "a second and third principle pass the exemplar's shape without a new template being invented". A writer cannot meet it by copying `communication-principle-show-dont-describe`, because nothing in that file separates the parts which are the shape from the parts which are its own content, and ten neighbouring files answer the same question differently.

The norm doctrine settles what kind of rule the shape is. [`policy_declarative_framing.md`](../../docs/adr/policy_declarative_framing.md) (2026-10-17) states that a norm is a rule when an observer detects its violation, and that a norm asserting structure is a model. The shape asserts structure and asks an author to follow it, so it is a rule, and a rule without an observer is a model that nothing holds. The statement and the check therefore land together.

## Options Considered

**A. Convert the corpus to `##` headings.** Ten files already use them, and a rendered skill gains a table of contents and named anchors. The cost is that the exemplar named by the roadmap and by acceptance criterion 3 becomes the non-conforming file until it converts, so the criterion cannot be read mid-iteration, and the roadmap's sentence naming the exemplar needs rewriting.

**B. Convert the corpus to the exemplar's bold lead-in form.** Ten files convert, the exemplar already carries the form, and the criterion reads "the exemplar's shape" without redefinition. The cost is that the form has two jobs in one file, where a bold lead-in also opens a bullet item; that file converts its list instead of keeping the ambiguity.

**C. Leave the two shapes and state the split as intended.** This is the row's second ending. It costs nothing to build and leaves the writer with the defect, because the corpus still states two answers to a question the writer asks once.

**D. State the shape in the gate only.** The gate reports a violation after the file exists, and a writer needs the shape before writing it. A gate alone is an observer with no home for the rule.

## Decision

B, with the shape stated in [`prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) and held by a gate. The exemplar is the artifact acceptance criterion 3 names and the artifact a writer copies, so adopting its form needs no redefinition of the exemplar sentence the roadmap already carries.

The settled shape has six parts, and the first of them is the only heading in the file.

1. A title in sentence case, `# <the judgement as a sentence>`.
2. One sentence under the title stating the judgement.
3. `**The pattern.**` with the wrong form beside the right form.
4. `**Why.**` with the reason the wrong form fails.
5. Zero or more named parts, `**<label>.**`, each labelled for the situation or the material it carries, sitting between the why and the test.
6. `**The test.**` with the question the writer asks their own draft.

Four sub-decisions the shape settles besides serialization.

- **A part is any bold label ending on a period.** The `Where ...` form is one label among several, because the files carry `**What it does not cover.**`, `**The three kinds of criterion.**` and `**Stop.**`, and a rule admitting only the `Where` form would have rewritten content to satisfy a serialization.
- **The pattern's vehicle is free.** Ten of the 22 state the pattern as a list, and requiring a table would assert a contrast those judgements do not draw. The required part is the contrast, not the vehicle.
- **The test is required.** Three files gain one, each written from its own content: `only-derive-what-you-own`, `one-home-per-rule` and `guard-the-context-window`.
- **The title is sentence case.** The tree's document headings use it, and a writer copying `# Show, Don't Describe` beside `# One addressing axis` still meets two conventions.
- **`guard-the-context-window` converts rather than being exempted.** Its body is a bulleted procedure under `**Why:**` and `**Pattern:**`, and an exemption is a second shape.

## Consequences

- A new gate joins `GATES` in [`scripts/lint.sh`](../../scripts/lint.sh): `scripts/check_skill_shape.sh` over `scripts/lint/skill-shape.mjs`. Its subject is derived from the name, so every skill directory whose name carries `principle-` enters the check the day it exists and the rule holds no hand list.
- The gate holds the four dimensions: no `##` heading below the title, the three required parts in order, only `**Where ... .**` between the why and the test, and no non-first word of the title beginning uppercase.
- Twenty of the 22 files change. `communication-principle-one-addressing-axis` conforms already.
- Two files carried their parts before the why and one carried a named part after the test, so the conversion reordered blocks as well as relabelling them. The order is part of the shape, and a part that names what a rule does not cover reads after the why that argues for the rule.
- The same files load from `$AGENT_HOME/agent/skills/`, so the installed copy is re-synced in the same iteration.
- A title that needs an acronym fails the gate until the rule is widened. That is the intended failure, because it is loud and it is cleared by one edit to the rule rather than by a per-file exception.
- The draft `.agents/drafts/communication-principle-write-plainly/` is not converted. The open row **The plain-wording standard** promotes it, and the shape applies at promotion.
- The shape is stated once, in the authoring convention, and observed by the gate. The corpus's files carry no restatement of it.
