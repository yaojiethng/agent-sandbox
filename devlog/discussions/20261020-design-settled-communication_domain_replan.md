# The communication-domain re-plan

**Status:** settled

## Context

Two days produced four censuses over the same prose standards: the norm-kind census (C1), which landed the kind table and `norm-ownership.tsv`; the spec census (C2), which proposed twelve principles and was never settled; the sentence-structure study (C3), which landed `communication-principle-attach-as-you-read` from eighteen sentences and two blind readers; and the neutral census (C4), whose method was rejected and whose plans are deleted. Alongside them, handover `20261020-04` landed the norm-kind table's home rule in `docs/reference/agent_workflow.md` `### Norm kinds`, and `20261019-12` landed the classifier-model usage prompt.

Four forward plans stayed open at once and no record said which question was open. This page answers that: it states what is settled, what the next two iterations are, and what will not be done.

## What is settled

1. **The home rule.** The document whose workflow produces a norm owns it. A judgement used by more than one document lives in a principle skill, and that is the only case where a judgement leaves its producing document. Stated once in `docs/reference/agent_workflow.md` `### Norm kinds`; `principle-one-home-per-rule` carries it as a judgement.
2. **A skill is not a gate.** `check_norm_ownership.sh` resolves a `review:` observer only under `workflow/coding-agent/skills/` or `.agents/skills/`, so a `communication-principle-*` skill cannot observe a ledger row. Filing a skill moves text between homes and never changes a kind.
3. **Duplication is the reason to file.** Three surfaces declare the same rules, recorded by `20261019-06` and confirmed since. Duplication is a maintenance surface, not an evidence claim: a rule earns its single home by having one, not by having a recorded failure behind it.
4. **No further classifier work.** The method question is closed and filed as a prompt with its first antipattern.

## Options Considered

- **File the twelve.** Rejected. Twelve skills state one home per judgement, where the rule asks for one home per *duplicated* judgement. Most of the twelve are used by one document only, so under the settled home rule they stay where they are. The tranche also multiplies a form the evidence did not support: one group was exercised by a real failure and another was over-broad against its own events.
- **Resolve in place, no skills.** Rejected. It contradicts the landed home rule for the multi-document case, and it would retire `attach-as-you-read`, which was filed on its own evidence.
- **Adopted: apply the landed rule, with a two-class triage.** The rule decides the home; the triage decides what is a candidate and what is not.

## Decision

**The triage.** A judgement used by two or more documents is **class 1**: it becomes a principle skill and every other site becomes a pointer. A judgement stated in one document that should generalise is **class 2**: it is flagged as a candidate in the map, reviewed on its own, and not landed by this chain. A judgement in one document that should stay local is in neither class and needs no work.

**The input.** A duplication map: one row per judgement, every site that states it, its distinct-document count, and its class. The spec census's dedupe table is within-document only, so the map replaces it rather than extending it: the map is the single table from which both the dedupe groups and the cross-document overlap are read.

**The sequence.** Two iterations, because the map is the filing's work list and the filing cannot be scoped without it.

1. **The duplication map.** Build the table over the 75 judgement rows of the live ledger, the six filed principle skills, and the scaffolder's template; classify every row; align `skill-scaffolder` to the conventions and put its repo-owned copy in the tree that seeds the installed skill, so the alignment ships.
2. **The filing.** Apply the map: file one skill per class-1 judgement, repoint every other site, confirm the two filed absorptions, regenerate `norm-ownership.tsv`, and retire the spec census.

**The scaffolder.** It is editable as of this page. Its `## When to Use`, `## Step-by-Step Instructions` and `## Constraints & Rules` body template and its `paths:` frontmatter restate rules the conventions own. The map records each of those sites; the alignment makes them pointers, and the repo-owned copy makes the fix durable rather than container-local.

## What is unknown

- The map's counts: how many judgements are class 1, how many class 2, how many stay local. Not forecast here, because a forecast is the guess this page exists to avoid.
- Whether aligning the scaffolder's template leaves it anything to emit. Its output shape is what duplicates; a pointer may leave it with no body to scaffold, and if so the answer is to have it compose from the conventions rather than to keep a copy.
- Whether any class-2 candidate is real. Each gets its own reading at review, and one can be rejected on its own.

## What will not be done

- The twelve-group settlement, and the twelve names.
- Any new census, classifier call, corpus or probe.
- Deleting an unexercised ledger line. They are candidates, and no line is removed without a separate decision.
- W2's taxonomy, its larger corpus, and the signalling experiment. They stay with W2.

## Consequences

- The filing's file list is cut from the map, not from this page's prose.
- `20261019-design-draft-prose_standards_specs.md` was the plan; the map is its successor. It is a `draft`, so its exit is `rejected` with the reason, then archived at the filing's close, with the map carrying the content that survives.
- The scaffolder becomes repo-owned, so its future drift is an ordinary record change rather than a container hand-edit.
- The ledger's kinds do not change in either iteration. Every site edit is a `model` pointer or a unchanged judgement.

## Open questions

None. Every choice above is settled; what remains is measurement, and measurement is the map's job.
