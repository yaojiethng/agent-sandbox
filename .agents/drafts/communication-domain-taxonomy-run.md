# Communication Domain Taxonomy - Run

**Status:** draft

**Scope:** the run directive for the deep communication-domain work: a taxonomy of the reader's processing costs that slices the domain into principles, a controlled vocabulary of the domain terms, and a measured answer to whether those terms signal the domain to an agent. It carries the hypothesis the run tests, the primary material it starts from, the partition and agreement checks, and the stop conditions.

**Origin:** the operator's scoping request (2026-10-19), the derived principle in [`20261019-design-settled-sentence_structure_principle.md`](../../devlog/discussions/20261019-design-settled-sentence_structure_principle.md), and the spec census in [`20261019-design-draft-prose_standards_specs.md`](../../devlog/discussions/archive/20261019-design-draft-prose_standards_specs.md). This brief is a draft under `.agents/drafts/`, so no live dispatch path reaches it until the operator promotes it.

## Purpose

The communication domain is sliced by surface rule today: active voice, given-before-new, a whole main clause, and the prompt-authoring structure rules. The slices overlap, and a writer cannot tell why they are one family. A deeper slice is available. The reader's processing architecture supplies cost types, and each cost type is one principle. This run produces the taxonomy, the vocabulary, and the evidence that the vocabulary changes an agent's output.

The reader of the taxonomy is the next agent. It needs a small set of principles that do not overlap and that it can reach mid-draft. The reader of the vocabulary decision is the operator, who needs to know whether domain terms earn their tokens.

## The hypothesis to test, not assume

An agent produces higher-quality output when its context carries domain-specific terms. The test is whether adding the processing terms to a principle changes the agent's rewrites, graded blind. The falsifier is a tie or a loss for the term-carrying condition, in which case the vocabulary stays out of the instruction surface.

## Start from

1. The primary works, read or fetched, not summaries. Gibson on Dependency Locality. Haviland and Clark on given-new. Frazier and Rayner on reanalysis. Ferreira on good-enough processing and noncanonical sentences. Bever on the noun-verb-noun strategy. Wasow and Behaghel on weight. Hale and Levy on surprisal. Halliday, Lambrecht and Prince on information structure, theme and rheme, given and new. Mark each citation verified or unverified. Do not invent one.

2. A labelled failure corpus of at least 60 sentences from this repository and its history, each carrying exactly one mechanism label. Expand the 18-sentence corpus in [`20261019-report-settled-sentence_structure_evidence.md`](../../devlog/discussions/20261019-report-settled-sentence_structure_evidence.md).

3. The existing partition. Read the `kind` column of `scripts/lint/norm-ownership.tsv` and the filed principles under `src/reasoning/providers/pi/config/agent/skills/`. That is the slice the new taxonomy is measured against.

4. The terminology layer, `docs/reference/terminology.md`, and the reserved-term list.

5. The `eval` skill under `workflow/coding-agent/skills/eval/`, which is the only place the signalling experiment can run.

## Steps

1. Propose the axes as processing costs, not surface rules. Candidate axes: referential anchoring, dependency locality, reanalysis, predictability, argument mapping. For each axis state the mechanism, the failure it predicts, and the surface moves it covers. Merge or split an axis until the partition is defensible.

2. Build the coverage matrix, failure class against principle. Every labelled failure maps to exactly one principle, and every principle is non-empty. Report every overlap and every gap. If two axes are not separable on the corpus, say so and merge them.

3. Measure agreement. Two independent labellers label a sample with the taxonomy. Report the agreement. A taxonomy one person cannot reproduce is not a partition.

4. Reconcile. Compare the taxonomy against the field's own rule groups and against the ledger's four kinds. State every contradiction.

5. Build the controlled vocabulary. Define each mechanism term once in `docs/reference/terminology.md`. Each principle uses the terms in its test, not in a preamble. A term that does not appear in a test is decoration.

6. Run the signalling experiment through the `eval` skill. Take 20 corpus sentences. Produce two rewrite conditions, one that states the rule in plain words and one that states it with the domain terms. Grade blind on whether the rewrite fixes the failure class. Report the counts and the falsifier. State the outcome even if the jargon loses.

7. Classify the result in the ledger. A mechanism principle with no observer is a judgement, observer `none`.

## Deliverable

A discussion document with the taxonomy, the coverage matrix, the agreement, the reconciliation, and the experiment; the vocabulary patch; the eval case; and the evidence. Do not file a principle skill and do not edit a principle skill.

## Stop conditions

Stop and report if the coverage matrix shows two axes are not separable, if agreement is too low to call the taxonomy a partition, or if the signalling experiment shows no difference between the two conditions.
