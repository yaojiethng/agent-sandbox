# Design - Name the inverse defect, a section that holds two subjects

**Status:** settled

## Context

The row **Name the inverse defect: a section that holds two unrelated concepts** observes that the corpus names scatter, a rule's parts sitting apart, and does not name lumping, one section carrying two subjects. The graft it cites is the bullet `One term, one meaning` at `documentation_policy.md:45`, inside `### Simplified Technical English`, whose subject is sentence structure.

That bullet reads two ways. Read one way it is a terminology clause sitting away from the terminology section, so it is a scattered part. Read the other way it is a foreign subject inside a section about sentences, so it is a lumped section. Only the first reading has a home: `communication-principle-dont-scatter-what-belongs-together` when this design opened, and `communication-principle-keep-a-subject-near` once it landed.

Two things changed while this design ran. The naming and leading-word clauses landed in `principle-effective-skill-routing` through sidequest `20261021-06`, so a rename now follows a stated rule. And the leading word became the corpus's linking device, which means the principle that takes this defect also takes one word for it.

## Options Considered

1. Widen `communication-principle-dont-scatter-what-belongs-together` and rename it, so one adjacency law is read from either end. The principle's rationale already argues from the reader's cost, which is symmetric. Cost: the name states one direction, so the rename carries a carrier list.
2. Fold the rule into `principle-own-the-scope-you-declare`, which is the fold `20261020-13` proposed for `one-subject-per-prompt`. Case: a heading declares a subject and a second subject overruns it. Cost: that proposal covers prompts and records that the fold needs its own grill session, the claim moves from `reader` to `scope`, and the reader cost leaves the corpus.
3. File a new principle with its own claim line. Cost: a twenty-third skill for a rule that may be the inverse of a landed one.
4. Record a scope limit on the scatter principle, stating that the second reading advances no decision. Cost: the row's own analysis finds lumping a real defect, so a limit that declares it out of scope would be hollow.

Merging the scatter principle with `principle-one-home-per-rule` was considered and rejected. The two defects occur independently: one rule can be stated twice, each copy complete, and one rule can sit whole with a caveat three sections away. Their repairs differ, because one deletes a copy and points at the home while the other moves a part beside its rule, and this row adds a third repair, splitting a section. A merged skill would carry three observations and three repairs, which is a lumped section committed at corpus level.

## Decision

Widen the scatter principle and rename it to `communication-principle-keep-a-subject-near`. The name carries the leading word `proximity`, avoids the words `home` and `place` that pull it toward `principle-one-home-per-rule`, and states the act rather than the quality.

The law states proximity as the property, and reads it against the four costs a writer can check: working memory, because the reader holds the rule while reading the caveat; mental-model repair, because a rule read without its caveat has to be unlearned; attention, because a section carrying a second subject spends it on nobody's question; and the next edit, because a writer who cannot see the whole subject edits part of it.

The test asks both questions, whether the reader still holds the rule and whether the section serves one subject.

The claim stays `reader`, because both questions ask what the reader holds at a point in the reading. `principle-one-home-per-rule` keeps `source`, because its test asks where the text lives. That distinction is what a merge would have erased.

## Consequences

Both readings of the graft now have a home. The first, a terminology clause away from its home, is the scatter half of the widened principle. The second, a foreign subject inside a sentence-structure section, is its lumping half. The graft is not moved, because `M3.3.2` retires the policy's judgement rows and a move now would be undone by that retirement.

The rename carries a list. The skill directory and its `SKILL.md` change. `principle-one-home-per-rule` names the widened skill in its boundary line, and it follows the new name. The live records follow: the roadmap, the conventions, and both ledger files. Four closed handovers keep the old name, because each was true when it was written, and this record is where a reader reaches the new one.

A review run against a first draft of this decision found the four cost labels mixing three vocabularies: engineering, in propagation and maintenance; agent runtime, in a loaded context window; and the reader's, in cognitive load. The labels now take the reader's words throughout, and the leading word moved from locality to proximity, which is the document-design and perceptual-grouping term for the same rule. The name follows the word, so the skill reads `communication-principle-keep-a-subject-near`.

No ADR is written for this decision. It applies [`principle_skill_shape.md`](../../docs/adr/principle_skill_shape.md), which already governs the corpus shape, and it changes one skill's name and body rather than setting a convention later work must follow.

The domain exception that sidequest `20261021-06` settled is available to the widened principle in its self-contained form, so the rename does not depend on a repository path a shipped skill cannot open.
