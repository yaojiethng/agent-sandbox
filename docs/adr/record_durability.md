# Record durability

**Current:** 2026-09-30

## 2026-09-30 -- Discussion-family records are reference-durable; the ADR is the durable home of record

**Decision:** A discussion-family record (story, study, design, or report) is reference-durable, not permanent. It stays as a reference for future work units for the course of the implementation it describes; after that implementation it is subsumable and may be cleaned up or subsumed when several records overlap, existing content is more stale than current, or names conflict. The approaches considered and the knowledge tested that a discussion used to hold now surface, in summary, in the ADR, which is the durable home of record. Durability is a classification (a model) and lives in the concept document; the policies and ADRs that depend on it link back.

**Rationale:** The story and study policies still framed a closed record as a permanent reasoning trace ("never deleted"). ADRs changed the durable seat: approaches and knowledge moved into ADRs and final documents in summary. A discussion record remains useful as a reference through the implementing work but is not a maintained reference after it. "Reference-durable" reconciles the sub-policies with the concept-document durability classification and with the ADR as the surfacing home.

**Rejected alternatives:**

- *Keep the permanent-reasoning-record framing* -- intent failure. It contradicts the ADR-as-durable-home model and the operator's practice of cleaning up or subsuming records.
- *Classify discussion records as durable* -- intent failure. They are evidential work in progress that settles into ADRs and final documents; only the settled principle survives in the ADR.

**Edge cases / drivers:** More than one record overlapping, content more stale than current, and a naming conflict each justify cleanup and subsumption. The concept document is the single owner of the durability classification; the ADR records why.
