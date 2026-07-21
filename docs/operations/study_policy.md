# Investigation Policy

Governs the creation, lifecycle, and closure of investigation documents. Investigations evaluate a specific candidate approach within a user story. One investigation per candidate. They run until a recommendation can be made and fed back to the parent story.

---

## Purpose

An investigation exists to answer a bounded question: is this specific approach viable, and should it be recommended? It is not an open-ended exploration — it has a defined candidate, a defined parent story, and a defined endpoint (a recommendation or a rejection with reasoning).

A well-run investigation produces a clear recommendation that the parent story can act on. An investigation that remains open indefinitely without producing a recommendation is a planning failure.

---

## Where Investigations Live

Investigation documents live in `docs/discussions/` with the prefix `investigation_` (e.g. `investigation_mcp_server.md`). One document per candidate approach. Multiple investigations may be open simultaneously for the same parent story.

Investigations are reasoning records. They are not architecture documents and are not referenced from `architecture/` or `concepts/` documents. Once closed, they are background reading only.

---

## When to Open an Investigation

Open an investigation during the major loop when a parent story has identified two or more candidate approaches that need comparative evaluation, and one investigation per candidate is warranted.

An investigation is not required when:
- A story has only one viable approach — evaluate it within the story itself
- The question can be answered by reading existing documentation or running a targeted grep
- The candidate is clearly non-viable — record the rejection reasoning in the story directly

---

## Required Sections

Investigations follow a fixed section order. The fixed order makes grep-based section navigation reliable without reading the full file.

| Section | When added | Purpose |
|---|---|---|
| **Status line** | At creation | One line immediately after the title: current state and key blocker or outcome |
| **Direction + Parent story** | At creation | Which investigation direction this belongs to; link to parent story |
| **Required reading** | At creation | Prerequisite documents; links only, no prose |
| **Summary** | At creation | What this candidate is and how it works; 2–4 sentences |
| **Findings** | During investigation | What was discovered; may be iterative subsections |
| **Open Questions** | During investigation | Unresolved questions blocking a recommendation; updated as questions resolve |
| **Constraints** | At creation or during investigation | Non-negotiable requirements this candidate must satisfy to be viable |
| **Next Steps** | During investigation | Immediate actions; replaced by Resolution at closure |
| **Resolution** | At closure | Recommendation (adopt / reject / defer), rationale, where the decision was recorded |

---

## Lifecycle States

The Status line sits immediately after the title. No preamble before it.

| Status | Meaning |
|---|---|
| `Not started` | Stub — structure created, investigation not begun |
| `In progress` | Active — open questions remain; findings accumulating |
| `Resolved` | Closed — Resolution section complete; recommendation fed back to parent story |
| `Superseded` | Closed — made obsolete by a broader decision; redirect to superseding document |

---

## Running an Investigation

An investigation advances by answering its open questions. Each finding either closes a question or opens a new one. An investigation is ready to close when:
- All open questions are answered
- A clear recommendation (adopt, reject, or defer with conditions) can be stated
- The recommendation is grounded in the findings, not in preference

During investigation, update the Findings section iteratively — do not wait until the investigation is complete to record findings. Findings recorded only in chat do not survive the session boundary.

---

## Closure

When closing an investigation:

1. Replace the Next Steps section with a `## Resolution` section. It must cover:
   - The recommendation: adopt, reject, or defer
   - The rationale grounded in the findings
   - Where the decision was recorded (parent story, roadmap entry, or both)
2. Update the Status line to `Resolved` or `Superseded`
3. If superseded, add a blockquote redirect after the Status line pointing to the superseding document
4. Update the parent story's Investigation Findings section with a summary link to this investigation and its recommendation

A closed investigation is not modified without cause. It is the reasoning record for why a candidate was chosen or rejected. Future agents must be able to read it and reconstruct the decision. Corrections to closed investigations follow the procedure below.

---

## Relationship to Parent Story

An investigation is commissioned by and subordinate to a parent story. The story owns the problem framing and the final design decision. The investigation owns the evaluation of one candidate.

When all investigations for a story are closed:
- The story's Investigation Findings section summarises each candidate's recommendation
- The story is ready to resolve: choose the approach, write the Resolution section, graduate to a roadmap entry

If a single investigation produces a clear enough recommendation that further investigations are unnecessary, the remaining investigation stubs may be closed as `Superseded` with a redirect to the adopted approach.

---

## Corrections to Closed Investigations

The full correction principle is defined in `docs/operations/documentation_policy.md` — Post-Close Document Corrections. This section defines the specific form for investigation documents.

### Valid investigation — minor error

If the investigation's core findings are sound but a detail is incorrect (wrong filename, inaccurate measurement, incomplete finding):

1. Edit the affected text directly in the body of the document.
2. Append a dated amendment block at the bottom:

```
---
[CORRECTION — YYYY-MM-DD]: <description of what was wrong and what was changed>
```

3. Do not alter the document's status, title, or metadata.
4. Propose the amended document to the operator for review.

### Invalid investigation — superseded or incorrect content

If the investigation's core content is wrong or has been superseded by properly organised work elsewhere:

1. Set the document status to `Superseded`.
2. Add a blockquote redirect after the status line pointing to the correct source:

```
> **Superseded.** This investigation has been superseded by [correct document name](path/to/document). Do not rely on the findings below.
```

3. Do not edit the body content.
4. Propose the amended document to the operator for review.

The operator may delete the document. If deleted, the operator will mark any referencing links `[REMOVED]`. The agent does not delete investigation documents.

### Missing investigations

If an investigation document the agent expects to find is absent:

- If its referencing link carries a `[REMOVED]` marker — the absence is expected. No error.
- If its referencing link has no `[REMOVED]` marker — flag as an error and prompt the operator before proceeding.

---

## References

| Document | Purpose |
|---|---|
| [`story_policy.md`](story_policy.md) | Parent story format, lifecycle, and graduation |
| [`milestone_policy.md`](milestone_policy.md) | Major loop — when investigations are commissioned |
| [`iteration_policy.md`](iteration_policy.md) | Minor loop — where deferred investigations may resume |
