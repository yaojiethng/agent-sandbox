# Policy Declarative Framing

**Current:** 2026-07-21

## 2026-07-21 -- Policies state rules declaratively; rationale lives in ADRs

**Decision:** Policy files under `docs/operations/` state rules declaratively, not as design records. Rationale and justification are concentrated in a single steering sentence per document. Correction forms and format rules live in the type-specific policy, not in a general index.

**Rationale:** The `docs/operations/` policies were written incrementally, each session adding the rule structure it needed, which produced: duplicated correction formats restated across `documentation_policy.md`, `handover_policy.md`, `study_policy.md`, and `roadmap_policy.md` (changed only in lockstep); mixed rationale and rule, making grep-targeting hard; procedural drift (execution guidance embedded in policy constraints); and no central home for the principles of how policies relate (one rule one owner, no bridge documents, type-specific ownership). Adopting the declarative framing gives one rationale anchor — policy files stop explaining themselves, which compacts each file and makes "one rule, one owner" checkable by review: does this rule duplicate another file? If yes, one must be a link and the other the owner.

**Rejected alternatives:**
- *Keep the current framing, fix overlaps editorially per session* — no
  governing principle to prevent re-divergence; each agent re-derives the approach from the same overlaps.
- *Merge all policies into one `operations_policy.md`* — eliminates
  cross-file duplication but loses grep-targetability at the file level and creates a monolithic reference; violates the documentation policy's unnamed-block rules.

**Edge cases / drivers:** Risk of over-trimming: a policy too terse loses context for why the rule exists — mitigated by the steering sentence per document. The boundary between "what the rule is" and "how to execute it" belongs to type-specific policies (e.g. `handover_policy.md` owns handover correction forms; `documentation_policy.md` provides a link-only index).
