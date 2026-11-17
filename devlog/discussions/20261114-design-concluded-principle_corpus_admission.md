---
status: concluded
date: 2026-11-14
---

# Design - The principle corpus is admitted by case

## Context

A corpus-wide semantic pass cannot keep the principle corpus coherent at a cost or reliability the operator will accept. A model cannot categorize every rule and extract duplicates reliably; the operator will not adjudicate every classification; evals are uncertain under the current infrastructure. The leitwort pass was reverted (`20261028-06`), the trigger repair reached only ten principles (`20261029-01`), and a duplicate schema field landed while the relevant principle was in context (`20261103-04`).

The corpus also has no single home for the relay class: a bridge document, a forwarding function and a staging-ground config each add no guarantee the party across the hop does not already hold, and the fragments that touch it are scoped elsewhere. That case is the first admission.

The problem is not detection at corpus scale. It is that the only cheap moment for the semantic decision is when a principle is proposed, where the new case and its nearest neighbours are the whole context.

## The decision this settles

A principle enters or changes by an **admission decision**: the author names the nearest existing principles, the distinction, and the case that demanded the rule; the operator decides. The declaration is `metadata.neighbours`, a list of full skill names.

- The field lists neighbours only. A handoff ("apply this next") is a different edge and stays in prose.
- The body's scope statement carries the meaning. A per-neighbour explanation is not stored; the patterns in standards, lint catalogs and legal codes carry a scope and a citation, and the boundary is argued where a case contests it.
- A contested distinction lives in the admission record, which is this corpus's case law, not in every skill.
- `neighbours: []` declares that no neighbour is declared. An absent field is undeclared; a principle the survey finds with no neighbour is recorded on the survey map, not in a different field value.

## The mechanism

**A -- the admission pattern.** A pattern under `instruction-authoring` carries the question, the neighbour search, the case, and the operator's decision. Step 1 cites it, because "does this purpose already have a principle?" belongs where the purpose is settled. The `scope` prompt's `## Check the boundary` cites it when the unit is a principle, so the boundary is drawn before the authoring handoff.

**B -- the lever and the gate.** A deterministic inventory script reads the repo-owned provider root (`src/reasoning/agent-runtime/pi/config/agent/skills/`, 25 principle skills) and extracts `metadata.neighbours`. It reports structural facts only: a name that does not resolve, a principle with no field, an explicit `[]`, a duplicate name. It makes no semantic decision.

The gate checks liveness and presence:

- every declared name resolves to a live principle skill;
- every principle carries the field or is named in a baseline;
- the baseline holds the existing principle skills and must only shrink: the gate fails if a baseline entry now carries the field and the baseline is not updated.

The baseline makes the check enforceable before the migration completes. It is a gated copy, not a registry: its only consumer is the gate, and the gate forces it to shrink.

## The replay set

The replay freezes a historical case, runs the lever and the admission question as if the principle were proposed now, records the operator's decision, and compares it with the historical outcome. A miss is a finding, never a silent gap.

| Case | What it tests | Replay expects |
|---|---|---|
| Passthrough (this session) | a missing general principle | the lever surfaces SSOT, materialization and `cut-what-serves-nothing`; the operator distinguishes the relay class and lands it as a sibling |
| `absent` schema field (`20261103-04`) | a duplicate guarantee | the lever surfaces SSOT and the bump merge; the operator refuses the field |
| Boundary merge (`20261104-04`) | two principles stating one situation | the lever surfaces the pair; the operator merges them |
| `cut-what-serves-nothing` rename (2026-11-05) | a principle changes its unit | the lever surfaces SSOT and the bridge case; the operator records the new unit and its neighbour |

Excluded, with reason:

- **The leitwort revert** (`20261028-06`) is a naming decision, not a principle gap.
- **The review-runbook purpose gap** (2026-10-31) is a standard without a stated purpose, not a duplicate principle.
- **The materialization rename** (`20261028-09`) is a trigger and description failure; the neighbour field does not test descriptions.

## Replay results

Run 2026-11-14 against a copy of the provider root with a draft for each case. The draft's prose links are the neighbours its author would have declared; the lever reports them, and the historical decision is the comparison. The boundary case restores `principle-delegation-over-machinery` as a stub because the replay is the historical state; the rename case removes the new name and adds the old one, for the same reason.

| Case | Lever candidates | Historical decision | Cost | Verdict |
|---|---|---|---|---|
| Passthrough | `communication-principle-cut-what-serves-nothing`, `principle-justify-materialization-cost`, `principle-single-source-of-truth` | Distinguish the relay class and land it as a sibling | 3 principles, 1 decision | Caught |
| `absent` schema field (`20261103-04`) | `principle-single-source-of-truth` | Refuse the field; the bump's local diff already computes it | 1 principle and 1 deciding document | Caught |
| Boundary merge (`20261104-04`) | `principle-delegation-over-machinery`, `principle-single-source-of-truth` | Merge into SSOT and retire the delegation skill | 2 principles, 1 decision | Caught |
| `cut-what-serves-nothing` rename (2026-11-05) | `principle-single-source-of-truth` (its awkward bridge case) | Record the new unit and its neighbour | 1 principle and 1 section, 1 decision | Caught |

All four are caught with one decision, so A+B stands and the field, gate and migration rows proceed.

The lever surfaces the links the draft declares; it does not infer a neighbour the draft never names, and the deciding document can sit outside the principle corpus, as the bump runbook does in the `absent` case. That is the admission decision's half, not a miss: the lever makes the candidate set small and visible, and the operator decides.

## What the gate cannot decide

The gate cannot judge whether the named neighbour is the right one, whether the distinction is real, or whether a handoff was mislabelled as a neighbour. Those are the admission decision. The gate is the mechanical half; the operator is the semantic half.

## Rejected

- **A periodic whole-corpus semantic pass.** Intent failure: the semantic decision is unreliable at that grain, the operator becomes the ground truth, and the cost repeats.
- **Any Markdown link as the edge.** Intent failure: it conflates handoffs with neighbours, so orphanhood becomes a false proxy.
- **A canonical neighbour body part.** **Neither**: it is correct and keeps one carrier, but the operator chose a machine index independent of prose. The body part would put the machine edge in text the lever parses and give up the field's explicit shape.
- **Reciprocity.** Intent failure: it forces a link into the neighbour for every one-way distinction, manufacturing edges to satisfy the gate.
- **No baseline; gate the corpus at once.** Execution failure: it forces a full semantic review before the gate can land.
- **An eval of model categorization.** Intent failure: nondeterministic under the current infrastructure, and it measures the model rather than the mechanism.

## Remaining work

The migration this record assumed is withdrawn. The neighbour relation is not decidable per skill: without a case, "neighbour" degrades to "shares a subject", a conflict has no state to be parked in, and unresolved edges propagate into a tangled group. The existing corpus therefore declares `[]`, the baseline is deleted with its `--update`, and the edges are produced by a survey rather than a migration. The survey, its census, the five-card dry run and the full map are on the M3.3.7 task list.

`[]` now means "no neighbour declared". A principle the survey finds with no neighbour is recorded on the survey map, not as a different field value.

## Evidence

- Handover `20261114-01`, which records the decisions and the plan session.
- The scan of 2026-11-14: 25 principle skills in the provider root; 54 principle directories across the provider root and `$AGENT_HOME`, most with no outgoing principle link under the narrow definition. The installed home carries extras and stale duplicates, so the lever reads the provider root.
- `devlog/AGENT_FEEDBACK.md` entries of 2026-10-29 and 2026-11-03; handovers `20261028-06`, `20261028-09`, `20261029-01`, `20261103-04`, `20261104-04`.
