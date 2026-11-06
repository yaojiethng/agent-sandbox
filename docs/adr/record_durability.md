# Record durability

**Current:** 2026-11-05

## 2026-11-05 -- The determination belongs to work-log, and a discussion record dies with its task

**Decision:** The determination belongs to the `work-log` convention, which owns `devlog/discussions/` and states when a discussion record is opened, when it ends and what inherits it. The `decision-records` convention owns `docs/adr/` and states the ADR side instead: the entry is the authority and does not restate the evidence. This entry records why that is the ruling and fixes the shape it rests on. The record's state is one region of a two-region machine, tenancy being the other, so the state set is `open`, `concluded` and `rejected`, with deletion as the terminal transition. `draft` and `active` merge into `open`, `superseded` merges into `rejected`, and `archived` is removed. `documentation_taxonomy.md` keeps the classification of record kinds and cites the determination, as does the shape `work-log` states. The model is drawn at `docs/reference/workflow_statechart.md` `## The discussion record`.

**Rationale:** The 2026-09-30 entry decided durability and left the determination unstated, so seven statements filled the gap and contradicted each other: this file called a closed record subsumable while `work-log` forbade deleting a study and offered no delete transition. Two facts were also conflated. Whether the enquiry has reached its result and whether the task that owns the record is still open move independently, and a single status column cannot carry both -- which is why records sit in `draft` and `active` months after the row that produced them closed. Ownership follows the object rather than the act: the record lives under `devlog/discussions/`, which `work-log` owns, and `decision-records` owns `docs/adr/`; the first draft of this entry gave the determination to the convention that owns the settling, and the settled text corrects that. Splitting them makes deletion a transition between two states rather than a state the vocabulary lacked, and it makes the state observable: the enquiry reads from the file, tenancy reads from the roadmap. The ground for deleting rather than archiving is `principle-single-source-of-truth`, whose unit is a subject together with a mode: once the ADR holds the subject in explanation, the record is a second source in the same mode, and archiving preserves exactly what the principle removes.

**Rejected alternatives:**

- *Give the determination to `decision-records`, because it owns the settling.* **Boundary failure**: ownership follows the object, and a record under `devlog/discussions/` is the `work-log` convention's, so the rule would sit in a component that does not own what it governs.
- *Let the taxonomy own the determination.* **Boundary failure**: the taxonomy answers what kind of document this is, not how long evidence lives before a decision is durable, so the rule would sit where the writer never reads it. The ADR's own clause naming the concept document the single owner of the classification narrows to that object, and the determination is named beside it.
- *Record an absorber, naming the document that consumed the record.* **Intent failure**: one record feeds several documents at once -- its decisions to an ADR, its design and implementation notes to a reference document, its operation to a handover -- so no single absorber exists, and the field would be wrong for most records.
- *Keep `archived` as the terminal and delete by exception.* **Intent failure**: archiving keeps the second source the principle removes, and the state has no instance in the 38 records the tree holds.
- *One chart per type.* **Execution failure**: the four types differ in the guard that concludes the enquiry and in the dependent that sends the event, not in their states, so four charts are four copies of one model.
- *Let the record name its roadmap row.* **Execution failure**: a row has no identity but its prose title, which compaction rewrites, so the join is on unverified text; a filename is unique and stable, so the row names the record and a closed row strips its link.

**Edge cases / drivers:** A record whose row never closes keeps its file, whatever its state. An inheriting row re-points the record and the closed row strips its link, which makes the compaction survival table's "design document links survive" obsolete -- that rule and the two files carrying it are follow-on rows. Records dated before 2026-11-05 keep the old state tokens until they are substantively edited, and the name gate's cutover moved to that date for the same reason. The `report` type stays: a review or audit report is composed across iterations and lives while it is being processed, so it meets the criterion the type was first thought to fail.

## 2026-09-30 -- Discussion-family records are reference-durable; the ADR is the durable home of record

**Supervened in part** by the 2026-11-05 entry, which sets the record's life, its states and its owner; the durability class below stands.

**Decision:** A discussion-family record (story, study, design, or report) is reference-durable, not permanent. It stays as a reference for future work units for the course of the implementation it describes; after that implementation it is subsumable and may be cleaned up or subsumed when several records overlap, existing content is more stale than current, or names conflict. The approaches considered and the knowledge tested that a discussion used to hold now surface, in summary, in the ADR, which is the durable home of record. Durability is a classification (a model) and lives in the concept document; the policies and ADRs that depend on it link back.

**Rationale:** The story and study policies still framed a closed record as a permanent reasoning trace ("never deleted"). ADRs changed the durable seat: approaches and knowledge moved into ADRs and final documents in summary. A discussion record remains useful as a reference through the implementing work but is not a maintained reference after it. "Reference-durable" reconciles the sub-policies with the concept-document durability classification and with the ADR as the surfacing home.

**Rejected alternatives:**

- *Keep the permanent-reasoning-record framing* -- intent failure. It contradicts the ADR-as-durable-home model and the operator's practice of cleaning up or subsuming records.
- *Classify discussion records as durable* -- intent failure. They are evidential work in progress that settles into ADRs and final documents; only the settled principle survives in the ADR.

**Edge cases / drivers:** More than one record overlapping, content more stale than current, and a naming conflict each justify cleanup and subsumption. The concept document is the single owner of the durability classification; the ADR records why.
