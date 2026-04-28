# Story — Sequencing and Knowledge Persistence

**Status:** Open  
**Opened:** 2026-04-28  
**Sub-milestone:** TBD — pending planning session  

---

## Problem Statement

The current workflow uses a three-document set — `roadmap.md`, `roadmap_future.md`, `changelog.md` — as the planning and sequencing layer, with the handover chain as the session-level execution layer. In practice, this design has produced recurring failure modes that suggest the granularity and durability of the sequencing layer may be mismatched to how work actually executes.

The immediate policy fixes applied in M2.3 (Mid-session findings, write triggers, carry-forward escalation) address the symptoms. This story asks whether the underlying structure needs to change.

---

## Observed Pain Points

### 1. The queue-of-one problem

The roadmap queues at milestone granularity — one active sub-milestone at a time. The handover's Next session section queues at session granularity — one session at a time. Nothing queues at unit granularity (the chunked implementation pieces within a session).

When a session contains multiple implementation units (Unit 1, Unit 2, Unit 3), their ordering, dependencies, and boundaries exist only in the handover's Scope section and the agent's working memory. If the session ends mid-unit, or if steering redefines a unit boundary, the queue-of-one at each level has no place to represent this.

The result: the next session reconstructs the unit queue from incomplete signals (Deferred items, Next session prose, the spec), and frequently gets the reconstruction wrong.

### 2. Handover chain fragility

By convention, agents read only the most recent handover. Findings deferred across multiple sessions fall through — each handover passes the item forward, but without a durable record outside the chain, any gap in reading produces loss.

The carry-forward escalation rule (write to roadmap after one hop) partially addresses this. But it exposes a second problem: the roadmap's task list format was designed for coarse task groups, not for fine-grained deferred findings. A deferred finding written as a roadmap task entry looks like a planned feature, not a discovered constraint.

### 3. Write discipline in cheap models

Cheap models operating from a handover brief tend to accumulate session state in working memory rather than writing back mid-session. The write triggers (on task completion, on discovery, on steering received) are now in policy, but the incentive to write is low when writing requires reading the handover file, locating the right section, and performing a targeted edit — all before resuming the interrupted task.

The Mid-session findings section reduces this friction by providing an append-only buffer. But it is still a write that competes with forward momentum on the task.

### 4. Next session is doing two jobs

The Next session section currently serves as both an orientation brief (context, watch-outs, blocking questions) and a scheduling signal (what to do next). These are different in character. Orientation is stable — it describes a state. Scheduling is dynamic — it changes when findings arrive mid-session, when steering redefines unit boundaries, or when a unit takes longer than expected.

Conflating them means orientation prose gets overwritten when scheduling changes, and scheduling signals get buried in orientation prose.

---

## Open Questions

1. **Is the roadmap the right sequencing artifact at unit granularity?** The roadmap was designed for task groups — coarse, milestone-scoped. Representing unit-level sequencing there risks polluting the milestone planning layer with implementation detail that becomes irrelevant after the sub-milestone closes.

2. **Should there be a dedicated session plan document?** A lightweight, session-scoped artifact that represents the unit queue for the current sub-milestone — ordered, with explicit dependencies and handoff points. It would be created at scope confirmation, updated mid-session as findings arrive, and closed (not archived) at sub-milestone close. Unlike the handover, it would persist across multiple sessions within the sub-milestone.

3. **Is the roadmap + roadmap_future + changelog set sufficient?** These documents express: what is happening now, what will happen later, and what has happened. They do not express: the internal sequencing of a sub-milestone's implementation, the dependencies between units, or the findings that constrain future units. Is this a gap the document set should fill, or does it belong in a separate layer?

4. **Should Next session be split?** An orientation section (stable, written once at close) and a scheduling section (dynamic, updated when the plan changes) would separate the two jobs. The scheduling section would be the primary input to the next session's scope confirmation, not the orientation prose.

5. **How should the system represent a deferred finding that is not a task?** A bug discovered mid-session, a design gap that constrains future units, a contradiction in the spec — these are findings, not planned work. The roadmap's task format does not represent them cleanly. Is a findings register needed alongside the task list, or should findings be typed differently within the existing structure?

---

## Candidate Directions

These are not recommendations — they are options to evaluate.

**A. Expand the roadmap to unit granularity.** Add a sub-section under each sub-milestone for implementation units, with explicit ordering and dependency notes. Cheap to introduce; risks polluting milestone planning with implementation detail.

**B. Introduce a session plan document.** A new artifact type in `docs/devlog/` (alongside handovers) that represents the unit queue for the current sub-milestone. Persists across sessions within the sub-milestone; closed at Trigger B. Requires new policy and new tooling conventions.

**C. Split the handover's Next session section.** Low cost; partially addresses the queue-of-one problem without introducing new artifacts. Does not solve the multi-hop fragility problem or the findings representation problem.

**D. Redesign the scheduling layer entirely.** Treat the roadmap as planning-only; introduce a separate scheduling document set (unit queue, findings register, session plan) that operates between the roadmap and the handover. High cost; addresses all four pain points structurally.

---

## Resolution

Not yet defined. Requires a planning session to evaluate the candidate directions and select an approach before any implementation is scoped.

---

## Recommended Workflow Pattern (operator-initiated)

After each implementation session, the operator may do a brief retrospective pass: read the stuck points from the session trace, extract conclusions and gaps found, and amend the spec before the next session opens. This is not mandated by policy — it is a low-overhead practice that breaks the pattern of each agent re-deriving the same things from first principles. The policy additions in this milestone (Mid-session findings, spec amendment rule, Conclusions from this session) reduce but do not eliminate the need for this pass.
