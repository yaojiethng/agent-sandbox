---
status: concluded
date: 2026-11-14
---

# Design - The judgement corpus is admitted by case

## Context

A corpus-wide semantic pass cannot keep the judgement corpus coherent at a cost or reliability the operator will accept. A model cannot categorize every rule and extract duplicates reliably; the operator will not adjudicate every classification; evals are uncertain under the current infrastructure. The leitwort pass was reverted (`20261028-06`), the trigger repair reached only ten principles (`20261029-01`), and a duplicate schema field landed while the relevant judgement was in context (`20261103-04`).

The corpus also has no single home for the relay class: a bridge document, a forwarding function and a staging-ground config each add no guarantee the party across the hop does not already hold, and the fragments that touch it are scoped elsewhere. That case is the first admission.

The problem is not detection at corpus scale. It is that the only cheap moment for the semantic decision is when a judgement is proposed, where the new case and its nearest neighbours are the whole context.

## The judgement this settles

A judgement enters or changes by an **admission decision**: the author names the nearest existing judgements, the distinction, and the case that demanded the rule; the operator decides. The declaration is `metadata.neighbours`, a list of full skill names.

- The field lists neighbours only. A handoff ("apply this next") is a different edge and stays in prose.
- The body's scope statement carries the meaning. A per-neighbour explanation is not stored; the patterns in standards, lint catalogs and legal codes carry a scope and a citation, and the boundary is argued where a case contests it.
- A contested distinction lives in the admission record, which is this corpus's case law, not in every skill.
- `neighbours: []` declares that a judgement has no neighbour. An absent field is undeclared.

## The mechanism

**A -- the admission pattern.** A pattern under `instruction-authoring` carries the question, the neighbour search, the case, and the operator's decision. Step 1 cites it, because "does this purpose already have a judgement?" belongs where the purpose is settled. The `scope` prompt's `## Check the boundary` cites it when the unit is a judgement, so the boundary is drawn before the authoring handoff.

**B -- the lever and the gate.** A deterministic inventory script reads the repo-owned provider root (`src/reasoning/agent-runtime/pi/config/agent/skills/`, 25 judgement skills) and extracts `metadata.neighbours`. It reports structural facts only: a name that does not resolve, a judgement with no field, an explicit `[]`, a duplicate name. It makes no semantic judgement.

The gate checks liveness and presence:

- every declared name resolves to a live judgement skill;
- every judgement carries the field or is named in a baseline;
- the baseline holds the existing judgement skills and must only shrink: the gate fails if a baseline entry now carries the field and the baseline is not updated.

The baseline makes the check enforceable before the migration completes. It is a gated copy, not a registry: its only consumer is the gate, and the gate forces it to shrink.

## The replay set

The replay freezes a historical case, runs the lever and the admission question as if the judgement were proposed now, records the operator's decision, and compares it with the historical outcome. A miss is a finding, never a silent gap.

| Case | What it tests | Replay expects |
|---|---|---|
| Passthrough (this session) | a missing general judgement | the lever surfaces SSOT, materialization and `cut-what-serves-nothing`; the operator distinguishes the relay class and lands it as a sibling |
| `absent` schema field (`20261103-04`) | a duplicate guarantee | the lever surfaces SSOT and the bump merge; the operator refuses the field |
| Boundary merge (`20261104-04`) | two judgements stating one situation | the lever surfaces the pair; the operator merges them |
| `cut-what-serves-nothing` rename (2026-11-05) | a judgement changes its unit | the lever surfaces SSOT and the bridge case; the operator records the new unit and its neighbour |

Excluded, with reason:

- **The leitwort revert** (`20261028-06`) is a naming decision, not a judgement gap.
- **The review-runbook purpose gap** (2026-10-31) is a standard without a stated purpose, not a duplicate judgement.
- **The materialization rename** (`20261028-09`) is a trigger and description failure; the neighbour field does not test descriptions.

## What the gate cannot decide

The gate cannot judge whether the named neighbour is the right one, whether the distinction is real, or whether a handoff was mislabelled as a neighbour. Those are the admission decision. The gate is the mechanical half; the operator is the semantic half.

## Rejected

- **A periodic whole-corpus semantic pass.** Intent failure: the semantic judgement is unreliable at that grain, the operator becomes the ground truth, and the cost repeats.
- **Any Markdown link as the edge.** Intent failure: it conflates handoffs with neighbours, so orphanhood becomes a false proxy.
- **A canonical neighbour body part.** **Neither**: it is correct and keeps one carrier, but the operator chose a machine index independent of prose. The body part would put the machine edge in text the lever parses and give up the field's explicit shape.
- **Reciprocity.** Intent failure: it forces a link into the neighbour for every one-way distinction, manufacturing edges to satisfy the gate.
- **No baseline; gate the corpus at once.** Execution failure: it forces a full semantic review before the gate can land.
- **An eval of model categorization.** Intent failure: nondeterministic under the current infrastructure, and it measures the model rather than the mechanism.

## Open questions

- The replay decides whether A+B stands. If it fails, the catch-all bin (C) is the fallback and the full mechanism does not open as a sub-milestone.
- The migration is the scope brief's work table: the lever extracts candidate neighbours from the existing prose, the agent proposes the field, and the operator reviews the batch. The baseline shrinks as the fields land.
- The `metadata.neighbours` field needs the ADR entry recorded in `docs/adr/principle_skill_shape.md`, because it reopens the 2026-10-28 decision that a principle carries the body shape and nothing else.

## Evidence

- Handover `20261114-01`, which records the decisions and the plan session.
- The scan of 2026-11-14: 25 judgement skills in the provider root; 54 judgement directories across the provider root and `$AGENT_HOME`, most with no outgoing judgement link under the narrow definition. The installed home carries extras and stale duplicates, so the lever reads the provider root.
- `devlog/AGENT_FEEDBACK.md` entries of 2026-10-29 and 2026-11-03; handovers `20261028-06`, `20261028-09`, `20261029-01`, `20261103-04`, `20261104-04`.
