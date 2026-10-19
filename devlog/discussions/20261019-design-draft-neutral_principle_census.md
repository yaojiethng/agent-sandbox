# The neutral principle census, and the communication-surface filing

**Status:** draft

## Context

The reduced iteration accepted on 2026-10-19 files and resolves the three communication surfaces: `documentation_policy.md` `## Communication Standards`, `prompt-authoring-conventions.md`, and the `skill-scaffolder` skill. It is the minimal execution of W2's principle-cleanup dependency, before the deep W2 taxonomy.

The existing spec census, [`20261019-design-draft-prose_standards_specs.md`](20261019-design-draft-prose_standards_specs.md), assigned all 80 judgement lines to 12 proposed principles. It carries two anchoring pressures. Its acceptance criterion is "the criterion resolves every row to one side or the other", so forced placement dilutes a principle with rows that have no home. And the worker saw the filed principles and the proposed set while it worked, so it could not induce a category outside that frame. The operator's risk is that an item deserving a new rule is stuffed into an existing one.

This design amends the method before the filing runs.

## Options Considered

- **The existing census as the method.** Rejected. Forced resolution and a visible frame are the two defects, and neither is removed by re-running it.
- **GLM 3.5 advisors.** Partial. Model-family diversity is the right lever, because two deepseek-family coders share a bias. A "classify onto broad groups" instruction re-anchors them, so the instruction must be bottom-up and must allow a category that is not in any list shown.
- **Jev as a classifier onto broad groups.** Rejected in that form. A `choice` question takes `criteria` as a map of label to meaning, so the labels are supplied by the caller. That is the same prescribed frame, and it cannot induce a category. Jev is useful as a probe and measurement instrument instead.
- **The original procedure, then compare.** Kept, as the baseline arm and the control.
- **Adopted: a triangulated census, four arms, with Jev as the probe instrument.** The induction sits with the generative coders and the adversarial pass; Jev measures whether the induced axes separate the events.

## Decision

### The unit of analysis

Code failure events, not prose lines. A principle earns its place by a real misreading. A prose line that states a rule no event exercises is a candidate for deletion, not filing. This is the delete test applied to principles.

### Arm A, the baseline

The existing spec census. It stops being the answer and becomes one arm. Its 12 proposed principles, in [`20261019-design-draft-prose_standards_specs.md`](20261019-design-draft-prose_standards_specs.md).

### Arm B, blind open coding

Three coders on three model families, one of them GLM. Each receives only the raw failure events, the sentence and the misreading. No category list, no existing principle, no ledger. Each returns its own named categories and places every event, with a mandatory residual bucket. This is grounded-theory open coding, and it is the only arm that can surface a category the frame lacks.

### Arm C, the Jev probe matrix

Jev does not choose a category. For each failure event, ask a battery of narrow, observable probes as `bool` and `score` questions, and read the probabilities.

Candidate probes, each stated as a property of the text and not as a principle name:

- must a reader hold a word in memory before it can attach it.
- does the sentence name the actor of the main action before the reader needs it.
- does the sentence use a term before the reader has met it.
- can the sentence be read with two incompatible meanings.
- does the sentence state a fact about the past where a current rule is needed.

Cluster the answer vectors and read the natural groupings. No label set is imposed.

### Arm D, the adversarial coder

One coder instructed to falsify the existing partition. For every event, argue either that the event belongs to no current principle, or that the current principle is over-broad to predict it. This is the cheapest single guard against dilution.

### The pre-registered comparison and decision rule

Fix the rule before any coder runs, so the result cannot be rationalized after.

- A candidate new rule is accepted when at least two of the three blind coders induce it independently, and it is not a restatement of an existing principle.
- A merge is accepted when every coder collapses the same two principles.
- An event no coder places is under-specified and becomes its own finding.
- Report pairwise agreement among the blind coders. Without a number, "we found a new rule" is one model's opinion.

### The reduced filing and resolution

Run this only after the census settles.

- `documentation_policy.md` `## Communication Standards`: file the prose principles that survive the census. Leave the structure remainder, rule placement and reserved terminology. Replace each filed judgement row with a pointer to its skill.
- `prompt-authoring-conventions.md`: file the writer judgements that survive. Leave the document-structure rules for M3.3.2 and M3.3.3.
- `skill-scaffolder`: the skill is installed under `$AGENT_HOME` and the repository cannot edit it. Record the duplicate declaration, align the repository-owned conventions, and route the fork through the M3.3.3 pipeline.
- File the subset that carries the duplication. Do not file all 12 census principles here; that is the plan's normal tranche.
- Regenerate `scripts/lint/norm-ownership.tsv` and classify every new line. A moved judgement leaves its source line and becomes a pointer, classified `model`.

### The blocker and its fix

Codemode is off unless a server enables it. The `models.classify` path is unreachable and no `codemode` tool is declared. Enable it with `"defaultTools": ["+codemode"]` in `$AGENT_HOME/agent/settings.json`, and start a fresh session so the tool is declared. No `TYPESAFE_API_KEY` is set; the reachable routes are `openrouter/typesafe/jev-1.13` and `opencode/jev-1.13-free`.

## Consequences

- W2 keeps the taxonomy as theory, the corpus beyond the failure events, the controlled vocabulary, and the signalling experiment. This design supplies the census method and the minimal filing, and it feeds W2.
- Jev returns in W2 as the blind grader for the signalling experiment, because an LLM grading its own family's rewrites is biased.
- The neutrality caveat stands. The probe criteria are still a prior, so probes are stated as observable properties and two or three probes cover one axis.
- The cost is three blind coders, one adversary, one Jev matrix, and one comparison. The free tier is quota-limited, so the coders run serially or on separate providers.
- The reduced label is honest only if the filing stays a subset. Filing all 12 principles is the full tranche, not the reduced version.
