---
name: state-machine-specification
description: "Specify a component as a state machine before writing it. Propose the states, get feedback, propose the labelled state diagram, get feedback, then derive the invariants and test cases from the model. Use when a component has modes, sources, caches, or lifecycle states that are hard to pin down, when designing or auditing a fetch, merge, or cache pipeline, when test cases pass but no edit can make them fail, or when the user asks to model states and transitions."
---

Help the operator specify a component as a state machine: enumerate its states and transitions, confirm the model, then hold the implementation to it with test cases. Work in three proposal steps. Stop after each step and wait for confirmation before starting the next.

## Terms

This skill works in the statechart domain and uses statechart terms throughout. The core ones:

- **state**: a named condition the component holds while no event is being applied.
- **event**: an input that can fire a transition.
- **transition**: an edge from a source state to a target state.
- **guard**: the condition on a transition that decides whether it may fire.
- **effect**: what a transition does besides change the state.
- **internal transition**: a transition that fires without leaving its source state.
- **ignored event**: an event that no transition accepts in the state where it arrives.

Two words look alike and are not related. A **guard** is a condition on a transition. A **gate** is a project's pass-or-fail check over the suite.

## Propose the states

In the first step, ask the operator to define the scope: which part of the system the model covers, and what it leaves out. Restate that scope in your own words, and recommend a cut. A safe cut is to model the part whose state a caller can observe, and to treat everything else as a source or a sink. Wait for confirmation before you enumerate states.

Split the confirmed scope into submachines. For each submachine, name the states it can be in and the events it accepts. When a state holds states of its own, record it as a composite state rather than flattening the hierarchy.

Separate three roles in the interaction, because they answer three different questions:

- the producer, which consults the sources and returns events
- the component, which holds the state and applies events
- the output, which turns state changes into what a caller sees

Model these as distinct states: no event has arrived; an event arrived and a guard blocked it; an event arrived and changed the state. They are three different facts, and one role cannot report all three.

Then list the events, including the ones that fire an internal transition:

- absent: the source was not consulted. A disabled network, an undeclared source.
- failed: the source was consulted and did not answer. Carry the reason.
- received: the source answered. Its contents decide which transition the event fires.

Collapse events while you enumerate. Three rules:

- Group by transition. Two events that fire the same transition, under the same guard, with the same effect are one event class. Name the class after the source and what it does, not after the payload.
- Carry only what a guard or an effect reads. A field no transition reads is not part of the event, and dropping it is what keeps the event generic.
- Name the source by kind, not by vendor. A provider or product name in an event field is a dependency the model does not need.

An event no transition accepts in any state is an ignored event. Record it next to the diagram and leave it out of the event list, because the drop is a scope decision.

Propose a candidate state set: one state per distinct situation the component can be in at rest. Ask the operator to confirm, split, merge, or add, and wait for the answer before drawing anything.

## Propose the state diagram

Draw the state diagram: its states, its initial state, and its transitions. Mark a final state if one exists. Label every transition `event [guard] / effect`: the event that fires it, the guard that can block it, and the effect it applies. The arrow names the target state.

A guard produces no output of its own, and it is never a state. A date comparison, a freshness window, or a precedence order is a guard.

Record the state diagram in the project's own documentation, not in chat. Record only what exists. A planned source gets a gap marker that names it; never write "to be amended later", because the next reader cannot tell an omission from a decision. Ask the operator for feedback, and wait.

## Enumerate the invariants

Classify each invariant by what it constrains:

- state invariant: holds whenever the component is at rest. "Ids are unique." "Every entry is usable."
- transition invariant: holds of one firing of a transition. "Fields fill first-wins." "The served order is preserved."
- guard invariant: holds of one guard. "The stored catalog is admitted only while it is newer than the built-in one."

An invariant that is none of the three is not an invariant. Rewrite it until it fits, or remove it.

## Enumerate the tests

Six rules. Apply all six. They check a suite that already exists. When none exists, they are the worklist instead: the model is the test plan, and each rule names one thing to write.

1. Every transition names at least one invariant, or records why it has none. A transition with no invariant is a finding.
2. Every state invariant and every transition invariant gets a test case, including the blocked path.
3. Every transition invariant gets a mutation: a small edit that breaks the invariant and must turn its test case red.
4. Every transition outside the normal event flow, such as creation or teardown, gets an id and a test case that can turn red on its own. A manual run is not a test case.
5. A check in the suite holds the mapping. One test case asserts that every transition id in the diagram has a case, and every case names a transition or a state id.
6. No state has two transitions on the same event whose guards can both hold, because the model then does not say which one fires. When they can, resolve it in this order:
   1. Both transitions share a target state and an effect. Replace them with one transition whose guard joins the two conditions with "or".
   2. The target states differ. Make one guard exclude the other: `g1`, then `g2 and not g1`.
   3. Neither fits. Split the state, so the event is unambiguous in each part.

Rule 3 is what makes the tests evidence. Rule 5 is what keeps the mapping true. Without it the suite stops matching the diagram, and an invariant with no case still reads as covered. Rule 6 is the one check on the diagram itself.

## Keep the gate honest

Two properties decide whether a green suite means anything:

- A failing case must name its invariant. A case that fails by crashing proves nothing about the invariant.
- A control row replays the code unedited and must stay green. If the suite cannot pass unedited, every mutation row passes for free.

## Check before you finish

- The diagram is in the project's own record and matches the code.
- The operator confirmed the states and the diagram.
- Every state invariant and every transition has a case that runs in the suite, including the blocked paths.
- Every transition invariant has a mutation row, and the control row survives.
- Every transition outside the normal event flow has an id and a case that can turn red.
- The mapping check runs with the suite.
