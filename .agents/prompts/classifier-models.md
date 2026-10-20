---
name: classifier-models
description: "When a classifier model earns its call on pi, the four checks to run before one, and the register of times one returned nothing useful."
---

# Classifier models

A classifier answers typed questions about one piece of state and returns probabilities. It measures variation in text. It cannot adjudicate meaning, and it cannot be evidence for the caller's own hypothesis.

## Before the call

Answer all four. A "no" anywhere means the classifier is not the instrument.

1. **Which decision reads the probability, and what threshold moves it?** A number that nothing branches on is decoration. Name the decision, the cut, and what happens on each side.
2. **Does the corpus carry contrast?** A control set, or items known to differ. Without it the classifier partitions one sample, and the partition is an artifact of the 0.5 cut rather than a finding.
3. **Are the questions the caller's own restatement of the hypothesis?** Then a matching answer restates the prior, not the world. Use it to select items for a read, never to conclude.
4. **What does the run cost in requests, and what changes if it returns nothing?** If nothing changes, the arm is cost with no branch.

## Invoke

- pi, the classifier section: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md#use-classifier-models
- The Jev model, worked through: https://huggingface.co/blog/sora-2/how-to-use-the-jev-ai-model-a-step-by-step-develop

Three facts the call itself rests on:

1. One call takes one `state` and a set of questions keyed by id. Several questions ride one call; several items take one call each.
2. The caller chooses the answer shape. A `bool` returns a probability, a `score` a position on the criteria you wrote, a `choice` a distribution over the labels you supplied. A caller who supplies labels has already chosen the taxonomy.
3. One call is one request against the provider's quota. On the free tier that quota is the day's binding limit, so count the calls before the run, not after.

## Antipatterns

One entry per incident, five lines: what was asked, what it cost, what came back, why it failed anyway, the rule. Newest first.

### 2026-10-19 - a probe matrix that no decision read

- **Asked:** whether 21 prose-failure events separated on five properties - a word held in memory, an actor named, a term defined, two readings, a past fact where a current rule belongs. Source: `devlog/discussions/20261019-report-settled-neutral_principle_census.md`.
- **Cost:** 21 of the day's 200 `opencode-free` requests, inside a five-dispatch run.
- **Returned:** seven clusters, the largest holding 9 of 21 events. Two probes were near-constants: the term probe fired on 17 of 21 (median 0.81), the past-fact probe on almost none (median 0.08).
- **Why it failed although the call was correct:** the method's verdict came from three blind coders and one adversarial coder, and nothing read the probabilities, so no honest result could have moved the decision. The five probes restated the plan's own hypothesis, so agreement with them proved nothing independent. And the 21 events carried no control set, so the clusters partitioned one sample.
- **Rule:** checks 1, 2 and 3 in `## Before the call` each fail here. Run them before the call, and write the call count and its quota cost into the plan.

Add the next entry with the same five lines and a dated `###` heading.
