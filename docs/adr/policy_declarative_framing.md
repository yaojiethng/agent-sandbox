# Policy Declarative Framing

**Current:** 2026-09-30

## 2026-09-30 -- Discussion-family records are reference-durable; the ADR is the durable home of record

**Decision:** A discussion-family record (story, study, design, or report) is reference-durable, not permanent. It stays as a reference for future work units for the course of the implementation it describes; after that implementation it is subsumable and may be cleaned up or subsumed when several records overlap, existing content is more stale than current, or names conflict. The approaches considered and the knowledge tested that a discussion used to hold now surface, in summary, in the ADR, which is the durable home of record. Durability is a classification (a model) and lives in the concept document; the policies and ADRs that depend on it link back.

**Rationale:** The story and study policies still framed a closed record as a permanent reasoning trace ("never deleted"). ADRs changed the durable seat: approaches and knowledge moved into ADRs and final documents in summary. A discussion record remains useful as a reference through the implementing work but is not a maintained reference after it. "Reference-durable" reconciles the sub-policies with the concept-document durability classification and with the ADR as the surfacing home.

**Rejected alternatives:**

- *Keep the permanent-reasoning-record framing* -- intent failure. It contradicts the ADR-as-durable-home model and the operator's practice of cleaning up or subsuming records.
- *Classify discussion records as durable* -- intent failure. They are evidential work in progress that settles into ADRs and final documents; only the settled principle survives in the ADR.

**Edge cases / drivers:** More than one record overlapping, content more stale than current, and a naming conflict each justify cleanup and subsumption. The concept document is the single owner of the durability classification; the ADR records why.

## 2026-09-30 -- Rules are authoritative only where a policy canonically states them; concepts and ADRs describe but do not bind

**Decision:** A rule is authoritative only where a policy document canonically states it. A concept document or ADR may describe a rule in readable form, but it links to the policy and is not the rule's home. A rule with no policy home is descriptive, not binding. Separate the two by kind: a statement is a rule when it imposes an obligation a document or its author must meet, and belongs in policy; a statement is a model when it describes the system's structure as a consequence of earlier decisions, and belongs in a concept document, which states it readably and links the rules behind it.

**Rationale:** The declarative framing covered workflow rules against skill files and prompt templates. It did not cover the general case: a rule that lives only in a concept document or an ADR, or that exists only implicitly across several documents. The document promotion topology -- a discussion promotes to an ADR, an ADR informs a concept, a concept feeds an architecture document -- was spread across `adr_policy.md` and `documentation_policy.md` with no single home. It is a view, the accumulated consequence of individual ADR decisions, so it belongs in a concept document. Its edges are obligations -- when an ADR must be spawned, what an ADR owns -- and each is a rule that must have exactly one policy home. The authority principle gives a decisive test: any MUST that lives in a concept or ADR without a policy home, or any rule stated twice, is a defect a review can flag.

**Rejected alternatives:**

- *Let concepts and ADRs be authoritative in their own right* -- recreates the cross-document gap and the duplicate-content defect the framing exists to remove.

## 2026-07-21 -- Policies state rules declaratively; rationale lives in ADRs

**Decision:** Policy files under `docs/operations/` state rules declaratively, not as design records. Rationale and justification are concentrated in a single steering sentence per document. Correction forms and format rules live in the type-specific policy, not in a general index.

**Rationale:** The `docs/operations/` policies were written incrementally, each session adding the rule structure it needed, which produced: duplicated correction formats restated across `documentation_policy.md`, `handover_policy.md`, `study_policy.md`, and `roadmap_policy.md` (changed only in lockstep); mixed rationale and rule, making grep-targeting hard; procedural drift (execution guidance embedded in policy constraints); and no central home for the principles of how policies relate (one rule one owner, no bridge documents, type-specific ownership). Adopting the declarative framing gives one rationale anchor -- policy files stop explaining themselves, which compacts each file and makes "one rule, one owner" checkable by review: does this rule duplicate another file? If yes, one must be a link and the other the owner.

**Rejected alternatives:**

- *Keep the current framing, fix overlaps editorially per session* -- no
  governing principle to prevent re-divergence; each agent re-derives the approach from the same overlaps.
- *Merge all policies into one `operations_policy.md`* -- eliminates
  cross-file duplication but loses grep-targetability at the file level and creates a monolithic reference; violates the documentation policy's unnamed-block rules.

**Edge cases / drivers:** Risk of over-trimming: a policy too terse loses context for why the rule exists -- mitigated by the steering sentence per document. The boundary between "what the rule is" and "how to execute it" belongs to type-specific policies (e.g. `handover_policy.md` owns handover correction forms; `documentation_policy.md` provides a link-only index).
