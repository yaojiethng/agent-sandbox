---
name: novel-bug-hunter
description: Hunt the novel defects in one component -- the ones no test, mutation row or invariant case anticipates -- and deliver each as a reproducer and a gate gap. Use when a component's gates are green and the question is what they cannot see.
disable-model-invocation: true
---

# Novel-Bug Hunter

Find the defects in a component that its gates cannot see. The suite, the mutation corpus and the invariant report are green by assumption; the hunt is the residue they were built without.

## Done looks like

A finding that reaches the record carries four things:

1. a minimal reproducer that fails today;
2. the invariant it violates, named from the contract;
3. the gate that stayed green, and the reason it could not see this;
4. the check that would have caught it.

A run that finds nothing is done only when it states why the contract is fully covered: which invariants were exercised, by which execution, and what change would let the gate miss one.

## The contract is the target

The unit is the component, not the diff. A change may trigger the run; the sweep covers the whole contract, because a novel defect lives where the change meets the part no test drives.

Read the component's contract record for its states, transitions and invariants. If the component has no model, the contract is produced first: the hunt has no target without one.

An invariant is one of four kinds: a state property, a transition property, a guard property, or a policy property about the gate itself.

## Evidence rules

- A finding is reproduced before it is recorded. One the confirmation pass cannot reproduce is dropped.
- A surviving mutation is a lead, not a result: classify it as a coverage gap or a code row before it counts as evidence.
- A test that cannot turn red is not evidence; a manual run is not a test.
- The hunters never commit. The main agent commits.

## The register

The run writes a register pair: a JSON Lines file, one object per finding, and a prose report beside it. The pair sits beside the run's log, under the session's scratch directory. The schema is [`references/register.md`](references/register.md); the report skeleton is [`assets/report.md`](assets/report.md).
