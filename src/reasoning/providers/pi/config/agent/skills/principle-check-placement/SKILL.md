---
name: principle-check-placement
description: "A check reads evidence and produces a decision. Apply when placing, moving or adding a check, a verification step or an audit. Put it where its evidence first exists and where its decision is cheapest to take."
---

# Place the check at its input

A check reads evidence and produces a decision. Put the check where the evidence first exists, and where the decision is cheapest to take.

**The pattern.**

1. Name the decision the check takes. A check with no decision is a reading.
2. Name the record that carries the evidence, and the step that produces the record.
3. Place the check at the step after that producer.
4. Name the gate that owns the decision. Where no gate owns it, the decision waits for the close. The close can then only repair work that is already finished.

**Why.** A check that runs before its evidence exists has nothing to read. It guesses, and the guess reads as a verdict. A check that runs after its gate takes the decision can only edit work that is already finished. Every such edit costs a second pass over the same artifact.

**Three signs a check is misplaced.** The evidence is stale when the check runs. The check decides again what a reader already decided. The check's output is an edit to a record that already passed its gate.

**Stop.**

- Place the check by the order of the evidence, not by the order of the sections.
- Ship a check only where the violation can occur. A violation that cannot occur reports zero on every run and costs a run every time.
- Put a rule that a lint can check with the lint. `/opt/sandbox/docs/reference/agent_workflow.md` `### Norm kinds` states the kinds and their homes.

**The test.** Name the record the check reads and the gate that owns its decision. If you cannot name both, the check is misplaced.

Related: [`principle-minimal-corrections`](../principle-minimal-corrections/SKILL.md) treats a repair commit as a sign that a check ran too late. `principle-encode-lessons-in-structure` covers the placement a mechanism can detect. `principle-sequence-verifiable-units` sequences the units of work rather than the decisions.
