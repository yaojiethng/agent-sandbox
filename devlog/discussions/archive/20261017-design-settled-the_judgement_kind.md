# The judgement kind in the authority doctrine

**Status:** settled

## Context

The M3.3.4 row *Retire the authority doctrine where a principle must be its own home* states its premise in one sentence: the doctrine holds that a rule outside policy is not binding, a principle skill is its judgement's only home, so the doctrine forbids the corpus by the project's own rule.

Read against the doctrine's own definition, that premise does not hold. `documentation_policy.md` `## Rule authority` defines its subject: "A statement is a rule when it imposes an obligation a document or its author must meet." A principle imposes no obligation, and M3.3.4's own text says so: "A principle here is a convention, not a rule. It cannot be enforced, so it carries no gate and no authority claim." A principle is therefore outside the doctrine's subject and needs no exemption from it.

What the carriers actually do is fail to name the judgement, so a reader who meets a principle must file it as a rule, and the rule bucket carries a policy-home requirement. Two carriers say so outright. `prompt-authoring-conventions.md:28` says an advisor "holds judgement rules", and `:56` forbids an advisor from carrying "an authoritative rule". `:60` says "A constraint that exists only in a skill is not authoritative", and "constraint" covers more than "rule". The defect is a missing kind and an overloaded word, not a rule worth deleting.

## Options Considered

- **Delete the authority claim at every carrier**, the row's literal reading. Removes the `## Rule authority` section, and with it the canonical-owner test, the producer-owns-the-definition rule, the no-bridge rule and the policy-membership rule. Three live pointers then break (`agent_workflow.md:145`, `documentation_taxonomy.md:66` and `:75`), `doc-maintenance` and `prompt-authoring-conventions.md:105` lose the test they apply, and M3.3.2's opening row exists to retire the *echoes* of this section, so the echoes would outlive their owner. Rejected: it deletes true rules to remove a false inference.
- **State the judgement as a third kind, then scope every carrier to rules.** The doctrine keeps its subject and gains the kind it lacks. One definition, at one home, and each over-broad carrier loses a word or a clause.
- **Do nothing, on the ground that the milestone already states the reconciliation.** Rejected: the milestone is a roadmap row, and no author reads it mid-draft. The collision at `:28`, `:56` and `:60` survives.

Adopted: the second.

## Decision

**The kind is defined once, in `prompt-authoring-conventions.md`, in `## Identify the document type`.** A statement is a *judgement* when it states how a writer decides, and it lives in the principle skill that states it, which is that judgement's only home. A judgement carries no gate and no authority claim. `documentation_policy.md` `## Rule authority` states the rule-versus-model split as it does today and adds one deferring clause for the judgement kind, so the classification keeps a single owner and the policy keeps its anchor.

The home is the authoring bar rather than the policy section for three reasons. The authoring bar survives the policy retirement M3.3.2 executes, so the definition does not move twice. It is the document a prompt or skill author opens. And the three carriers that over-reach are the bars inside it.

**The two over-broad carriers are narrowed in place.** `prompt-authoring-conventions.md:60` reads "A constraint that exists only in a skill is not authoritative" and becomes "A rule that exists only in a skill is not authoritative", pointing at the new kind for the judgement. `:28` reads "an advisor holds judgement rules" and becomes "an advisor holds judgements and reference facts", which removes the phrase that made a judgement a rule. The advisor bar at `:56` and the consumer rule at `:100`-`:105` keep their force, now unambiguously over rules.

**The `doc-advisor-policy` prompt is verified, not edited.** The bar it cites at `:28` is `prompt-authoring-conventions.md:86`, "a prompt is never the only home of a rule", and that bar survives in rule scope. The citation stays true, so no edit reaches the pi prompt root.

**The ADR records the change.** `docs/adr/policy_declarative_framing.md` carries the 2026-09-30 authority entry as its current decision. Per `adr_policy.md` `### Editing procedure`, a new dated entry becomes `Current:`, the authority entry moves to the historical position with a line naming why the old pattern was rejected, and its rationale is not rewritten.

## Consequences

- A principle skill is legal by the project's own rule, which is what M3.3.4 exists to unblock.
- `## Rule authority` and its `#rule-authority` anchor survive, so the three inbound pointers resolve and M3.3.2 still has a canonical owner for the echoes it retires.
- The split-criterion row gains a third type to resolve. The classification sentence now lives in the authoring bar, so when that row files a principle for it, the sentence moves rather than being copied.
- The roadmap row is narrower than what lands. It is reworded at close from *retire the authority doctrine* to *scope the authority doctrine to rules*, with the judgement kind as what unblocks the corpus.

## Evidence, measured

The census instrument is `scripts/check_norm_ownership.sh` and its ledger `scripts/lint/norm-ownership.tsv`, one row per prose line of both source documents, keyed on the line's hash so an edited sentence loses its kind. It reads 167 rows: 23 gated, 20 reviewed, 85 judgement, 39 model.

The kind was tested for reliability on a 20-row sample drawn every eighth row. Round one, with the criterion as first written, gave 12 of 20 agreement between two independent classifiers, 60 percent. The failures clustered on two boundaries: a line that describes a classification and also asks for something, and a line whose nearest check is a general reading habit rather than a named one. Two tie-breakers were added, a line's kind follows its main clause, and `rule-reviewed` requires a procedure whose text names the check and a prompt that dispatches it, plus one worked example per kind. Round two gave 18 of 20, 90 percent. The two residuals are named: a placement sentence phrased as a fact, and a preference whose adjacent observer checks resolution but not the preference.

The carry-over matrix over the two closed retirements was not run. The design's landing map and the retirement records name where each section went, and the spot checks agreed, but a section-by-section reconciliation was not produced, so a rule lost in either slice is not yet excluded.
