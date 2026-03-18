# Story Policy

Governs the creation, lifecycle, and closure of user story documents. Stories are planning tools used during the major loop to frame design problems before a solution approach is chosen. They are reasoning records — not task lists, not architecture, not current system description.

---

## Purpose

A story exists when a sub-milestone objective is understood but the approach is not. It frames the problem, surfaces constraints, and defines the investigation space. The output of a story is either a resolved design decision (graduated to a roadmap entry) or an explicit deferral (flagged for the relevant minor loop session).

A story that is never closed is a planning failure. A story that is closed without a Resolution section is not closed.

---

## Where Stories Live

Stories live in `docs/discussions/` with the prefix `story_` (e.g. `story_capability_layer_mcp.md`).

They are investigation documents, not architecture. No live links to stories are required from `architecture/` or `concepts/` documents. Stories are background reading for the decisions that produced roadmap entries — they are not referenced from current system documentation.

---

## When to Open a Story

Open a story during the major loop when:
- A sub-milestone objective is clear but the approach has not been agreed
- Multiple candidate approaches exist and need evaluation
- A constraint or threat surface needs investigation before the design can proceed

Do not open a story when:
- The design is already agreed — write the roadmap entry directly
- The uncertainty depends on an earlier sub-milestone's implementation decisions — defer and flag in the roadmap entry; the story opens during the relevant minor loop session's design step

---

## Required Sections

A story accumulates sections as it progresses. Not all sections are present at creation — they are added as the investigation advances. The fixed order makes grep-based navigation reliable.

| Section | When added | Purpose |
|---|---|---|
| **Status** | At creation | One line immediately after the title: current lifecycle state |
| **Context** | At creation | What the use case is and why it matters; 2–4 sentences |
| **Pain Points** | At creation | The concrete problems being investigated; what is broken or missing |
| **Constraints** | At creation or during investigation | Non-negotiable requirements any solution must satisfy |
| **Open Questions** | During investigation | Unresolved questions blocking progress; updated as questions resolve |
| **Investigation Findings** | During investigation | What was discovered; may be iterative subsections linked to investigation documents |
| **Resolution** | At closure | Decision reached, where the work went, why |

---

## Lifecycle States

The Status line sits immediately after the title. No preamble before it.

| Status | Meaning |
|---|---|
| `Investigation in progress` | Active — open questions remain; investigation ongoing |
| `Resolved` | Closed — Resolution section complete; work promoted to roadmap or explicitly deferred |
| `Superseded` | Closed — made obsolete by a broader architectural decision; Resolution section points to the superseding document |

---

## Graduation Criteria

A story graduates to a roadmap entry when:
- The pain point is fully understood and recorded
- All open questions that can be resolved now are resolved
- A concrete solution approach is agreed and recorded with rationale
- The resulting tasks are specific enough to enter the minor loop (each identifies a file and a nature of change)

When a story graduates:
1. Write the sub-milestone roadmap entry (objective, rationale, task list) in `roadmap_future.md` or `roadmap.md` per `roadmap_policy.md`
2. Close the story (see Closure below)
3. Remove the story from the roadmap User Stories list — the story document is the permanent record

Tasks are not duplicated back into the story. The roadmap entry is the task record. The story is the reasoning record.

---

## Closure

When closing a story:

1. Add a `## Resolution` section as the final section. It must cover:
   - The decision reached
   - Where the work went (roadmap milestone reference, or explicit deferral with reason)
   - Why — the rationale that made this the chosen approach
2. Update the Status line to `Resolved` or `Superseded`
3. If superseded by a broader decision, add a blockquote redirect immediately after the Status line pointing to the superseding document
4. Remove the story from the roadmap User Stories list

A closed story is never deleted. It is the reasoning record for the decision. Future agents and operators reading it must be able to reconstruct why the design went the way it did.

---

## Relationship to Investigations

A story may commission one or more investigation documents — one per candidate approach — when comparative evaluation is needed. The story owns the problem framing; investigations own the candidate evaluation. Investigation findings feed back into the story's Investigation Findings section as summary links.

See [`investigation_policy.md`](investigation_policy.md) for investigation format and lifecycle.

---

## Roadmap Reference

Open stories are listed in the roadmap under a `## User Stories` section with a single line and a short description. Closed stories are removed from this list. The story document itself is the permanent record.

---

## References

| Document | Purpose |
|---|---|
| [`milestone_policy.md`](milestone_policy.md) | Major loop process — when stories are opened and closed |
| [`investigation_policy.md`](investigation_policy.md) | Investigation format and lifecycle |
| [`iteration_policy.md`](iteration_policy.md) | Minor loop — where deferred stories resurface |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap update rules — User Stories section |
